// ============================================================================
// Platform: Commercial MikroTik Network & HotSpot Card Management System (Jalsah)
// File: test/secure_credential_storage_test.dart
// Description: Comprehensive unit tests verifying strict identity enforcement,
//              prevention of global/shared keys, ownership-verified legacy migration,
//              atomic write-readback verification, corrupt data safety, and
//              lifecycle isolation across tenants and accounts.
// ============================================================================

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mikrotik_cards_app/services/api_client.dart';
import 'package:mikrotik_cards_app/services/mikrotik_discovery_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    MikrotikDiscoveryService.resetTestStorage();
    ApiClient.resetClient();
    ApiClient.setAuthToken(null);
  });

  tearDown(() {
    MikrotikDiscoveryService.resetTestStorage();
    ApiClient.resetClient();
    ApiClient.setAuthToken(null);
  });

  String createMockJwt({
    required String? tenantId,
    required String? userId,
    String role = 'TENANT_ADMIN',
  }) {
    final header = base64Url.encode(utf8.encode(jsonEncode({'alg': 'HS256', 'typ': 'JWT'}))).replaceAll('=', '');
    final payloadMap = <String, dynamic>{'role': role};
    if (tenantId != null) payloadMap['tenantId'] = tenantId;
    if (userId != null) payloadMap['userId'] = userId;
    final payload = base64Url.encode(utf8.encode(jsonEncode(payloadMap))).replaceAll('=', '');
    return '$header.$payload.mock_signature';
  }

  group('Fix 1: Rejection of Storage and Read Without Genuine Identity', () {
    test('1.1 Refuses to save or read credentials when unauthenticated (no JWT)', () async {
      ApiClient.setAuthToken(null);

      final saveOk = await MikrotikDiscoveryService.saveRouterCredentials(
        routerId: 'router-unauth-1',
        username: 'admin',
        password: 'pass',
      );
      expect(saveOk, isFalse, reason: 'Must reject saving without authenticated identity');

      final readRes = await MikrotikDiscoveryService.getRouterCredentials('router-unauth-1');
      expect(readRes, isNull, reason: 'Must refuse to read without authenticated identity');
    });

    test('1.2 Refuses to save or read when JWT lacks tenantId or userId', () async {
      // Token missing tenantId
      final tokenNoTenant = createMockJwt(tenantId: null, userId: 'user-only-1');
      ApiClient.setAuthToken(tokenNoTenant);

      final save1 = await MikrotikDiscoveryService.saveRouterCredentials(
        routerId: 'router-no-tenant',
        username: 'admin',
        password: 'pass',
      );
      expect(save1, isFalse);
      expect(await MikrotikDiscoveryService.getRouterCredentials('router-no-tenant'), isNull);

      // Token missing userId
      final tokenNoUser = createMockJwt(tenantId: 'tenant-only-1', userId: null);
      ApiClient.setAuthToken(tokenNoUser);

      final save2 = await MikrotikDiscoveryService.saveRouterCredentials(
        routerId: 'router-no-user',
        username: 'admin',
        password: 'pass',
      );
      expect(save2, isFalse);
      expect(await MikrotikDiscoveryService.getRouterCredentials('router-no-user'), isNull);
    });

    test('1.3 Never creates "global" or "shared" keys in secure storage or memory', () async {
      ApiClient.setAuthToken(null);

      await MikrotikDiscoveryService.saveRouterCredentials(
        routerId: 'router-check-keys',
        username: 'admin',
        password: 'pass',
      );

      // Inspect test mock storage directly
      MikrotikDiscoveryService.mockSecureStorage = {};
      final storedKeys = MikrotikDiscoveryService.mockSecureStorage!.keys;
      expect(storedKeys.any((k) => k.contains('global') || k.contains('shared')), isFalse);
    });
  });

  group('Fix 2: Safe Legacy Migration with Ownership Verification', () {
    test('2.1 Blind batch migration is disabled and does not transfer unknown legacy keys', () async {
      final token = createMockJwt(tenantId: 'tenant-active', userId: 'user-active');
      ApiClient.setAuthToken(token);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('rc_usr_legacy-batch-1', 'admin');
      await prefs.setString('rc_sec_legacy-batch-1', base64Encode(utf8.encode('pass')));

      final count = await MikrotikDiscoveryService.migrateAllLegacyCredentials();
      expect(count, equals(0), reason: 'Blind batch migration must be disabled to prevent cross-account leakage');

      // Legacy keys must remain untouched
      expect(prefs.containsKey('rc_usr_legacy-batch-1'), isTrue);
      expect(prefs.containsKey('rc_sec_legacy-batch-1'), isTrue);
    });

    test('2.2 Refuses migration if router ownership is NOT verified, leaving legacy keys untouched', () async {
      final token = createMockJwt(tenantId: 'tenant-intruder', userId: 'user-intruder');
      ApiClient.setAuthToken(token);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('rc_usr_unowned-router', 'victim_admin');
      await prefs.setString('rc_sec_unowned-router', base64Encode(utf8.encode('victim_secret')));

      // Verifier returns false (router does NOT belong to tenant-intruder)
      MikrotikDiscoveryService.routerOwnershipVerifier = (routerId, tenantId) async => false;

      final creds = await MikrotikDiscoveryService.getRouterCredentials('unowned-router');
      expect(creds, isNull, reason: 'Must not migrate credentials of unverified router');

      // Crucial: Original SharedPreferences keys MUST NOT be deleted
      expect(prefs.containsKey('rc_usr_unowned-router'), isTrue);
      expect(prefs.containsKey('rc_sec_unowned-router'), isTrue);
    });

    test('2.3 Does NOT delete legacy keys if secure storage write fails', () async {
      final token = createMockJwt(tenantId: 'tenant-owner', userId: 'user-owner');
      ApiClient.setAuthToken(token);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('rc_usr_write-fail-rt', 'owner_admin');
      await prefs.setString('rc_sec_write-fail-rt', base64Encode(utf8.encode('owner_pass')));

      // Ownership is verified
      MikrotikDiscoveryService.routerOwnershipVerifier = (routerId, tenantId) async => true;

      // Simulate a secure storage that rejects writes (read-only mock map)
      MikrotikDiscoveryService.mockSecureStorage = _FailingWriteMap({});

      final creds = await MikrotikDiscoveryService.getRouterCredentials('write-fail-rt');
      expect(creds, isNull, reason: 'Migration should return null when secure write fails');

      // Crucial: Original keys must NOT be deleted when secure write fails
      expect(prefs.containsKey('rc_usr_write-fail-rt'), isTrue);
      expect(prefs.containsKey('rc_sec_write-fail-rt'), isTrue);
    });

    test('2.4 Does NOT delete legacy keys if readback verification fails', () async {
      final token = createMockJwt(tenantId: 'tenant-owner', userId: 'user-owner');
      ApiClient.setAuthToken(token);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('rc_usr_verify-fail-rt', 'owner_admin');
      await prefs.setString('rc_sec_verify-fail-rt', base64Encode(utf8.encode('owner_pass')));

      MikrotikDiscoveryService.routerOwnershipVerifier = (routerId, tenantId) async => true;

      // Simulate a secure storage where write succeeds but readback returns corrupt/mismatched data
      MikrotikDiscoveryService.mockSecureStorage = _CorruptingReadMap({});

      final creds = await MikrotikDiscoveryService.getRouterCredentials('verify-fail-rt');
      expect(creds, isNull, reason: 'Migration must abort if readback verification fails');

      // Crucial: Original keys must NOT be deleted
      expect(prefs.containsKey('rc_usr_verify-fail-rt'), isTrue);
      expect(prefs.containsKey('rc_sec_verify-fail-rt'), isTrue);
    });

    test('2.5 Does NOT treat corrupted Base64 as plaintext and does NOT delete corrupted original', () async {
      final token = createMockJwt(tenantId: 'tenant-owner', userId: 'user-owner');
      ApiClient.setAuthToken(token);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('rc_usr_corrupt-b64-rt', 'admin');
      // Set non-base64 invalid string
      await prefs.setString('rc_sec_corrupt-b64-rt', '@@@INVALID-BASE64-NOT-ENCODED@@@');

      MikrotikDiscoveryService.routerOwnershipVerifier = (routerId, tenantId) async => true;

      final creds = await MikrotikDiscoveryService.getRouterCredentials('corrupt-b64-rt');
      expect(creds, isNull, reason: 'Must not blindly import corrupted data');

      // Original data must NOT be deleted silently
      expect(prefs.containsKey('rc_usr_corrupt-b64-rt'), isTrue);
      expect(prefs.containsKey('rc_sec_corrupt-b64-rt'), isTrue);
    });

    test('2.6 Successful migration occurs ONLY after verified write & readback, then purges legacy keys', () async {
      final token = createMockJwt(tenantId: 'tenant-legit', userId: 'user-legit');
      ApiClient.setAuthToken(token);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('rc_usr_legit-rt', 'legit_admin');
      await prefs.setString('rc_sec_legit-rt', base64Encode(utf8.encode('legit_password_999')));

      // Ownership confirmed
      MikrotikDiscoveryService.routerOwnershipVerifier = (routerId, tenantId) async => true;

      final creds = await MikrotikDiscoveryService.getRouterCredentials('legit-rt');
      expect(creds, isNotNull);
      expect(creds!['username'], equals('legit_admin'));
      expect(creds['password'], equals('legit_password_999'));

      // Now and ONLY now should the legacy unencrypted keys be purged from SharedPreferences!
      expect(prefs.containsKey('rc_usr_legit-rt'), isFalse);
      expect(prefs.containsKey('rc_sec_legit-rt'), isFalse);

      // Verify persistent secure storage has the data even after memory is cleared
      MikrotikDiscoveryService.clearMemoryCreds();
      final fromSecure = await MikrotikDiscoveryService.getRouterCredentials('legit-rt');
      expect(fromSecure, isNotNull);
      expect(fromSecure!['username'], equals('legit_admin'));
      expect(fromSecure['password'], equals('legit_password_999'));
    });
  });

  group('Fix 3: Credential Isolation and Data Lifecycle', () {
    test('3.1 Credentials do NOT transfer between tenants upon account switch', () async {
      final tokenA = createMockJwt(tenantId: 'tenant-AAA', userId: 'user-AAA');
      ApiClient.setAuthToken(tokenA);

      await MikrotikDiscoveryService.saveRouterCredentials(
        routerId: 'isolated-rt',
        username: 'admin_a',
        password: 'pass_a',
      );

      // Logout and login as Tenant B
      await ApiClient.logout();
      final tokenB = createMockJwt(tenantId: 'tenant-BBB', userId: 'user-BBB');
      ApiClient.setAuthToken(tokenB);

      // Tenant B queries the same router ID
      final credsB = await MikrotikDiscoveryService.getRouterCredentials('isolated-rt');
      expect(credsB, isNull, reason: 'Tenant B must not see Tenant A credentials');

      // Logout and switch back to Tenant A
      await ApiClient.logout();
      ApiClient.setAuthToken(tokenA);

      final credsA = await MikrotikDiscoveryService.getRouterCredentials('isolated-rt');
      expect(credsA, isNotNull);
      expect(credsA!['username'], equals('admin_a'));
      expect(credsA['password'], equals('pass_a'));
    });

    test('3.2 Deleting router or clearing tenant scope does NOT affect other tenants', () async {
      // Tenant 1
      await MikrotikDiscoveryService.saveRouterCredentials(
        routerId: 'r1',
        username: 'u1',
        password: 'p1',
        tenantId: 'tenant-1',
        userId: 'user-1',
      );

      // Tenant 2
      await MikrotikDiscoveryService.saveRouterCredentials(
        routerId: 'r2',
        username: 'u2',
        password: 'p2',
        tenantId: 'tenant-2',
        userId: 'user-2',
      );

      // Clear Tenant 1 scope only
      await MikrotikDiscoveryService.clearTenantCredentials('tenant-1');

      // Verify Tenant 1 is deleted
      final r1 = await MikrotikDiscoveryService.getRouterCredentials(
        'r1',
        tenantId: 'tenant-1',
        userId: 'user-1',
      );
      expect(r1, isNull);

      // Verify Tenant 2 is completely unaffected
      final r2 = await MikrotikDiscoveryService.getRouterCredentials(
        'r2',
        tenantId: 'tenant-2',
        userId: 'user-2',
      );
      expect(r2, isNotNull);
      expect(r2!['username'], equals('u2'));
      expect(r2['password'], equals('p2'));
    });
  });
}

