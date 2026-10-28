// ============================================================================
// Platform: Commercial MikroTik Network & HotSpot Card Management System (Jalsah)
// File: lib/services/mikrotik_discovery_service.dart
// Service: Local MikroTik Router Discovery & Direct On-Device Diagnostics
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/discovered_router_model.dart';
import '../models/router_model.dart';
import 'api_client.dart';
import 'routeros_binary_client.dart';

class MikrotikDiscoveryService {
  static const Duration defaultProbeTimeout = Duration(milliseconds: 2200);

  /// Optional mock hook for direct connection testing in unit/widget tests
  static Future<Map<String, dynamic>> Function({
    required String host,
    required int port,
    required String username,
    required String password,
    String? connectionMethod,
    Duration timeout,
  })? directConnectionTester;

  /// Optional mock hook for probeHost in tests
  static Future<DiscoveredRouterModel> Function(
    String host, {
    int port,
    Duration timeout,
    String? username,
    String? password,
  })? probeHostTester;

  /// In-memory backing store for tests when running under flutter test.
  static final Map<String, String> _testSecureStorage = {};

  /// Optional mock backing store for unit/widget tests.
  /// When non-null, reads and writes operate on this map directly.
  static Map<String, String>? mockSecureStorage;

  /// Underlying FlutterSecureStorage instance with Android EncryptedSharedPreferences enabled.
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );

  /// Returns the mock or test storage map if running in test environment, or null for real device storage.
  static Map<String, String>? get _effectiveStorage {
    if (mockSecureStorage != null) return mockSecureStorage;
    if (Platform.environment.containsKey('FLUTTER_TEST')) return _testSecureStorage;
    return null;
  }

  /// Local cache for router credentials on device (for on-device LAN authentication)
  static final Map<String, Map<String, String>> _inMemoryCreds = {};

  /// Helper to safely read from secure storage (or mock in tests).
  static Future<String?> _secureRead(String key) async {
    final mock = _effectiveStorage;
    if (mock != null) {
      return mock[key];
    }
    try {
      return await _storage.read(key: key);
    } catch (e) {
      debugPrint('[MikrotikDiscoveryService] Secure storage read error: $e');
      return null;
    }
  }

  /// Helper to safely write to secure storage (or mock in tests).
  static Future<bool> _secureWrite(String key, String value) async {
    final mock = _effectiveStorage;
    if (mock != null) {
      mock[key] = value;
      return true;
    }
    try {
      await _storage.write(key: key, value: value);
      return true;
    } catch (e) {
      debugPrint('[MikrotikDiscoveryService] Secure storage write error: $e');
      return false;
    }
  }

  /// Helper to safely delete from secure storage (or mock in tests).
  static Future<bool> _secureDelete(String key) async {
    final mock = _effectiveStorage;
    if (mock != null) {
      mock.remove(key);
      return true;
    }
    try {
      await _storage.delete(key: key);
      return true;
    } catch (e) {
      debugPrint('[MikrotikDiscoveryService] Secure storage delete error: $e');
      return false;
    }
  }

  /// Helper to read all keys from secure storage (or mock in tests).
  static Future<Map<String, String>> _secureReadAll() async {
    final mock = _effectiveStorage;
    if (mock != null) {
      return Map<String, String>.from(mock);
    }
    try {
      return await _storage.readAll();
    } catch (e) {
      debugPrint('[MikrotikDiscoveryService] Secure storage readAll error: $e');
      return {};
    }
  }

  /// Resolves the authenticated tenant ID or returns null if not authenticated.
  static String? _resolveTenantId(String? explicitTenantId) {
    if (explicitTenantId != null && explicitTenantId.trim().isNotEmpty) {
      return explicitTenantId.trim();
    }
    final fromToken = ApiClient.getTenantId();
    if (fromToken != null && fromToken.trim().isNotEmpty) {
      return fromToken.trim();
    }
    return null;
  }

  /// Resolves the authenticated user ID or returns null if not authenticated.
  static String? _resolveUserId(String? explicitUserId) {
    if (explicitUserId != null && explicitUserId.trim().isNotEmpty) {
      return explicitUserId.trim();
    }
    final fromToken = ApiClient.getUserId();
    if (fromToken != null && fromToken.trim().isNotEmpty) {
      return fromToken.trim();
    }
    return null;
  }

  /// Generates a namespaced key ensuring isolation between tenants, users, and routers.
  /// Returns null if valid authenticated identity (tenantId and userId) is missing.
  /// Strictly eliminates any fallback to 'global', 'shared', or default namespaces.
  static String? _buildKey({
    required String routerId,
    required String field,
    String? tenantId,
    String? userId,
  }) {
    if (routerId.trim().isEmpty) return null;
    final tId = _resolveTenantId(tenantId);
    final uId = _resolveUserId(userId);
    if (tId == null || uId == null) return null;
    return 'sec_rt_${tId}_${uId}_${routerId.trim()}_$field';
  }

  /// Generates an in-memory cache key ensuring tenant and user isolation.
  /// Returns null if valid authenticated identity is missing.
  static String? _buildMemoryKey({
    required String routerId,
    String? tenantId,
    String? userId,
  }) {
    if (routerId.trim().isEmpty) return null;
    final tId = _resolveTenantId(tenantId);
    final uId = _resolveUserId(userId);
    if (tId == null || uId == null) return null;
    return '${tId}_${uId}_${routerId.trim()}';
  }

  /// Optional hook to verify router ownership in tests or custom flows.
  static Future<bool> Function(String routerId, String tenantId)? routerOwnershipVerifier;

  /// Verifies that the router belongs to the authenticated tenant via reliable backend source.
  static Future<bool> _verifyRouterOwnership(String routerId, String tenantId) async {
    if (routerOwnershipVerifier != null) {
      return await routerOwnershipVerifier!(routerId, tenantId);
    }
    try {
      final res = await ApiClient.getRouters();
      if (res['success'] == true && res['data'] is List<RouterModel>) {
        final routers = res['data'] as List<RouterModel>;
        return routers.any((r) => r.id == routerId);
      }
    } catch (e) {
      debugPrint('[MikrotikDiscoveryService] Ownership verification check error: $e');
    }
    return false;
  }

  /// Securely caches router credentials using FlutterSecureStorage with tenant & user isolation.
  /// Rejects storage and returns false if authenticated tenant or user identity is missing.
  /// Removes unencrypted legacy SharedPreferences credentials only upon successful verified write.
  static Future<bool> saveRouterCredentials({
    required String routerId,
    required String username,
    required String password,
    String? tenantId,
    String? userId,
  }) async {
    if (routerId.trim().isEmpty || username.trim().isEmpty) return false;

    final memKey = _buildMemoryKey(
      routerId: routerId,
      tenantId: tenantId,
      userId: userId,
    );
    final userKey = _buildKey(
      routerId: routerId,
      field: 'user',
      tenantId: tenantId,
      userId: userId,
    );
    final passKey = _buildKey(
      routerId: routerId,
      field: 'pass',
      tenantId: tenantId,
      userId: userId,
    );

    // Reject save if identity is missing or unauthenticated (Fix 1)
    if (memKey == null || userKey == null || passKey == null) {
      debugPrint('[MikrotikDiscoveryService] Rejected saveRouterCredentials: No valid authenticated tenant/user identity');
      return false;
    }

    final uOk = await _secureWrite(userKey, username.trim());
    final pOk = await _secureWrite(passKey, password);

    if (!uOk || !pOk) {
      debugPrint('[MikrotikDiscoveryService] Failed to write credentials to secure storage');
      return false;
    }

    // Verify written credentials can be read back before updating memory or purging legacy
    final verifyUser = await _secureRead(userKey);
    final verifyPass = await _secureRead(passKey);
    if (verifyUser != username.trim() || verifyPass != password) {
      debugPrint('[MikrotikDiscoveryService] Readback verification failed after write');
      return false;
    }

    // Only update memory cache after secure storage persistence is verified
    _inMemoryCreds[memKey] = {
      'username': username.trim(),
      'password': password,
    };

    // Purge legacy insecure SharedPreferences keys for this router only after verified write
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('rc_usr_$routerId');
      await prefs.remove('rc_sec_$routerId');
    } catch (_) {}

    return true;
  }

  /// Retrieves saved credentials for a router if present on this device for the authenticated user/tenant.
  /// Rejects retrieval and returns null if authenticated tenant or user identity is missing.
  /// Checks memory first, then FlutterSecureStorage.
  /// If missing from secure storage, safely checks for legacy SharedPreferences credentials,
  /// verifies router ownership against the active tenant, verifies write & readback,
  /// and only purges the unencrypted legacy keys after complete verification.
  static Future<Map<String, String>?> getRouterCredentials(
    String routerId, {
    String? tenantId,
    String? userId,
  }) async {
    if (routerId.trim().isEmpty) return null;

    final memKey = _buildMemoryKey(
      routerId: routerId,
      tenantId: tenantId,
      userId: userId,
    );
    final userKey = _buildKey(
      routerId: routerId,
      field: 'user',
      tenantId: tenantId,
      userId: userId,
    );
    final passKey = _buildKey(
      routerId: routerId,
      field: 'pass',
      tenantId: tenantId,
      userId: userId,
    );

    // Reject read if identity is missing or unauthenticated (Fix 1)
    if (memKey == null || userKey == null || passKey == null) {
      debugPrint('[MikrotikDiscoveryService] Rejected getRouterCredentials: No valid authenticated tenant/user identity');
      return null;
    }

    if (_inMemoryCreds.containsKey(memKey)) {
      return _inMemoryCreds[memKey];
    }

    // 1. Attempt reading from Secure Storage
    final storedUser = await _secureRead(userKey);
    final storedPass = await _secureRead(passKey);

    if (storedUser != null && storedUser.isNotEmpty) {
      final creds = {
        'username': storedUser,
        'password': storedPass ?? '',
      };
      _inMemoryCreds[memKey] = creds;
      return creds;
    }

    // 2. Safe Legacy Migration with Ownership Verification (Fix 2)
    try {
      final prefs = await SharedPreferences.getInstance();
      final legacyUser = prefs.getString('rc_usr_$routerId');
      final legacySec = prefs.getString('rc_sec_$routerId');

      if (legacyUser != null && legacyUser.trim().isNotEmpty) {
        final tId = _resolveTenantId(tenantId);
        if (tId == null) {
          return null;
        }

        // Verify router ownership for the current tenant
        final isOwned = await _verifyRouterOwnership(routerId, tId);
        if (!isOwned) {
          debugPrint(
            '[MikrotikDiscoveryService] Legacy credentials for router $routerId NOT migrated: '
            'Router ownership not verified for tenant $tId. Legacy data left untouched on device.',
          );
          // Do NOT migrate, do NOT delete legacy keys!
          return null;
        }

        // Decode password strictly. Do NOT assume corrupted data is plaintext!
        String legacyPass = '';
        if (legacySec != null && legacySec.isNotEmpty) {
          try {
            final decodedBytes = base64Decode(legacySec);
            legacyPass = utf8.decode(decodedBytes);
          } catch (e) {
            debugPrint('[MikrotikDiscoveryService] Legacy password corrupted or invalid base64: $e');
            // Corrupted data: Do NOT migrate, do NOT delete original!
            return null;
          }
        }

        // Write to secure storage
        final wUserOk = await _secureWrite(userKey, legacyUser.trim());
        final wPassOk = await _secureWrite(passKey, legacyPass);
        if (!wUserOk || !wPassOk) {
          debugPrint('[MikrotikDiscoveryService] Failed to write legacy credentials to secure storage');
          // Write failed: Do NOT delete legacy keys!
          return null;
        }

        // Verify readback from secure storage before deleting original!
        final verifyUser = await _secureRead(userKey);
        final verifyPass = await _secureRead(passKey);
        if (verifyUser != legacyUser.trim() || verifyPass != legacyPass) {
          debugPrint('[MikrotikDiscoveryService] Secure storage readback verification failed during migration');
          // Verification failed: Do NOT delete legacy keys!
          return null;
        }

        // Only after proven write and readback verification, purge the unencrypted keys!
        await prefs.remove('rc_usr_$routerId');
        await prefs.remove('rc_sec_$routerId');

        final creds = {
          'username': legacyUser.trim(),
          'password': legacyPass,
        };
        _inMemoryCreds[memKey] = creds;
        return creds;
      }
    } catch (e) {
      debugPrint('[MikrotikDiscoveryService] Legacy migration error: $e');
    }

    return null;
  }

  /// Safely deletes router credentials locally from secure storage and memory.
  /// Deletes for the verifiable scope (current authenticated tenant and user).
  static Future<bool> deleteRouterCredentials({
    required String routerId,
    String? tenantId,
    String? userId,
  }) async {
    if (routerId.trim().isEmpty) return false;

    final memKey = _buildMemoryKey(
      routerId: routerId,
      tenantId: tenantId,
      userId: userId,
    );
    final userKey = _buildKey(
      routerId: routerId,
      field: 'user',
      tenantId: tenantId,
      userId: userId,
    );
    final passKey = _buildKey(
      routerId: routerId,
      field: 'pass',
      tenantId: tenantId,
      userId: userId,
    );

    if (memKey != null) {
      _inMemoryCreds.remove(memKey);
    }

    var uOk = true;
    var pOk = true;
    if (userKey != null) {
      uOk = await _secureDelete(userKey);
    }
    if (passKey != null) {
      pOk = await _secureDelete(passKey);
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('rc_usr_$routerId');
      await prefs.remove('rc_sec_$routerId');
    } catch (_) {}

    return uOk && pOk;
  }

  /// Clears in-memory credentials cache (useful for testing or session reset).
  static void clearMemoryCreds() {
    _inMemoryCreds.clear();
  }

  /// Resets test secure storage and memory cache (used by unit/widget test runners).
  static void resetTestStorage() {
    _inMemoryCreds.clear();
    _testSecureStorage.clear();
    mockSecureStorage = null;
    routerOwnershipVerifier = null;
  }

  /// Clears credentials belonging to a specific tenant from secure storage and memory,
  /// strictly preserving other tenants' credentials.
  static Future<void> clearTenantCredentials(String tenantId) async {
    if (tenantId.trim().isEmpty) return;
    final cleanTenantId = tenantId.trim();
    try {
      _inMemoryCreds.removeWhere((k, _) => k.startsWith('${cleanTenantId}_'));

      final all = await _secureReadAll();
      final prefix = 'sec_rt_${cleanTenantId}_';
      for (final key in all.keys) {
        if (key.startsWith(prefix)) {
          await _secureDelete(key);
        }
      }
    } catch (e) {
      debugPrint('[MikrotikDiscoveryService] clearTenantCredentials error: $e');
    }
  }

  /// Batch migration of legacy SharedPreferences credentials.
  /// Blind batch migration is disabled for security to prevent cross-account credential leakage.
  /// Individual router migration occurs on-demand via [getRouterCredentials]
  /// after verifying router ownership against the authenticated tenant.
  static Future<int> migrateAllLegacyCredentials({
    String? tenantId,
    String? userId,
  }) async {
    debugPrint(
      '[MikrotikDiscoveryService] Blind batch migration is disabled to prevent cross-account credential leakage. '
      'Routers are migrated individually upon ownership verification.',
    );
    return 0;
  }

  /// Checks whether an IP or hostname is a private RFC1918 local network address.
  static bool isLocalPrivateIp(String host) {
    final clean = host.trim().toLowerCase();
    if (clean == 'localhost' || clean.startsWith('127.')) return true;

    final parts = clean.split('.').map((p) => int.tryParse(p)).toList();
    if (parts.length != 4 || parts.any((p) => p == null || p < 0 || p > 255)) {
      return false;
    }

    final b0 = parts[0]!;
    final b1 = parts[1]!;

    if (b0 == 10) return true; // 10.0.0.0/8
    if (b0 == 172 && b1 >= 16 && b1 <= 31) return true; // 172.16.0.0/12
    if (b0 == 192 && b1 == 168) return true; // 192.168.0.0/16
    return false;
  }

  /// Determines candidate gateway IPs to probe on the local network.
  static Future<List<String>> getCandidateGatewayIps() async {
    final candidates = <String>{};

    // 1. MikroTik default factory address
    candidates.add('192.168.88.1');

    // 2. Derive gateway from local network interfaces if possible
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );

      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          final ipStr = addr.address;
          if (isLocalPrivateIp(ipStr)) {
            final parts = ipStr.split('.');
            if (parts.length == 4) {
              // Assume standard default gateway at .1
              candidates.add('${parts[0]}.${parts[1]}.${parts[2]}.1');
            }
          }
        }
      }
    } catch (_) {
      // Platform may disallow interface listing without root / Termux ai_flags
    }

    // 3. Common SOHO router gateways
    candidates.add('192.168.1.1');
    candidates.add('192.168.0.1');
    candidates.add('10.0.0.1');
    candidates.add('172.16.0.1');

    return candidates.toList();
  }

  /// Probes a specific IP address to determine if it is a MikroTik router
  /// and reads its system identity and resources if accessible.
  static Future<DiscoveredRouterModel> probeHost(
    String host, {
    int port = 8728,
    Duration timeout = defaultProbeTimeout,
    String? username,
    String? password,
  }) async {
    if (probeHostTester != null) {
      return await probeHostTester!(
        host,
        port: port,
        timeout: timeout,
        username: username,
        password: password,
      );
    }
    bool isMikrotik = false;
    bool managementReachable = false;
    bool authRequired = false;
    int resolvedPort = port;
    String? identity;
    String? boardName;
    String? version;
    String? cpu;
    String? uptime;
    String? platform;
    String? errorMessage;

    final hasCreds = (username != null && username.isNotEmpty);

    // 1. First Priority: Check standard RouterOS API port 8728 (supported on RouterOS v6 & v7)
    try {
      final probeTimeout = timeout > const Duration(milliseconds: 1200)
          ? const Duration(milliseconds: 1200)
          : timeout;
      final socket = await Socket.connect(host, 8728, timeout: probeTimeout);
      isMikrotik = true;
      managementReachable = true;
      resolvedPort = 8728;
      await socket.close();

      // If credentials provided, fetch real identity and resource info via binary client
      if (hasCreds) {
        try {
          final binaryClient = RouterOsBinaryClient(
            host: host,
            port: 8728,
            timeout: timeout,
          );
          await binaryClient.connect();
          await binaryClient.login(username, password ?? '');
          final info = await binaryClient.readSystemInfo();
          identity = info['identity'];
          boardName = info['boardName'];
          version = info['version'];
          cpu = info['cpuLoad'] != null ? '${info['cpuLoad']}%' : null;
          await binaryClient.close();
        } on AuthException catch (_) {
          authRequired = true;
        } catch (_) {}
      } else {
        authRequired = true;
      }
    } catch (_) {}

    // 2. Second Priority: Check secure RouterOS API-SSL port 8729
    if (!isMikrotik) {
      try {
        final probeTimeout = timeout > const Duration(milliseconds: 1000)
            ? const Duration(milliseconds: 1000)
            : timeout;
        final socket = await Socket.connect(host, 8729, timeout: probeTimeout);
        isMikrotik = true;
        managementReachable = true;
        resolvedPort = 8729;
        authRequired = true;
        await socket.close();
      } catch (_) {}
    }

    // 3. Third Priority: Probe HTTP port 80 / 443 (WebFig or RouterOS v7 REST API)
    if (!isMikrotik) {
      final client = http.Client();
      try {
        final restUri = Uri.parse('http://$host:80/rest/system/resource');
        final headers = <String, String>{
          'Accept': 'application/json',
        };
        if (hasCreds) {
          final basicAuth = base64Encode(utf8.encode('$username:${password ?? ''}'));
          headers['Authorization'] = 'Basic $basicAuth';
        }

        http.Response? response;
        try {
          response = await client.get(restUri, headers: headers).timeout(timeout);
        } catch (_) {}

        if (response != null) {
          final serverHeader = response.headers['server'] ?? '';
          final wwwAuthHeader = response.headers['www-authenticate'] ?? '';
          final contentType = response.headers['content-type'] ?? '';

          if (serverHeader.toLowerCase().contains('routeros') ||
              serverHeader.toLowerCase().contains('mikrotik') ||
              wwwAuthHeader.toLowerCase().contains('routeros')) {
            isMikrotik = true;
          }

          if (response.statusCode == 200 && contentType.contains('application/json')) {
            // True RouterOS v7 REST API supported on port 80
            isMikrotik = true;
            managementReachable = true;
            resolvedPort = 80;
            try {
              final Map<String, dynamic> body = jsonDecode(utf8.decode(response.bodyBytes));
              version = body['version'] as String?;
              boardName = body['board-name'] as String?;
              cpu = body['cpu'] as String?;
              uptime = body['uptime'] as String?;
              platform = body['platform'] as String?;
            } catch (_) {}
          } else if (response.statusCode == 401 && wwwAuthHeader.toLowerCase().contains('routeros')) {
            isMikrotik = true;
            managementReachable = true;
            authRequired = true;
            resolvedPort = 80;
          }
        }

        // If not confirmed by REST, probe root WebFig page
        if (!isMikrotik) {
          try {
            final rootUri = Uri.parse('http://$host:80/');
            final rootRes = await client.get(rootUri).timeout(timeout);
            final rootServer = rootRes.headers['server'] ?? '';
            final bodyText = rootRes.body.toLowerCase();

            if (rootServer.toLowerCase().contains('routeros') ||
                rootServer.toLowerCase().contains('mikrotik') ||
                bodyText.contains('routeros') ||
                bodyText.contains('mikrotik') ||
                bodyText.contains('webfig')) {
              isMikrotik = true;
              // WebFig is detected, but port 80 is not a reliable REST management port on v6.
              // Direct user to port 8728 (RouterOS API).
              resolvedPort = 8728;
              managementReachable = false;
              errorMessage = 'تم اكتشاف راوتر MikroTik عبر واجهة WebFig على المنفذ 80. للإدارة، يرجى تفعيل خدمة API عبر المنفذ 8728 (/ip service enable api).';
            }
          } catch (_) {}
        }
      } catch (e) {
        errorMessage = 'خطأ أثناء فحص العنوان: $e';
      } finally {
        client.close();
      }
    }

    return DiscoveredRouterModel(
      host: host,
      port: resolvedPort,
      isMikrotik: isMikrotik,
      identity: identity,
      boardName: boardName,
      version: version,
      cpu: cpu,
      uptime: uptime,
      platform: platform,
      managementReachable: managementReachable,
      authRequired: authRequired,
      errorMessage: errorMessage,
    );
  }

  /// Scans candidate gateways on the local network to find a live MikroTik router.
  static Future<DiscoveredRouterModel?> discoverOnLocalNetwork({
    Duration timeout = defaultProbeTimeout,
    String? username,
    String? password,
  }) async {
    final candidateIps = await getCandidateGatewayIps();

    // Check 192.168.88.1 first (default MikroTik), then derived interfaces
    for (final ip in candidateIps) {
      try {
        final result = await probeHost(
          ip,
          timeout: timeout,
          username: username,
          password: password,
        );

        if (result.isMikrotik) {
          return result;
        }
      } catch (_) {}
    }

    return null;
  }

  /// Tests connectivity directly from the mobile device to a MikroTik router on LAN
  /// Supports:
  /// - RouterOS Binary API (port 8728 plain or 8729 SSL, RouterOS v6 & v7)
  /// - RouterOS REST API (port 80 or 443, RouterOS v7.1+)
  static Future<Map<String, dynamic>> testDirectConnection({
    required String host,
    required int port,
    required String username,
    required String password,
    String? connectionMethod,
    Duration timeout = const Duration(seconds: 6),
  }) async {
    if (directConnectionTester != null) {
      return await directConnectionTester!(
        host: host,
        port: port,
        username: username,
        password: password,
        connectionMethod: connectionMethod,
        timeout: timeout,
      );
    }
    final isExplicitBinary = port == 8728 ||
        port == 8729 ||
        connectionMethod == 'ROUTEROS_API_PLAIN' ||
        connectionMethod == 'ROUTEROS_API_SSL';

    // 1. If Binary API (port 8728/8729 or explicit RouterOS API)
    if (isExplicitBinary || (port != 80 && port != 443 && port != 8080)) {
      final useTls = port == 8729 || connectionMethod == 'ROUTEROS_API_SSL';
      final binaryClient = RouterOsBinaryClient(
        host: host,
        port: port,
        timeout: timeout,
        useTls: useTls,
      );

      try {
        await binaryClient.connect();
        await binaryClient.login(username, password);
        final info = await binaryClient.readSystemInfo();

        return {
          'success': true,
          'data': info,
          'message': 'تم الاتصال بالراوتر بنجاح عبر بروتوكول RouterOS API المباشر',
        };
      } on AuthException catch (e) {
        return {
          'success': false,
          'errorCode': 'INVALID_CREDENTIALS',
          'errorMessage': e.message,
        };
      } on SocketException catch (e) {
        return {
          'success': false,
          'errorCode': 'PORT_CLOSED',
          'errorMessage':
              'تعذر الاتصال بمنفذ RouterOS API ($host:$port): ${e.osError?.message ?? e.message}. تأكد من تفعيل خدمة api في الراوتر (/ip service).',
        };
      } on TimeoutException {
        return {
          'success': false,
          'errorCode': 'TIMEOUT',
          'errorMessage': 'انتهت مهلة الاتصال بالراوتر ($host:$port). تأكد من اتصال هاتفك بنفس الشبكة.',
        };
      } catch (e) {
        return {
          'success': false,
          'errorCode': 'CONNECTION_ERROR',
          'errorMessage': 'فشل فحص اتصال الراوتر: $e',
        };
      } finally {
        await binaryClient.close();
      }
    }

    // 2. HTTP / HTTPS REST API (ports 80, 443, 8080)
    final client = http.Client();
    try {
      final scheme = (port == 443 || connectionMethod == 'REST_API_HTTPS') ? 'https' : 'http';
      final uri = Uri.parse('$scheme://$host:$port/rest/system/resource');
      final basicAuth = base64Encode(utf8.encode('$username:$password'));
      final headers = {
        'Accept': 'application/json',
        'Authorization': 'Basic $basicAuth',
      };

      final response = await client.get(uri, headers: headers).timeout(timeout);

      final contentType = response.headers['content-type'] ?? '';
      final isHtml = contentType.contains('text/html') || response.body.trim().startsWith('<');

      if (isHtml) {
        // RouterOS v6 returns 200 OK with WebFig HTML login page for /rest/ paths!
        // Automatically attempt RouterOS Binary API on port 8728:
        try {
          final fallbackBinary = RouterOsBinaryClient(
            host: host,
            port: 8728,
            timeout: const Duration(seconds: 4),
          );
          await fallbackBinary.connect();
          await fallbackBinary.login(username, password);
          final info = await fallbackBinary.readSystemInfo();
          await fallbackBinary.close();

          return {
            'success': true,
            'data': info,
            'message':
                'تم الاتصال بنجاح عبر منفذ RouterOS API (8728). (المنفذ $port يعرض واجهة WebFig، وتم الاتصال بنجاح عبر بروتوكول API المباشر)',
          };
        } on AuthException catch (e) {
          return {
            'success': false,
            'errorCode': 'INVALID_CREDENTIALS',
            'errorMessage': e.message,
          };
        } catch (_) {
          return {
            'success': false,
            'errorCode': 'WEBFIG_HTML_DETECTED',
            'errorMessage':
                'المنفذ $port يعرض صفحة WebFig فقط ولا يدعم REST API في هذا الإصدار من RouterOS. يرجى تفعيل خدمة API على المنفذ 8728 في الراوتر (/ip service enable api) وتعيين المنفذ 8728 في التطبيق.',
          };
        }
      }

      if (response.statusCode == 200) {
        final dynamic raw = jsonDecode(utf8.decode(response.bodyBytes));
        final Map<String, dynamic> resData = raw is Map<String, dynamic> ? raw : {};

        // Fetch identity
        String routerName = 'راوتر MikroTik';
        try {
          final idUri = Uri.parse('$scheme://$host:$port/rest/system/identity');
          final idRes = await client.get(idUri, headers: headers).timeout(timeout);
          if (idRes.statusCode == 200) {
            final Map<String, dynamic> idData = jsonDecode(utf8.decode(idRes.bodyBytes));
            routerName = (idData['name'] as String?)?.trim() ?? routerName;
          }
        } catch (_) {}

        return {
          'success': true,
          'data': {
            'identity': routerName,
            'version': resData['version'] ?? 'RouterOS',
            'boardName': resData['board-name'] ?? 'MikroTik RouterBoard',
            'cpuLoad': int.tryParse(resData['cpu-load']?.toString() ?? '0') ?? 0,
            'uptimeSeconds': 0,
            'isDirectLocal': true,
            'protocol': scheme == 'https' ? 'REST_API_HTTPS' : 'REST_API_PLAIN',
          },
          'message': 'تم الاتصال بالراوتر بنجاح وقراءة بياناته مباشرة عبر REST API',
        };
      } else if (response.statusCode == 401) {
        return {
          'success': false,
          'errorCode': 'INVALID_CREDENTIALS',
          'errorMessage': 'فشل تسجيل الدخول: اسم المستخدم أو كلمة مرور الراوتر غير صحيحة',
        };
      } else if (response.statusCode == 404) {
        // RouterOS v6 does not support REST API. Try probing port 8728 binary socket automatically.
        try {
          final fallbackBinary = RouterOsBinaryClient(
            host: host,
            port: 8728,
            timeout: const Duration(seconds: 4),
          );
          await fallbackBinary.connect();
          await fallbackBinary.login(username, password);
          final info = await fallbackBinary.readSystemInfo();
          await fallbackBinary.close();

          return {
            'success': true,
            'data': info,
            'message':
                'تم الاتصال بنجاح عبر منفذ RouterOS API (8728). (نظام الراوتر v6 لا يدعم REST API ولكن تم الاتصال بالمنفذ الثنائي بنجاح)',
          };
        } catch (_) {
          return {
            'success': false,
            'errorCode': 'REST_API_UNSUPPORTED',
            'errorMessage':
                'الراوتر يعمل بنظام RouterOS v6 الذي لا يدعم REST API (رمز 404). يرجى تغيير المنفذ إلى 8728 واختيار بروتوكول RouterOS API.',
          };
        }
      } else {
        return {
          'success': false,
          'errorCode': 'ROUTER_ERROR',
          'errorMessage': 'استجاب الراوتر برمز حالة غير متوقع: ${response.statusCode}',
        };
      }
    } on SocketException catch (e) {
      return {
        'success': false,
        'errorCode': 'HOST_UNREACHABLE',
        'errorMessage':
            'تعذر الوصول إلى عنوان الراوتر ($host:$port): ${e.osError?.message ?? e.message}. تأكد من الاتصال بالشبكة وتفعيل خدمة الإدارة (www).',
      };
    } on TimeoutException {
      return {
        'success': false,
        'errorCode': 'TIMEOUT',
        'errorMessage': 'انتهت مهلة الاتصال بالراوتر ($host:$port): تأكد من صحة رقم المنفذ والشبكة',
      };
    } catch (e) {
      return {
        'success': false,
        'errorCode': 'CONNECTION_ERROR',
        'errorMessage': 'خطأ في الاتصال بالراوتر: $e',
      };
    } finally {
      client.close();
    }
  }

  // --------------------------------------------------------------------------
  // Direct LAN HotSpot Management via Native RouterOS API
  // --------------------------------------------------------------------------

  @visibleForTesting
  static Future<Map<String, dynamic>> Function({
    required String host,
    required int port,
    required String username,
    required String password,
    String? connectionMethod,
  })? hotspotUsersDirectTester;

  @visibleForTesting
  static Future<Map<String, dynamic>> Function({
    required String host,
    required int port,
    required String username,
    required String password,
    String? connectionMethod,
  })? hotspotSessionsDirectTester;

  @visibleForTesting
  static Future<Map<String, dynamic>> Function({
    required String host,
    required int port,
    required String username,
    required String password,
    required String targetUsername,
    required bool isEnabled,
    String? connectionMethod,
  })? toggleHotspotUserDirectTester;

  @visibleForTesting
  static Future<Map<String, dynamic>> Function({
    required String host,
    required int port,
    required String username,
    required String password,
    required String targetUsername,
    String? connectionMethod,
  })? disconnectHotspotSessionDirectTester;

  /// Fetches live HotSpot users directly from the router on the local LAN.
  static Future<Map<String, dynamic>> getHotspotUsersDirect({
    required String host,
    required int port,
    required String username,
    required String password,
    String? connectionMethod,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    if (hotspotUsersDirectTester != null) {
      return await hotspotUsersDirectTester!(
        host: host,
        port: port,
        username: username,
        password: password,
        connectionMethod: connectionMethod,
      );
    }

    if (directConnectionTester != null) {
      return {
        'success': false,
        'errorCode': 'TEST_MODE_BYPASS',
        'errorMessage': 'Direct socket test bypassed in test mode',
      };
    }

    final useTls = port == 8729 || connectionMethod == 'ROUTEROS_API_SSL';
    final binaryClient = RouterOsBinaryClient(
      host: host,
      port: port,
      timeout: timeout,
      useTls: useTls,
    );

    try {
      await binaryClient.connect();
      await binaryClient.login(username, password);
      final users = await binaryClient.getHotspotUsers();
      return {
        'success': true,
        'data': users,
      };
    } on AuthException catch (e) {
      return {
        'success': false,
        'errorCode': 'INVALID_CREDENTIALS',
        'errorMessage': e.message,
      };
    } on SocketException catch (e) {
      return {
        'success': false,
        'errorCode': 'PORT_CLOSED',
        'errorMessage': 'تعذر الاتصال بالراوتر لجلب المستخدمين: ${e.message}',
      };
    } on TimeoutException {
      return {
        'success': false,
        'errorCode': 'TIMEOUT',
        'errorMessage': 'انتهت مهلة استجابة الراوتر أثناء جلب المستخدمين',
      };
    } catch (e) {
      return {
        'success': false,
        'errorCode': 'HOTSPOT_USERS_ERROR',
        'errorMessage': 'فشل جلب مستخدمي الهوتسبوت: $e',
      };
    } finally {
      await binaryClient.close();
    }
  }

  /// Fetches live active HotSpot sessions directly from the router on the local LAN.
  static Future<Map<String, dynamic>> getHotspotActiveSessionsDirect({
    required String host,
    required int port,
    required String username,
    required String password,
    String? connectionMethod,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    if (hotspotSessionsDirectTester != null) {
      return await hotspotSessionsDirectTester!(
        host: host,
        port: port,
        username: username,
        password: password,
        connectionMethod: connectionMethod,
      );
    }

    if (directConnectionTester != null) {
      return {
        'success': false,
        'errorCode': 'TEST_MODE_BYPASS',
        'errorMessage': 'Direct socket test bypassed in test mode',
      };
    }

    final useTls = port == 8729 || connectionMethod == 'ROUTEROS_API_SSL';
    final binaryClient = RouterOsBinaryClient(
      host: host,
      port: port,
      timeout: timeout,
      useTls: useTls,
    );

    try {
      await binaryClient.connect();
      await binaryClient.login(username, password);
      final sessions = await binaryClient.getHotspotActiveSessions();
      return {
        'success': true,
        'data': sessions,
      };
    } on AuthException catch (e) {
      return {
        'success': false,
        'errorCode': 'INVALID_CREDENTIALS',
        'errorMessage': e.message,
      };
    } on SocketException catch (e) {
      return {
        'success': false,
        'errorCode': 'PORT_CLOSED',
        'errorMessage': 'تعذر الاتصال بالراوتر لجلب الجلسات: ${e.message}',
      };
    } on TimeoutException {
      return {
        'success': false,
        'errorCode': 'TIMEOUT',
        'errorMessage': 'انتهت مهلة استجابة الراوتر أثناء جلب الجلسات النشطة',
      };
    } catch (e) {
      return {
        'success': false,
        'errorCode': 'HOTSPOT_SESSIONS_ERROR',
        'errorMessage': 'فشل جلب الجلسات النشطة: $e',
      };
    } finally {
      await binaryClient.close();
    }
  }

  /// Toggles (enables/disables) a HotSpot user directly on the router on the local LAN.
  static Future<Map<String, dynamic>> toggleHotspotUserDirect({
    required String host,
    required int port,
    required String username,
    required String password,
    required String targetUsername,
    required bool isEnabled,
    String? connectionMethod,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    if (toggleHotspotUserDirectTester != null) {
      return await toggleHotspotUserDirectTester!(
        host: host,
        port: port,
        username: username,
        password: password,
        targetUsername: targetUsername,
        isEnabled: isEnabled,
        connectionMethod: connectionMethod,
      );
    }

    final useTls = port == 8729 || connectionMethod == 'ROUTEROS_API_SSL';
    final binaryClient = RouterOsBinaryClient(
      host: host,
      port: port,
      timeout: timeout,
      useTls: useTls,
    );

    try {
      await binaryClient.connect();
      await binaryClient.login(username, password);
      await binaryClient.toggleHotspotUser(targetUsername, isEnabled);
      return {
        'success': true,
        'data': {'username': targetUsername, 'isEnabled': isEnabled},
      };
    } on AuthException catch (e) {
      return {
        'success': false,
        'errorCode': 'INVALID_CREDENTIALS',
        'errorMessage': e.message,
      };
    } catch (e) {
      return {
        'success': false,
        'errorCode': 'TOGGLE_USER_ERROR',
        'errorMessage': 'فشل تعديل حالة المستخدم على الراوتر: $e',
      };
    } finally {
      await binaryClient.close();
    }
  }

  /// Disconnects an active HotSpot session directly on the router on the local LAN.
  static Future<Map<String, dynamic>> disconnectHotspotSessionDirect({
    required String host,
    required int port,
    required String username,
    required String password,
    required String targetUsername,
    String? connectionMethod,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    if (disconnectHotspotSessionDirectTester != null) {
      return await disconnectHotspotSessionDirectTester!(
        host: host,
        port: port,
        username: username,
        password: password,
        targetUsername: targetUsername,
        connectionMethod: connectionMethod,
      );
    }

    final useTls = port == 8729 || connectionMethod == 'ROUTEROS_API_SSL';
    final binaryClient = RouterOsBinaryClient(
      host: host,
      port: port,
      timeout: timeout,
      useTls: useTls,
    );

    try {
      await binaryClient.connect();
      await binaryClient.login(username, password);
      await binaryClient.disconnectHotspotSession(targetUsername);
      return {
        'success': true,
        'data': {'username': targetUsername, 'disconnected': true},
      };
    } on AuthException catch (e) {
      return {
        'success': false,
        'errorCode': 'INVALID_CREDENTIALS',
        'errorMessage': e.message,
      };
    } catch (e) {
      return {
        'success': false,
        'errorCode': 'DISCONNECT_SESSION_ERROR',
        'errorMessage': 'فشل فصل الجلسة على الراوتر: $e',
      };
    } finally {
      await binaryClient.close();
    }
  }
}
