// ============================================================================
// Platform: Commercial MikroTik Network & HotSpot Card Management System (Jalsah)
// File: test/mock_routeros_server_test.dart
// Description: Real TCP Socket Mock RouterOS Server tests for fix/probe-read-hang:
//   1. Simulates !empty then !done (RouterOS 7.18+ empty result)
//   2. Simulates standard !re and !done in single/multiple packets
//   3. Simulates !trap responses (permission denied and generic errors)
//   4. Simulates large responses split across small chunks with delays
//   5. Simulates delayed responses without hanging
//   6. Proves failure messages report "لا رد", "رد غير مفهوم", "رفض صلاحيات (trap)"
//   7. Proves /system/resource/print reading succeeds and does NOT hang
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
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

  /// Encodes a sentence (words terminated by empty word 0x00) into RouterOS binary bytes.
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

  /// Sends a sentence to a specific client.
  static void sendSentenceTo(Socket client, List<String> words) {
    client.add(encodeSentence(words));
  }

  /// Sends multiple sentences together in a single TCP payload to a specific client.
  static void sendSentencesBurstTo(Socket client, List<List<String>> sentenceList) {
    final bb = BytesBuilder();
    for (final s in sentenceList) {
      bb.add(encodeSentence(s));
    }
    client.add(bb.toBytes());
  }

  /// Sends raw bytes broken into small chunks with optional delay between chunks to a client.
  static Future<void> sendBytesChunkedTo(Socket client, List<int> bytes, int chunkSize, Duration chunkDelay) async {
    for (int i = 0; i < bytes.length; i += chunkSize) {
      final end = (i + chunkSize < bytes.length) ? i + chunkSize : bytes.length;
      final chunk = bytes.sublist(i, end);
      client.add(chunk);
      if (chunkDelay > Duration.zero) {
        await Future.delayed(chunkDelay);
      }
    }
  }

  Future<void> stop() async {
    onSentence = null;
    for (final c in List<Socket>.from(clients)) {
      try {
        await c.close();
        c.destroy();
      } catch (_) {}
    }
    clients.clear();
    await server.close();
  }
}

