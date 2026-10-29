// ============================================================================
// Platform: Commercial MikroTik Network & HotSpot Card Management System
// File: test/api_client_test.dart
// Integration Test: ApiClient to Fastify Backend API Verification with Auth
// Master Reference: Rule 14 (Security), Rule 19 (Auth), Rule 23 (Errors)
// ============================================================================

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mikrotik_cards_app/models/package_model.dart';
import 'package:mikrotik_cards_app/models/router_model.dart';
import 'package:mikrotik_cards_app/services/api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response utf8Response(Map<String, dynamic> data, int statusCode) {
  return http.Response.bytes(
    utf8.encode(jsonEncode(data)),
    statusCode,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

void setupMockBackend() {
  final routers = <Map<String, dynamic>>[];
  final packages = <Map<String, dynamic>>[];

  ApiClient.client = MockClient((request) async {
    final path = request.url.path;

    if (path.endsWith('/api/v1/auth/login')) {
      final body = jsonDecode(request.body);
      if (body['password'] == 'wrong_password_123') {
        return utf8Response({
          'success': false,
          'errorCode': 'UNAUTHORIZED',
          'errorMessage': 'بيانات الدخول غير صحيحة',
        }, 401);
      }
      return utf8Response({
        'success': true,
        'data': {
          'token': 'jwt_mock_token_123',
          'user': {
            'id': 'u1',
            'username': 'admin',
            'role': 'TENANT_ADMIN',
          },
        },
      }, 200);
    }

    if (path.contains('/api/v1/routers/test-connection')) {
      final body = jsonDecode(request.body);
      if (body['host'] == 'fail.test') {
        return utf8Response({
          'success': false,
          'errorCode': 'CONNECTION_REFUSED',
          'errorMessage': 'Connection refused',
        }, 400);
      }
      return utf8Response({
        'success': true,
        'data': {
          'identity': 'MOCK-ROUTER-01',
          'version': 'RouterOS v7.14.3',
          'boardName': 'RB4011iGS+',
        },
      }, 200);
    }

    if (path == '/api/v1/routers') {
      if (request.method == 'GET') {
        return utf8Response({'success': true, 'data': routers}, 200);
      } else if (request.method == 'POST') {
        final body = jsonDecode(request.body);
        final item = {
          'id': 'r_${DateTime.now().millisecondsSinceEpoch}',
          'name': body['name'],
          'host': body['host'],
          'port': body['port'] ?? 8728,
          'username': body['username'],
          'status': 'ONLINE',
          'activeHotspotUsers': 0,
        };
        routers.add(item);
        return utf8Response({'success': true, 'data': item}, 201);
      }
    }

    if (path.startsWith('/api/v1/routers/')) {
      if (request.method == 'DELETE') {
        final id = path.split('/').last;
        routers.removeWhere((r) => r['id'] == id);
        return utf8Response({'success': true, 'data': {'message': 'deleted'}}, 200);
      }
    }

    if (path == '/api/v1/packages') {
      if (request.method == 'GET') {
        return utf8Response({'success': true, 'data': packages}, 200);
      } else if (request.method == 'POST') {
        final body = jsonDecode(request.body);
        final item = {
          'id': 'p_${DateTime.now().millisecondsSinceEpoch}',
          'name': body['name'],
          'code': body['code'],
          'price': (body['price'] as num).toDouble(),
          'downloadSpeedLimit': body['downloadSpeedLimit'],
          'uploadSpeedLimit': body['uploadSpeedLimit'],
          'durationMinutes': body['durationMinutes'],
          'validityDays': body['validityDays'],
          'hotspotProfileName': body['hotspotProfileName'],
        };
        packages.add(item);
        return utf8Response({'success': true, 'data': item}, 201);
      }
    }

    if (path.startsWith('/api/v1/packages/')) {
      if (request.method == 'DELETE') {
        final id = path.split('/').last;
        packages.removeWhere((p) => p['id'] == id);
        return utf8Response({'success': true, 'data': {'message': 'deleted'}}, 200);
      }
    }

    return utf8Response({'success': false, 'message': 'Not Found'}, 404);
  });
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    setupMockBackend();
  });

  group('ApiClient Authentication & Session Tests', () {
    test('login with invalid credentials returns UNAUTHORIZED', () async {
      final result = await ApiClient.login(
        username: 'admin',
        password: 'wrong_password_123',
      );

      expect(result['success'], isFalse);
      expect(result['errorCode'], equals('UNAUTHORIZED'));
      expect(result['errorMessage'], contains('بيانات الدخول غير صحيحة'));
      expect(ApiClient.authToken, isNull);
    });

    test('login with valid credentials sets authToken and returns user data', () async {
      final result = await ApiClient.login(
        username: 'admin',
        password: 'E3*NUdX&R==yKrD3',
      );

      expect(result['success'], isTrue,
          reason: 'Login failed: ${result['errorMessage']}');
      expect(result['data'], isNotNull);
      expect(ApiClient.authToken, isNotNull);
      expect(ApiClient.isAuthenticated, isTrue);

      final userData = result['data']['user'];
      expect(userData['username'], equals('admin'));
    });

    test('loadSavedToken restores token from storage', () async {
      final loadedToken = await ApiClient.loadSavedToken();
      expect(loadedToken, isNotNull);
      expect(loadedToken, equals(ApiClient.authToken));
    });

    test('logout clears in-memory and persistent token', () async {
      await ApiClient.logout();
      expect(ApiClient.authToken, isNull);
      expect(ApiClient.isAuthenticated, isFalse);

      final loaded = await ApiClient.loadSavedToken();
      expect(loaded, isNull);
    });

    test('baseUrl is https://alrafeerouter.zone.id and requests target new API domain without Render', () async {
      expect(ApiClient.baseUrl, equals('https://alrafeerouter.zone.id'));
      expect(ApiClient.baseUrl.contains('render'), isFalse);
      expect(ApiClient.baseUrl.contains('onrender.com'), isFalse);

      Uri? capturedUri;
      Map<String, String>? capturedHeaders;

      ApiClient.client = MockClient((request) async {
        capturedUri = request.url;
        capturedHeaders = request.headers;
        return utf8Response({'success': true, 'data': []}, 200);
      });

      ApiClient.setAuthToken('test_bearer_token_abc123');
      await ApiClient.getRouters();

      expect(capturedUri, isNotNull);
      expect(capturedUri!.scheme, equals('https'));
      expect(capturedUri!.host, equals('alrafeerouter.zone.id'));
      expect(capturedUri.toString().contains('onrender.com'), isFalse);
      expect(capturedHeaders?['authorization'], equals('Bearer test_bearer_token_abc123'));

      // Restore mock backend
      setupMockBackend();
    });

    testWidgets('login waits up to 60s (succeeds at 35s, times out at 60s) while non-login requests keep 25s timeout',
        (WidgetTester tester) async {
      // 1. A slow login taking 35s (>25s, <60s) should succeed without timing out
      ApiClient.setDeviceFingerprint('dev_test_fingerprint');
      ApiClient.client = MockClient((request) async {
        await Future<void>.delayed(const Duration(seconds: 35));
        return utf8Response({
          'success': true,
          'data': {
            'token': 'jwt_slow_login_token',
            'user': {'id': 'u1', 'username': 'admin', 'role': 'TENANT_ADMIN'},
          },
        }, 200);
      });

      Map<String, dynamic>? slowLoginResult;
      ApiClient.login(username: 'admin', password: 'valid').then((res) {
        slowLoginResult = res;
      });

      await tester.pump(const Duration(seconds: 30));
      expect(slowLoginResult, isNull); // Still waiting at 30s (did not fail at 25s)

      await tester.pump(const Duration(seconds: 6));
      expect(slowLoginResult, isNotNull);
      expect(slowLoginResult!['success'], isTrue);
      expect(ApiClient.authToken, equals('jwt_slow_login_token'));

      // 2. A login taking >60s should time out at 60s with TIMEOUT errorCode
      ApiClient.client = MockClient((request) async {
        await Future<void>.delayed(const Duration(seconds: 70));
        return utf8Response({'success': true, 'data': {}}, 200);
      });

      Map<String, dynamic>? timeoutLoginResult;
      ApiClient.login(username: 'admin', password: 'valid').then((res) {
        timeoutLoginResult = res;
      });

      await tester.pump(const Duration(seconds: 59));
      expect(timeoutLoginResult, isNull); // Not timed out yet at 59s

      await tester.pump(const Duration(seconds: 2));
      expect(timeoutLoginResult, isNotNull);
      expect(timeoutLoginResult!['success'], isFalse);
      expect(timeoutLoginResult!['errorCode'], equals('TIMEOUT'));
      expect(
        timeoutLoginResult!['errorMessage'],
        equals('انتهت مهلة الاتصال بالخادم (60 ثانية). يرجى التأكد من استجابة السيرفر.'),
      );
      await tester.pump(const Duration(seconds: 10));

      // 3. Non-login requests (e.g. getRouters) still time out at 25s
      Map<String, dynamic>? routersTimeoutResult;
      ApiClient.getRouters().then((res) {
        routersTimeoutResult = res;
      });

      await tester.pump(const Duration(seconds: 24));
      expect(routersTimeoutResult, isNull);

      await tester.pump(const Duration(seconds: 2));
      expect(routersTimeoutResult, isNotNull);
      expect(routersTimeoutResult!['success'], isFalse);
      expect(routersTimeoutResult!['errorCode'], equals('TIMEOUT'));
      expect(
        routersTimeoutResult!['errorMessage'],
        equals('انتهت مهلة الاتصال بالخادم (25 ثانية). يرجى التأكد من استجابة السيرفر.'),
      );
      expect(routersTimeoutResult!['errorMessage'].contains('5 ثوانٍ'), isFalse);
      await tester.pump(const Duration(seconds: 45));

      // Restore mock backend for subsequent tests
      setupMockBackend();
    });

    testWidgets('testRouterConnection timeout returns 25s error message and does not mention 5s',
        (WidgetTester tester) async {
      ApiClient.client = MockClient((request) async {
        await Future<void>.delayed(const Duration(seconds: 30));
        return utf8Response({'success': true, 'data': {}}, 200);
      });

      Map<String, dynamic>? probeTimeoutResult;
      ApiClient.testRouterConnection(
        host: '1.2.3.4',
        port: 8729,
        username: 'admin',
        password: 'password',
      ).then((res) {
        probeTimeoutResult = res;
      });

      await tester.pump(const Duration(seconds: 24));
      expect(probeTimeoutResult, isNull);

      await tester.pump(const Duration(seconds: 2));
      expect(probeTimeoutResult, isNotNull);
      expect(probeTimeoutResult!['success'], isFalse);
      expect(probeTimeoutResult!['errorCode'], equals('TIMEOUT'));
      expect(
        probeTimeoutResult!['errorMessage'],
        equals('انتهت مهلة الاتصال بالخادم (25 ثانية). يرجى التأكد من استجابة السيرفر.'),
      );
      expect(probeTimeoutResult!['errorMessage'].contains('5 ثوانٍ'), isFalse);

      await tester.pump(const Duration(seconds: 10));
      setupMockBackend();
    });
  });

  group('ApiClient Live Backend Integration Tests (Authenticated)', () {
    setUpAll(() async {
      final loginResult = await ApiClient.login(
        username: 'admin',
        password: 'E3*NUdX&R==yKrD3',
      );
      expect(loginResult['success'], isTrue);
    });

    test('testRouterConnection returns success with RouterInfo for valid host', () async {
      final result = await ApiClient.testRouterConnection(
        host: 'router.example.com',
        port: 8728,
        username: 'admin',
        password: 'test',
      );

      expect(result['success'], isTrue);
      expect(result['data'], isNotNull);
      expect(result['data']['identity'], equals('MOCK-ROUTER-01'));
      expect(result['data']['version'], equals('RouterOS v7.14.3'));
      expect(result['data']['boardName'], equals('RB4011iGS+'));
    });

    test('testRouterConnection returns failure for fail.test host', () async {
      final result = await ApiClient.testRouterConnection(
        host: 'fail.test',
        port: 8728,
        username: 'admin',
        password: 'test',
      );

      expect(result['success'], isFalse);
      expect(result['errorCode'], equals('CONNECTION_REFUSED'));
      expect(result['errorMessage'], contains('Connection refused'));
    });

    test('Live CRUD lifecycle: create -> getRouters -> delete against live backend', () async {
      final initialGetResult = await ApiClient.getRouters();
      expect(initialGetResult['success'], isTrue);
      final initialList = (initialGetResult['data'] as List).cast<RouterModel>();
      final int initialCount = initialList.length;

      final uniqueName = 'راوتر فحص الربط ${DateTime.now().millisecondsSinceEpoch}';
      final createResult = await ApiClient.createRouter(
        name: uniqueName,
        host: '192.168.88.200',
        port: 8728,
        username: 'admin',
        password: 'securePassword123',
      );

      expect(createResult['success'], isTrue,
          reason: 'createRouter failed: ${createResult['errorMessage']}');
      expect(createResult['data'], isA<RouterModel>());
      final createdRouter = createResult['data'] as RouterModel;
      expect(createdRouter.id.isNotEmpty, isTrue);
      expect(createdRouter.name, equals(uniqueName));
      expect(createdRouter.host, equals('192.168.88.200'));

      final afterCreateResult = await ApiClient.getRouters();
      expect(afterCreateResult['success'], isTrue);
      final afterCreateList = (afterCreateResult['data'] as List).cast<RouterModel>();
      expect(afterCreateList.length, equals(initialCount + 1));
      expect(afterCreateList.any((r) => r.id == createdRouter.id), isTrue);

      final deleteResult = await ApiClient.deleteRouter(createdRouter.id);
      expect(deleteResult['success'], isTrue,
          reason: 'deleteRouter failed: ${deleteResult['errorMessage']}');

      final afterDeleteResult = await ApiClient.getRouters();
      expect(afterDeleteResult['success'], isTrue);
      final afterDeleteList = (afterDeleteResult['data'] as List).cast<RouterModel>();
      expect(afterDeleteList.length, equals(initialCount));
      expect(afterDeleteList.any((r) => r.id == createdRouter.id), isFalse);
    });

    test('Live Package CRUD lifecycle: create -> getPackages -> delete against live backend', () async {
      final initialGet = await ApiClient.getPackages();
      expect(initialGet['success'], isTrue);
      final initialList = (initialGet['data'] as List).cast<PackageModel>();
      final int initialCount = initialList.length;

      final uniqueCode = 'PKG-TEST-${DateTime.now().millisecondsSinceEpoch}';
      final createResult = await ApiClient.createPackage(
        name: 'باقة اختبار حي',
        code: uniqueCode,
        downloadSpeedLimit: '6M',
        uploadSpeedLimit: '3M',
        durationMinutes: 1440,
        validityDays: 1,
        price: 550,
        hotspotProfileName: 'hs_test_profile',
      );

      expect(createResult['success'], isTrue,
          reason: 'createPackage failed: ${createResult['errorMessage']}');
      expect(createResult['data'], isA<PackageModel>());
      final createdPkg = createResult['data'] as PackageModel;
      expect(createdPkg.id.isNotEmpty, isTrue);
      expect(createdPkg.code, equals(uniqueCode));
      expect(createdPkg.name, equals('باقة اختبار حي'));

      final afterCreate = await ApiClient.getPackages();
      expect(afterCreate['success'], isTrue);
      final afterCreateList = (afterCreate['data'] as List).cast<PackageModel>();
      expect(afterCreateList.length, equals(initialCount + 1));
      expect(afterCreateList.any((p) => p.id == createdPkg.id), isTrue);

      final deleteResult = await ApiClient.deletePackage(createdPkg.id);
      expect(deleteResult['success'], isTrue,
          reason: 'deletePackage failed: ${deleteResult['errorMessage']}');

      final afterDelete = await ApiClient.getPackages();
      expect(afterDelete['success'], isTrue);
      final afterDeleteList = (afterDelete['data'] as List).cast<PackageModel>();
      expect(afterDeleteList.length, equals(initialCount));
      expect(afterDeleteList.any((p) => p.id == createdPkg.id), isFalse);
    });

    test('ApiClient Router Management & HotSpot Session Operations Unit Tests', () async {
      final capturedCalls = <String>[];
      ApiClient.client = MockClient((request) async {
        capturedCalls.add('${request.method} ${request.url.path}');

        if (request.method == 'PATCH' && request.url.path == '/api/v1/routers/r-123') {
          final payload = jsonDecode(request.body) as Map<String, dynamic>;
          expect(payload['name'], equals('Updated Router'));
          expect(payload['port'], equals(8729));
          return utf8Response({
            'success': true,
            'data': {
              'id': 'r-123',
              'name': 'Updated Router',
              'host': '192.168.88.1',
              'apiPort': 8729,
              'connectionMethod': 'ROUTEROS_API_SSL',
              'status': 'ONLINE',
            },
          }, 200);
        }

        if (request.method == 'POST' && request.url.path.contains('/api/v1/routers/r-123/test-connection')) {
          return utf8Response({
            'success': true,
            'data': {
              'identity': 'MikroTik-Main',
              'version': 'RouterOS v7.14.3',
              'boardName': 'RB4011iGS+',
              'cpuLoad': 12,
              'uptimeSeconds': 12345,
            },
          }, 200);
        }

        if (request.method == 'GET' && request.url.path.contains('/api/v1/routers/r-123/hotspot-users')) {
          return utf8Response({
            'success': true,
            'data': [
              {
                'username': 'user101',
                'profile': 'default',
                'isEnabled': true,
                'uptimeSeconds': 3600,
                'bytesIn': 5000000,
                'bytesOut': 15000000,
                'verifiedOnRouter': true,
                'dbStatus': 'ACTIVE',
              },
            ],
          }, 200);
        }

        if (request.method == 'PATCH' && request.url.path.contains('/api/v1/routers/r-123/hotspot-users/user101')) {
          final payload = jsonDecode(request.body) as Map<String, dynamic>;
          expect(payload['isEnabled'], isFalse);
          return utf8Response({
            'success': true,
            'message': 'تم تعطيل المستخدم user101 بنجاح',
            'data': {'username': 'user101', 'isEnabled': false},
          }, 200);
        }

        if (request.method == 'GET' && request.url.path.contains('/api/v1/routers/r-123/hotspot-sessions')) {
          return utf8Response({
            'success': true,
            'data': [
              {
                'username': 'user101',
                'ipAddress': '192.168.88.240',
                'macAddress': '00:11:22:33:44:55',
                'uptimeSeconds': 1200,
                'bytesIn': 2048576,
                'bytesOut': 8192000,
              },
            ],
          }, 200);
        }

        if (request.method == 'POST' && request.url.path.contains('/api/v1/routers/r-123/hotspot-sessions/user101/disconnect')) {
          return utf8Response({
            'success': true,
            'message': 'تم فصل الجلسة بنجاح',
          }, 200);
        }

        if (request.method == 'POST' && request.url.path.contains('/api/v1/cards/generate-batch')) {
          final payload = jsonDecode(request.body) as Map<String, dynamic>;
          expect(payload['routerId'], equals('r-123'));
          return utf8Response({
            'success': true,
            'data': {
              'batch': {
                'id': 'b-1',
                'name': 'دفعة اختبار',
                'quantity': 5,
                'packageId': 'pkg-1',
                'routerId': 'r-123',
                'unitPrice': 100,
                'totalPrice': 500,
              },
              'cards': [],
            },
          }, 201);
        }

        if (request.method == 'GET' && request.url.path.contains('/api/v1/cards/batches')) {
          return utf8Response({
            'success': true,
            'data': [
              {
                'id': 'b-1',
                'name': 'دفعة اختبار',
                'quantity': 5,
                'packageId': 'pkg-1',
                'routerId': 'r-123',
                'unitPrice': 100,
                'totalPrice': 500,
              },
            ],
          }, 200);
        }

        return utf8Response({'success': true, 'data': {}}, 200);
      });

      // 1. updateRouter
      final updateRes = await ApiClient.updateRouter(
        id: 'r-123',
        name: 'Updated Router',
        port: 8729,
      );
      expect(updateRes['success'], isTrue);
      expect((updateRes['data'] as RouterModel).name, equals('Updated Router'));

      // 2. testRouterConnectionForId
      final testConnRes = await ApiClient.testRouterConnectionForId('r-123');
      expect(testConnRes['success'], isTrue);
      expect(testConnRes['data']['boardName'], equals('RB4011iGS+'));

      // 3. getRouterHotspotUsers
      final usersRes = await ApiClient.getRouterHotspotUsers('r-123');
      expect(usersRes['success'], isTrue);
      expect(usersRes['data'].length, equals(1));
      expect(usersRes['data'][0]['username'], equals('user101'));

      // 4. toggleHotspotUser
      final toggleRes = await ApiClient.toggleHotspotUser(
        routerId: 'r-123',
        username: 'user101',
        isEnabled: false,
      );
      expect(toggleRes['success'], isTrue);

      // 5. getRouterHotspotSessions
      final sessionsRes = await ApiClient.getRouterHotspotSessions('r-123');
      expect(sessionsRes['success'], isTrue);
      expect(sessionsRes['data'][0]['ipAddress'], equals('192.168.88.240'));

      // 6. disconnectHotspotSession
      final disconnectRes = await ApiClient.disconnectHotspotSession(
        routerId: 'r-123',
        username: 'user101',
      );
      expect(disconnectRes['success'], isTrue);

      // 7. generateCardBatch with routerId
      final genBatchRes = await ApiClient.generateCardBatch(
        packageId: 'pkg-1',
        quantity: 5,
        routerId: 'r-123',
      );
      expect(genBatchRes['success'], isTrue);

      // 8. getBatches
      final batchesRes = await ApiClient.getBatches();
      expect(batchesRes['success'], isTrue);
      expect(batchesRes['data'].length, equals(1));

      // Restore mock backend
      setupMockBackend();
    });
  });
}
