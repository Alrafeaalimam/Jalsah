// ============================================================================
// Platform: Commercial MikroTik Network & HotSpot Card Management System (Jalsah)
// File: test/local_card_sync_test.dart
// Description: Comprehensive unit tests for local hotspot card synchronization,
//              covering Card Type (a) [Username + Password], Card Type (b) [Numbers Only / Empty Password],
//              mixed batches, pre-flight probe test, deduplication against live router print,
//              local persistence security (no credentials in SharedPreferences), and resync pending.
// ============================================================================

import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mikrotik_cards_app/models/card_model.dart';
import 'package:mikrotik_cards_app/models/router_model.dart';
import 'package:mikrotik_cards_app/services/api_client.dart';
import 'package:mikrotik_cards_app/services/local_card_sync_service.dart';
import 'package:mikrotik_cards_app/services/mikrotik_discovery_service.dart';
import 'package:mikrotik_cards_app/services/routeros_binary_client.dart';

/// Fake RouterOS Binary Client simulating RouterOS API in memory
class FakeRouterOsBinaryClient extends RouterOsBinaryClient {
  final List<Map<String, String>> routerUsers = [];
  final List<String> createdUserLog = [];
  final List<String> removedUserLog = [];
  bool shouldFailConnect = false;
  bool shouldFailLogin = false;
  bool shouldFailOnUser = false;
  String? failOnUsername;

  FakeRouterOsBinaryClient({
    required super.host,
    required super.port,
    super.useTls = false,
    super.timeout = const Duration(seconds: 5),
  });

  @override
  Future<void> connect() async {
    if (shouldFailConnect) {
      throw const SocketException('Connection refused');
    }
  }

  @override
  Future<bool> login(String username, String password) async {
    if (shouldFailLogin) {
      throw AuthException('invalid user name or password');
    }
    return true;
  }

  @override
  Future<List<Map<String, String>>> getHotspotUsers() async {
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
    if (shouldFailOnUser && username == failOnUsername) {
      throw const SocketException('Broken pipe mid-sync');
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
    removedUserLog.add(username);
    final count = routerUsers.length;
    routerUsers.removeWhere((u) => u['name'] == username);
    return routerUsers.length < count;
  }

  @override
  Future<void> close() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeRouterOsBinaryClient fakeClient;
  late RouterModel testRouter;

  String createMockJwt({
    required String? tenantId,
    required String? userId,
    String role = 'TENANT_ADMIN',
  }) {
    final header = base64Url
        .encode(utf8.encode(jsonEncode({'alg': 'HS256', 'typ': 'JWT'})))
        .replaceAll('=', '');
    final payloadMap = <String, dynamic>{'role': role};
    if (tenantId != null) payloadMap['tenantId'] = tenantId;
    if (userId != null) payloadMap['userId'] = userId;
    final payload = base64Url
        .encode(utf8.encode(jsonEncode(payloadMap)))
        .replaceAll('=', '');
    return '$header.$payload.mock_signature';
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    LocalCardSyncService.resetTestStorage();
    MikrotikDiscoveryService.resetTestStorage();
    ApiClient.resetClient();

    // Authenticate client
    final jwt = createMockJwt(tenantId: 'tenant-test-1', userId: 'user-test-1');
    ApiClient.setAuthToken(jwt);

    testRouter = RouterModel(
      id: 'router-local-1',
      name: 'Local Mikrotik',
      host: '192.168.88.1',
      apiPort: 8728,
      status: 'ONLINE',
      connectionMethod: 'ROUTEROS_API_PLAIN',
    );

    // Save router credentials securely
    await MikrotikDiscoveryService.saveRouterCredentials(
      routerId: testRouter.id,
      username: 'admin',
      password: 'mypassword',
    );

    fakeClient = FakeRouterOsBinaryClient(
      host: testRouter.host,
      port: testRouter.apiPort,
    );

    LocalCardSyncService.clientFactory = ({
      required String host,
      required int port,
      required bool useTls,
      required Duration timeout,
    }) {
      return fakeClient;
    };
  });

  tearDown(() {
    LocalCardSyncService.resetTestStorage();
    MikrotikDiscoveryService.resetTestStorage();
    ApiClient.resetClient();
  });

