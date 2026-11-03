// ============================================================================
// Platform: Commercial MikroTik Network & HotSpot Card Management System (Jalsah)
// File: test/auto_profile_test.dart
// Description: Comprehensive Unit & Mock Server tests for automatic HotSpot profile
//   isolation (jalsah-*):
//   1. Pure deterministic name generation: jalsah-d{download}-u{upload}-s{shared}
//   2. Speed validation (upload speed required)
//   3. Empty responses (!empty then !done, RouterOS 7.18+)
//   4. rate-limit ordering: upload/download
//   5. Strict prohibition of set / remove on user profiles
//   6. Verification check and verification failure handling
//   7. Permission denial translation (write policy requirement)
//   8. Arabic translation for known RouterOS errors
//   9. Close case-insensitive profile name suggestions (e.g. 1D)
// ============================================================================

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mikrotik_cards_app/models/package_model.dart';
import 'package:mikrotik_cards_app/models/router_model.dart';
import 'package:mikrotik_cards_app/services/api_client.dart';
import 'package:mikrotik_cards_app/services/local_card_sync_service.dart';
import 'package:mikrotik_cards_app/services/mikrotik_discovery_service.dart';
import 'package:mikrotik_cards_app/services/routeros_binary_client.dart';

/// Lightweight Mock RouterOS TCP Server for Profile Lifecycle Testing
class AutoProfileMockServer {
  final ServerSocket server;
  final List<Socket> clients = [];
  final List<List<String>> receivedSentences = [];
  void Function(Socket client, List<String> sentence)? onSentence;

  AutoProfileMockServer._(this.server);

  int get port => server.port;

  static Future<AutoProfileMockServer> start() async {
    final s = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final mock = AutoProfileMockServer._(s);

    s.listen((client) {
      mock.clients.add(client);
      final buffer = <int>[];

      client.listen(
        (data) {
          buffer.addAll(data);
          while (true) {
            final sentence = _extractSentence(buffer);
            if (sentence == null) break;
            mock.receivedSentences.add(sentence);
            mock.onSentence?.call(client, sentence);
          }
        },
        onError: (_) {},
        onDone: () {
          mock.clients.remove(client);
        },
      );
    });

    return mock;
  }

  static List<String>? _extractSentence(List<int> buf) {
    int offset = 0;
    final List<String> words = [];

    while (offset < buf.length) {
      final b = buf[offset];
      if (b == 0x00) {
        offset++;
        buf.removeRange(0, offset);
        return words;
      }

      int len = 0;
      int lenBytes = 0;
      if ((b & 0x80) == 0) {
        len = b;
        lenBytes = 1;
      } else if ((b & 0xC0) == 0x80) {
        if (buf.length < offset + 2) return null;
        len = ((b & 0x3F) << 8) | buf[offset + 1];
        lenBytes = 2;
      } else {
        if (buf.length < offset + 2) return null;
        len = b;
        lenBytes = 1;
      }

      if (buf.length < offset + lenBytes + len) return null;
      words.add(utf8.decode(buf.sublist(offset + lenBytes, offset + lenBytes + len)));
      offset += lenBytes + len;
    }

    return null;
  }

  static List<int> encodeSentence(List<String> words) {
    final bb = BytesBuilder();
    for (final word in words) {
      final bytes = utf8.encode(word);
      final len = bytes.length;
      if (len < 0x80) {
        bb.addByte(len);
      } else if (len < 0x4000) {
        bb.addByte((len >> 8) | 0x80);
        bb.addByte(len & 0xFF);
      } else {
        throw ArgumentError('Word too long for test mock');
      }
      bb.add(bytes);
    }
    bb.addByte(0x00);
    return bb.toBytes();
  }

  void reply(Socket client, List<String> sentence) {
    client.add(encodeSentence(sentence));
  }