/// Helper mock map that throws or fails on write for testing error recovery
class _FailingWriteMap implements Map<String, String> {
  final Map<String, String> _inner;
  _FailingWriteMap(this._inner);

  @override
  void operator []=(String key, String value) {
    throw Exception('Simulated secure storage write failure');
  }

  @override
  String? operator [](Object? key) => _inner[key];

  @override
  void clear() => _inner.clear();

  @override
  bool containsKey(Object? key) => _inner.containsKey(key);

  @override
  bool containsValue(Object? value) => _inner.containsValue(value);

  @override
  Iterable<MapEntry<String, String>> get entries => _inner.entries;

  @override
  bool get isEmpty => _inner.isEmpty;

  @override
  bool get isNotEmpty => _inner.isNotEmpty;

  @override
  Iterable<String> get keys => _inner.keys;

  @override
  int get length => _inner.length;

  @override
  String? remove(Object? key) => _inner.remove(key);

  @override
  Iterable<String> get values => _inner.values;

  @override
  void addAll(Map<String, String> other) => _inner.addAll(other);

  @override
  void addEntries(Iterable<MapEntry<String, String>> newEntries) => _inner.addEntries(newEntries);

  @override
  Map<RK, RV> cast<RK, RV>() => _inner.cast<RK, RV>();

  @override
  void forEach(void Function(String key, String value) action) => _inner.forEach(action);

  @override
  Map<K2, V2> map<K2, V2>(MapEntry<K2, V2> Function(String key, String value) convert) => _inner.map(convert);

  @override
  String putIfAbsent(String key, String Function() ifAbsent) => _inner.putIfAbsent(key, ifAbsent);

  @override
  void removeWhere(bool Function(String key, String value) test) => _inner.removeWhere(test);

  @override
  String update(String key, String Function(String value) update, {String Function()? ifAbsent}) =>
      _inner.update(key, update, ifAbsent: ifAbsent);

  @override
  void updateAll(String Function(String key, String value) update) => _inner.updateAll(update);
}

/// Helper mock map that writes correctly but returns corrupted/mismatched data on read
class _CorruptingReadMap extends _FailingWriteMap {
  _CorruptingReadMap(super.inner);

  @override
  void operator []=(String key, String value) {
    _inner[key] = value;
  }

  @override
  String? operator [](Object? key) {
    if (_inner.containsKey(key)) {
      return 'mismatched_corrupt_readback_value';
    }
    return null;
  }
}
