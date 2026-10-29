// ============================================================================
// Platform: Commercial MikroTik Network & HotSpot Card Management System (Jalsah)
// File: lib/services/local_card_sync_service.dart
// Service: Local On-Device Hotspot Card Provisioning for Private LAN Routers
// ============================================================================

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/card_model.dart';
import '../models/router_model.dart';
import 'mikrotik_discovery_service.dart';
import 'routeros_binary_client.dart';

enum CardSyncStatus {
  synced,
  pending,
  failed,
}

class CardSyncItem {
  final String cardId;
  final String username;
  final CardSyncStatus status;
  final String? errorMessage;
  final DateTime? syncedAt;

  const CardSyncItem({
    required this.cardId,
    required this.username,
    required this.status,
    this.errorMessage,
    this.syncedAt,
  });

  bool get isSynced => status == CardSyncStatus.synced;
  bool get isFailed => status == CardSyncStatus.failed;
  bool get isPending => status == CardSyncStatus.pending;
}

class BatchSyncResult {
  final bool success;
  final int totalCount;
  final int syncedCount;
  final int failedCount;
  final List<CardSyncItem> items;
  final String? errorMessage;

  const BatchSyncResult({
    required this.success,
    required this.totalCount,
    required this.syncedCount,
    required this.failedCount,
    required this.items,
    this.errorMessage,
  });
}

class LocalCardSyncService {
  /// Test hooks for unit testing without physical hardware
  static Future<Map<String, dynamic>> Function(RouterModel router, {String? profile})? probeTester;
  static Future<BatchSyncResult> Function({
    required RouterModel router,
    required List<CardModel> cards,
    String? profile,
    String? comment,
    String? timeLimit,
    void Function(int current, int total, String currentUsername)? onProgress,
  })? syncBatchTester;

  static RouterOsBinaryClient Function({
    required String host,
    required int port,
    required bool useTls,
    required Duration timeout,
  })? clientFactory;

  /// Helper to instantiate client (or mock in tests)
  static RouterOsBinaryClient _createClient({
    required String host,
    required int port,
    required bool useTls,
    Duration timeout = const Duration(seconds: 6),
  }) {
    if (clientFactory != null) {
      return clientFactory!(
        host: host,
        port: port,
        useTls: useTls,
        timeout: timeout,
      );
    }
    return RouterOsBinaryClient(
      host: host,
      port: port,
      useTls: useTls,
      timeout: timeout,
    );
  }

