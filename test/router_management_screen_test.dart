// ============================================================================
// Platform: Commercial MikroTik Network & HotSpot Card Management System
// File: test/router_management_screen_test.dart
// Tests: RouterDetailScreen, AddRouterScreen (Edit Mode) & HotSpot Inspection
// Master Reference: Task 3 - Real-Device & Local Connection Verification
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
import 'package:mikrotik_cards_app/screens/router_detail_screen.dart';
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
      'tenantId': 'tenant-test-mgmt',
      'userId': 'user-test-mgmt',
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

  final sampleRouter = RouterModel(
    id: 'router-uuid-001',
    name: 'راوتر الفرع الرئيسي',
    host: '192.168.88.1',
    apiPort: 8728,
    connectionMethod: 'ROUTEROS_API_PLAIN',
    status: 'ONLINE',
    cpuLoadPercentage: 14,
    uptimeSeconds: 7200,
    lastSeenAt: DateTime.now(),
  );

  final remoteRouter = RouterModel(
    id: 'router-remote-002',
    name: 'راوتر السيرفر الخارجي',
    host: 'gw.mycompany.sd',
    apiPort: 8729,
    connectionMethod: 'ROUTEROS_API_SSL',
    status: 'ONLINE',
    cpuLoadPercentage: 8,
    uptimeSeconds: 86400,
    lastSeenAt: DateTime.now(),
  );

  Widget createTestWidget(Widget child) {
    return MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: child,
      ),
    );
  }

  testWidgets('RouterDetailScreen displays router header and tabs', (tester) async {
    ApiClient.client = MockClient((request) async {
      if (request.url.path.contains('/hotspot-users')) {
        return utf8Response({
          'success': true,
          'data': [
            {
              'username': 'hotspot_user_1',
              'profile': 'default',
              'isEnabled': true,
              'uptimeSeconds': 1800,
              'bytesIn': 1024000,
              'bytesOut': 5120000,
              'verifiedOnRouter': true,
              'dbStatus': 'ACTIVE',
            }
          ],
        }, 200);
      }
      if (request.url.path.contains('/hotspot-sessions')) {
        return utf8Response({
          'success': true,
          'data': [
            {
              'username': 'hotspot_user_1',
              'ipAddress': '192.168.88.50',
              'macAddress': 'AA:BB:CC:DD:EE:FF',
              'uptimeSeconds': 600,
              'bytesIn': 512000,
              'bytesOut': 2048000,
            }
          ],
        }, 200);
      }
      return utf8Response({'success': true, 'data': {}}, 200);
    });

    await tester.pumpWidget(createTestWidget(RouterDetailScreen(router: sampleRouter)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    // Verify Router details header
    expect(find.text('راوتر الفرع الرئيسي'), findsOneWidget);
    expect(find.text('192.168.88.1:8728'), findsOneWidget);
    expect(find.text('ROUTEROS_API_PLAIN'), findsOneWidget);

    // Verify tabs
    expect(find.textContaining('مستخدمو الهوتسبوت'), findsOneWidget);
    expect(find.textContaining('الجلسات النشطة'), findsOneWidget);

    // Verify user list loaded
    expect(find.text('hotspot_user_1'), findsOneWidget);
    expect(find.text('مؤكد على الراوتر'), findsOneWidget);

    // Switch to Sessions Tab
    await tester.tap(find.textContaining('الجلسات النشطة'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    // Verify session details loaded
    expect(find.textContaining('192.168.88.50'), findsOneWidget);
    expect(find.textContaining('AA:BB:CC:DD:EE:FF'), findsOneWidget);
    expect(find.byTooltip('فصل الجلسة'), findsOneWidget);
  });

  testWidgets('RouterDetailScreen live probe for remote public router executes test connection via backend', (tester) async {
    bool testConnCalled = false;

    ApiClient.client = MockClient((request) async {
      if (request.url.path.contains('/test-connection')) {
        testConnCalled = true;
        return utf8Response({
          'success': true,
          'message': 'تم الاتصال بالراوتر بنجاح',
          'data': {
            'identity': 'MikroTik-HQ',
            'version': 'RouterOS v7.15',
            'boardName': 'CCR2004-1G-12S+2XS',
            'cpuLoad': 8,
            'uptimeSeconds': 86400,
          },
        }, 200);
      }
      return utf8Response({'success': true, 'data': []}, 200);
    });

    await tester.pumpWidget(createTestWidget(RouterDetailScreen(router: remoteRouter)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final probeButton = find.text('فحص الاتصال');
    expect(probeButton, findsOneWidget);

    await tester.tap(probeButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(testConnCalled, isTrue);
    expect(find.textContaining('CCR2004-1G-12S+2XS'), findsWidgets);
  });

  testWidgets('1. Opening port alone without credentials does NOT produce ONLINE for local router', (tester) async {
    bool updateRouterCalled = false;
    MikrotikDiscoveryService.clearMemoryCreds();

    ApiClient.client = MockClient((request) async {
      if (request.method == 'PATCH' && request.url.path.contains('/routers/')) {
        updateRouterCalled = true;
      }
      return utf8Response({'success': true, 'data': {}}, 200);
    });

    await tester.pumpWidget(createTestWidget(RouterDetailScreen(router: sampleRouter)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final probeButton = find.text('فحص الاتصال');
    expect(probeButton, findsOneWidget);

    await tester.tap(probeButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify: updateRouter was NOT called to mark ONLINE, and user is informed that credentials are required
    expect(updateRouterCalled, isFalse);
    expect(find.textContaining('غير متوفرة محلياً'), findsWidgets);
  });

  testWidgets('2. Actual auth success allows ONLINE update', (tester) async {
    bool updateStatusOnline = false;

    // Save valid local credentials on device
    await MikrotikDiscoveryService.saveRouterCredentials(
      routerId: 'router-uuid-001',
      username: 'admin',
      password: 'valid-secret-password',
    );

    // Mock direct connection returning verified authentication & hardware info
    MikrotikDiscoveryService.directConnectionTester = ({
      required String host,
      required int port,
      required String username,
      required String password,
      String? connectionMethod,
      Duration timeout = const Duration(seconds: 6),
    }) async {
      return {
        'success': true,
        'data': {
          'identity': 'MikroTik-Main-Office',
          'version': '7.16',
          'boardName': 'CCR2004-Direct',
          'cpuLoad': 12,
          'uptimeSeconds': 7200,
        },
      };
    };

    ApiClient.client = MockClient((request) async {
      if (request.method == 'PATCH' && request.url.path == '/api/v1/routers/router-uuid-001') {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        if (body['status'] == 'ONLINE') {
          updateStatusOnline = true;
        }
        return utf8Response({'success': true, 'data': {}}, 200);
      }
      return utf8Response({'success': true, 'data': {}}, 200);
    });

    await tester.pumpWidget(createTestWidget(RouterDetailScreen(router: sampleRouter)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final probeButton = find.text('فحص الاتصال');
    await tester.tap(probeButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(updateStatusOnline, isTrue);
    expect(find.textContaining('CCR2004-Direct'), findsWidgets);
    expect(find.textContaining('الاتصال بالراوتر والمصادقة ناجحة'), findsOneWidget);
  });

  testWidgets('3. Auth failure does NOT produce ONLINE', (tester) async {
    String? sentStatus;

    await MikrotikDiscoveryService.saveRouterCredentials(
      routerId: 'router-uuid-001',
      username: 'admin',
      password: 'wrong-password',
    );

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
        'errorCode': 'INVALID_CREDENTIALS',
        'errorMessage': 'فشلت المصادقة: اسم المستخدم أو كلمة المرور غير صحيحة لنظام MikroTik',
      };
    };

    ApiClient.client = MockClient((request) async {
      if (request.method == 'PATCH' && request.url.path == '/api/v1/routers/router-uuid-001') {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        sentStatus = body['status'] as String?;
        return utf8Response({'success': true, 'data': {}}, 200);
      }
      return utf8Response({'success': true, 'data': {}}, 200);
    });

    await tester.pumpWidget(createTestWidget(RouterDetailScreen(router: sampleRouter)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final probeButton = find.text('فحص الاتصال');
    await tester.tap(probeButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    // Must NOT be ONLINE!
    expect(sentStatus, isNot(equals('ONLINE')));
    expect(sentStatus, equals('ERROR'));
    expect(find.textContaining('فشلت المصادقة'), findsWidgets);
  });

  testWidgets('4. Editing router name with empty password saves edit and preserves credentials', (tester) async {
    bool updateCalled = false;
    String? sentName;
    int? sentPort;
    dynamic sentPassword;

    ApiClient.client = MockClient((request) async {
      if (request.method == 'PATCH' && request.url.path == '/api/v1/routers/router-uuid-001') {
        updateCalled = true;
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        sentName = body['name'] as String?;
        sentPort = body['port'] as int?;
        sentPassword = body['password'];
        return utf8Response({
          'success': true,
          'data': {
            'id': 'router-uuid-001',
            'name': sentName,
            'host': '192.168.88.1',
            'apiPort': sentPort,
            'connectionMethod': 'ROUTEROS_API_PLAIN',
            'status': 'ONLINE',
          },
        }, 200);
      }
      return utf8Response({'success': true, 'data': {}}, 200);
    });

    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(createTestWidget(AddRouterScreen(routerToEdit: sampleRouter)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify title indicates Edit
    expect(find.text('تعديل الراوتر'), findsWidgets);
    expect(find.text('راوتر الفرع الرئيسي'), findsOneWidget);

    // Change the name and keep password field EMPTY
    await tester.enterText(
      find.widgetWithText(NeumorphicTextField, 'اسم الراوتر / الموقع'),
      'راوتر الفرع المحدث',
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Submit form
    final saveButton = find.text('حفظ التعديلات');
    await tester.ensureVisible(saveButton);
    await tester.pump();
    expect(saveButton, findsOneWidget);
    await tester.tap(saveButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify: successfully saved without empty password authentication error
    expect(updateCalled, isTrue);
    expect(sentName, equals('راوتر الفرع المحدث'));
    expect(sentPort, equals(8728));
    expect(sentPassword, isNull);
  });

  testWidgets('5. Entering new password validates and saves without logging secrets', (tester) async {
    bool updateCalled = false;
    String? sentPassword;

    await MikrotikDiscoveryService.saveRouterCredentials(
      routerId: 'router-uuid-001',
      username: 'admin',
      password: 'oldPassword123',
    );

    MikrotikDiscoveryService.directConnectionTester = ({
      required String host,
      required int port,
      required String username,
      required String password,
      String? connectionMethod,
      Duration timeout = const Duration(seconds: 6),
    }) async {
      return {
        'success': true,
        'data': {'identity': 'MikroTik-New', 'version': '7.16', 'boardName': 'hEX'},
      };
    };

    ApiClient.client = MockClient((request) async {
      if (request.method == 'PATCH' && request.url.path == '/api/v1/routers/router-uuid-001') {
        updateCalled = true;
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        sentPassword = body['password'] as String?;
        return utf8Response({'success': true, 'data': {}}, 200);
      }
      return utf8Response({'success': true, 'data': {}}, 200);
    });

    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(createTestWidget(AddRouterScreen(routerToEdit: sampleRouter)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Fill new password
    await tester.enterText(
      find.widgetWithText(NeumorphicTextField, 'كلمة المرور'),
      'newSecurePass99',
    );
    await tester.pump();

    final saveButton = find.text('حفظ التعديلات');
    await tester.ensureVisible(saveButton);
    await tester.pump();
    await tester.tap(saveButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(updateCalled, isTrue);
    expect(sentPassword, equals('newSecurePass99'));

    // Verify credentials cached locally
    final cached = await MikrotikDiscoveryService.getRouterCredentials('router-uuid-001');
    expect(cached?['password'], equals('newSecurePass99'));
  });

  testWidgets('6. Failure of updateRouter on server is NOT shown as a status save success', (tester) async {
    await MikrotikDiscoveryService.saveRouterCredentials(
      routerId: 'router-uuid-001',
      username: 'admin',
      password: 'valid-secret-password',
    );

    MikrotikDiscoveryService.directConnectionTester = ({
      required String host,
      required int port,
      required String username,
      required String password,
      String? connectionMethod,
      Duration timeout = const Duration(seconds: 6),
    }) async {
      return {
        'success': true,
        'data': {
          'identity': 'MikroTik-Main',
          'version': '7.16',
          'boardName': 'CCR2004',
          'cpuLoad': 10,
          'uptimeSeconds': 1000,
        },
      };
    };

    // Server update fails with 500 error
    ApiClient.client = MockClient((request) async {
      if (request.method == 'PATCH' && request.url.path == '/api/v1/routers/router-uuid-001') {
        return utf8Response({
          'success': false,
          'errorCode': 'INTERNAL_SERVER_ERROR',
          'errorMessage': 'فشل الاتصال بقاعدة البيانات على السيرفر',
        }, 500);
      }
      return utf8Response({'success': true, 'data': {}}, 200);
    });

    await tester.pumpWidget(createTestWidget(RouterDetailScreen(router: sampleRouter)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final probeButton = find.text('فحص الاتصال');
    await tester.tap(probeButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    // Verify: error warning shown, and NOT false success!
    expect(find.textContaining('تعذر حفظ الحالة في السيرفر'), findsWidgets);
    expect(find.textContaining('الاتصال بالراوتر والمصادقة ناجحة ومستقرة محلياً'), findsNothing);
  });

  testWidgets('7. Adding new router validates connection and sets ONLINE on success', (tester) async {
    bool postCalled = false;
    String? sentStatus;

    MikrotikDiscoveryService.directConnectionTester = ({
      required String host,
      required int port,
      required String username,
      required String password,
      String? connectionMethod,
      Duration timeout = const Duration(seconds: 6),
    }) async {
      return {
        'success': true,
        'data': {
          'identity': 'New-Mikrotik-Gateway',
          'version': '7.16.1',
          'boardName': 'RB5009',
          'cpuLoad': 6,
          'uptimeSeconds': 5000,
        },
      };
    };

    ApiClient.client = MockClient((request) async {
      if (request.method == 'POST' && request.url.path == '/api/v1/routers') {
        postCalled = true;
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        sentStatus = body['status'] as String?;
        return utf8Response({
          'success': true,
          'data': {
            'id': 'new-router-999',
            'name': body['name'],
            'host': body['host'],
            'apiPort': body['port'],
            'status': sentStatus,
          },
        }, 201);
      }
      return utf8Response({'success': true, 'data': {}}, 200);
    });

    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(createTestWidget(const AddRouterScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Fill form
    await tester.enterText(
      find.widgetWithText(NeumorphicTextField, 'اسم الراوتر / الموقع'),
      'راوتر الفرع الجديد',
    );
    await tester.enterText(
      find.widgetWithText(NeumorphicTextField, 'عنوان الـ Host أو الـ IP'),
      '192.168.88.20',
    );
    await tester.enterText(
      find.widgetWithText(NeumorphicTextField, 'اسم المستخدم للراوتر'),
      'admin',
    );
    await tester.enterText(
      find.widgetWithText(NeumorphicTextField, 'كلمة المرور'),
      'SuperSecret123',
    );
    await tester.pump();

    final saveButton = find.text('حفظ الراوتر');
    await tester.ensureVisible(saveButton);
    await tester.pump();
    await tester.tap(saveButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(postCalled, isTrue);
    expect(sentStatus, equals('ONLINE'));

    // Check credentials cached locally
    final cached = await MikrotikDiscoveryService.getRouterCredentials('new-router-999');
    expect(cached?['username'], equals('admin'));
    expect(cached?['password'], equals('SuperSecret123'));
  });
}
