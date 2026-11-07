// ============================================================================
// Platform: Commercial MikroTik Network & HotSpot Card Management System (Jalsah)
// File: test/probe_diagnostics_test.dart
// Description: Unit tests for probe diagnostics (fix/probe-diagnostics):
//  1. Diagnosing failed steps in Arabic (الاتصال، تسجيل الدخول، قراءة المستخدمين، الإنشاء، التحقق، الحذف).
//  2. Reporting port and connection type (مشفر / غير مشفر).
//  3. Ensuring port 8728 NEVER uses TLS even if connectionMethod is ROUTEROS_API_SSL.
//  4. Ensuring getHotspotUsers uses server-side name filter (?name=_jalsah_probe_test).
//  5. Ensuring passwords are never exposed in error messages.
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mikrotik_cards_app/models/router_model.dart';
import 'package:mikrotik_cards_app/services/api_client.dart';
import 'package:mikrotik_cards_app/services/local_card_sync_service.dart';
import 'package:mikrotik_cards_app/services/mikrotik_discovery_service.dart';
import 'package:mikrotik_cards_app/services/routeros_binary_client.dart';

class DiagnosticMockRouterOsClient extends RouterOsBinaryClient {
  final List<Map<String, String>> routerUsers = [];
  final List<String?> queriedNameFilters = [];

  bool failConnect = false;
  bool failLogin = false;
  bool failReadUsersOnLeftoverCheck = false;
  bool failCreateUser = false;
  bool failVerifyUserMissing = false;
  bool failVerifyQuery = false;
  bool failDeleteUser = false;

  bool throwTimeoutOnStep = false;
  String? stepToTimeout;

  DiagnosticMockRouterOsClient({
    required super.host,
    required super.port,
    super.useTls = false,
    super.timeout = const Duration(seconds: 5),
  });

  @override
  Future<void> connect() async {
    if (failConnect) {
      throw const SocketException('Connection refused');
    }
    if (throwTimeoutOnStep && stepToTimeout == 'connect') {
      throw TimeoutException('Socket connection timeout');
    }
  }

  @override
  Future<bool> login(String username, String password) async {
    if (throwTimeoutOnStep && stepToTimeout == 'login') {
      throw TimeoutException('Login sentence response timeout');
    }
    if (failLogin) {
      throw AuthException('invalid user name or password');
    }
    return true;
  }

  @override
  Future<List<Map<String, dynamic>>> getHotspotUsers({String? name, int? limit}) async {
    queriedNameFilters.add(name);

    if (throwTimeoutOnStep && stepToTimeout == 'readUsers') {
      throw TimeoutException('Sentence response timeout while reading users');
    }
    if (failReadUsersOnLeftoverCheck && queriedNameFilters.length == 1) {
      throw const SocketException('Broken pipe during leftover check');
    }
    if (failVerifyQuery && queriedNameFilters.length > 1) {
      throw const SocketException('Broken pipe during verification check');
    }
    if (failVerifyUserMissing && queriedNameFilters.length > 1) {
      return []; // probe user not found
    }

    List<Map<String, String>> res = routerUsers;
    if (name != null && name.isNotEmpty) {
      res = res.where((u) => u['name'] == name).toList();
    }
    if (limit != null && limit > 0) {
      return res.take(limit).toList();
    }
    return List.from(res);
  }

  @override
  Future<bool> createHotspotUser({
    required String username,
    required String password,
    required String profile,
    String? comment,
    String? timeLimit,
    int? limitBytesTotal,
  }) async {
    if (throwTimeoutOnStep && stepToTimeout == 'createUser') {
      throw TimeoutException('Sentence response timeout while creating user');
    }
    if (failCreateUser) {
      throw Exception('failure: action not permitted, not enough permissions (9)');
    }

    routerUsers.add({
      '.id': '*${routerUsers.length + 1}',
      'name': username,
      'password': password,
      'profile': profile,
    });
    return true;
  }