  /// Probes the local router using a temporary user (_jalsah_probe_test)
  /// Verifies creation, print lookup, and immediate deletion before any card batch is generated.
  static Future<Map<String, dynamic>> probeRouter({
    required RouterModel router,
    String? profile,
  }) async {
    if (probeTester != null) {
      return await probeTester!(router, profile: profile);
    }

    final creds = await MikrotikDiscoveryService.getRouterCredentials(router.id);
    if (creds == null ||
        creds['username'] == null ||
        creds['username']!.isEmpty ||
        creds['password'] == null) {
      return {
        'success': false,
        'errorCode': 'NO_LOCAL_CREDENTIALS',
        'errorMessage': 'بيانات اعتماد الراوتر غير متوفرة على هذا الجهاز. يرجى تعديل بيانات الراوتر وحفظ كلمة المرور.',
      };
    }

    final useTls = router.apiPort == 8729 || router.connectionMethod == 'ROUTEROS_API_SSL';
    final client = _createClient(
      host: router.host,
      port: router.apiPort,
      useTls: useTls,
      timeout: const Duration(seconds: 5),
    );

    const probeUsername = '_jalsah_probe_test';

    try {
      await client.connect();
      await client.login(creds['username']!, creds['password']!);

      // Clean up previous probe user if left behind
      try {
        await client.removeHotspotUser(probeUsername);
      } catch (_) {}

      // Attempt to create probe user with empty password (validating type a & b protocol handling)
      await client.createHotspotUser(
        username: probeUsername,
        password: '',
        profile: profile ?? 'default',
        comment: 'Jalsah:PreflightProbe',
      );

      // Verify user was created via /ip/hotspot/user/print
      final existingUsers = await client.getHotspotUsers();
      final exists = existingUsers.any((u) => u['name'] == probeUsername);

      if (!exists) {
        throw Exception('فشل التحقق من إضافة المستخدم التجريبي داخل الراوتر.');
      }

      // Immediately delete the probe user to keep router clean
      await client.removeHotspotUser(probeUsername);

      return {
        'success': true,
        'message': 'تم التحقق من جاهزية الراوتر لإنشاء بطاقات الهوتسبوت بنجاح.',
      };
    } on AuthException catch (e) {
      return {
        'success': false,
        'errorCode': 'INVALID_CREDENTIALS',
        'errorMessage': 'فشلت المصادقة مع الراوتر: ${e.message}',
      };
    } on SocketException catch (e) {
      return {
        'success': false,
        'errorCode': 'CONNECTION_REFUSED',
        'errorMessage': 'تعذر الاتصال بمنفذ الراوتر (${router.host}:${router.apiPort}): ${e.osError?.message ?? e.message}',
      };
    } on TimeoutException {
      return {
        'success': false,
        'errorCode': 'TIMEOUT',
        'errorMessage': 'انتهت مهلة استجابة الراوتر (${router.host}:${router.apiPort}). يرجى التأكد من الاتصال بنفس الشبكة.',
      };
    } catch (e) {
      final errStr = e.toString();
      if (errStr.contains('profile') && errStr.contains('not found')) {
        return {
          'success': false,
          'errorCode': 'PROFILE_NOT_FOUND',
          'errorMessage': 'بروفايل الهوتسبوت المحدد (${profile ?? "default"}) غير موجود في إعدادات الراوتر.',
        };
      }
      return {
        'success': false,
        'errorCode': 'PROBE_FAILED',
        'errorMessage': 'فشل الفحص التجريبي للراوتر: $e',
      };
    } finally {
      await client.close();
    }
  }