void main() {
  late MockRouterOsServer server;

  setUp(() async {
    server = await MockRouterOsServer.start();
  });

  tearDown(() async {
    await server.stop();
  });

  group('Mock RouterOS Server Tests (fix/probe-read-hang)', () {
    test('1. RouterOS 7.18+ !empty followed by !done does NOT hang and returns empty list', () async {
      server.onSentence = (client, cmd) {
        if (cmd.isNotEmpty && cmd[0] == '/ip/hotspot/user/print') {
          MockRouterOsServer.sendSentencesBurstTo(client, [
            ['!empty'],
            ['!done'],
          ]);
        }
      };

      final client = RouterOsBinaryClient(
        host: '127.0.0.1',
        port: server.port,
        timeout: const Duration(seconds: 10),
      );
      await client.connect();

      final users = await client.getHotspotUsers(name: '_jalsah_probe_test');
      expect(users, isEmpty);

      await client.close();
    });

    test('2. Standard !re and !done sent in a single TCP packet do NOT hang or drop !done', () async {
      server.onSentence = (client, cmd) {
        if (cmd.isNotEmpty && cmd[0] == '/ip/hotspot/user/print') {
          MockRouterOsServer.sendSentencesBurstTo(client, [
            [
              '!re',
              '=.id=*1',
              '=name=client_voucher_10',
              '=profile=gold_plan',
              '=uptime=1h20m',
              '=bytes-in=102400',
              '=bytes-out=204800',
              '=disabled=false',
            ],
            ['!done'],
          ]);
        }
      };

      final client = RouterOsBinaryClient(
        host: '127.0.0.1',
        port: server.port,
        timeout: const Duration(seconds: 10),
      );
      await client.connect();

      final users = await client.getHotspotUsers(name: 'client_voucher_10');
      expect(users.length, equals(1));
      expect(users[0]['username'], equals('client_voucher_10'));
      expect(users[0]['profile'], equals('gold_plan'));
      expect(users[0]['isEnabled'], isTrue);

      await client.close();
    });

    test('3. Trap with permission denied throws RouterOsTrapException mentioning "رفض صلاحيات (trap)" and sentence count', () async {
      server.onSentence = (client, cmd) {
        if (cmd.isNotEmpty && cmd[0] == '/ip/hotspot/user/add') {
          MockRouterOsServer.sendSentencesBurstTo(client, [
            ['!trap', '=category=2', '=message=not enough permissions'],
            ['!done'],
          ]);
        }
      };

      final client = RouterOsBinaryClient(
        host: '127.0.0.1',
        port: server.port,
        timeout: const Duration(seconds: 10),
      );
      await client.connect();

      await expectLater(
        client.createHotspotUser(username: 'test_user', password: '123', profile: 'default'),
        throwsA(isA<RouterOsTrapException>().having(
          (e) => e.message,
          'message',
          allOf([
            contains('رفض صلاحيات (trap)'),
            contains('not enough permissions'),
            contains('عدد الجمل المستلمة: 2'),
          ]),
        )),
      );

      await client.close();
    });

    test('4. Generic trap throws RouterOsTrapException mentioning "خطأ راوتر (trap)"', () async {
      server.onSentence = (client, cmd) {
        if (cmd.isNotEmpty && cmd[0] == '/ip/hotspot/user/remove') {
          MockRouterOsServer.sendSentencesBurstTo(client, [
            ['!trap', '=message=no such item'],
            ['!done'],
          ]);
        }
      };

      final client = RouterOsBinaryClient(
        host: '127.0.0.1',
        port: server.port,
        timeout: const Duration(seconds: 10),
      );
      await client.connect();

      await expectLater(
        client.executeCommand(['/ip/hotspot/user/remove', '=.id=*999']),
        throwsA(isA<RouterOsTrapException>().having(
          (e) => e.message,
          'message',
          allOf([
            contains('خطأ راوتر (trap)'),
            contains('no such item'),
            contains('عدد الجمل المستلمة: 2'),
          ]),
        )),
      );

      await client.close();
    });

    test('5. Large response split across tiny chunks with delays is read completely without hanging', () async {
      server.onSentence = (client, cmd) async {
        if (cmd.isNotEmpty && cmd[0] == '/ip/hotspot/user/print') {
          final List<List<String>> bigList = [];
          for (int i = 1; i <= 30; i++) {
            bigList.add([
              '!re',
              '=.id=*$i',
              '=name=bulk_user_$i',
              '=profile=default',
              '=uptime=10m',
              '=bytes-in=1000',
              '=bytes-out=2000',
              '=disabled=false',
            ]);
          }
          bigList.add(['!done']);

          final bb = BytesBuilder();
          for (final s in bigList) {
            bb.add(MockRouterOsServer.encodeSentence(s));
          }

          // Send in tiny 21-byte chunks with 2ms delays
          await MockRouterOsServer.sendBytesChunkedTo(client, bb.toBytes(), 21, const Duration(milliseconds: 2));
        }
      };

      final client = RouterOsBinaryClient(
        host: '127.0.0.1',
        port: server.port,
        timeout: const Duration(seconds: 10),
      );
      await client.connect();

      final users = await client.getHotspotUsers();
      expect(users.length, equals(30));
      expect(users[0]['username'], equals('bulk_user_1'));
      expect(users[29]['username'], equals('bulk_user_30'));

      await client.close();
    });

    test('6. Delayed response within timeout succeeds without hanging', () async {
      server.onSentence = (client, cmd) async {
        if (cmd.isNotEmpty && cmd[0] == '/ip/hotspot/user/print') {
          // Delay response by 250ms
          await Future.delayed(const Duration(milliseconds: 250));
          MockRouterOsServer.sendSentencesBurstTo(client, [
            ['!re', '=.id=*99', '=name=delayed_user', '=profile=default', '=uptime=0s', '=disabled=false'],
            ['!done'],
          ]);
        }
      };

      final client = RouterOsBinaryClient(
        host: '127.0.0.1',
        port: server.port,
        timeout: const Duration(seconds: 10),
      );
      await client.connect();

      final users = await client.getHotspotUsers(name: 'delayed_user');
      expect(users.length, equals(1));
      expect(users[0]['username'], equals('delayed_user'));

      await client.close();
    });

    test('7. Timeout failure reports "لا رد" and wait duration in seconds without passwords', () async {
      // Server does NOT respond at all
      server.onSentence = (client, cmd) {};

      final client = RouterOsBinaryClient(
        host: '127.0.0.1',
        port: server.port,
        timeout: const Duration(milliseconds: 300), // short timeout for test
      );
      await client.connect();

      await expectLater(
        client.getHotspotUsers(),
        throwsA(isA<TimeoutException>().having(
          (e) => e.message,
          'message',
          allOf([
            contains('لا رد (لم يتم استلام أي جملة)'),
            contains('بعد انتظار 0 ثوانٍ'), // 300ms rounded inSeconds
          ]),
        )),
      );

      await client.close();
    });

    test('8. Malformed / unrecognized response reports "رد غير مفهوم" immediately without hanging', () async {
      server.onSentence = (client, cmd) {
        if (cmd.isNotEmpty && cmd[0] == '/ip/hotspot/user/print') {
          MockRouterOsServer.sendSentenceTo(client, ['!corrupted_sentence_from_router']);
        }
      };

      final client = RouterOsBinaryClient(
        host: '127.0.0.1',
        port: server.port,
        timeout: const Duration(seconds: 10),
      );
      await client.connect();

      await expectLater(
        client.getHotspotUsers(),
        throwsA(isA<FormatException>().having(
          (e) => e.message,
          'message',
          allOf([
            contains('رد غير مفهوم من الراوتر'),
            contains('!corrupted_sentence_from_router'),
          ]),
        )),
      );

      await client.close();
    });

    test('9. /system/resource/print reads model, version, CPU, and uptime properly in single burst', () async {
      server.onSentence = (client, cmd) {
        if (cmd.isNotEmpty && cmd[0] == '/system/identity/print') {
          MockRouterOsServer.sendSentencesBurstTo(client, [
            ['!re', '=name=Main-Lab-Router'],
            ['!done'],
          ]);
        } else if (cmd.isNotEmpty && cmd[0] == '/system/resource/print') {
          MockRouterOsServer.sendSentencesBurstTo(client, [
            [
              '!re',
              '=board-name=RB750Gr3',
              '=version=7.18',
              '=cpu-load=12',
              '=uptime=4d18h22m',
            ],
            ['!done'],
          ]);
        }
      };

      final client = RouterOsBinaryClient(
        host: '127.0.0.1',
        port: server.port,
        timeout: const Duration(seconds: 10),
      );
      await client.connect();

      final info = await client.readSystemInfo();
      expect(info['identity'], equals('Main-Lab-Router'));
      expect(info['boardName'], equals('RB750Gr3'));
      expect(info['version'], equals('7.18'));
      expect(info['cpuLoad'], equals(12));
      expect(info['uptimeSeconds'], greaterThan(0));

      await client.close();
    });
  });
}
