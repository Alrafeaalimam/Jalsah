// ============================================================================
// Platform: Commercial MikroTik Network & HotSpot Card Management System (Jalsah)
// File: test/probe_router_idempotent_test.dart
// Description: Unit tests for idempotent router probe (probeRouter) in LocalCardSyncService.
//              Covers:
//              1. Leftover probe user (_jalsah_probe_test) existing prior to probe.
//              2. Recoverable "already have user with this name" on creation (auto-delete & retry).
//              3. Deletion failure handling ("no such item" ignored, cleanup in finally).
//              4. Connection interrupted in the middle (SocketException / Broken pipe).
//              5. Friendly Arabic error formatting without raw "Exception: failure:".
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

/// Configurable Fake RouterOS client for probe edge-case testing
class MockProbeRouterOsClient extends RouterOsBinaryClient {
  final List<Map<String, String>> routerUsers = [];
  final List<String> createdUserLog = [];
  final List<String> removedUserLog = [];

  int connectAttempts = 0;
  bool throwTimeoutOnConnectOnce = false;
  bool throwTimeoutAlways = false;

  bool throwAlreadyHaveUserOnce = false;
  int createAttempts = 0;

  bool throwNoSuchItemOnRemove = false;
  bool throwErrorOnRemove = false;

  bool throwBrokenPipeOnVerify = false;
  bool throwBrokenPipeOnCreate = false;

  bool simulateMissingUserOnVerify = false;
  bool throwProfileNotFoundOnCreate = false;
  bool throwPermissionDeniedOnCreate = false;

  bool closed = false;

  MockProbeRouterOsClient({
    required super.host,
    required super.port,
    super.useTls = false,
    super.timeout = const Duration(seconds: 5),
  });

  @override
  Future<void> connect() async {
    connectAttempts++;
    if (throwTimeoutAlways) {
      throw TimeoutException('Connection timed out');
    }
    if (throwTimeoutOnConnectOnce && connectAttempts == 1) {
      throw TimeoutException('Connection timed out');
    }
  }

  @override
  Future<bool> login(String username, String password) async => true;

  @override
  Future<List<Map<String, String>>> getHotspotUsers() async {
    if (throwBrokenPipeOnVerify) {
      throw const SocketException('Broken pipe');
    }
    if (simulateMissingUserOnVerify) {
      // Return list without probe user even if created
      return routerUsers.where((u) => u['name'] != '_jalsah_probe_test').toList();
    }
    return List.from(routerUsers);
  }

  @override
  Future<bool> createHotspotUser({
    required String username,
    required String password,
    required String profile,
    String? comment,
    String? timeLimit,
  }) async {
    createAttempts++;
    if (throwBrokenPipeOnCreate) {
      throw const SocketException('Connection reset by peer');
    }
    if (throwProfileNotFoundOnCreate) {
      throw Exception('failure: profile <nonexistent> not found');
    }
    if (throwPermissionDeniedOnCreate) {
      throw Exception('failure: action not permitted, not enough permissions (9)');
    }
    if (throwAlreadyHaveUserOnce && createAttempts == 1) {
      throw Exception('failure: already have user with this name for this server');
    }

    createdUserLog.add(username);
    routerUsers.add({
      '.id': '*${routerUsers.length + 1}',
      'name': username,
      'password': password,
      'profile': profile,
      if (comment != null) 'comment': comment,
      if (timeLimit != null) 'limit-uptime': timeLimit,
    });
    return true;
  }

  @override
  Future<bool> removeHotspotUser(String username) async {
    if (throwNoSuchItemOnRemove) {
      throw Exception('failure: no such item');
    }
    if (throwErrorOnRemove) {
      throw Exception('failure: cannot remove item in current state');
    }

    removedUserLog.add(username);
    final count = routerUsers.length;
    routerUsers.removeWhere((u) => u['name'] == username);
    return routerUsers.length < count;
  }

