// ============================================================================
// Platform: Commercial MikroTik Network & HotSpot Card Management System (Jalsah)
// File: test/data_limit_test.dart
// Description: Unit tests for package data limit feature (GB / MB / Unlimited),
//              binary conversion constants (1GB = 1073741824, 1MB = 1048576),
//              RouterOS add commands with limit and without limit,
//              edge cases, boundary values, and legacy packages.
// ============================================================================

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mikrotik_cards_app/models/card_model.dart';
import 'package:mikrotik_cards_app/models/package_model.dart';
import 'package:mikrotik_cards_app/models/router_model.dart';
import 'package:mikrotik_cards_app/services/api_client.dart';
import 'package:mikrotik_cards_app/services/local_card_sync_service.dart';
import 'package:mikrotik_cards_app/services/mikrotik_discovery_service.dart';
import 'package:mikrotik_cards_app/services/routeros_binary_client.dart';

String _createMockJwt({required String tenantId, required String userId}) {
  final header = base64Url
      .encode(utf8.encode(jsonEncode({'alg': 'HS256', 'typ': 'JWT'})))
      .replaceAll('=', '');
  final payload = base64Url
      .encode(utf8.encode(jsonEncode({'tenantId': tenantId, 'userId': userId})))
      .replaceAll('=', '');
  return '$header.$payload.mock_signature';
}

/// Test spy client to inspect exact command words executed on RouterOS
class CommandCapturingRouterClient extends RouterOsBinaryClient {
  final List<List<String>> executedCommands = [];

  CommandCapturingRouterClient({
    required super.host,
    required super.port,
    super.useTls = false,
  });

  @override
  Future<void> connect() async {}

  @override
  Future<bool> login(String username, String password) async => true;

  @override
  Future<List<Map<String, String>>> executeCommand(
    List<String> words, {
    Duration? timeout,
  }) async {
    executedCommands.add(List.from(words));
    return [];
  }

  @override
  Future<void> close() async {}
}

/// Fake RouterOS Client storing user records
class FakeMemoryRouterClient extends RouterOsBinaryClient {
  final List<Map<String, dynamic>> users = [];

  FakeMemoryRouterClient({
    required super.host,
    required super.port,
    super.useTls = false,
  });

  @override
  Future<void> connect() async {}

  @override
  Future<bool> login(String username, String password) async => true;

  @override
  Future<List<Map<String, dynamic>>> getHotspotUsers({
    String? name,
    int? limit,
  }) async {
    if (name != null && name.isNotEmpty) {
      return users.where((u) => u['name'] == name).toList();
    }
    return List.from(users);
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
    final record = <String, dynamic>{
      '.id': '*${users.length + 1}',
      'name': username,
      'password': password,
      'profile': profile,
      if (comment != null) 'comment': comment,
      if (timeLimit != null) 'limit-uptime': timeLimit,
      if (limitBytesTotal != null && limitBytesTotal > 0)
        'limit-bytes-total': limitBytesTotal.toString(),
    };
    users.add(record);
    return true;
  }

  @override
  Future<void> close() async {}
}