  /// Syncs an entire batch of cards directly to the local router on device.
  /// Handles both Card Type (a) [Username + Password] and Card Type (b) [Numbers Only / Empty Password].
  static Future<BatchSyncResult> syncCardsToRouter({
    required RouterModel router,
    required List<CardModel> cards,
    String? profile,
    String? comment,
    String? timeLimit,
    void Function(int current, int total, String currentUsername)? onProgress,
  }) async {
    if (syncBatchTester != null) {
      return await syncBatchTester!(
        router: router,
        cards: cards,
        profile: profile,
        comment: comment,
        timeLimit: timeLimit,
        onProgress: onProgress,
      );
    }

    if (cards.isEmpty) {
      return const BatchSyncResult(
        success: true,
        totalCount: 0,
        syncedCount: 0,
        failedCount: 0,
        items: [],
      );
    }

    final creds = await MikrotikDiscoveryService.getRouterCredentials(router.id);
    if (creds == null ||
        creds['username'] == null ||
        creds['username']!.isEmpty ||
        creds['password'] == null) {
      // Mark all cards as pending with error
      final failedItems = <CardSyncItem>[];
      for (final c in cards) {
        await saveCardSyncStatus(
          cardId: c.id,
          status: CardSyncStatus.pending,
          error: 'بيانات اعتماد الراوتر غير متوفرة على هذا الجهاز',
        );
        failedItems.add(CardSyncItem(
          cardId: c.id,
          username: c.username,
          status: CardSyncStatus.pending,
          errorMessage: 'بيانات اعتماد الراوتر غير متوفرة على هذا الجهاز',
        ));
      }
      return BatchSyncResult(
        success: false,
        totalCount: cards.length,
        syncedCount: 0,
        failedCount: cards.length,
        items: failedItems,
        errorMessage: 'بيانات اعتماد الراوتر غير متوفرة على هذا الجهاز.',
      );
    }

    final useTls = router.apiPort == 8729 || router.connectionMethod == 'ROUTEROS_API_SSL';
    final client = _createClient(
      host: router.host,
      port: router.apiPort,
      useTls: useTls,
      timeout: const Duration(seconds: 8),
    );

    final items = <CardSyncItem>[];
    int syncedCount = 0;
    int failedCount = 0;

    try {
      await client.connect();
      await client.login(creds['username']!, creds['password']!);

      // Fetch existing users on the router to safely prevent duplicate collision errors
      final existingUsers = await client.getHotspotUsers();
      final existingNames = existingUsers
          .map((u) => (u['name'] ?? '').toString().trim())
          .where((name) => name.isNotEmpty)
          .toSet();

      for (int i = 0; i < cards.length; i++) {
        final card = cards[i];
        onProgress?.call(i + 1, cards.length, card.username);

        // If user already exists on router, count as synced
        if (existingNames.contains(card.username)) {
          await saveCardSyncStatus(
            cardId: card.id,
            status: CardSyncStatus.synced,
          );
          items.add(CardSyncItem(
            cardId: card.id,
            username: card.username,
            status: CardSyncStatus.synced,
            syncedAt: DateTime.now(),
          ));
          syncedCount++;
          continue;
        }

        try {
          // Card Type (a): password has value.
          // Card Type (b): password is empty string.
          await client.createHotspotUser(
            username: card.username,
            password: card.password, // Empty string for NUMBERS_ONLY
            profile: profile ?? 'default',
            comment: comment ?? (card.batchId != null ? 'Jalsah:${card.batchId}' : 'Jalsah:Card'),
            timeLimit: timeLimit,
          );

          await saveCardSyncStatus(
            cardId: card.id,
            status: CardSyncStatus.synced,
          );
          items.add(CardSyncItem(
            cardId: card.id,
            username: card.username,
            status: CardSyncStatus.synced,
            syncedAt: DateTime.now(),
          ));
          syncedCount++;
        } catch (e) {
          final errStr = e.toString();
          String userFriendlyError = 'فشل الرفع: $e';
          if (errStr.contains('profile') && errStr.contains('not found')) {
            userFriendlyError = 'بروفايل الهوتسبوت (${profile ?? "default"}) غير موجود في الراوتر';
          } else if (errStr.contains('already exists')) {
            // Treat as synced if it was created concurrently
            await saveCardSyncStatus(
              cardId: card.id,
              status: CardSyncStatus.synced,
            );
            items.add(CardSyncItem(
              cardId: card.id,
              username: card.username,
              status: CardSyncStatus.synced,
              syncedAt: DateTime.now(),
            ));
            syncedCount++;
            continue;
          }

          await saveCardSyncStatus(
            cardId: card.id,
            status: CardSyncStatus.failed,
            error: userFriendlyError,
          );
          items.add(CardSyncItem(
            cardId: card.id,
            username: card.username,
            status: CardSyncStatus.failed,
            errorMessage: userFriendlyError,
            syncedAt: DateTime.now(),
          ));
          failedCount++;
        }
      }
    } catch (e) {
      // If full connection failed mid-process, mark remaining cards as pending
      for (int i = items.length; i < cards.length; i++) {
        final card = cards[i];
        final err = 'انقطع الاتصال بالراوتر أثناء الرفع: $e';
        await saveCardSyncStatus(
          cardId: card.id,
          status: CardSyncStatus.pending,
          error: err,
        );
        items.add(CardSyncItem(
          cardId: card.id,
          username: card.username,
          status: CardSyncStatus.pending,
          errorMessage: err,
        ));
        failedCount++;
      }
    } finally {
      await client.close();
    }

    return BatchSyncResult(
      success: failedCount == 0,
      totalCount: cards.length,
      syncedCount: syncedCount,
      failedCount: failedCount,
      items: items,
      errorMessage: failedCount > 0 ? 'اكتملت العملية مع تعذر مزامنة $failedCount كرت' : null,
    );
  }

