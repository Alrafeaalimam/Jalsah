// ============================================================================
// Platform: Commercial MikroTik Network & HotSpot Card Management System (Jalsah)
// File: test/probe_verify_test.dart
// Description: Real TCP Socket Mock RouterOS Server tests verifying:
//   1. add returns !done with =ret=*10A and filter read returns !empty (succeeds and deletes by ID).
//   2. add succeeds and probe user deletion fails (probe still succeeds).
//   3. add returns !trap (fails with clear message containing sentence diagnostics).
// ============================================================================

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mikrotik_cards_app/services/api_client.dart';
import 'package:mikrotik_cards_app/models/router_model.dart';
import 'package:mikrotik_cards_app/services/local_card_sync_service.dart';
import 'package:mikrotik_cards_app/services/mikrotik_discovery_service.dart';
import 'package:mikrotik_cards_app/services/routeros_binary_client.dart';

/// Lightweight Mock RouterOS Server running on loopback TCP port.
class MockRouterOsServer {
  final ServerSocket server;
  final List<Socket> clients = [];
  final List<List<String>> receivedSentences = [];
  void Function(Socket client, List<String> sentence)? onSentence;

  MockRouterOsServer._(this.server);

  int get port => server.port;

  static Future<MockRouterOsServer> start() async {
    final s = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final mock = MockRouterOsServer._(s);

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
    for (final w in words) {
      final bytes = utf8.encode(w);
      bb.add(RouterOsBinaryClient.encodeLength(bytes.length));
      bb.add(bytes);
    }
    bb.addByte(0x00);
    return bb.toBytes();
  }

  static void sendSentenceTo(Socket client, List<String> words) {
    client.add(encodeSentence(words));
  }

  static void sendSentencesBurstTo(Socket client, List<List<String>> sentenceList) {
    final bb = BytesBuilder();
    for (final s in sentenceList) {
      bb.add(encodeSentence(s));
    }
    client.add(bb.toBytes());
  }

