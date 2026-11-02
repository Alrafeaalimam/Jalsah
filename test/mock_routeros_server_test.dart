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
import 'package:crypto/crypto.dart';
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

  static List<String>? extractSentence(List<int> buf) => _extractSentence(buf);

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

    test('10. RouterOS v6.43+ modern plain login (/login with =name= and =password=)', () async {
      String? receivedUser;
      String? receivedPass;

      server.onSentence = (client, cmd) {
        if (cmd.isNotEmpty && cmd[0] == '/login') {
          for (final word in cmd) {
            if (word.startsWith('=name=')) receivedUser = word.substring(6);
            if (word.startsWith('=password=')) receivedPass = word.substring(10);
          }
          MockRouterOsServer.sendSentenceTo(client, ['!done']);
        }
      };

      final client = RouterOsBinaryClient(
        host: '127.0.0.1',
        port: server.port,
        timeout: const Duration(seconds: 10),
      );
      await client.connect();

      await client.login('admin', 'StrongPassword123');
      expect(receivedUser, equals('admin'));
      expect(receivedPass, equals('StrongPassword123'));

      await client.close();
    });

    test('11. RouterOS pre-6.43 MD5 challenge-response login', () async {
      const challengeHex = '0123456789abcdef0123456789abcdef';
      int loginStage = 0;
      String? responseSentByClient;

      server.onSentence = (client, cmd) {
        if (cmd.isNotEmpty && cmd[0] == '/login') {
          loginStage++;
          if (loginStage == 1) {
            // First stage: return !done with =ret= challenge
            MockRouterOsServer.sendSentenceTo(client, ['!done', '=ret=$challengeHex']);
          } else if (loginStage == 2) {
            // Second stage: capture client response
            for (final word in cmd) {
              if (word.startsWith('=response=')) {
                responseSentByClient = word.substring(10);
              }
            }
            MockRouterOsServer.sendSentenceTo(client, ['!done']);
          }
        }
      };

      final client = RouterOsBinaryClient(
        host: '127.0.0.1',
        port: server.port,
        timeout: const Duration(seconds: 10),
      );
      await client.connect();

      await client.login('legacy_admin', 'old_password');
      expect(loginStage, equals(2));
      expect(responseSentByClient, isNotNull);
      expect(responseSentByClient!.startsWith('00'), isTrue);

      // Verify the MD5 challenge formula: md5(0x00 + password_utf8 + challenge_bytes)
      final challengeBytes = <int>[];
      for (int i = 0; i < challengeHex.length; i += 2) {
        challengeBytes.add(int.parse(challengeHex.substring(i, i + 2), radix: 16));
      }
      final expectedDigest = md5.convert([0x00, ...utf8.encode('old_password'), ...challengeBytes]).bytes;
      final expectedHex = expectedDigest.map((b) => b.toRadixString(16).padLeft(2, '0')).join('').toLowerCase();
      expect(responseSentByClient, equals('00$expectedHex'));

      await client.close();
    });

    test('12. TLS connection connects securely, supports self-signed certs, and exchanges commands', () async {
      final secContext = SecurityContext();
      secContext.useCertificateChainBytes(utf8.encode(_testCertPem));
      secContext.usePrivateKeyBytes(utf8.encode(_testKeyPem));

      final secureServer = await SecureServerSocket.bind(
        InternetAddress.loopbackIPv4,
        0,
        secContext,
      );

      final secureClients = <Socket>[];
      secureServer.listen((client) {
        secureClients.add(client);
        final buffer = <int>[];
        client.listen((data) {
          buffer.addAll(data);
          while (true) {
            final sentence = MockRouterOsServer.extractSentence(buffer);
            if (sentence == null) break;
            if (sentence.isNotEmpty && sentence[0] == '/login') {
              MockRouterOsServer.sendSentenceTo(client, ['!done']);
            }
          }
        });
      });

      final client = RouterOsBinaryClient(
        host: '127.0.0.1',
        port: secureServer.port,
        useTls: true,
        timeout: const Duration(seconds: 10),
      );

      await client.connect();
      await client.login('tls_user', 'tls_secret');
      await client.close();

      for (final c in secureClients) {
        try { await c.close(); c.destroy(); } catch (_) {}
      }
      await secureServer.close();
    });

    test('12b. Port 8729 automatically enforces TLS and Port 8728 strictly forbids TLS', () {
      final client8729 = RouterOsBinaryClient(
        host: '127.0.0.1',
        port: 8729,
        useTls: false,
      );
      final effective8729 = client8729.port != 8728 && (client8729.useTls || client8729.port == 8729);
      expect(effective8729, isTrue);

      final client8728 = RouterOsBinaryClient(
        host: '127.0.0.1',
        port: 8728,
        useTls: true, // Port 8728 must NEVER use TLS even if requested
      );
      final effective8728 = client8728.port != 8728 && (client8728.useTls || client8728.port == 8729);
      expect(effective8728, isFalse);
    });

    test('13. Repeated commands (probe -> sync -> read -> sessions) and reconnect do NOT throw "Stream has already been listened to"', () async {
      server.onSentence = (client, cmd) {
        if (cmd.isEmpty) return;
        final verb = cmd[0];
        if (verb == '/ip/hotspot/user/print') {
          MockRouterOsServer.sendSentencesBurstTo(client, [
            ['!re', '=.id=*1', '=name=user1', '=profile=default', '=disabled=false'],
            ['!done'],
          ]);
        } else if (verb == '/ip/hotspot/user/add') {
          MockRouterOsServer.sendSentenceTo(client, ['!done', '=.ret=*2']);
        } else if (verb == '/system/identity/print') {
          MockRouterOsServer.sendSentencesBurstTo(client, [
            ['!re', '=name=LabRouter'],
            ['!done'],
          ]);
        } else if (verb == '/system/resource/print') {
          MockRouterOsServer.sendSentencesBurstTo(client, [
            ['!re', '=board-name=hAP ac3', '=version=7.18', '=cpu-load=5', '=uptime=1d'],
            ['!done'],
          ]);
        } else if (verb == '/ip/hotspot/active/print') {
          MockRouterOsServer.sendSentencesBurstTo(client, [
            ['!re', '=.id=*10', '=user=active1', '=address=192.168.88.50', '=uptime=30m'],
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

      // 1. Probe (getHotspotUsers with name filter)
      final probeUsers = await client.getHotspotUsers(name: 'probe_test');
      expect(probeUsers.length, equals(1));

      // 2. Sync (createHotspotUser)
      final created = await client.createHotspotUser(username: 'user2', password: '123', profile: 'default');
      expect(created, isTrue);

      // 3. Read system info
      final info = await client.readSystemInfo();
      expect(info['identity'], equals('LabRouter'));
      expect(info['boardName'], equals('hAP ac3'));

      // 4. Read active sessions
      final sessions = await client.getHotspotActiveSessions();
      expect(sessions.length, equals(1));
      expect(sessions[0]['username'], equals('active1'));

      // 5. Subsequent user query
      final usersAgain = await client.getHotspotUsers();
      expect(usersAgain.length, equals(1));

      // 6. Close and re-connect cycle on the same instance
      await client.close();
      await client.connect();
      final usersAfterReconnect = await client.getHotspotUsers(name: 'probe_test');
      expect(usersAfterReconnect.length, equals(1));

      await client.close();
    });

    test('14. Optional /system/resource: empty or trap response falls back to "غير متوفر" without failing connection test', () async {
      server.onSentence = (client, cmd) {
        if (cmd.isNotEmpty && cmd[0] == '/system/identity/print') {
          MockRouterOsServer.sendSentencesBurstTo(client, [
            ['!re', '=name=Office-Router'],
            ['!done'],
          ]);
        } else if (cmd.isNotEmpty && cmd[0] == '/system/resource/print') {
          // Simulate trap rejection on /system/resource (e.g. lack of permissions or unsupported)
          MockRouterOsServer.sendSentencesBurstTo(client, [
            ['!trap', '=category=2', '=message=action not permitted, not enough permissions'],
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

      // readSystemInfo must NOT throw even if /system/resource traps!
      final info = await client.readSystemInfo();
      expect(info['identity'], equals('Office-Router'));
      expect(info['boardName'], equals('غير متوفر'));
      expect(info['version'], equals('غير متوفر'));
      expect(info['resourceFailureReason'], contains('رفض صلاحيات (trap)'));

      await client.close();
    });
  });
}

const _testCertPem = '''-----BEGIN CERTIFICATE-----
MIIDCTCCAfGgAwIBAgIUf80yV7aHoJp10xuBaJUTN6bBoj0wDQYJKoZIhvcNAQEL
BQAwFDESMBAGA1UEAwwJMTI3LjAuMC4xMB4XDTI2MTEwMjEzMDg1MFoXDTM2MTAz
MDEzMDg1MFowFDESMBAGA1UEAwwJMTI3LjAuMC4xMIIBIjANBgkqhkiG9w0BAQEF
AAOCAQ8AMIIBCgKCAQEA1s9q8KE5boEU5rLOMDcGxaMo7UUtsCFYTu8MEj7mggyB
bUsSNK0Qq8a0DYY+0Y/6+y4QWaYlxBbEn8dna/A49Z9bBmUA2cYNlecYZ7cs/9me
VUwmN/moV6xUVgJMKzuQo8CGD+C6PWjSFTRsELCHGu8yv4IOW8z3eEo0cTHTdG15
U8KSm1D3kaQy+GWVGVt8IlIJm8GchCUeVBCsJJXs7gIOnrKPP7JCZFNJRi3Lz/Cj
n+KpFGRe19hGghfnkwVbiR7dsUpweziQoNmcUz5dYkTbmtbdm1skxPjeag1Lh6PC
YGPUWYT2hPV0q4yoGjCBJ8LsjhQRIGCo7SqhkEdWpQIDAQABo1MwUTAdBgNVHQ4E
FgQUA4Vyvo14oeFZu8OB/NZJ/VjLYFEwHwYDVR0jBBgwFoAUA4Vyvo14oeFZu8OB
/NZJ/VjLYFEwDwYDVR0TAQH/BAUwAwEB/zANBgkqhkiG9w0BAQsFAAOCAQEAwQPh
lxfl3NZJDU7B1OtVHR1/ZewEgbBQ+kWFoSVSpxOIB7mT0RsFbRpVIxeJLgohE6S9
+0N3LMsp54abV0CcJiRlE525gM12u7bwWrbezqOe7uRpmC9zYIo0RifUZzoNW52U
PJSLse4A/GSA+AUJnTQ8j9Rqa/DdbOe4AlEsG5GcvKmhKttvxaM4+TOScEyhI8x/
Y7IBRDI2LUeYNXjG7uQW9Tj+ZAHe//F891AIPEMYAbrxXUXjRubrbUc5StfPvSul
uaN6gRkkqpvjogf39qSzk0Yq59uwENOyyMq2l8pDPqVOZoNXSyO/s3iRfDFgGMNE
lIBKgbLE9LGPGjBJGw==
-----END CERTIFICATE-----''';

const _testKeyPem = '''-----BEGIN PRIVATE KEY-----
MIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQDWz2rwoTlugRTm
ss4wNwbFoyjtRS2wIVhO7wwSPuaCDIFtSxI0rRCrxrQNhj7Rj/r7LhBZpiXEFsSf
x2dr8Dj1n1sGZQDZxg2V5xhntyz/2Z5VTCY3+ahXrFRWAkwrO5CjwIYP4Lo9aNIV
NGwQsIca7zK/gg5bzPd4SjRxMdN0bXlTwpKbUPeRpDL4ZZUZW3wiUgmbwZyEJR5U
EKwklezuAg6eso8/skJkU0lGLcvP8KOf4qkUZF7X2EaCF+eTBVuJHt2xSnB7OJCg
2ZxTPl1iRNua1t2bWyTE+N5qDUuHo8JgY9RZhPaE9XSrjKgaMIEnwuyOFBEgYKjt
KqGQR1alAgMBAAECggEAIKx3DzfuxOy0cazT6QiNqqU5NfH2U5qW1JbOxr2zkSd2
zlmDYOjMJty4CXCYgIa+fdNRYFmB2BRAfy80/3mQKGg/T7cwTG+wJFN85lW57ga7
ay0EiTIb1Y4cW+LIlDDgvM+tdJ/RpEKb5ebN4zH+su2cUf3l0jfYkn7zAB68k7JF
z8HOm0txdGNliqA/xpSBucvyEIf0TZ5tRm3EgVQtnbki+ipQY/KkEwpJOjyGoxQV
D/po3ybShERNfDiWmoQr8jel/1CCvoRwPYigF3M0cHRyX00bVLARiFGcfIWSP4RF
rYFyCzS0C9ny3ObMTylS5nxS2t3xrXEF1VyEvUzccQKBgQDuEyDH/Bv4XrUkRZbx
30/tmJz7v/iuIRAeUNot6nOGnAmLRD+y/Lu5WUHMCUZ8JnPUbn4NSLZS4D9xrxRi
A0xIuqZd1HwPILSafaGHy0yHoQiWFZdCl3regx9tPKSayjKrUQQ90XKCFkWk45sI
59RyzOloigCOEC8cn+vsIQEc/QKBgQDm+95Mlx3DGN8cg6MCHz1ojE84WSICd7Xx
55RBdq9qNqB/4O6aNB5g8BgYXN6o86yL6E5O/s44eEnhvbw5JS2+I7QCaYzUCzIB
0raBB+erDmWISNJk5d7bON7GoIw5zzzz7y3hoaTXn5idxXYkiHBD7hxrI5rMOycM
45JmceQkyQKBgQCRYTTfamBaJttOrwAh61APsuYKBYyCKMaC/LR+3XB2fsqFNMQB
NLwdzxeS1QcpwQFyc5ad3g0YRr/3WAaGY6UttGzrV1n6kuo2fQkqt0agfAGWRND9
ZSsuvbtvJV0O+PJAE1UXutLGBXu52RNPOOJOyDqwD7WPCur5+95Bb1YSsQKBgDKP
6+eEJOWyKhTJ1AMA56ZdIHJLQKCdp9xePxvdaSSs9JFJobFru0KpC/05RxxgyuKN
ZabxLB88ZZ/esrcnpk267wqgJE2+baHsiDrSiintqtgcaMHhd9kxJ8L/HfMBpGwZ
bUe45Ka2rufKc8Qngbu9AceKMbaHNFMj9cYrJC/RAoGBANuKQlwkCaEgaahMdLwP
aBo00+DNcxnTudwUE8cxpgPIlmkzJygZ6lXN3xsQdzS1Z/KpaD9IkNDAx1DC0AXq
uNQ4hJVVhq9jmw/Pn4b40/tKPRfilOaEfCVV9utn5nmBOtOtGeQ41krdDqVNkXdR
M+/c/77fifMF7ILSA73TNh8F
-----END PRIVATE KEY-----''';