  group('Requirement 4: Card Types (a), (b), and Mixed Batch', () {
    test('4.1 Card Type (a) [Username + Password] syncs successfully with credentials', () async {
      final cardA = const CardModel(
        id: 'card-a-1',
        username: 'user_alpha',
        password: 'pass_secret_123',
        status: 'GENERATED',
        price: 100,
      );

      final result = await LocalCardSyncService.syncCardsToRouter(
        router: testRouter,
        cards: [cardA],
        profile: 'u1m-d2m',
      );

      expect(result.success, isTrue);
      expect(result.syncedCount, equals(1));
      expect(result.failedCount, equals(0));

      // Verify router state
      expect(fakeClient.routerUsers.length, equals(1));
      final userOnRouter = fakeClient.routerUsers.first;
      expect(userOnRouter['name'], equals('user_alpha'));
      expect(userOnRouter['password'], equals('pass_secret_123'));
      expect(userOnRouter['profile'], equals('u1m-d2m'));

      // Verify local status
      final status = await LocalCardSyncService.getCardSyncStatus('card-a-1', 'user_alpha');
      expect(status, isNotNull);
      expect(status!.isSynced, isTrue);
    });

    test('4.2 Card Type (b) [Numbers Only] syncs successfully with empty password', () async {
      // For NUMBERS_ONLY, password is generated as empty string ''
      final cardB = const CardModel(
        id: 'card-b-1',
        username: '88219475',
        password: '',
        status: 'GENERATED',
        price: 50,
      );

      final result = await LocalCardSyncService.syncCardsToRouter(
        router: testRouter,
        cards: [cardB],
        profile: 'default',
      );

      expect(result.success, isTrue);
      expect(result.syncedCount, equals(1));
      expect(result.failedCount, equals(0));

      // Verify router state
      expect(fakeClient.routerUsers.length, equals(1));
      final userOnRouter = fakeClient.routerUsers.first;
      expect(userOnRouter['name'], equals('88219475'));
      expect(userOnRouter['password'], equals(''));
      expect(userOnRouter['profile'], equals('default'));

      // Verify local status
      final status = await LocalCardSyncService.getCardSyncStatus('card-b-1', '88219475');
      expect(status, isNotNull);
      expect(status!.isSynced, isTrue);
    });

    test('4.3 Mixed batch containing both Type (a) and Type (b) syncs seamlessly', () async {
      final mixedBatch = [
        const CardModel(
          id: 'card-mix-1',
          username: 'vip_user1',
          password: 'pin_4432',
          status: 'GENERATED',
        ),
        const CardModel(
          id: 'card-mix-2',
          username: '99482710',
          password: '',
          status: 'GENERATED',
        ),
        const CardModel(
          id: 'card-mix-3',
          username: 'vip_user2',
          password: 'pin_8871',
          status: 'GENERATED',
        ),
      ];

      final progressEvents = <String>[];

      final result = await LocalCardSyncService.syncCardsToRouter(
        router: testRouter,
        cards: mixedBatch,
        profile: 'default',
        onProgress: (current, total, currentUsername) {
          progressEvents.add('$current/$total: $currentUsername');
        },
      );

      expect(result.success, isTrue);
      expect(result.syncedCount, equals(3));
      expect(result.failedCount, equals(0));
      expect(progressEvents.length, equals(3));
      expect(progressEvents[0], equals('1/3: vip_user1'));
      expect(progressEvents[1], equals('2/3: 99482710'));
      expect(progressEvents[2], equals('3/3: vip_user2'));

      // Verify users on router
      expect(fakeClient.routerUsers.length, equals(3));
      expect(fakeClient.routerUsers[0]['password'], equals('pin_4432'));
      expect(fakeClient.routerUsers[1]['password'], equals(''));
      expect(fakeClient.routerUsers[2]['password'], equals('pin_8871'));
    });
  });