  /// Resyncs pending or failed cards by first querying actual router users (/ip/hotspot/user/print)
  /// and comparing by name, never relying blindly on local state.
  static Future<BatchSyncResult> resyncPendingCards({
    required RouterModel router,
    required List<CardModel> cards,
    String? profile,
    String? comment,
    String? timeLimit,
    void Function(int current, int total, String currentUsername)? onProgress,
  }) async {
    final creds = await MikrotikDiscoveryService.getRouterCredentials(router.id);
    if (creds == null ||
        creds['username'] == null ||
        creds['username']!.isEmpty ||
        creds['password'] == null) {
      return BatchSyncResult(
        success: false,
        totalCount: cards.length,
        syncedCount: 0,
        failedCount: cards.length,
        items: cards
            .map((c) => CardSyncItem(
                  cardId: c.id,
                  username: c.username,
                  status: CardSyncStatus.pending,
                  errorMessage: 'بيانات اعتماد الراوتر غير متوفرة على هذا الجهاز',
                ))
            .toList(),
        errorMessage: 'بيانات اعتماد الراوتر غير متوفرة على هذا الجهاز.',
      );
    }

    final useTls = router.apiPort == 8729 || router.connectionMethod == 'ROUTEROS_API_SSL';
    final client = _createClient(
      host: router.host,
      port: router.apiPort,
      useTls: useTls,
      timeout: const Duration(seconds: 8),
    );

    final items = <CardSyncItem>[];
    int syncedCount = 0;
    int failedCount = 0;

    try {
      await client.connect();
      await client.login(creds['username']!, creds['password']!);

      // Requirement 2: Read users actually present on router via /ip/hotspot/user/print
      final existingUsers = await client.getHotspotUsers();
      final existingNames = existingUsers
          .map((u) => (u['name'] ?? '').toString().trim())
          .where((name) => name.isNotEmpty)
          .toSet();

      for (int i = 0; i < cards.length; i++) {
        final card = cards[i];
        onProgress?.call(i + 1, cards.length, card.username);

        // Comparison by username/name only (Requirement: supports both Type a & b)
        if (existingNames.contains(card.username)) {
          await saveCardSyncStatus(
            cardId: card.id,
            status: CardSyncStatus.synced,
          );
          items.add(CardSyncItem(
            cardId: card.id,
            username: card.username,
            status: CardSyncStatus.synced,
            syncedAt: DateTime.now(),
          ));
          syncedCount++;
          continue;
        }

        // If missing on router, upload now
        try {
          await client.createHotspotUser(
            username: card.username,
            password: card.password,
            profile: profile ?? 'default',
            comment: comment ?? (card.batchId != null ? 'Jalsah:${card.batchId}' : 'Jalsah:Card'),
            timeLimit: timeLimit,
          );
          await saveCardSyncStatus(
            cardId: card.id,
            status: CardSyncStatus.synced,
          );
          items.add(CardSyncItem(
            cardId: card.id,
            username: card.username,
            status: CardSyncStatus.synced,
            syncedAt: DateTime.now(),
          ));
          syncedCount++;
        } catch (e) {
          final errStr = e.toString();
          String userFriendlyError = 'فشل الرفع: $e';
          if (errStr.contains('profile') && errStr.contains('not found')) {
            userFriendlyError = 'بروفايل الهوتسبوت (${profile ?? "default"}) غير موجود في الراوتر';
          }
          await saveCardSyncStatus(
            cardId: card.id,
            status: CardSyncStatus.failed,
            error: userFriendlyError,
          );
          items.add(CardSyncItem(
            cardId: card.id,
            username: card.username,
            status: CardSyncStatus.failed,
            errorMessage: userFriendlyError,
            syncedAt: DateTime.now(),
          ));
          failedCount++;
        }
      }
    } catch (e) {
      for (int i = items.length; i < cards.length; i++) {
        final card = cards[i];
        final err = 'تعذر الاتصال بالراوتر لإعادة المزامنة: $e';
        await saveCardSyncStatus(
          cardId: card.id,
          status: CardSyncStatus.pending,
          error: err,
        );
        items.add(CardSyncItem(
          cardId: card.id,
          username: card.username,
          status: CardSyncStatus.pending,
          errorMessage: err,
        ));
        failedCount++;
      }
    } finally {
      await client.close();
    }

    return BatchSyncResult(
      success: failedCount == 0,
      totalCount: cards.length,
      syncedCount: syncedCount,
      failedCount: failedCount,
      items: items,
      errorMessage: failedCount > 0 ? 'تبقى $failedCount كرت لم تتم مزامنتها' : null,
    );
  }

