// ============================================================================
// Platform: Commercial MikroTik Network & HotSpot Card Management System (Jalsah)
// File: test/local_router_detail_test.dart
// Description: Unit & Widget tests for Local Router Details (fix/local-router-detail):
//  1. Fetching hotspot users directly on-device with limits and without extra fields.
//  2. Handling empty hotspot users list for local routers.
//  3. Fetching active sessions directly on-device.
//  4. Disconnecting active session strictly by full exact username matching.
//  5. Direct connection test reading board-name, version, CPU, uptime from /system/resource.
//  6. Handling local connection/auth failure with Arabic step name and retry button (NO backend fallback).
//  7. Ensuring public/remote routers retain the backend API path without change.
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
import 'package:mikrotik_cards_app/screens/router_detail_screen.dart';
import 'package:mikrotik_cards_app/services/api_client.dart';
import 'package:mikrotik_cards_app/services/mikrotik_discovery_service.dart';
import 'package:mikrotik_cards_app/services/routeros_binary_client.dart';

http.Response utf8Response(Map<String, dynamic> data, int statusCode) {
  return http.Response.bytes(
    utf8.encode(jsonEncode(data)),
    statusCode,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

Widget createTestWidget(Widget child) {
  return MaterialApp(
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: child,
    ),
  );
}

/// Fake RouterOsBinaryClient for strict command verification
class FakeLocalRouterOsClient extends RouterOsBinaryClient {
  final List<Map<String, String>> routerUsers = [];
  final List<Map<String, String>> activeSessions = [];
  final List<List<String>> executedSentences = [];

  bool failConnect = false;
  bool failLogin = false;

  FakeLocalRouterOsClient({
    required super.host,
    required super.port,
    super.useTls = false,
  });

  @override
  Future<void> connect() async {
    if (failConnect) {
      throw const SocketException('Connection refused');
    }
  }

  @override
  Future<bool> login(String username, String password) async {
    if (failLogin) {
      throw AuthException('invalid user name or password');
    }
    return true;
  }

  @override
  Future<List<Map<String, String>>> executeCommand(List<String> commandWords) async {
    executedSentences.add(List.from(commandWords));
    final cmd = commandWords[0];

    if (cmd == '/ip/hotspot/user/print') {
      String? nameFilter;
      for (final w in commandWords) {
        if (w.startsWith('?name=')) {
          nameFilter = w.substring(6);
        }
      }
      if (nameFilter != null) {
        return routerUsers.where((u) => u['name'] == nameFilter).toList();
      }
      return List.from(routerUsers);
    }

    if (cmd == '/ip/hotspot/active/print') {
      String? userFilter;
      for (final w in commandWords) {
        if (w.startsWith('?user=')) {
          userFilter = w.substring(6);
        }
      }
      if (userFilter != null) {
        return activeSessions.where((s) => s['user'] == userFilter).toList();
      }
      return List.from(activeSessions);
    }

    if (cmd == '/ip/hotspot/active/remove') {
      String? id;
      for (final w in commandWords) {
        if (w.startsWith('=.id=')) {
          id = w.substring(5);
        }
      }
      if (id != null) {
        activeSessions.removeWhere((s) => s['.id'] == id);
      }
      return [];
    }

    if (cmd == '/system/resource/print') {
      return [
        {
          'version': '7.16',
          'board-name': 'hAP ax^3',
          'cpu-load': '8',
          'uptime': '1d04:20:00',
        }
      ];
    }

    if (cmd == '/system/identity/print') {
      return [
        {'name': 'Branch-Router-Local'}
      ];
    }

    return [];
  }
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});

    try {
      final fontLoaderCairo = FontLoader('Cairo');
      final arabicFontBytes = File('/system/fonts/NotoNaskhArabicUI-Regular.ttf').readAsBytesSync();
      fontLoaderCairo.addFont(Future.value(ByteData.sublistView(arabicFontBytes)));
      await fontLoaderCairo.load();

      final iconLoader = FontLoader('MaterialIcons');
      final iconBytes = File(
        '/data/data/com.termux/files/home/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
      ).readAsBytesSync();
      iconLoader.addFont(Future.value(ByteData.sublistView(iconBytes)));
      await iconLoader.load();
    } catch (_) {}
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    MikrotikDiscoveryService.resetTestStorage();
    MikrotikDiscoveryService.directConnectionTester = ({
      required String host,
      required int port,
      required String username,
      required String password,
      String? connectionMethod,
      Duration timeout = MikrotikDiscoveryService.defaultProbeTimeout,
    }) async {
      return {
        'success': true,
        'data': {
          'boardName': 'RB750Gr3',
          'version': '7.15.3',
          'cpuLoad': 8,
          'uptimeSeconds': 3600,
          'identity': 'TestRouter',
        },
      };
    };
    MikrotikDiscoveryService.hotspotUsersDirectTester = null;
    MikrotikDiscoveryService.hotspotSessionsDirectTester = null;
    MikrotikDiscoveryService.disconnectHotspotSessionDirectTester = null;
    MikrotikDiscoveryService.toggleHotspotUserDirectTester = null;

    final token = base64Url.encode(utf8.encode(jsonEncode({
      'tenantId': 't-local-detail',
      'userId': 'u-local-detail',
      'role': 'TENANT_ADMIN',
    }))).replaceAll('=', '');
    ApiClient.setAuthToken('eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.$token.mock_sig');
  });

  tearDown(() {
    ApiClient.resetClient();
    ApiClient.setAuthToken(null);
    MikrotikDiscoveryService.resetTestStorage();
    MikrotikDiscoveryService.directConnectionTester = null;
    MikrotikDiscoveryService.hotspotUsersDirectTester = null;
    MikrotikDiscoveryService.hotspotSessionsDirectTester = null;
    MikrotikDiscoveryService.disconnectHotspotSessionDirectTester = null;
    MikrotikDiscoveryService.toggleHotspotUserDirectTester = null;
  });

  final localRouter = RouterModel(
    id: 'router-local-101',
    name: 'راوتر الشبكة المحلية',
    host: '192.168.88.1',
    apiPort: 8728,
    connectionMethod: 'ROUTEROS_API_PLAIN',
    status: 'ONLINE',
    cpuLoadPercentage: 8,
    uptimeSeconds: 3600,
  );

  final publicRouter = RouterModel(
    id: 'router-public-202',
    name: 'راوتر السيرفر الخارجي',
    host: '197.234.1.1',
    apiPort: 8729,
    connectionMethod: 'ROUTEROS_API_SSL',
    status: 'ONLINE',
  );

  group('Requirement 2.1 & 2.2: HotSpot Users direct fetch and empty state', () {
    testWidgets('Local router fetches users directly on-device and does NOT call backend', (tester) async {
      await MikrotikDiscoveryService.saveRouterCredentials(
        routerId: localRouter.id,
        username: 'admin',
        password: 'password123',
      );

      bool backendUsersCalled = false;
      ApiClient.client = MockClient((request) async {
        if (request.url.path.contains('/hotspot-users')) {
          backendUsersCalled = true;
          return utf8Response({'success': false, 'errorMessage': 'محظور في المرحلة الأولى'}, 403);
        }
        return utf8Response({'success': true, 'data': {}}, 200);
      });

      MikrotikDiscoveryService.hotspotUsersDirectTester = ({
        required String host,
        required int port,
        required String username,
        required String password,
        String? connectionMethod,
        String? searchName,
        int? limit,
      }) async {
        return {
          'success': true,
          'data': [
            {
              'id': '*1',
              'username': 'client_voucher_77',
              'profile': 'gold_10mb',
              'uptime': '2h15m',
              'uptimeSeconds': 8100,
              'bytesIn': 1048576,
              'bytesOut': 2097152,
              'disabled': false,
              'isEnabled': true,
              'verifiedOnRouter': true,
            }
          ],
        };
      };

      await tester.pumpWidget(createTestWidget(RouterDetailScreen(router: localRouter)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Tap on Hotspot Users tab
      final usersTab = find.textContaining('مستخدمو الهوتسبوت');
      expect(usersTab, findsOneWidget);
      await tester.tap(usersTab);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify user is displayed
      expect(find.text('client_voucher_77'), findsOneWidget);
      expect(find.textContaining('gold_10mb'), findsOneWidget);
      expect(find.text('مؤكد على الراوتر'), findsOneWidget);

      // Verify cloud backend was NEVER called for local router
      expect(backendUsersCalled, isFalse);
    });

    testWidgets('Local router handles empty users list gracefully without falling back to cloud', (tester) async {
      await MikrotikDiscoveryService.saveRouterCredentials(
        routerId: localRouter.id,
        username: 'admin',
        password: 'password123',
      );

      bool backendUsersCalled = false;
      ApiClient.client = MockClient((request) async {
        if (request.url.path.contains('/hotspot-users')) {
          backendUsersCalled = true;
        }
        return utf8Response({'success': true, 'data': {}}, 200);
      });

      MikrotikDiscoveryService.hotspotUsersDirectTester = ({
        required String host,
        required int port,
        required String username,
        required String password,
        String? connectionMethod,
        String? searchName,
        int? limit,
      }) async {
        return {
          'success': true,
          'data': [],
        };
      };

      await tester.pumpWidget(createTestWidget(RouterDetailScreen(router: localRouter)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Tap HotSpot Users tab
      await tester.tap(find.textContaining('مستخدمو الهوتسبوت'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('لا يوجد مستخدمو هوتسبوت'), findsOneWidget);
      expect(backendUsersCalled, isFalse);
    });
  });

  group('Requirement 2.2: Active Sessions direct fetch', () {
    testWidgets('Local router fetches active sessions directly on-device and does NOT call backend', (tester) async {
      await MikrotikDiscoveryService.saveRouterCredentials(
        routerId: localRouter.id,
        username: 'admin',
        password: 'password123',
      );

      bool backendSessionsCalled = false;
      ApiClient.client = MockClient((request) async {
        if (request.url.path.contains('/hotspot-sessions')) {
          backendSessionsCalled = true;
        }
        return utf8Response({'success': true, 'data': {}}, 200);
      });

      MikrotikDiscoveryService.hotspotSessionsDirectTester = ({
        required String host,
        required int port,
        required String username,
        required String password,
        String? connectionMethod,
      }) async {
        return {
          'success': true,
          'data': [
            {
              'id': '*s1',
              'username': 'active_user_55',
              'ipAddress': '192.168.88.55',
              'macAddress': 'DC:2C:6E:11:22:33',
              'uptime': '45m',
              'uptimeSeconds': 2700,
              'bytesIn': 500000,
              'bytesOut': 1500000,
              'loginBy': 'http-chap',
            }
          ],
        };
      };

      await tester.pumpWidget(createTestWidget(RouterDetailScreen(router: localRouter)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Tap on Active Sessions tab
      final sessionsTab = find.textContaining('الجلسات النشطة');
      expect(sessionsTab, findsOneWidget);
      await tester.tap(sessionsTab);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify active session is displayed
      expect(find.text('active_user_55'), findsOneWidget);
      expect(find.textContaining('192.168.88.55'), findsOneWidget);
      expect(find.textContaining('DC:2C:6E:11:22:33'), findsOneWidget);

      // Verify cloud backend was NEVER called
      expect(backendSessionsCalled, isFalse);
    });
  });

  group('Requirement 2.3: Disconnect session strictly matches full username', () {
    test('RouterOsBinaryClient disconnectHotspotSession only deletes exact matching username', () async {
      final fakeClient = FakeLocalRouterOsClient(
        host: '192.168.88.1',
        port: 8728,
        useTls: false,
      );

      fakeClient.activeSessions.addAll([
        {'.id': '*1', 'user': 'user12', 'address': '192.168.88.12'},
        {'.id': '*2', 'user': 'user1_extra', 'address': '192.168.88.13'},
        {'.id': '*3', 'user': 'user1', 'address': '192.168.88.14'},
      ]);

      final ok = await fakeClient.disconnectHotspotSession('user1');
      expect(ok, isTrue);

      // *3 (user1) must be removed
      expect(fakeClient.activeSessions.any((s) => s['user'] == 'user1'), isFalse);
      // user12 and user1_extra must be intact!
      expect(fakeClient.activeSessions.any((s) => s['user'] == 'user12'), isTrue);
      expect(fakeClient.activeSessions.any((s) => s['user'] == 'user1_extra'), isTrue);
    });

    test('RouterOsBinaryClient disconnectHotspotSession throws when no exact username match exists', () async {
      final fakeClient = FakeLocalRouterOsClient(
        host: '192.168.88.1',
        port: 8728,
        useTls: false,
      );

      fakeClient.activeSessions.addAll([
        {'.id': '*1', 'user': 'john_doe_2', 'address': '192.168.88.20'},
      ]);

      expect(
        () => fakeClient.disconnectHotspotSession('john_doe'),
        throwsException,
      );
      expect(fakeClient.activeSessions.length, equals(1));
    });
  });

  group('Requirement 2.4: Connection Test reads hardware from /system/resource directly', () {
    testWidgets('Connection test updates hardware details and reloads users & sessions', (tester) async {
      await MikrotikDiscoveryService.saveRouterCredentials(
        routerId: localRouter.id,
        username: 'admin',
        password: 'password123',
      );

      bool updateRouterCalled = false;
      ApiClient.client = MockClient((request) async {
        if (request.method == 'PATCH' && request.url.path.contains('/routers/')) {
          updateRouterCalled = true;
          return utf8Response({'success': true, 'data': {}}, 200);
        }
        return utf8Response({'success': true, 'data': {}}, 200);
      });

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
            'identity': 'Branch-Router-Local',
            'version': '7.16',
            'boardName': 'hAP ax^3',
            'cpuLoad': 12,
            'uptimeSeconds': 14400,
          },
        };
      };

      bool usersLoadedAfterProbe = false;
      MikrotikDiscoveryService.hotspotUsersDirectTester = ({
        required String host,
        required int port,
        required String username,
        required String password,
        String? connectionMethod,
        String? searchName,
        int? limit,
      }) async {
        usersLoadedAfterProbe = true;
        return {'success': true, 'data': []};
      };

      await tester.pumpWidget(createTestWidget(RouterDetailScreen(router: localRouter)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final testButton = find.text('فحص الاتصال');
      expect(testButton, findsOneWidget);
      await tester.tap(testButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verifies board and version from /system/resource are displayed
      expect(find.textContaining('hAP ax^3'), findsWidgets);
      expect(find.textContaining('7.16'), findsWidgets);
      expect(updateRouterCalled, isTrue);
      expect(usersLoadedAfterProbe, isTrue);
    });
  });

  group('Requirement 4: Local failure reports step name with retry button and NO backend fallback', () {
    testWidgets('Local router failure shows Arabic step name without passwords and allows retry', (tester) async {
      await MikrotikDiscoveryService.saveRouterCredentials(
        routerId: localRouter.id,
        username: 'admin',
        password: 'SECRET_PLAINTEXT_PASS_123',
      );

      bool backendUsersCalled = false;
      ApiClient.client = MockClient((request) async {
        if (request.url.path.contains('/hotspot-users')) {
          backendUsersCalled = true;
          return utf8Response({'success': false, 'errorMessage': 'محظور في المرحلة الأولى'}, 403);
        }
        return utf8Response({'success': true, 'data': {}}, 200);
      });

      // Direct call returns error with step name
      MikrotikDiscoveryService.hotspotUsersDirectTester = ({
        required String host,
        required int port,
        required String username,
        required String password,
        String? connectionMethod,
        String? searchName,
        int? limit,
      }) async {
        return {
          'success': false,
          'errorCode': 'PORT_CLOSED',
          'errorMessage': 'فشل خطوة (الاتصال) أثناء جلب مستخدمي الهوتسبوت عبر المنفذ 8728 (غير مشفر): تعذر الاتصال بالراوتر على الشبكة المحلية',
        };
      };

      await tester.pumpWidget(createTestWidget(RouterDetailScreen(router: localRouter)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Switch to users tab
      await tester.tap(find.textContaining('مستخدمو الهوتسبوت'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Error message must contain step name and port
      expect(find.textContaining('خطوة (الاتصال)'), findsOneWidget);
      expect(find.textContaining('المنفذ 8728 (غير مشفر)'), findsOneWidget);
      expect(find.textContaining('SECRET_PLAINTEXT_PASS_123'), findsNothing);

      // Retry button must be present
      expect(find.text('إعادة المحاولة'), findsOneWidget);

      // Backend must NOT have been called
      expect(backendUsersCalled, isFalse);
    });
  });

  group('Requirement 3: Public routers retain cloud backend API path', () {
    testWidgets('Public router requests users and sessions via ApiClient', (tester) async {
      bool backendUsersCalled = false;
      ApiClient.client = MockClient((request) async {
        if (request.url.path.contains('/hotspot-users')) {
          backendUsersCalled = true;
          return utf8Response({
            'success': true,
            'data': [
              {
                'id': '*cloud_u1',
                'username': 'cloud_client',
                'profile': 'default',
                'uptime': '10m',
                'uptimeSeconds': 600,
                'disabled': false,
                'isEnabled': true,
              }
            ],
          }, 200);
        }
        return utf8Response({'success': true, 'data': {}}, 200);
      });

      await tester.pumpWidget(createTestWidget(RouterDetailScreen(router: publicRouter)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.textContaining('مستخدمو الهوتسبوت'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(backendUsersCalled, isTrue);
      expect(find.text('cloud_client'), findsOneWidget);
    });
  });
}