  group('Requirement 3: Pre-flight Probe (_jalsah_probe_test) & Name Comparison', () {
    test('3.1 Probe connects, creates _jalsah_probe_test with empty pass, verifies, and removes it cleanly', () async {
      final probeResult = await LocalCardSyncService.probeRouter(
        router: testRouter,
        profile: 'default',
      );

      expect(probeResult['success'], isTrue);
      expect(probeResult['message'], contains('تم التحقق من جاهزية الراوتر'));

      // Verify probe user was created and then removed immediately
      expect(fakeClient.createdUserLog, contains('_jalsah_probe_test'));
      expect(fakeClient.removedUserLog, contains('_jalsah_probe_test'));
      expect(fakeClient.routerUsers.any((u) => u['name'] == '_jalsah_probe_test'), isFalse);
    });

    test('3.2 Probe failure aborts before batch generation', () async {
      fakeClient.shouldFailConnect = true;

      final probeResult = await LocalCardSyncService.probeRouter(
        router: testRouter,
      );

      expect(probeResult['success'], isFalse);
      expect(probeResult['errorCode'], equals('CONNECTION_REFUSED'));
      expect(fakeClient.createdUserLog, isEmpty);
    });

    test('3.3 Comparison against /ip/hotspot/user/print deduplicates existing users by name for both types', () async {
      // Pre-populate router with existing users
      fakeClient.routerUsers.add({
        '.id': '*1',
        'name': 'existing_user_a',
        'password': 'existing_pass',
        'profile': 'default',
      });
      fakeClient.routerUsers.add({
        '.id': '*2',
        'name': '77218390',
        'password': '',
        'profile': 'default',
      });

      final cards = [
        const CardModel(
          id: 'c1',
          username: 'existing_user_a',
          password: 'new_pass_ignored',
          status: 'GENERATED',
        ),
        const CardModel(
          id: 'c2',
          username: '77218390',
          password: '',
          status: 'GENERATED',
        ),
        const CardModel(
          id: 'c3',
          username: 'brand_new_user',
          password: 'pass_new',
          status: 'GENERATED',
        ),
      ];

      final result = await LocalCardSyncService.syncCardsToRouter(
        router: testRouter,
        cards: cards,
      );

      expect(result.success, isTrue);
      expect(result.syncedCount, equals(3));
      // Only brand_new_user should have been added; existing two were not re-created
      expect(fakeClient.createdUserLog, equals(['brand_new_user']));
    });
  });

  group('Requirement 1: Security - ZERO Passwords in Local Persistence', () {
    test('1.1 saveCardSyncStatus saves ONLY cardId, status, timestamp and error without credentials', () async {
      await LocalCardSyncService.saveCardSyncStatus(
        cardId: 'card-sec-101',
        status: CardSyncStatus.synced,
      );

      await LocalCardSyncService.saveCardSyncStatus(
        cardId: 'card-sec-102',
        status: CardSyncStatus.failed,
        error: 'Profile missing on router',
      );

      // Verify retrieval
      final status1 = await LocalCardSyncService.getCardSyncStatus('card-sec-101', 'user1');
      expect(status1, isNotNull);
      expect(status1!.status, equals(CardSyncStatus.synced));
      expect(status1.errorMessage, isNull);

      final status2 = await LocalCardSyncService.getCardSyncStatus('card-sec-102', 'user2');
      expect(status2, isNotNull);
      expect(status2!.status, equals(CardSyncStatus.failed));
      expect(status2.errorMessage, equals('Profile missing on router'));

      // Now verify raw SharedPreferences data does NOT leak any passwords
      final prefs = await SharedPreferences.getInstance();
      final allKeys = prefs.getKeys();
      for (final key in allKeys) {
        expect(key, isNot(contains('pass')));
        expect(key, isNot(contains('secret')));
        final val = prefs.get(key).toString();
        expect(val, isNot(contains('pass_secret')));
        expect(val, isNot(contains('mypassword')));
      }
    });
  });

  group('Requirement 2: Resync Pending Cards with Live Router Print', () {
    test('2.1 Resync reads /ip/hotspot/user/print and syncs only missing cards', () async {
      // First attempt: Card 1 succeeds, Card 2 fails mid-sync
      fakeClient.shouldFailOnUser = true;
      fakeClient.failOnUsername = 'card_fails_user';

      final cards = [
        const CardModel(
          id: 'rc-1',
          username: 'card_ok_user',
          password: 'pass_ok',
          status: 'GENERATED',
        ),
        const CardModel(
          id: 'rc-2',
          username: 'card_fails_user',
          password: '',
          status: 'GENERATED',
        ),
      ];

      final firstResult = await LocalCardSyncService.syncCardsToRouter(
        router: testRouter,
        cards: cards,
      );

      expect(firstResult.success, isFalse);
      expect(firstResult.syncedCount, equals(1));
      expect(firstResult.failedCount, equals(1));

      // Fix network/router
      fakeClient.shouldFailOnUser = false;
      fakeClient.failOnUsername = null;

      // Call resyncPendingCards
      final resyncResult = await LocalCardSyncService.resyncPendingCards(
        router: testRouter,
        cards: cards,
      );

      expect(resyncResult.success, isTrue);
      expect(resyncResult.syncedCount, equals(2));
      expect(resyncResult.failedCount, equals(0));

      // Verify that card_ok_user was not duplicated on router
      final okMatches = fakeClient.routerUsers.where((u) => u['name'] == 'card_ok_user').toList();
      expect(okMatches.length, equals(1));

      // Verify card_fails_user was successfully created with empty password
      final failMatches = fakeClient.routerUsers.where((u) => u['name'] == 'card_fails_user').toList();
      expect(failMatches.length, equals(1));
      expect(failMatches.first['password'], equals(''));
    });
  });
}