void main() {
  group('1. PackageModel Data Limit & Binary Units Tests', () {
    test('Binary constants are strictly 1GB = 1073741824 and 1MB = 1048576', () {
      expect(PackageModel.bytesPerMb, equals(1048576));
      expect(PackageModel.bytesPerGb, equals(1073741824));
      expect(PackageModel.bytesPerMb, equals(1024 * 1024));
      expect(PackageModel.bytesPerGb, equals(1024 * 1024 * 1024));
    });

    test('formattedDataLimit returns "غير محدود" when dataLimitBytes is null (unlimited / legacy)', () {
      const pkg = PackageModel(
        id: 'pkg-legacy',
        name: 'باقة قديمة',
        code: 'LEGACY',
        downloadSpeedLimit: '5M',
        uploadSpeedLimit: '2M',
        durationMinutes: 60,
        validityDays: 1,
        price: 100,
        hotspotProfileName: 'default',
        dataLimitBytes: null,
      );
      expect(pkg.formattedDataLimit, equals('غير محدود'));
    });

    test('formattedDataLimit returns "غير محدود" when dataLimitBytes is 0 or negative', () {
      const pkgZero = PackageModel(
        id: 'pkg-zero',
        name: 'باقة صفرية',
        code: 'ZERO',
        downloadSpeedLimit: '5M',
        uploadSpeedLimit: '2M',
        durationMinutes: 60,
        validityDays: 1,
        price: 100,
        hotspotProfileName: 'default',
        dataLimitBytes: 0,
      );
      expect(pkgZero.formattedDataLimit, equals('غير محدود'));

      const pkgNegative = PackageModel(
        id: 'pkg-neg',
        name: 'باقة سالبة',
        code: 'NEG',
        downloadSpeedLimit: '5M',
        uploadSpeedLimit: '2M',
        durationMinutes: 60,
        validityDays: 1,
        price: 100,
        hotspotProfileName: 'default',
        dataLimitBytes: -100,
      );
      expect(pkgNegative.formattedDataLimit, equals('غير محدود'));
    });

    test('formattedDataLimit formats exact GB values correctly', () {
      const pkg1Gb = PackageModel(
        id: 'pkg-1gb',
        name: '1 جيجا',
        code: '1GB',
        downloadSpeedLimit: '5M',
        uploadSpeedLimit: '2M',
        durationMinutes: 60,
        validityDays: 1,
        price: 100,
        hotspotProfileName: 'default',
        dataLimitBytes: 1073741824, // 1 GB
      );
      expect(pkg1Gb.formattedDataLimit, equals('1 GB'));

      const pkg5Gb = PackageModel(
        id: 'pkg-5gb',
        name: '5 جيجا',
        code: '5GB',
        downloadSpeedLimit: '5M',
        uploadSpeedLimit: '2M',
        durationMinutes: 60,
        validityDays: 1,
        price: 500,
        hotspotProfileName: 'default',
        dataLimitBytes: 5 * 1073741824, // 5368709120
      );
      expect(pkg5Gb.formattedDataLimit, equals('5 GB'));
    });

    test('formattedDataLimit formats exact MB values correctly', () {
      const pkg1Mb = PackageModel(
        id: 'pkg-1mb',
        name: '1 ميجا',
        code: '1MB',
        downloadSpeedLimit: '1M',
        uploadSpeedLimit: '1M',
        durationMinutes: 60,
        validityDays: 1,
        price: 50,
        hotspotProfileName: 'default',
        dataLimitBytes: 1048576, // 1 MB
      );
      expect(pkg1Mb.formattedDataLimit, equals('1 MB'));

      const pkg500Mb = PackageModel(
        id: 'pkg-500mb',
        name: '500 ميجا',
        code: '500MB',
        downloadSpeedLimit: '2M',
        uploadSpeedLimit: '1M',
        durationMinutes: 60,
        validityDays: 1,
        price: 150,
        hotspotProfileName: 'default',
        dataLimitBytes: 500 * 1048576, // 524288000
      );
      expect(pkg500Mb.formattedDataLimit, equals('500 MB'));
    });

    test('formattedDataLimit handles fractional/boundary values gracefully', () {
      // 1.5 GB = 1.5 * 1073741824 = 1610612736 bytes
      const pkg1Point5Gb = PackageModel(
        id: 'pkg-1.5gb',
        name: '1.5 جيجا',
        code: '1.5GB',
        downloadSpeedLimit: '5M',
        uploadSpeedLimit: '2M',
        durationMinutes: 60,
        validityDays: 1,
        price: 250,
        hotspotProfileName: 'default',
        dataLimitBytes: 1610612736,
      );
      expect(pkg1Point5Gb.formattedDataLimit, equals('1.5 GB'));

      // 1.5 MB = 1.5 * 1048576 = 1572864 bytes
      const pkg1Point5Mb = PackageModel(
        id: 'pkg-1.5mb',
        name: '1.5 ميجا',
        code: '1.5MB',
        downloadSpeedLimit: '1M',
        uploadSpeedLimit: '1M',
        durationMinutes: 60,
        validityDays: 1,
        price: 60,
        hotspotProfileName: 'default',
        dataLimitBytes: 1572864,
      );
      expect(pkg1Point5Mb.formattedDataLimit, equals('1.5 MB'));
    });

    test('fromJson and toJson preserve dataLimitBytes correctly', () {
      final json = {
        'id': 'pkg-json',
        'name': 'باقة 10G',
        'code': 'P-10G',
        'downloadSpeedLimit': '10M',
        'uploadSpeedLimit': '5M',
        'durationMinutes': 1440,
        'validityDays': 7,
        'dataLimitBytes': 10737418240, // 10 GB
        'price': 1000.0,
        'hotspotProfileName': 'hs_10g',
        'isActive': true,
        'currency': 'SDG',
        'simultaneousSessions': 1,
      };

      final model = PackageModel.fromJson(json);
      expect(model.dataLimitBytes, equals(10737418240));
      expect(model.formattedDataLimit, equals('10 GB'));

      final outJson = model.toJson();
      expect(outJson['dataLimitBytes'], equals(10737418240));
    });

    test('Legacy json without dataLimitBytes defaults to null and "غير محدود"', () {
      final legacyJson = {
        'id': 'pkg-old',
        'name': 'باقة قديمة بدون حجم بيانات',
        'code': 'OLD-PKG',
        'downloadSpeedLimit': '2M',
        'uploadSpeedLimit': '1M',
        'durationMinutes': 720,
        'validityDays': 1,
        'price': 300.0,
        'hotspotProfileName': 'default',
      };

      final model = PackageModel.fromJson(legacyJson);
      expect(model.dataLimitBytes, isNull);
      expect(model.formattedDataLimit, equals('غير محدود'));

      final outJson = model.toJson();
      expect(outJson.containsKey('dataLimitBytes'), isFalse);
    });
  });

  group('2. RouterOsBinaryClient createHotspotUser Add Command Tests', () {
    test('Sends =limit-bytes-total when limitBytesTotal is specified (> 0)', () async {
      final client = CommandCapturingRouterClient(host: '192.168.88.1', port: 8728);

      final fiveGbBytes = 5 * PackageModel.bytesPerGb; // 5368709120
      await client.createHotspotUser(
        username: 'user_5gb',
        password: 'pin_123',
        profile: 'jalsah-profile',
        comment: 'Jalsah:BATCH1',
        timeLimit: '60m',
        limitBytesTotal: fiveGbBytes,
      );

      expect(client.executedCommands.length, equals(1));
      final words = client.executedCommands.first;

      expect(words, contains('/ip/hotspot/user/add'));
      expect(words, contains('=name=user_5gb'));
      expect(words, contains('=password=pin_123'));
      expect(words, contains('=profile=jalsah-profile'));
      expect(words, contains('=comment=Jalsah:BATCH1'));
      expect(words, contains('=limit-uptime=60m'));
      expect(words, contains('=limit-bytes-total=5368709120'));
    });

    test('Sends =limit-bytes-total with exact MB bytes', () async {
      final client = CommandCapturingRouterClient(host: '192.168.88.1', port: 8728);

      final fiveHundredMbBytes = 500 * PackageModel.bytesPerMb; // 524288000
      await client.createHotspotUser(
        username: 'user_500mb',
        password: '',
        profile: 'default',
        limitBytesTotal: fiveHundredMbBytes,
      );

      expect(client.executedCommands.length, equals(1));
      final words = client.executedCommands.first;

      expect(words, contains('=limit-bytes-total=524288000'));
    });

    test('Does NOT send =limit-bytes-total when limitBytesTotal is null (Unlimited)', () async {
      final client = CommandCapturingRouterClient(host: '192.168.88.1', port: 8728);

      await client.createHotspotUser(
        username: 'user_unlimited',
        password: 'pass',
        profile: 'default',
        timeLimit: '120m',
        limitBytesTotal: null,
      );

      expect(client.executedCommands.length, equals(1));
      final words = client.executedCommands.first;

      expect(words, contains('/ip/hotspot/user/add'));
      expect(words, contains('=name=user_unlimited'));
      expect(words, contains('=limit-uptime=120m'));
      expect(words.any((w) => w.startsWith('=limit-bytes-total')), isFalse);
    });

    test('Does NOT send =limit-bytes-total when limitBytesTotal is 0 or negative', () async {
      final client = CommandCapturingRouterClient(host: '192.168.88.1', port: 8728);

      await client.createHotspotUser(
        username: 'user_zero_limit',
        password: 'pass',
        profile: 'default',
        limitBytesTotal: 0,
      );

      expect(client.executedCommands.length, equals(1));
      final words = client.executedCommands.first;

      expect(words.any((w) => w.startsWith('=limit-bytes-total')), isFalse);
    });
  });

  group('3. LocalCardSyncService Data Limit Integration Tests', () {
    late RouterModel testRouter;
    late FakeMemoryRouterClient fakeClient;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      LocalCardSyncService.resetTestStorage();
      MikrotikDiscoveryService.resetTestStorage();
      ApiClient.resetClient();

      final jwt = _createMockJwt(tenantId: 'tenant-dl-1', userId: 'user-dl-1');
      ApiClient.setAuthToken(jwt);

      await MikrotikDiscoveryService.saveRouterCredentials(
        routerId: 'router-data-test',
        username: 'admin',
        password: 'pass123',
      );

      testRouter = const RouterModel(
        id: 'router-data-test',
        name: 'Test Data Limit Router',
        host: '192.168.88.1',
        apiPort: 8728,
        status: 'ONLINE',
      );

      fakeClient = FakeMemoryRouterClient(host: '192.168.88.1', port: 8728);
      LocalCardSyncService.clientFactory = ({
        required String host,
        required int port,
        required bool useTls,
        required Duration timeout,
      }) =>
          fakeClient;
    });

    tearDown(() {
      LocalCardSyncService.resetTestStorage();
    });

    test('syncCardsToRouter propagates limitBytesTotal to router users', () async {
      final cards = [
        const CardModel(
          id: 'card-dl-1',
          username: 'user_dl_1',
          password: 'pin1',
          status: 'GENERATED',
        ),
      ];

      final twoGb = 2 * PackageModel.bytesPerGb; // 2147483648
      final result = await LocalCardSyncService.syncCardsToRouter(
        router: testRouter,
        cards: cards,
        profile: 'jalsah-pkg',
        timeLimit: '60m',
        limitBytesTotal: twoGb,
      );

      expect(result.success, isTrue);
      expect(result.syncedCount, equals(1));
      expect(fakeClient.users.length, equals(1));

      final created = fakeClient.users.first;
      expect(created['name'], equals('user_dl_1'));
      expect(created['limit-uptime'], equals('60m'));
      expect(created['limit-bytes-total'], equals('2147483648'));
    });

    test('syncCardsToRouter omits limit-bytes-total when limitBytesTotal is null (Unlimited)', () async {
      final cards = [
        const CardModel(
          id: 'card-unlimited-1',
          username: 'user_unlimited_1',
          password: 'pin2',
          status: 'GENERATED',
        ),
      ];

      final result = await LocalCardSyncService.syncCardsToRouter(
        router: testRouter,
        cards: cards,
        profile: 'default',
        limitBytesTotal: null,
      );

      expect(result.success, isTrue);
      expect(result.syncedCount, equals(1));
      expect(fakeClient.users.length, equals(1));

      final created = fakeClient.users.first;
      expect(created['name'], equals('user_unlimited_1'));
      expect(created.containsKey('limit-bytes-total'), isFalse);
    });

    test('resyncPendingCards propagates limitBytesTotal on retry', () async {
      final cards = [
        const CardModel(
          id: 'card-resync-1',
          username: 'user_resync_1',
          password: 'pin3',
          status: 'GENERATED',
        ),
      ];

      final fiveHundredMb = 500 * PackageModel.bytesPerMb; // 524288000
      final result = await LocalCardSyncService.resyncPendingCards(
        router: testRouter,
        cards: cards,
        profile: 'default',
        limitBytesTotal: fiveHundredMb,
      );

      expect(result.success, isTrue);
      expect(result.syncedCount, equals(1));
      expect(fakeClient.users.length, equals(1));

      final created = fakeClient.users.first;
      expect(created['name'], equals('user_resync_1'));
      expect(created['limit-bytes-total'], equals('524288000'));
    });
  });
}