  Future<void> stop() async {
    for (final c in List<Socket>.from(clients)) {
      try {
        c.destroy();
      } catch (_) {}
    }
    await server.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Requirement 1 & 2: Pure Deterministic Profile Name & Speed Validation', () {
    test('Profile name format follows jalsah-d{download}-u{upload}-s{shared}', () {
      final name = PackageModel.generateProfileName(
        downloadSpeed: '2M',
        uploadSpeed: '512k',
        simultaneousSessions: 1,
      );
      expect(name, equals('jalsah-d2m-u512k-s1'));
    });

    test('Profile name cleans uppercase, spaces, and non-alphanumeric chars', () {
      final pkg = PackageModel(
        id: 'pkg-999',
        name: 'VIP 2Mbps Package',
        code: 'VIP_CODE_123',
        price: 50.0,
        downloadSpeedLimit: ' 4M ',
        uploadSpeedLimit: ' 1M ',
        durationMinutes: 1440,
        validityDays: 1,
        hotspotProfileName: 'default',
        simultaneousSessions: 2,
        isActive: true,
      );

      // Name is purely a function of speeds and sessions; ignores package id or code
      expect(pkg.automaticProfileName, equals('jalsah-d4m-u1m-s2'));
    });

    test('Changing package speeds generates a different profile naturally without set', () {
      final name1 = PackageModel.generateProfileName(
        downloadSpeed: '2M',
        uploadSpeed: '512k',
        simultaneousSessions: 1,
      );
      final name2 = PackageModel.generateProfileName(
        downloadSpeed: '4M',
        uploadSpeed: '512k',
        simultaneousSessions: 1,
      );
      expect(name1, isNot(equals(name2)));
      expect(name2, equals('jalsah-d4m-u512k-s1'));
    });

    test('Incomplete package without upload speed returns descriptive error', () {
      final incompletePkg = PackageModel(
        id: 'pkg-incomplete',
        name: 'Incomplete Package',
        code: 'INC',
        price: 10.0,
        downloadSpeedLimit: '2M',
        uploadSpeedLimit: '',
        durationMinutes: 60,
        validityDays: 1,
        hotspotProfileName: 'default',
        simultaneousSessions: 1,
        isActive: true,
      );

      final err = incompletePkg.validateAutoProfileSpeeds();
      expect(err, isNotNull);
      expect(err, contains('سرعة الرفع (Upload) غير محددة'));
    });

    test('Package without download speed returns descriptive error', () {
      final incompletePkg = PackageModel(
        id: 'pkg-incomplete-dl',
        name: 'Incomplete DL',
        code: 'INC_DL',
        price: 10.0,
        downloadSpeedLimit: '',
        uploadSpeedLimit: '512k',
        durationMinutes: 60,
        validityDays: 1,
        hotspotProfileName: 'default',
        simultaneousSessions: 1,
        isActive: true,
      );

      final err = incompletePkg.validateAutoProfileSpeeds();
      expect(err, isNotNull);
      expect(err, contains('سرعة التحميل (Download) غير محددة'));
    });

    test('Fully specified speeds return null validation error', () {
      final validPkg = PackageModel(
        id: 'pkg-valid',
        name: 'Valid',
        code: 'VAL',
        price: 20.0,
        downloadSpeedLimit: '3M',
        uploadSpeedLimit: '1M',
        durationMinutes: 120,
        validityDays: 1,
        hotspotProfileName: 'default',
        simultaneousSessions: 1,
        isActive: true,
      );
      expect(validPkg.validateAutoProfileSpeeds(), isNull);
    });
  });

  group('Requirement 6: Translation of RouterOS Trap & Error Messages', () {
    test('Translates input does not match any value of profile', () {
      final translated = RouterOsBinaryClient.translateKnownRouterOsError(
        'failure: input does not match any value of profile',
      );
      expect(translated, contains('بروفايل الهوتسبوت المحدد غير موجود'));
    });

    test('Translates no such item', () {
      final translated = RouterOsBinaryClient.translateKnownRouterOsError(
        'failure: no such item',
      );
      expect(translated, contains('العنصر المطلوب غير موجود'));
    });

    test('Translates not enough permissions to write policy guidance', () {
      final translated = RouterOsBinaryClient.translateKnownRouterOsError(
        'failure: not enough permissions',
      );
      expect(translated, contains('صلاحية الكتابة الكافية'));
      expect(translated, contains('write policy'));
    });

    test('Translates already have error', () {
      final translated = RouterOsBinaryClient.translateKnownRouterOsError(
        'failure: already have such user profile',
      );
      expect(translated, contains('العنصر موجود مسبقاً'));
    });
  });

  group('Mock Server Profile Lifecycle Tests', () {
    late AutoProfileMockServer mockServer;
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

      final jwt = createMockJwt(tenantId: 'tenant-test-1', userId: 'user-test-1');
      ApiClient.setAuthToken(jwt);

      mockServer = await AutoProfileMockServer.start();

      testRouter = RouterModel(
        id: 'router-local-1',
        name: 'Local Lab Router',
        host: '127.0.0.1',
        apiPort: mockServer.port,
        connectionMethod: 'ROUTEROS_API',
        status: 'ONLINE',
      );

      await MikrotikDiscoveryService.saveRouterCredentials(
        routerId: testRouter.id,
        username: 'admin',
        password: 'password123',
      );
    });

    tearDown(() async {
      await mockServer.stop();
      ApiClient.resetClient();
    });

    test('checkProfileExists: handles RouterOS 7.18+ !empty then !done gracefully', () async {
      mockServer.onSentence = (client, words) {
        if (words.isEmpty) return;
        final cmd = words[0];
        if (cmd == '/login') {
          mockServer.reply(client, ['!done']);
        } else if (cmd == '/ip/hotspot/user/profile/print') {
          // Simulate RouterOS 7.18+ returning !empty then !done
          mockServer.reply(client, ['!empty']);
          mockServer.reply(client, ['!done']);
        }
      };

      final result = await LocalCardSyncService.checkProfileExists(
        router: testRouter,
        profileName: 'jalsah-d2m-u512k-s1',
      );

      expect(result['success'], isTrue);
      expect(result['exists'], isFalse);
    });

    test('checkProfileExists: returns true when profile is returned', () async {
      mockServer.onSentence = (client, words) {
        if (words.isEmpty) return;
        final cmd = words[0];
        if (cmd == '/login') {
          mockServer.reply(client, ['!done']);
        } else if (cmd == '/ip/hotspot/user/profile/print') {
          mockServer.reply(client, [
            '!re',
            '=.id=*A1',
            '=name=jalsah-d2m-u512k-s1',
            '=rate-limit=512k/2M',
            '=shared-users=1',
          ]);
          mockServer.reply(client, ['!done']);
        }
      };

      final result = await LocalCardSyncService.checkProfileExists(
        router: testRouter,
        profileName: 'jalsah-d2m-u512k-s1',
      );

      expect(result['success'], isTrue);
      expect(result['exists'], isTrue);
      expect(result['profile']?['name'], equals('jalsah-d2m-u512k-s1'));
    });

    test('createAndVerifyProfile: adds profile with upload/download rate-limit order and verifies', () async {
      final createdProfiles = <String, Map<String, String>>{};

      mockServer.onSentence = (client, words) {
        if (words.isEmpty) return;
        final cmd = words[0];
        if (cmd == '/login') {
          mockServer.reply(client, ['!done']);
        } else if (cmd == '/ip/hotspot/user/profile/add') {
          final props = <String, String>{};
          for (final w in words.skip(1)) {
            if (w.startsWith('=')) {
              final eq = w.indexOf('=', 1);
              if (eq != -1) {
                props[w.substring(1, eq)] = w.substring(eq + 1);
              }
            }
          }
          final name = props['name']!;
          createdProfiles[name] = props;
          mockServer.reply(client, ['!done', '=.ret=*B1']);
        } else if (cmd == '/ip/hotspot/user/profile/print') {
          // Verification lookup
          String? requestedName;
          for (final w in words.skip(1)) {
            if (w.startsWith('?name=')) {
              requestedName = w.substring('?name='.length);
            }
          }
          if (requestedName != null && createdProfiles.containsKey(requestedName)) {
            final p = createdProfiles[requestedName]!;
            mockServer.reply(client, [
              '!re',
              '=.id=*B1',
              '=name=$requestedName',
              '=rate-limit=${p['rate-limit']}',
              '=shared-users=${p['shared-users']}',
            ]);
          }
          mockServer.reply(client, ['!done']);
        }
      };

      final package = PackageModel(
        id: 'pkg-1',
        name: '2 Mbps Daily',
        code: '2M_1D',
        price: 5.0,
        downloadSpeedLimit: '2M',
        uploadSpeedLimit: '512k',
        durationMinutes: 1440,
        validityDays: 1,
        hotspotProfileName: 'default',
        simultaneousSessions: 1,
        isActive: true,
      );

      final result = await LocalCardSyncService.createAndVerifyProfile(
        router: testRouter,
        package: package,
      );

      expect(result['success'], isTrue);
      expect(result['profileName'], equals('jalsah-d2m-u512k-s1'));

      // Verify that rate-limit was sent as upload/download (rx/tx = 512k/2M)
      expect(createdProfiles['jalsah-d2m-u512k-s1']?['rate-limit'], equals('512k/2M'));
      expect(createdProfiles['jalsah-d2m-u512k-s1']?['shared-users'], equals('1'));

      // STRICT ISOLATION: Verify NO `set` or `remove` commands were ever sent to profile
      for (final sentence in mockServer.receivedSentences) {
        if (sentence.isNotEmpty) {
          expect(sentence[0], isNot(startsWith('/ip/hotspot/user/profile/set')));
          expect(sentence[0], isNot(startsWith('/ip/hotspot/user/profile/remove')));
        }
      }
    });

    test('createAndVerifyProfile: fails if print verification fails after add', () async {
      mockServer.onSentence = (client, words) {
        if (words.isEmpty) return;
        final cmd = words[0];
        if (cmd == '/login') {
          mockServer.reply(client, ['!done']);
        } else if (cmd == '/ip/hotspot/user/profile/add') {
          mockServer.reply(client, ['!done', '=.ret=*B1']);
        } else if (cmd == '/ip/hotspot/user/profile/print') {
          // Intentionally simulate verification failure by returning no profiles
          mockServer.reply(client, ['!done']);
        }
      };

      final package = PackageModel(
        id: 'pkg-2',
        name: '3 Mbps Plan',
        code: '3M',
        price: 15.0,
        downloadSpeedLimit: '3M',
        uploadSpeedLimit: '1M',
        durationMinutes: 60,
        validityDays: 1,
        hotspotProfileName: 'default',
        simultaneousSessions: 1,
        isActive: true,
      );

      final result = await LocalCardSyncService.createAndVerifyProfile(
        router: testRouter,
        package: package,
      );

      expect(result['success'], isFalse);
      expect(result['errorCode'], equals('VERIFICATION_FAILED'));
      expect(result['errorMessage'], contains('فشل التحقق'));
    });

    test('createAndVerifyProfile: translates not enough permissions trap', () async {
      mockServer.onSentence = (client, words) {
        if (words.isEmpty) return;
        final cmd = words[0];
        if (cmd == '/login') {
          mockServer.reply(client, ['!done']);
        } else if (cmd == '/ip/hotspot/user/profile/add') {
          mockServer.reply(client, [
            '!trap',
            '=category=2',
            '=message=not enough permissions',
          ]);
          mockServer.reply(client, ['!done']);
        }
      };

      final package = PackageModel(
        id: 'pkg-3',
        name: '1 Mbps Plan',
        code: '1M',
        price: 5.0,
        downloadSpeedLimit: '1M',
        uploadSpeedLimit: '256k',
        durationMinutes: 60,
        validityDays: 1,
        hotspotProfileName: 'default',
        simultaneousSessions: 1,
        isActive: true,
      );

      final result = await LocalCardSyncService.createAndVerifyProfile(
        router: testRouter,
        package: package,
      );

      expect(result['success'], isFalse);
      expect(result['errorCode'], equals('PERMISSION_DENIED'));
      expect(result['errorMessage'], contains('صلاحية الكتابة الكافية'));
      expect(result['errorMessage'], contains('write policy'));
    });

    test('probeRouter: suggests close case-insensitive match when manual profile has case mismatch', () async {
      mockServer.onSentence = (client, words) {
        if (words.isEmpty) return;
        final cmd = words[0];
        if (cmd == '/login') {
          mockServer.reply(client, ['!done']);
        } else if (cmd == '/ip/hotspot/user/print') {
          // Clean search for probe user
          mockServer.reply(client, ['!done']);
        } else if (cmd == '/ip/hotspot/user/add') {
          // Reject creation because profile '1d' does not exist exactly
          mockServer.reply(client, [
            '!trap',
            '=category=2',
            '=message=failure: input does not match any value of profile',
          ]);
          mockServer.reply(client, ['!done']);
        } else if (cmd == '/ip/hotspot/user/profile/print') {
          // Return existing profile '1D'
          mockServer.reply(client, [
            '!re',
            '=.id=*C1',
            '=name=1D',
          ]);
          mockServer.reply(client, ['!done']);
        } else if (cmd == '/ip/hotspot/user/remove') {
          mockServer.reply(client, ['!done']);
        }
      };

      final result = await LocalCardSyncService.probeRouter(
        router: testRouter,
        profile: '1d', // User typed '1d' lowercase
      );

      expect(result['success'], isFalse);
      expect(result['errorCode'], equals('PROFILE_NOT_FOUND'));
      expect(result['errorMessage'], contains('هل تقصد (1D)؟'));
    });
  });
}