  // --------------------------------------------------------------------------
  // Local Persistence (Requirement 1: NEVER store username or password!)
  // --------------------------------------------------------------------------

  /// In-memory mock storage for unit tests
  static final Map<String, String> _testPrefs = {};

  /// Saves sync status for a card without storing username or password
  static Future<void> saveCardSyncStatus({
    required String cardId,
    required CardSyncStatus status,
    String? error,
  }) async {
    if (cardId.trim().isEmpty) return;
    final statusStr = status == CardSyncStatus.synced
        ? 'SYNCED'
        : (status == CardSyncStatus.failed ? 'FAILED' : 'PENDING');
    final timeStr = DateTime.now().toIso8601String();

    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      _testPrefs['c_sync_st_$cardId'] = statusStr;
      _testPrefs['c_sync_ts_$cardId'] = timeStr;
      if (error != null) {
        _testPrefs['c_sync_er_$cardId'] = error;
      } else {
        _testPrefs.remove('c_sync_er_$cardId');
      }
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('c_sync_st_$cardId', statusStr);
      await prefs.setString('c_sync_ts_$cardId', timeStr);
      if (error != null) {
        await prefs.setString('c_sync_er_$cardId', error);
      } else {
        await prefs.remove('c_sync_er_$cardId');
      }
    } catch (e) {
      debugPrint('[LocalCardSyncService] SharedPreferences write error: $e');
    }
  }

  /// Retrieves local sync status for a card ID
  static Future<CardSyncItem?> getCardSyncStatus(String cardId, String username) async {
    if (cardId.trim().isEmpty) return null;

    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      final st = _testPrefs['c_sync_st_$cardId'];
      if (st == null) return null;
      final tsStr = _testPrefs['c_sync_ts_$cardId'];
      final er = _testPrefs['c_sync_er_$cardId'];
      return CardSyncItem(
        cardId: cardId,
        username: username,
        status: st == 'SYNCED'
            ? CardSyncStatus.synced
            : (st == 'FAILED' ? CardSyncStatus.failed : CardSyncStatus.pending),
        syncedAt: tsStr != null ? DateTime.tryParse(tsStr) : null,
        errorMessage: er,
      );
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final st = prefs.getString('c_sync_st_$cardId');
      if (st == null) return null;
      final tsStr = prefs.getString('c_sync_ts_$cardId');
      final er = prefs.getString('c_sync_er_$cardId');
      return CardSyncItem(
        cardId: cardId,
        username: username,
        status: st == 'SYNCED'
            ? CardSyncStatus.synced
            : (st == 'FAILED' ? CardSyncStatus.failed : CardSyncStatus.pending),
        syncedAt: tsStr != null ? DateTime.tryParse(tsStr) : null,
        errorMessage: er,
      );
    } catch (e) {
      debugPrint('[LocalCardSyncService] SharedPreferences read error: $e');
      return null;
    }
  }

  /// Clears in-memory test preferences
  @visibleForTesting
  static void resetTestStorage() {
    _testPrefs.clear();
    probeTester = null;
    syncBatchTester = null;
    clientFactory = null;
  }
}
