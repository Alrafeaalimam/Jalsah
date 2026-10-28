// ============================================================================
// Platform: Commercial MikroTik Network & HotSpot Card Management System (Jalsah)
// File: test/router_verified_status_flow_test.dart
// Tests: Verified Router Status Flow:
//   1. Real connection test succeeds -> save router -> sends status: 'ONLINE'
//   2. Dashboard renders verified router with 'متصل' (ONLINE) badge
//   3. Connection test fails -> save router -> sends status: 'OFFLINE' (Requirement 5)
//   4. Dashboard renders unverified router with 'غير متصل' (OFFLINE) badge
//   5. Persisted status is maintained after reloading router list (GET /routers)
//   6. Altering inputs after test invalidates verification and rejects fake ONLINE
// ============================================================================

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mikrotik_cards_app/models/router_model.dart';
import 'package:mikrotik_cards_app/screens/add_router_screen.dart';
import 'package:mikrotik_cards_app/screens/dashboard_screen.dart';
import 'package:mikrotik_cards_app/services/api_client.dart';
import 'package:mikrotik_cards_app/services/mikrotik_discovery_service.dart';
import 'package:mikrotik_cards_app/widgets/neumorphic_text_field.dart';

http.Response utf8Response(Map<String, dynamic> data, int statusCode) {
  return http.Response.bytes(
    utf8.encode(jsonEncode(data)),
    statusCode,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});

    try {
      final fontLoaderCairo = FontLoader('Cairo');
      final arabicFontBytes =
          File('/system/fonts/NotoNaskhArabicUI-Regular.ttf').readAsBytesSync();
      fontLoaderCairo
          .addFont(Future.value(ByteData.sublistView(arabicFontBytes)));

      final robotoBytes = File(
              '/data/data/com.termux/files/home/flutter/bin/cache/dart-sdk/bin/resources/devtools/assets/fonts/Roboto/Roboto-Regular.ttf')
          .readAsBytesSync();
      fontLoaderCairo.addFont(Future.value(ByteData.sublistView(robotoBytes)));
      await fontLoaderCairo.load();

      final iconLoader = FontLoader('MaterialIcons');
      final iconBytes = File(
              '/data/data/com.termux/files/home/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf')
          .readAsBytesSync();
      iconLoader.addFont(Future.value(ByteData.sublistView(iconBytes)));
      await iconLoader.load();
    } catch (_) {}
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    MikrotikDiscoveryService.resetTestStorage();
    MikrotikDiscoveryService.directConnectionTester = null;
    MikrotikDiscoveryService.probeHostTester = null;

    final token = base64Url.encode(utf8.encode(jsonEncode({
      'tenantId': 'tenant-verified-test',
      'userId': 'user-verified-test',
      'role': 'TENANT_ADMIN',
    }))).replaceAll('=', '');
    ApiClient.setAuthToken('eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.$token.mock_sig');
  });

  tearDown(() {
    ApiClient.resetClient();
    ApiClient.setAuthToken(null);
    MikrotikDiscoveryService.resetTestStorage();
    MikrotikDiscoveryService.directConnectionTester = null;
    MikrotikDiscoveryService.probeHostTester = null;
  });

  Widget createTestWidget(Widget child) {
    return MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: child,
      ),
    );
  }

  group('Router Verified Status Flow Tests', () {
    // ------------------------------------------------------------------------
    // Requirement 6.1: Real connection test succeeds -> save router -> status ONLINE
    // ------------------------------------------------------------------------
    testWidgets('6.1 Real connection test succeeds then router is saved with status ONLINE', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      bool testConnectionCalled = false;
      bool createRouterCalled = false;
      Map<String, dynamic>? createPayload;

      // Mock direct local connection tester simulating authentic handshake with router
      MikrotikDiscoveryService.directConnectionTester = ({
        required String host,
        required int port,
        required String username,
        required String password,
        String? connectionMethod,
        Duration timeout = const Duration(seconds: 6),
      }) async {
        testConnectionCalled = true;
        return {
          'success': true,
          'data': {
            'identity': 'MikroTik-Main-Office',
            'version': '7.15.2',
            'boardName': 'RB5009UG+S+IN',
            'cpuLoad': 12,
            'uptimeSeconds': 86400,
            'isDirectLocal': true,
          },
        };
      };

      ApiClient.client = MockClient((request) async {
        if (request.method == 'POST' && request.url.path == '/api/v1/routers') {
          createRouterCalled = true;
          createPayload = jsonDecode(request.body) as Map<String, dynamic>;
          return utf8Response({
            'success': true,
            'message': 'Router created successfully',
            'data': {
              'id': 'router-verified-101',
              'tenantId': 'tenant-verified-test',
              'name': createPayload!['name'],
              'host': createPayload!['host'],
              'port': createPayload!['port'],
              'connectionMethod': createPayload!['connectionMethod'] ?? 'ROUTEROS_API_PLAIN',
              'status': createPayload!['status'] ?? 'OFFLINE',
              'routerOsVersion': createPayload!['routerOsVersion'],
              'boardModel': createPayload!['boardModel'],
              'cpuLoadPercentage': createPayload!['cpuLoadPercentage'],
              'uptimeSeconds': createPayload!['uptimeSeconds'],
              'lastSeenAt': DateTime.now().toIso8601String(),
              'createdAt': DateTime.now().toIso8601String(),
              'updatedAt': DateTime.now().toIso8601String(),
            },
          }, 201);
        }
        return utf8Response({'success': true, 'data': {}}, 200);
      });

      await tester.pumpWidget(createTestWidget(const AddRouterScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Fill in Router form using NeumorphicTextField
      await tester.enterText(
        find.widgetWithText(NeumorphicTextField, 'اسم الراوتر / الموقع'),
        'راوتر الفرع الرئيسي',
      );
      await tester.enterText(
        find.widgetWithText(NeumorphicTextField, 'عنوان الـ Host أو الـ IP'),
        '192.168.88.1',
      );
      await tester.enterText(
        find.widgetWithText(NeumorphicTextField, 'اسم المستخدم للراوتر'),
        'admin',
      );
      await tester.enterText(
        find.widgetWithText(NeumorphicTextField, 'كلمة المرور'),
        'secure_pass_123',
      );
      await tester.pump();

      // Click "اختبار الاتصال"
      final testButton = find.text('اختبار الاتصال');
      expect(testButton, findsOneWidget);
      await tester.ensureVisible(testButton);
      await tester.tap(testButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(testConnectionCalled, isTrue);
      expect(find.textContaining('تم الاتصال بنجاح'), findsWidgets);

      // Now click "حفظ الراوتر"
      final saveButton = find.text('حفظ الراوتر');
      expect(saveButton, findsOneWidget);
      await tester.ensureVisible(saveButton);
      await tester.tap(saveButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Verify payload sent to Backend contains ONLINE status and verified hardware specs
      expect(createRouterCalled, isTrue);
      expect(createPayload, isNotNull);
      expect(createPayload!['status'], equals('ONLINE'));
      expect(createPayload!['boardModel'], equals('RB5009UG+S+IN'));
      expect(createPayload!['routerOsVersion'], equals('7.15.2'));
      expect(createPayload!['cpuLoadPercentage'], equals(12));
      expect(createPayload!['uptimeSeconds'], equals(86400));
    });

    // ------------------------------------------------------------------------
    // Requirement 6.1 (cont): Dashboard renders router with ONLINE status as 'متصل'
    // ------------------------------------------------------------------------
    testWidgets('6.2 Dashboard displays router with ONLINE status as متصل badge', (tester) async {
      final onlineRouter = RouterModel(
        id: 'router-verified-101',
        name: 'راوتر الفرع الرئيسي',
        host: '192.168.88.1',
        apiPort: 8728,
        connectionMethod: 'ROUTEROS_API_PLAIN',
        status: 'ONLINE',
        boardModel: 'RB5009UG+S+IN',
        routerOsVersion: '7.15.2',
        cpuLoadPercentage: 12,
        uptimeSeconds: 86400,
        lastSeenAt: DateTime.now(),
      );

      expect(onlineRouter.isOnline, isTrue);

      ApiClient.client = MockClient((request) async {
        if (request.url.path == '/api/v1/routers') {
          return utf8Response({
            'success': true,
            'data': [onlineRouter.toJson()],
          }, 200);
        }
        if (request.url.path.contains('/stats/dashboard')) {
          return utf8Response({
            'success': true,
            'data': {
              'activeCards': 10,
              'activeSessions': 5,
              'todayRevenue': 150.0,
              'totalRouters': 1,
              'onlineRouters': 1,
            },
          }, 200);
        }
        return utf8Response({'success': true, 'data': {}}, 200);
      });

      await tester.pumpWidget(createTestWidget(const DashboardScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Router card is displayed as 'متصل'
      expect(find.text('راوتر الفرع الرئيسي'), findsOneWidget);
      expect(find.text('متصل'), findsWidgets);
    });

    // ------------------------------------------------------------------------
    // Requirement 6.2: Connection fails -> router saved as OFFLINE
    // ------------------------------------------------------------------------
    testWidgets('6.3 Connection failure saves router as OFFLINE and does NOT mark ONLINE', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      bool createRouterCalled = false;
      Map<String, dynamic>? createPayload;

      // Mock direct local connection tester simulating unreachable host / timeout
      MikrotikDiscoveryService.directConnectionTester = ({
        required String host,
        required int port,
        required String username,
        required String password,
        String? connectionMethod,
        Duration timeout = const Duration(seconds: 6),
      }) async {
        return {
          'success': false,
          'errorCode': 'TIMEOUT',
          'errorMessage': 'تعذر الاتصال بالراوتر (تجاوز مهلة الانتظار)',
        };
      };

      ApiClient.client = MockClient((request) async {
        if (request.method == 'POST' && request.url.path == '/api/v1/routers') {
          createRouterCalled = true;
          createPayload = jsonDecode(request.body) as Map<String, dynamic>;
          return utf8Response({
            'success': true,
            'data': {
              'id': 'router-offline-102',
              'tenantId': 'tenant-verified-test',
              'name': createPayload!['name'],
              'host': createPayload!['host'],
              'port': createPayload!['port'],
              'connectionMethod': createPayload!['connectionMethod'] ?? 'ROUTEROS_API_PLAIN',
              'status': createPayload!['status'] ?? 'OFFLINE',
              'createdAt': DateTime.now().toIso8601String(),
              'updatedAt': DateTime.now().toIso8601String(),
            },
          }, 201);
        }
        return utf8Response({'success': true, 'data': {}}, 200);
      });

      await tester.pumpWidget(createTestWidget(const AddRouterScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Fill in Router form
      await tester.enterText(
        find.widgetWithText(NeumorphicTextField, 'اسم الراوتر / الموقع'),
        'راوتر المخزن غير المتصل',
      );
      await tester.enterText(
        find.widgetWithText(NeumorphicTextField, 'عنوان الـ Host أو الـ IP'),
        '192.168.99.1',
      );
      await tester.enterText(
        find.widgetWithText(NeumorphicTextField, 'اسم المستخدم للراوتر'),
        'admin',
      );
      await tester.enterText(
        find.widgetWithText(NeumorphicTextField, 'كلمة المرور'),
        'pass_warehouse',
      );
      await tester.pump();

      // Test connection fails
      final testButton = find.text('اختبار الاتصال');
      await tester.ensureVisible(testButton);
      await tester.tap(testButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.textContaining('تعذر الاتصال بالراوتر'), findsWidgets);

      // Now save the router anyway (allowed for offline configuration)
      final saveButton = find.text('حفظ الراوتر');
      await tester.ensureVisible(saveButton);
      await tester.tap(saveButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Must be saved with status 'OFFLINE'
      expect(createRouterCalled, isTrue);
      expect(createPayload, isNotNull);
      expect(createPayload!['status'], equals('OFFLINE'));
    });

    // ------------------------------------------------------------------------
    // Requirement 6.2 (cont): Dashboard renders router with OFFLINE status as 'غير متصل'
    // ------------------------------------------------------------------------
    testWidgets('6.4 Dashboard displays router with OFFLINE status as غير متصل badge', (tester) async {
      final offlineRouter = RouterModel(
        id: 'router-offline-102',
        name: 'راوتر المخزن غير المتصل',
        host: '192.168.99.1',
        apiPort: 8728,
        status: 'OFFLINE',
      );

      expect(offlineRouter.isOnline, isFalse);

      ApiClient.client = MockClient((request) async {
        if (request.url.path == '/api/v1/routers') {
          return utf8Response({
            'success': true,
            'data': [offlineRouter.toJson()],
          }, 200);
        }
        if (request.url.path.contains('/stats/dashboard')) {
          return utf8Response({
            'success': true,
            'data': {
              'activeCards': 0,
              'activeSessions': 0,
              'todayRevenue': 0.0,
              'totalRouters': 1,
              'onlineRouters': 0,
            },
          }, 200);
        }
        return utf8Response({'success': true, 'data': {}}, 200);
      });

      await tester.pumpWidget(createTestWidget(const DashboardScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Router card is displayed as 'غير متصل'
      expect(find.text('راوتر المخزن غير المتصل'), findsOneWidget);
      expect(find.text('غير متصل'), findsWidgets);
    });

    // ------------------------------------------------------------------------
    // Requirement 6.3: Reloading router list maintains persisted status
    // ------------------------------------------------------------------------
    test('6.5 Reloading router list maintains persisted ONLINE status from backend', () async {
      final persistedRouterData = {
        'id': 'router-uuid-persisted',
        'tenantId': 'tenant-verified-test',
        'name': 'الراوتر المحفوظ والمؤكد',
        'host': '192.168.88.1',
        'port': 8728,
        'connectionMethod': 'ROUTEROS_API_PLAIN',
        'status': 'ONLINE',
        'routerOsVersion': '7.15.2',
        'boardModel': 'CCR2004-1G-12S+2XS',
        'cpuLoadPercentage': 7,
        'uptimeSeconds': 120000,
        'lastSeenAt': DateTime.now().toIso8601String(),
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      };

      ApiClient.client = MockClient((request) async {
        if (request.method == 'GET' && request.url.path == '/api/v1/routers') {
          return utf8Response({
            'success': true,
            'data': [persistedRouterData],
          }, 200);
        }
        return utf8Response({'success': true, 'data': []}, 200);
      });

      // First load (e.g. initial fetch)
      final firstFetch = await ApiClient.getRouters();
      expect(firstFetch['success'], isTrue);
      final list1 = firstFetch['data'] as List<dynamic>;
      expect(list1.length, equals(1));
      final router1 = list1.first as RouterModel;
      expect(router1.status, equals('ONLINE'));
      expect(router1.isOnline, isTrue);
      expect(router1.boardModel, equals('CCR2004-1G-12S+2XS'));

      // Re-fetching routers (e.g. app reopened or pulled to refresh)
      final secondFetch = await ApiClient.getRouters();
      expect(secondFetch['success'], isTrue);
      final list2 = secondFetch['data'] as List<dynamic>;
      expect(list2.length, equals(1));
      final router2 = list2.first as RouterModel;
      expect(router2.status, equals('ONLINE'));
      expect(router2.isOnline, isTrue);
      expect(router2.boardModel, equals('CCR2004-1G-12S+2XS'));
      expect(router2.uptimeSeconds, equals(120000));
    });

    // ------------------------------------------------------------------------
    // Requirement 6.4: Modifying inputs after test or fake mock cannot produce ONLINE
    // ------------------------------------------------------------------------
    testWidgets('6.6 Altering host/credentials after test invalidates verification and prevents fake ONLINE status', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      Map<String, dynamic>? createPayload;
      int testCount = 0;

      MikrotikDiscoveryService.directConnectionTester = ({
        required String host,
        required int port,
        required String username,
        required String password,
        String? connectionMethod,
        Duration timeout = const Duration(seconds: 6),
      }) async {
        testCount++;
        if (host == '192.168.88.1' && password == 'good_pass') {
          return {
            'success': true,
            'data': {
              'identity': 'Tested-Router',
              'version': '7.15',
              'boardName': 'hEX',
            },
          };
        }
        return {
          'success': false,
          'errorCode': 'HOST_UNREACHABLE',
          'errorMessage': 'العنوان غير متاح',
        };
      };

      ApiClient.client = MockClient((request) async {
        if (request.method == 'POST' && request.url.path == '/api/v1/routers') {
          createPayload = jsonDecode(request.body) as Map<String, dynamic>;
          return utf8Response({
            'success': true,
            'data': {
              'id': 'router-tampered-103',
              'tenantId': 'tenant-verified-test',
              'name': createPayload!['name'],
              'host': createPayload!['host'],
              'port': createPayload!['port'],
              'status': createPayload!['status'] ?? 'OFFLINE',
            },
          }, 201);
        }
        return utf8Response({'success': true, 'data': {}}, 200);
      });

      await tester.pumpWidget(createTestWidget(const AddRouterScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Enter valid host & password and test
      await tester.enterText(
        find.widgetWithText(NeumorphicTextField, 'اسم الراوتر / الموقع'),
        'راوتر الفرع',
      );
      await tester.enterText(
        find.widgetWithText(NeumorphicTextField, 'عنوان الـ Host أو الـ IP'),
        '192.168.88.1',
      );
      await tester.enterText(
        find.widgetWithText(NeumorphicTextField, 'اسم المستخدم للراوتر'),
        'admin',
      );
      await tester.enterText(
        find.widgetWithText(NeumorphicTextField, 'كلمة المرور'),
        'good_pass',
      );
      await tester.pump();

      final testButton = find.text('اختبار الاتصال');
      await tester.ensureVisible(testButton);
      await tester.tap(testButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(testCount, equals(1));
      expect(find.textContaining('تم الاتصال بنجاح'), findsWidgets);

      // Now USER EDITS the host to an unverified address: '10.0.0.99'
      await tester.enterText(
        find.widgetWithText(NeumorphicTextField, 'عنوان الـ Host أو الـ IP'),
        '10.0.0.99',
      );
      await tester.pump();

      // Submit form
      final saveButton = find.text('حفظ الراوتر');
      await tester.ensureVisible(saveButton);
      await tester.tap(saveButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Verification: Pre-save check detects that host changed from tested host ('192.168.88.1' != '10.0.0.99')
      // It executes a fresh test on '10.0.0.99', which fails, so the router is saved as 'OFFLINE'
      expect(createPayload, isNotNull);
      expect(createPayload!['host'], equals('10.0.0.99'));
      expect(createPayload!['status'], equals('OFFLINE'));
    });
  });
}