  @override
  Future<bool> removeHotspotUser(String username) async {
    if (throwTimeoutOnStep && stepToTimeout == 'deleteUser') {
      throw TimeoutException('Sentence response timeout while deleting user');
    }
    if (failDeleteUser) {
      throw const SocketException('Connection reset during user removal');
    }
    routerUsers.removeWhere((u) => u['name'] == username);
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DiagnosticMockRouterOsClient mockClient;
  bool? capturedUseTls;
  int? capturedPort;

  String createMockJwt() {
    final header = base64Url.encode(utf8.encode(jsonEncode({'alg': 'HS256', 'typ': 'JWT'}))).replaceAll('=', '');
    final payload = base64Url.encode(utf8.encode(jsonEncode({'role': 'TENANT_ADMIN', 'tenantId': 't-1', 'userId': 'u-1'}))).replaceAll('=', '');
    return '$header.$payload.mock_sig';
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    LocalCardSyncService.resetTestStorage();
    MikrotikDiscoveryService.resetTestStorage();
    ApiClient.resetClient();
    ApiClient.setAuthToken(createMockJwt());

    capturedUseTls = null;
    capturedPort = null;

    LocalCardSyncService.clientFactory = ({
      required String host,
      required int port,
      required bool useTls,
      required Duration timeout,
    }) {
      capturedPort = port;
      capturedUseTls = useTls;
      return mockClient;
    };
  });

  tearDown(() {
    LocalCardSyncService.resetTestStorage();
  });

  group('Requirement 4: Port 8728 is Plain API and MUST NOT use TLS', () {
    test('Router with apiPort 8728 and connectionMethod ROUTEROS_API_SSL enforces useTls = false', () async {
      const routerWithSslOn8728 = RouterModel(
        id: 'router-ssl-8728',
        name: 'Misconfigured SSL on 8728',
        host: '10.0.0.1',
        apiPort: 8728,
        status: 'ONLINE',
        connectionMethod: 'ROUTEROS_API_SSL',
      );

      await MikrotikDiscoveryService.saveRouterCredentials(
        routerId: routerWithSslOn8728.id,
        username: 'admin',
        password: 'secretPassword123',
      );

      mockClient = DiagnosticMockRouterOsClient(
        host: routerWithSslOn8728.host,
        port: routerWithSslOn8728.apiPort,
        useTls: false,
      );

      final result = await LocalCardSyncService.probeRouter(router: routerWithSslOn8728);

      expect(result['success'], isTrue);
      // Even though router.connectionMethod was ROUTEROS_API_SSL, port 8728 MUST NOT use TLS!
      expect(capturedUseTls, isFalse);
      expect(capturedPort, equals(8728));
    });

    test('Router with apiPort 8729 uses TLS (useTls = true)', () async {
      const router8729 = RouterModel(
        id: 'router-ssl-8729',
        name: 'Valid SSL on 8729',
        host: '10.0.0.1',
        apiPort: 8729,
        status: 'ONLINE',
        connectionMethod: 'ROUTEROS_API_SSL',
      );

      await MikrotikDiscoveryService.saveRouterCredentials(
        routerId: router8729.id,
        username: 'admin',
        password: 'secretPassword123',
      );

      mockClient = DiagnosticMockRouterOsClient(
        host: router8729.host,
        port: router8729.apiPort,
        useTls: true,
      );

      final result = await LocalCardSyncService.probeRouter(router: router8729);

      expect(result['success'], isTrue);
      expect(capturedUseTls, isTrue);
      expect(capturedPort, equals(8729));
    });
  });