  Future<void> stop() async {
    onSentence = null;
    for (final c in List<Socket>.from(clients)) {
      try {
        await c.close();
      } catch (_) {}
    }
    clients.clear();
    await server.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockRouterOsServer server;

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
    server = await MockRouterOsServer.start();
    LocalCardSyncService.clientFactory = null; // Use real RouterOsBinaryClient
  });

  tearDown(() async {
    LocalCardSyncService.resetTestStorage();
    MikrotikDiscoveryService.resetTestStorage();
    ApiClient.resetClient();
    await server.stop();
  });

  group('Verification & Cleanup on RouterOS 7.25 (fix/probe-verify)', () {
    test(
        '1. add returns !done with ret and filter read returns !empty (probe succeeds and deletes by ID)',
        () async {
      final router = RouterModel(
        id: 'router-test-725',
        name: 'RouterOS 7.25',
        host: '127.0.0.1',
        apiPort: server.port,
        status: 'ONLINE',
        connectionMethod: 'ROUTEROS_API_PLAIN',
      );

      await MikrotikDiscoveryService.saveRouterCredentials(
        routerId: router.id,
        username: 'admin',
        password: 'password123',
      );

      final List<List<String>> receivedCmds = [];

      server.onSentence = (client, sentence) {
        receivedCmds.add(sentence);
        final cmd = sentence[0];

        if (cmd == '/login') {
          MockRouterOsServer.sendSentenceTo(client, ['!done']);
        } else if (cmd == '/ip/hotspot/user/print') {
          // Both leftover check and verification step return !empty then !done (RouterOS 7.18+)
          MockRouterOsServer.sendSentencesBurstTo(client, [
            ['!empty'],
            ['!done'],
          ]);
        } else if (cmd == '/ip/hotspot/user/add') {
          // RouterOS creates user and returns internal ID =ret=*10A
          MockRouterOsServer.sendSentenceTo(client, ['!done', '=ret=*10A']);
        } else if (cmd == '/ip/hotspot/user/remove') {
          MockRouterOsServer.sendSentenceTo(client, ['!done']);
        } else {
          MockRouterOsServer.sendSentenceTo(client, ['!done']);
        }
      };

      final result = await LocalCardSyncService.probeRouter(router: router);

      expect(result['success'], isTrue);
      expect(result['message'], contains('تم التحقق'));

      // Verify that remove was called with =.numbers=*10A
      final removeCmd = receivedCmds.firstWhere(
        (cmd) => cmd[0] == '/ip/hotspot/user/remove',
        orElse: () => [],
      );
      expect(removeCmd, isNotEmpty);
      expect(removeCmd, contains('=.numbers=*10A'));
    });

    test('2. add succeeds and deletion fails (probe still succeeds)', () async {
      final router = RouterModel(
        id: 'router-del-fail',
        name: 'Del Fail Router',
        host: '127.0.0.1',
        apiPort: server.port,
        status: 'ONLINE',
        connectionMethod: 'ROUTEROS_API_PLAIN',
      );

      await MikrotikDiscoveryService.saveRouterCredentials(
        routerId: router.id,
        username: 'admin',
        password: 'password123',
      );

      server.onSentence = (client, sentence) {
        final cmd = sentence[0];
        if (cmd == '/login') {
          MockRouterOsServer.sendSentenceTo(client, ['!done']);
        } else if (cmd == '/ip/hotspot/user/print') {
          MockRouterOsServer.sendSentencesBurstTo(client, [
            ['!empty'],
            ['!done'],
          ]);
        } else if (cmd == '/ip/hotspot/user/add') {
          MockRouterOsServer.sendSentenceTo(client, ['!done', '=ret=*20B']);
        } else if (cmd == '/ip/hotspot/user/remove') {
          // Remove returns a trap error, e.g. cannot remove
          MockRouterOsServer.sendSentencesBurstTo(client, [
            ['!trap', '=category=1', '=message=cannot remove user'],
            ['!done'],
          ]);
        } else {
          MockRouterOsServer.sendSentenceTo(client, ['!done']);
        }
      };

      final result = await LocalCardSyncService.probeRouter(router: router);

      // Probe MUST still succeed even if probe user deletion failed
      expect(result['success'], isTrue);
      expect(result['message'], contains('تم التحقق'));
    });

    test(
        '3. add returns trap (probe fails at الإنشاء with safe diagnostic sentence details)',
        () async {
      final router = RouterModel(
        id: 'router-add-trap',
        name: 'Add Trap Router',
        host: '127.0.0.1',
        apiPort: server.port,
        status: 'ONLINE',
        connectionMethod: 'ROUTEROS_API_PLAIN',
      );

      await MikrotikDiscoveryService.saveRouterCredentials(
        routerId: router.id,
        username: 'admin',
        password: 'superSecretPassword',
      );

      server.onSentence = (client, sentence) {
        final cmd = sentence[0];
        if (cmd == '/login') {
          MockRouterOsServer.sendSentenceTo(client, ['!done']);
        } else if (cmd == '/ip/hotspot/user/print') {
          MockRouterOsServer.sendSentencesBurstTo(client, [
            ['!empty'],
            ['!done'],
          ]);
        } else if (cmd == '/ip/hotspot/user/add') {
          // Router returns permission denied trap
          MockRouterOsServer.sendSentencesBurstTo(client, [
            ['!trap', '=category=2', '=message=action not permitted, not enough permissions (9)'],
            ['!done'],
          ]);
        } else {
          MockRouterOsServer.sendSentenceTo(client, ['!done']);
        }
      };

      final result = await LocalCardSyncService.probeRouter(router: router);

      expect(result['success'], isFalse);
      expect(result['step'], equals('الإنشاء'));
      final errorMsg = result['errorMessage'] as String;

      // Diagnostic message checks
      expect(errorMsg, contains('خطوة (الإنشاء)'));
      expect(errorMsg, contains('صلاحية'));
      expect(errorMsg, contains('عدد الجمل: 2'));
      expect(errorMsg, contains('!trap: 1'));
      expect(errorMsg, contains('!done: 1'));
      expect(errorMsg, contains('أول trap:'));

      // Safety checks: no credentials or sensitive probe name leaked
      expect(errorMsg.contains('superSecretPassword'), isFalse);
      expect(errorMsg.contains('_jalsah_probe_test'), isFalse);
    });

    test(
        '4. RouterOsBinaryClient captures lastDoneRet, lastCreatedUserId and sentence diagnostics',
        () async {
      final client = RouterOsBinaryClient(
        host: '127.0.0.1',
        port: server.port,
        useTls: false,
        timeout: const Duration(seconds: 3),
      );

      server.onSentence = (c, sentence) {
        final cmd = sentence[0];
        if (cmd == '/login') {
          MockRouterOsServer.sendSentenceTo(c, ['!done']);
        } else if (cmd == '/test/ret') {
          MockRouterOsServer.sendSentenceTo(c, ['!done', '=ret=*999']);
        } else if (cmd == '/test/empty') {
          MockRouterOsServer.sendSentencesBurstTo(c, [
            ['!empty'],
            ['!done'],
          ]);
        }
      };

      await client.connect();
      await client.login('admin', '1234');

      final records = await client.executeCommand(['/test/ret']);
      expect(records, isEmpty);
      expect(client.lastDoneRet, equals('*999'));
      expect(client.lastCreatedUserId, equals('*999'));
      expect(client.commandSentencesReceived, equals(1));
      expect(client.commandSentenceTypes['!done'], equals(1));

      await client.executeCommand(['/test/empty']);
      expect(client.commandSentencesReceived, equals(2));
      expect(client.commandSentenceTypes['!empty'], equals(1));
      expect(client.commandSentenceTypes['!done'], equals(1));

      final diag = client.getSentenceDiagnostics();
      expect(diag, contains('عدد الجمل: 2'));
      expect(diag, contains('!empty: 1'));
      expect(diag, contains('!done: 1'));

      await client.close();
    });

    test('5. Empty or invalid ID executes NO command on router and returns false', () async {
      final client = RouterOsBinaryClient(
        host: '127.0.0.1',
        port: server.port,
        useTls: false,
        timeout: const Duration(seconds: 3),
      );

      final List<List<String>> executedCommands = [];
      server.onSentence = (c, sentence) {
        executedCommands.add(sentence);
        if (sentence[0] == '/login') {
          MockRouterOsServer.sendSentenceTo(c, ['!done']);
        }
      };

      await client.connect();
      await client.login('admin', '1234');
      executedCommands.clear();

      // Test empty, whitespace, and invalid ID patterns
      expect(await client.removeHotspotUserById(''), isFalse);
      expect(await client.removeHotspotUserById('   '), isFalse);
      expect(await client.removeHotspotUserById('user1'), isFalse);
      expect(await client.removeHotspotUserById('null'), isFalse);
      expect(await client.removeHotspotUserById('*'), isFalse);
      expect(await client.removeHotspotUserById('*xyz'), isFalse);

      // Verify no remove command was ever sent to the server
      final removeCommands = executedCommands
          .where((cmd) => cmd.isNotEmpty && cmd[0] == '/ip/hotspot/user/remove')
          .toList();
      expect(removeCommands, isEmpty);

      await client.close();
    });

    test('6. "no such item" on primary format returns false and NEVER attempts fallback format', () async {
      final client = RouterOsBinaryClient(
        host: '127.0.0.1',
        port: server.port,
        useTls: false,
        timeout: const Duration(seconds: 3),
      );

      final List<List<String>> removeCommands = [];
      server.onSentence = (c, sentence) {
        if (sentence[0] == '/login') {
          MockRouterOsServer.sendSentenceTo(c, ['!done']);
        } else if (sentence[0] == '/ip/hotspot/user/remove') {
          removeCommands.add(sentence);
          MockRouterOsServer.sendSentencesBurstTo(c, [
            ['!trap', '=message=failure: no such item'],
            ['!done'],
          ]);
        }
      };

      await client.connect();
      await client.login('admin', '1234');

      final removed = await client.removeHotspotUserById('*10A');
      expect(removed, isFalse);

      // Only ONE command using =.numbers=*10A was sent, NO fallback format was attempted
      expect(removeCommands.length, equals(1));
      expect(removeCommands[0], contains('=.numbers=*10A'));

      await client.close();
    });

    test('7. "unknown parameter" on primary format triggers fallback format =.id=ID', () async {
      final client = RouterOsBinaryClient(
        host: '127.0.0.1',
        port: server.port,
        useTls: false,
        timeout: const Duration(seconds: 3),
      );

      final List<List<String>> removeCommands = [];
      server.onSentence = (c, sentence) {
        if (sentence[0] == '/login') {
          MockRouterOsServer.sendSentenceTo(c, ['!done']);
        } else if (sentence[0] == '/ip/hotspot/user/remove') {
          removeCommands.add(sentence);
          if (sentence.contains('=.numbers=*10A')) {
            // First attempt with =.numbers fails with unknown parameter
            MockRouterOsServer.sendSentencesBurstTo(c, [
              ['!trap', '=message=unknown parameter .numbers'],
              ['!done'],
            ]);
          } else if (sentence.contains('=.id=*10A')) {
            // Fallback attempt succeeds
            MockRouterOsServer.sendSentenceTo(c, ['!done']);
          }
        }
      };

      await client.connect();
      await client.login('admin', '1234');

      final removed = await client.removeHotspotUserById('*10A');
      expect(removed, isTrue);

      // Exactly two commands: primary format then fallback format
      expect(removeCommands.length, equals(2));
      expect(removeCommands[0], contains('=.numbers=*10A'));
      expect(removeCommands[1], contains('=.id=*10A'));

      await client.close();
    });

    test('8. probeRouter executes remove ONLY with the exact ID returned by add', () async {
      final router = RouterModel(
        id: 'router-exact-id-test',
        name: 'Exact ID Router',
        host: '127.0.0.1',
        apiPort: server.port,
        status: 'ONLINE',
        connectionMethod: 'ROUTEROS_API_PLAIN',
      );

      await MikrotikDiscoveryService.saveRouterCredentials(
        routerId: router.id,
        username: 'admin',
        password: 'password123',
      );

      final List<List<String>> removeCommands = [];

      server.onSentence = (client, sentence) {
        final cmd = sentence[0];
        if (cmd == '/login') {
          MockRouterOsServer.sendSentenceTo(client, ['!done']);
        } else if (cmd == '/ip/hotspot/user/print') {
          MockRouterOsServer.sendSentencesBurstTo(client, [
            ['!empty'],
            ['!done'],
          ]);
        } else if (cmd == '/ip/hotspot/user/add') {
          // Returns exact unique ID =ret=*99B
          MockRouterOsServer.sendSentenceTo(client, ['!done', '=ret=*99B']);
        } else if (cmd == '/ip/hotspot/user/remove') {
          removeCommands.add(sentence);
          MockRouterOsServer.sendSentenceTo(client, ['!done']);
        }
      };

      final result = await LocalCardSyncService.probeRouter(router: router);

      expect(result['success'], isTrue);
      expect(removeCommands, isNotEmpty);
      expect(removeCommands[0], contains('=.numbers=*99B'));
    });
  });
}