  @override
  Future<void> close() async {
    closed = true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockProbeRouterOsClient mockClient;
  late RouterModel testRouter;

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

    testRouter = RouterModel(
      id: 'router-probe-test',
      name: 'Test MikroTik Probe',
      host: '192.168.88.1',
      apiPort: 8728,
      status: 'ONLINE',
      connectionMethod: 'ROUTEROS_API_PLAIN',
    );

    await MikrotikDiscoveryService.saveRouterCredentials(
      routerId: testRouter.id,
      username: 'admin',
      password: 'password123',
    );

    mockClient = MockProbeRouterOsClient(
      host: testRouter.host,
      port: testRouter.apiPort,
    );

    LocalCardSyncService.clientFactory = ({
      required String host,
      required int port,
      required bool useTls,
      required Duration timeout,
    }) {
      return mockClient;
    };
  });

  tearDown(() {
    LocalCardSyncService.resetTestStorage();
  });

  group('Requirement 6.1: Leftover Probe User (_jalsah_probe_test) Exists in Router', () {
    test('Cleans up leftover probe user before creation and keeps existing users untouched', () async {
      // Router already has _jalsah_probe_test left behind from a crashed session, plus a real customer
      mockClient.routerUsers.add({
        '.id': '*1',
        'name': 'real_client_card_99',
        'password': 'pin',
        'profile': 'default',
      });
      mockClient.routerUsers.add({
        '.id': '*2',
        'name': '_jalsah_probe_test',
        'password': '',
        'profile': 'default',
      });

      final result = await LocalCardSyncService.probeRouter(router: testRouter);

      expect(result['success'], isTrue);
      expect(result['message'], contains('تم التحقق من جاهزية الراوتر'));

      // Real user was NOT touched
      expect(mockClient.routerUsers.any((u) => u['name'] == 'real_client_card_99'), isTrue);

      // Probe user was cleaned up before creation AND in finally
      expect(mockClient.removedUserLog.where((u) => u == '_jalsah_probe_test').length, greaterThanOrEqualTo(2));
      expect(mockClient.routerUsers.any((u) => u['name'] == '_jalsah_probe_test'), isFalse);
      expect(mockClient.closed, isTrue);
    });

    test('Recovers gracefully when creation returns "already have user with this name" by deleting and retrying', () async {
      // Simulate race condition where creation fails with "already have user with this name" on first try
      mockClient.throwAlreadyHaveUserOnce = true;
      mockClient.routerUsers.add({
        '.id': '*1',
        'name': '_jalsah_probe_test',
        'password': '',
        'profile': 'default',
      });

      final result = await LocalCardSyncService.probeRouter(router: testRouter);

      expect(result['success'], isTrue);
      expect(mockClient.createAttempts, equals(2)); // Attempted, failed, cleaned up, retried and succeeded
      expect(mockClient.routerUsers.any((u) => u['name'] == '_jalsah_probe_test'), isFalse);
    });
  });

  group('Requirement 6.2: Deletion Failure & "no such item" Handling', () {
    test('Ignores "no such item" error during deletion and succeeds normally', () async {
      mockClient.throwNoSuchItemOnRemove = true;

      final result = await LocalCardSyncService.probeRouter(router: testRouter);

      expect(result['success'], isTrue);
      expect(mockClient.closed, isTrue);
    });

    test('Finally block safely handles deletion errors without masking result when verification failed', () async {
      mockClient.simulateMissingUserOnVerify = true; // Verification will fail
      mockClient.throwErrorOnRemove = true; // Removal in finally also throws

      final result = await LocalCardSyncService.probeRouter(router: testRouter);

      expect(result['success'], isFalse);
      expect(result['errorCode'], equals('PROBE_FAILED'));
      expect(result['errorMessage'], contains('فشل التحقق من إضافة المستخدم التجريبي داخل الراوتر'));
      expect(mockClient.closed, isTrue);
    });
  });

  group('Requirement 6.3: Connection Interrupted Mid-Probe', () {
    test('Returns clear Arabic error when connection drops after user creation during verification', () async {
      mockClient.throwBrokenPipeOnVerify = true;

      final result = await LocalCardSyncService.probeRouter(router: testRouter);

      expect(result['success'], isFalse);
      expect(result['errorCode'], equals('CONNECTION_REFUSED'));
      expect(result['errorMessage'], contains('انقطع الاتصال بالراوتر أثناء الفحص'));
      expect(result['errorMessage'], isNot(contains('Exception:')));
      expect(mockClient.closed, isTrue);
    });

    test('Returns clear Arabic error when connection resets during creation', () async {
      mockClient.throwBrokenPipeOnCreate = true;

      final result = await LocalCardSyncService.probeRouter(router: testRouter);

      expect(result['success'], isFalse);
      expect(result['errorCode'], equals('CONNECTION_REFUSED'));
      expect(result['errorMessage'], contains('تعذر الاتصال بمنفذ الراوتر'));
      expect(result['errorMessage'], isNot(contains('Exception:')));
      expect(mockClient.closed, isTrue);
    });
  });

  group('Requirement 5: Clear Arabic Error Messages (No raw Exception/failure)', () {
    test('Profile not found error is formatted in Arabic without failure: prefix', () async {
      mockClient.throwProfileNotFoundOnCreate = true;

      final result = await LocalCardSyncService.probeRouter(
        router: testRouter,
        profile: 'special_profile',
      );

      expect(result['success'], isFalse);
      expect(result['errorCode'], equals('PROFILE_NOT_FOUND'));
      expect(result['errorMessage'], contains('بروفايل الهوتسبوت المحدد (special_profile) غير موجود'));
      expect(result['errorMessage'], isNot(contains('failure:')));
      expect(result['errorMessage'], isNot(contains('Exception:')));
    });

    test('Permission denied error is formatted in Arabic without raw code', () async {
      mockClient.throwPermissionDeniedOnCreate = true;

      final result = await LocalCardSyncService.probeRouter(router: testRouter);

      expect(result['success'], isFalse);
      expect(result['errorCode'], equals('PROBE_FAILED'));
      expect(result['errorMessage'], contains('حساب الدخول للراوتر لا يملك صلاحية إضافة مستخدمين'));
      expect(result['errorMessage'], isNot(contains('Exception:')));
      expect(result['errorMessage'], isNot(contains('failure:')));
    });
  });

  group('Requirement 1 & 2: Timeout Handling & Single Retry', () {
    test('Timeout on first attempt retries once and succeeds', () async {
      mockClient.throwTimeoutOnConnectOnce = true;

      final result = await LocalCardSyncService.probeRouter(router: testRouter);

      expect(result['success'], isTrue);
      expect(mockClient.connectAttempts, equals(2)); // First timed out, second succeeded
      expect(result['message'], contains('تم التحقق من جاهزية الراوتر'));
    });

    test('Timeout twice returns failure with required Arabic message', () async {
      mockClient.throwTimeoutAlways = true;

      final result = await LocalCardSyncService.probeRouter(router: testRouter);

      expect(result['success'], isFalse);
      expect(result['errorCode'], equals('TIMEOUT'));
      expect(
        result['errorMessage'],
        equals('تعذر الاتصال بالراوتر، تأكد أن الهاتف على نفس شبكة الراوتر وأن خدمة API شغالة'),
      );
      expect(mockClient.connectAttempts, equals(2)); // Only 1 retry attempted
    });
  });

  group('Requirement 4: Strict Exact Name Equality (==) in removeHotspotUser', () {
    test('RouterOsBinaryClient.removeHotspotUser strictly checks == and never deletes _jalsah_probe_test_2 or similar', () async {
      final fakeRawClient = FakeRawCommandRouterOsClient();
      fakeRawClient.recordsToReturn = [
        {'.id': '*1', 'name': '_jalsah_probe_test_2'},
        {'.id': '*2', 'name': '_jalsah_probe_test_prefix'},
        {'.id': '*3', 'name': '_jalsah_probe_test'},
      ];

      final removed = await fakeRawClient.removeHotspotUser('_jalsah_probe_test');

      expect(removed, isTrue);
      // Verify that removal was ONLY invoked for '*3' (exact match), never for '*1' or '*2'
      final removeCommands = fakeRawClient.executedCommands
          .where((cmd) => cmd.contains('/ip/hotspot/user/remove'))
          .toList();
      expect(removeCommands.length, equals(1));
      expect(removeCommands.first, contains('=.id=*3'));
      expect(removeCommands.any((cmd) => cmd.contains('=.id=*1')), isFalse);
      expect(removeCommands.any((cmd) => cmd.contains('=.id=*2')), isFalse);
    });

    test('probeRouter preserves users with similar names like _jalsah_probe_test_2', () async {
      mockClient.routerUsers.add({
        '.id': '*1',
        'name': '_jalsah_probe_test_2',
        'password': 'pass',
        'profile': 'default',
      });
      mockClient.routerUsers.add({
        '.id': '*2',
        'name': '_jalsah_probe_test_similar',
        'password': 'pass',
        'profile': 'default',
      });

      final result = await LocalCardSyncService.probeRouter(router: testRouter);

      expect(result['success'], isTrue);
      // Both similar users must still exist untouched
      expect(mockClient.routerUsers.any((u) => u['name'] == '_jalsah_probe_test_2'), isTrue);
      expect(mockClient.routerUsers.any((u) => u['name'] == '_jalsah_probe_test_similar'), isTrue);
      // The probe user itself must be cleaned up
      expect(mockClient.routerUsers.any((u) => u['name'] == '_jalsah_probe_test'), isFalse);
    });
  });
}

class FakeRawCommandRouterOsClient extends RouterOsBinaryClient {
  final List<List<String>> executedCommands = [];
  List<Map<String, String>> recordsToReturn = [];

  FakeRawCommandRouterOsClient()
      : super(host: '192.168.88.1', port: 8728);

  @override
  Future<List<Map<String, String>>> executeCommand(List<String> commandWords) async {
    executedCommands.add(List.from(commandWords));
    if (commandWords[0] == '/ip/hotspot/user/print') {
      return recordsToReturn;
    }
    return [];
  }
}