  group('Requirement 2: Server-side filter ?name=_jalsah_probe_test to avoid dumping all users', () {
    test('getHotspotUsers is called with name filter _jalsah_probe_test', () async {
      const testRouter = RouterModel(
        id: 'router-filter-test',
        name: 'Filter Test Router',
        host: '10.0.0.1',
        apiPort: 8728,
        status: 'ONLINE',
        connectionMethod: 'ROUTEROS_API_PLAIN',
      );

      await MikrotikDiscoveryService.saveRouterCredentials(
        routerId: testRouter.id,
        username: 'admin',
        password: 'password123',
      );

      mockClient = DiagnosticMockRouterOsClient(
        host: testRouter.host,
        port: testRouter.apiPort,
      );

      final result = await LocalCardSyncService.probeRouter(router: testRouter);

      expect(result['success'], isTrue);
      expect(mockClient.queriedNameFilters, isNotEmpty);
      // All queries must filter specifically for '_jalsah_probe_test'
      for (final filter in mockClient.queriedNameFilters) {
        expect(filter, equals('_jalsah_probe_test'));
      }
    });
  });

  group('Requirement 3: Diagnostic error messages report exact step in Arabic and connection type', () {
    const testRouter = RouterModel(
      id: 'router-diagnostic-test',
      name: 'Diagnostic Router',
      host: '10.0.0.1',
      apiPort: 8728,
      status: 'ONLINE',
      connectionMethod: 'ROUTEROS_API_PLAIN',
    );

    const secretPassword = 'SUPER_CONFIDENTIAL_PASS_777!';

    setUp(() async {
      await MikrotikDiscoveryService.saveRouterCredentials(
        routerId: testRouter.id,
        username: 'admin',
        password: secretPassword,
      );
    });

    test('1. Fails at step "الاتصال" with Arabic diagnostic info', () async {
      mockClient = DiagnosticMockRouterOsClient(
        host: testRouter.host,
        port: testRouter.apiPort,
      )..failConnect = true;

      final result = await LocalCardSyncService.probeRouter(router: testRouter);

      expect(result['success'], isFalse);
      expect(result['step'], equals('الاتصال'));
      expect(result['errorMessage'], contains('خطوة (الاتصال)'));
      expect(result['errorMessage'], contains('المنفذ 8728'));
      expect(result['errorMessage'], contains('غير مشفر'));
      expect(result['errorMessage'].contains(secretPassword), isFalse);
    });

    test('2. Fails at step "تسجيل الدخول" with Arabic diagnostic info', () async {
      mockClient = DiagnosticMockRouterOsClient(
        host: testRouter.host,
        port: testRouter.apiPort,
      )..failLogin = true;

      final result = await LocalCardSyncService.probeRouter(router: testRouter);

      expect(result['success'], isFalse);
      expect(result['step'], equals('تسجيل الدخول'));
      expect(result['errorMessage'], contains('خطوة (تسجيل الدخول)'));
      expect(result['errorMessage'], contains('المنفذ 8728'));
      expect(result['errorMessage'], contains('غير مشفر'));
      expect(result['errorMessage'], contains('فشلت المصادقة'));
      expect(result['errorMessage'].contains(secretPassword), isFalse);
    });

    test('3. Fails at step "قراءة المستخدمين" with Arabic diagnostic info', () async {
      mockClient = DiagnosticMockRouterOsClient(
        host: testRouter.host,
        port: testRouter.apiPort,
      )..failReadUsersOnLeftoverCheck = true;

      final result = await LocalCardSyncService.probeRouter(router: testRouter);

      expect(result['success'], isFalse);
      expect(result['step'], equals('قراءة المستخدمين'));
      expect(result['errorMessage'], contains('خطوة (قراءة المستخدمين)'));
      expect(result['errorMessage'], contains('المنفذ 8728'));
      expect(result['errorMessage'], contains('غير مشفر'));
      expect(result['errorMessage'].contains(secretPassword), isFalse);
    });

    test('4. Fails at step "الإنشاء" with Arabic diagnostic info', () async {
      mockClient = DiagnosticMockRouterOsClient(
        host: testRouter.host,
        port: testRouter.apiPort,
      )..failCreateUser = true;

      final result = await LocalCardSyncService.probeRouter(router: testRouter);

      expect(result['success'], isFalse);
      expect(result['step'], equals('الإنشاء'));
      expect(result['errorMessage'], contains('خطوة (الإنشاء)'));
      expect(result['errorMessage'], contains('المنفذ 8728'));
      expect(result['errorMessage'], contains('غير مشفر'));
      expect(result['errorMessage'].contains(secretPassword), isFalse);
    });

    test('5. Fails at step "التحقق" with Arabic diagnostic info', () async {
      mockClient = DiagnosticMockRouterOsClient(
        host: testRouter.host,
        port: testRouter.apiPort,
      )..failVerifyUserMissing = true;

      final result = await LocalCardSyncService.probeRouter(router: testRouter);

      expect(result['success'], isFalse);
      expect(result['step'], equals('التحقق'));
      expect(result['errorMessage'], contains('خطوة (التحقق)'));
      expect(result['errorMessage'], contains('المنفذ 8728'));
      expect(result['errorMessage'], contains('غير مشفر'));
      expect(result['errorMessage'], contains('فشل التحقق من إضافة المستخدم التجريبي داخل الراوتر'));
      expect(result['errorMessage'].contains(secretPassword), isFalse);
    });

    test('6. Fails at step "الحذف" with Arabic diagnostic info when leftover deletion fails', () async {
      mockClient = DiagnosticMockRouterOsClient(
        host: testRouter.host,
        port: testRouter.apiPort,
      )
        ..routerUsers.add({
          '.id': '*leftover',
          'name': '_jalsah_probe_test',
          'password': '',
          'profile': 'default',
        })
        ..failDeleteUser = true;

      final result = await LocalCardSyncService.probeRouter(router: testRouter);

      expect(result['success'], isFalse);
      expect(result['step'], equals('الحذف'));
      expect(result['errorMessage'], contains('خطوة (الحذف)'));
      expect(result['errorMessage'], contains('المنفذ 8728'));
      expect(result['errorMessage'], contains('غير مشفر'));
      expect(result['errorMessage'].contains(secretPassword), isFalse);
    });

    test('Timeout on step "الاتصال" reports timeout and step details', () async {
      mockClient = DiagnosticMockRouterOsClient(
        host: testRouter.host,
        port: testRouter.apiPort,
      )
        ..throwTimeoutOnStep = true
        ..stepToTimeout = 'connect';

      final result = await LocalCardSyncService.probeRouter(router: testRouter);

      expect(result['success'], isFalse);
      expect(result['errorCode'], equals('TIMEOUT'));
      expect(result['step'], equals('الاتصال'));
      expect(result['errorMessage'], contains('خطوة (الاتصال)'));
      expect(result['errorMessage'], contains('المنفذ 8728'));
      expect(result['errorMessage'], contains('غير مشفر'));
      expect(result['errorMessage'].contains(secretPassword), isFalse);
    });

    test('Encrypted connection on port 8729 reports (مشفر) in error message', () async {
      const sslRouter = RouterModel(
        id: 'router-ssl-8729-fail',
        name: 'SSL Router',
        host: '10.0.0.1',
        apiPort: 8729,
        status: 'ONLINE',
        connectionMethod: 'ROUTEROS_API_SSL',
      );

      await MikrotikDiscoveryService.saveRouterCredentials(
        routerId: sslRouter.id,
        username: 'admin',
        password: secretPassword,
      );

      mockClient = DiagnosticMockRouterOsClient(
        host: sslRouter.host,
        port: sslRouter.apiPort,
        useTls: true,
      )..failConnect = true;

      final result = await LocalCardSyncService.probeRouter(router: sslRouter);

      expect(result['success'], isFalse);
      expect(result['step'], equals('الاتصال'));
      expect(result['errorMessage'], contains('المنفذ 8729'));
      expect(result['errorMessage'], contains('مشفر'));
      expect(result['errorMessage'], isNot(contains('غير مشفر')));
    });
  });
}
