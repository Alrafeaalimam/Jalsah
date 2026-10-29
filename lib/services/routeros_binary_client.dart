// ============================================================================
// Platform: Commercial MikroTik Network & HotSpot Card Management System (Jalsah)
// File: lib/services/routeros_binary_client.dart
// Service: Native Dart MikroTik RouterOS Binary API Client (Ports 8728 / 8729)
// Supports: RouterOS v6.43+, RouterOS v7, and pre-6.43 MD5 challenge login
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

class RouterOsBinaryClient {
  final String host;
  final int port;
  final Duration timeout;
  final bool useTls;

  Socket? _socket;
  final StreamController<List<int>> _byteStream = StreamController<List<int>>.broadcast();
  StreamSubscription<List<int>>? _socketSubscription;

  RouterOsBinaryClient({
    required this.host,
    this.port = 8728,
    this.timeout = const Duration(seconds: 6),
    this.useTls = false,
  });

  /// Connects to the MikroTik router via standard socket or secure TLS socket.
  Future<void> connect() async {
    if (useTls || port == 8729) {
      final securityContext = SecurityContext(withTrustedRoots: true);
      _socket = await SecureSocket.connect(
        host,
        port,
        context: securityContext,
        onBadCertificate: (cert) => true, // Local router self-signed TLS support
        timeout: timeout,
      );
    } else {
      _socket = await Socket.connect(host, port, timeout: timeout);
    }

    _socketSubscription = _socket!.listen(
      (data) => _byteStream.add(data),
      onError: (err) => _byteStream.addError(err),
      onDone: () => _byteStream.close(),
      cancelOnError: true,
    );
  }

  /// Closes the socket cleanly.
  Future<void> close() async {
    try {
      await _socketSubscription?.cancel();
      await _socket?.flush();
      await _socket?.close();
      _socket?.destroy();
    } catch (_) {}
  }

  /// Encodes length according to MikroTik RouterOS binary protocol specification.
  static List<int> encodeLength(int length) {
    if (length < 0x80) {
      return [length];
    } else if (length < 0x4000) {
      return [(length >> 8) | 0x80, length & 0xFF];
    } else if (length < 0x200000) {
      return [(length >> 16) | 0xC0, (length >> 8) & 0xFF, length & 0xFF];
    } else if (length < 0x10000000) {
      return [
        (length >> 24) | 0xE0,
        (length >> 16) & 0xFF,
        (length >> 8) & 0xFF,
        length & 0xFF,
      ];
    } else {
      return [
        0xF0,
        (length >> 24) & 0xFF,
        (length >> 16) & 0xFF,
        (length >> 8) & 0xFF,
        length & 0xFF,
      ];
    }
  }

  /// Writes a complete sentence composed of words, terminated by an empty word.
  Future<void> writeSentence(List<String> words) async {
    if (_socket == null) throw StateError('Socket is not connected');

    final BytesBuilder bb = BytesBuilder();
    for (final word in words) {
      final bytes = utf8.encode(word);
      bb.add(encodeLength(bytes.length));
      bb.add(bytes);
    }
    // Sentence terminator: 0x00 (length 0)
    bb.addByte(0x00);

    _socket!.add(bb.toBytes());
    await _socket!.flush();
  }

  /// Reads one sentence from the socket byte stream.
  Future<List<String>> readSentence() async {
    final List<String> words = [];

    final buffer = <int>[];
    final completer = Completer<List<String>>();

    StreamSubscription<List<int>>? sub;

    Timer? timer;
    timer = Timer(timeout, () {
      if (!completer.isCompleted) {
        sub?.cancel();
        completer.completeError(
          TimeoutException('انتهت مهلة قراءة الرد من راوتر MikroTik ($timeout)'),
        );
      }
    });

    void processBuffer() {
      while (true) {
        if (buffer.isEmpty) break;

        // Read length
        int firstByte = buffer[0];
        if (firstByte == 0x00) {
          // End of sentence
          buffer.removeAt(0);
          timer?.cancel();
          sub?.cancel();
          if (!completer.isCompleted) {
            completer.complete(words);
          }
          return;
        }

        int length = 0;
        int lengthBytesCount = 0;

        if ((firstByte & 0x80) == 0x00) {
          length = firstByte;
          lengthBytesCount = 1;
        } else if ((firstByte & 0xC0) == 0x80) {
          if (buffer.length < 2) return;
          length = ((firstByte & 0x3F) << 8) | buffer[1];
          lengthBytesCount = 2;
        } else if ((firstByte & 0xE0) == 0xC0) {
          if (buffer.length < 3) return;
          length = ((firstByte & 0x1F) << 16) | (buffer[1] << 8) | buffer[2];
          lengthBytesCount = 3;
        } else if ((firstByte & 0xF0) == 0xE0) {
          if (buffer.length < 4) return;
          length = ((firstByte & 0x0F) << 24) |
              (buffer[1] << 16) |
              (buffer[2] << 8) |
              buffer[3];
          lengthBytesCount = 4;
        } else if ((firstByte & 0xF8) == 0xF0) {
          if (buffer.length < 5) return;
          length = (buffer[1] << 24) |
              (buffer[2] << 16) |
              (buffer[3] << 8) |
              buffer[4];
          lengthBytesCount = 5;
        }

        if (buffer.length < lengthBytesCount + length) {
          // Need more bytes
          return;
        }

        // Extract word
        final wordBytes = buffer.sublist(
          lengthBytesCount,
          lengthBytesCount + length,
        );
        buffer.removeRange(0, lengthBytesCount + length);
        final word = utf8.decode(wordBytes, allowMalformed: true);
        words.add(word);
      }
    }

    sub = _byteStream.stream.listen(
      (chunk) {
        buffer.addAll(chunk);
        processBuffer();
      },
      onError: (err) {
        timer?.cancel();
        if (!completer.isCompleted) completer.completeError(err);
      },
      onDone: () {
        timer?.cancel();
        if (!completer.isCompleted) completer.complete(words);
      },
    );

    return completer.future;
  }

  /// Performs authentication with MikroTik RouterOS (v6.43+, v7, and older challenge-response fallback).
  Future<void> login(String username, String password) async {
    // 1. Try modern plain login (/login with =name= and =password=)
    await writeSentence(['/login', '=name=$username', '=password=$password']);
    final response = await readSentence();

    if (response.isEmpty) {
      throw const SocketException('لم يستجب الراوتر لطلب تسجيل الدخول');
    }

    final status = response[0];
    if (status == '!done') {
      // Check if challenge is returned (pre-6.43 RouterOS)
      String? challengeHex;
      for (final word in response) {
        if (word.startsWith('=ret=')) {
          challengeHex = word.substring(5).trim();
          break;
        }
      }

      if (challengeHex != null && challengeHex.isNotEmpty) {
        // MD5 challenge response authentication
        await _authenticateChallengeResponse(username, password, challengeHex);
      }
      return; // Login succeeded!
    }

    if (status == '!trap') {
      String errMsg = 'اسم المستخدم أو كلمة المرور غير صحيحة';
      for (final word in response) {
        if (word.startsWith('=message=')) {
          errMsg = word.substring(9);
          break;
        }
      }
      throw AuthException(errMsg);
    }

    throw AuthException('فشل تسجيل الدخول: استجابة غير متوقعة من الراوتر ($status)');
  }

  Future<void> _authenticateChallengeResponse(
    String username,
    String password,
    String challengeHex,
  ) async {
    // Challenge bytes from hex
    final List<int> challengeBytes = [];
    for (int i = 0; i < challengeHex.length; i += 2) {
      challengeBytes.add(int.parse(challengeHex.substring(i, i + 2), radix: 16));
    }

    // Hash: md5(0x00 + password_utf8 + challenge_bytes)
    final passBytes = utf8.encode(password);
    final toHash = <int>[0x00, ...passBytes, ...challengeBytes];
    final hashDigest = md5.convert(toHash).bytes;

    final hexHash = hashDigest
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join('')
        .toLowerCase();
    final responseHex = '00$hexHash';

    await writeSentence(['/login', '=name=$username', '=response=$responseHex']);
    final res = await readSentence();

    if (res.isEmpty || res[0] != '!done') {
      String msg = 'فشل تسجيل الدخول بواسطة التحقق الثنائي القديم';
      for (final w in res) {
        if (w.startsWith('=message=')) msg = w.substring(9);
      }
      throw AuthException(msg);
    }
  }

  /// Executes a RouterOS command and collects all `!re` reply sentences until `!done`.
  Future<List<Map<String, String>>> executeCommand(List<String> commandWords) async {
    await writeSentence(commandWords);
    final List<Map<String, String>> records = [];

    while (true) {
      final sentence = await readSentence();
      if (sentence.isEmpty) break;

      final replyType = sentence[0];
      if (replyType == '!done') {
        break;
      } else if (replyType == '!re') {
        final Map<String, String> record = {};
        for (int i = 1; i < sentence.length; i++) {
          final word = sentence[i];
          if (word.startsWith('=')) {
            final eqIndex = word.indexOf('=', 1);
            if (eqIndex != -1) {
              final key = word.substring(1, eqIndex);
              final value = word.substring(eqIndex + 1);
              record[key] = value;
            } else {
              record[word.substring(1)] = '';
            }
          }
        }
        records.add(record);
      } else if (replyType == '!trap') {
        String msg = 'خطأ من راوتر MikroTik';
        for (final word in sentence) {
          if (word.startsWith('=message=')) {
            msg = word.substring(9);
            break;
          }
        }
        throw Exception(msg);
      }
    }

    return records;
  }

  /// Queries the router system identity and resources.
  Future<Map<String, dynamic>> readSystemInfo() async {
    // Read Identity
    String identity = 'MikroTik';
    try {
      final identityRecords = await executeCommand(['/system/identity/print']);
      if (identityRecords.isNotEmpty && identityRecords[0]['name'] != null) {
        identity = identityRecords[0]['name']!.trim();
      }
    } catch (_) {}

    // Read Resources
    String version = 'RouterOS';
    String boardName = 'MikroTik Router';
    int cpuLoad = 0;
    int uptimeSeconds = 0;

    try {
      final resourceRecords = await executeCommand(['/system/resource/print']);
      if (resourceRecords.isNotEmpty) {
        final r = resourceRecords[0];
        if (r['version'] != null) version = r['version']!.trim();
        if (r['board-name'] != null) boardName = r['board-name']!.trim();
        if (r['cpu-load'] != null) cpuLoad = int.tryParse(r['cpu-load']!.trim()) ?? 0;
        if (r['uptime'] != null) uptimeSeconds = parseRouterOsUptime(r['uptime']!.trim());
      }
    } catch (_) {}

    return {
      'identity': identity,
      'version': version,
      'boardName': boardName,
      'cpuLoad': cpuLoad,
      'uptimeSeconds': uptimeSeconds,
      'isDirectLocal': true,
      'protocol': useTls || port == 8729 ? 'ROUTEROS_API_SSL' : 'ROUTEROS_API_PLAIN',
    };
  }

  /// Retrieves live HotSpot users directly from the router (/ip/hotspot/user/print).
  Future<List<Map<String, dynamic>>> getHotspotUsers() async {
    final records = await executeCommand([
      '/ip/hotspot/user/print',
      '=.proplist=.id,name,password,profile,uptime,bytes-in,bytes-out,disabled,comment',
    ]);

    return records.map((r) => {
      'id': r['.id'] ?? '',
      'username': r['name'] ?? '',
      'profile': r['profile'] ?? 'default',
      'uptime': r['uptime'] ?? '0s',
      'bytesIn': int.tryParse(r['bytes-in'] ?? '0') ?? 0,
      'bytesOut': int.tryParse(r['bytes-out'] ?? '0') ?? 0,
      'disabled': r['disabled'] == 'true',
      'comment': r['comment'] ?? '',
      'verifiedOnRouter': true,
    }).toList();
  }

  /// Retrieves live active HotSpot sessions directly from the router (/ip/hotspot/active/print).
  Future<List<Map<String, dynamic>>> getHotspotActiveSessions() async {
    final records = await executeCommand([
      '/ip/hotspot/active/print',
      '=.proplist=.id,user,address,mac-address,uptime,bytes-in,bytes-out,login-by',
    ]);

    return records.map((r) => {
      'id': r['.id'] ?? '',
      'username': r['user'] ?? '',
      'ipAddress': r['address'] ?? '',
      'macAddress': r['mac-address'] ?? '',
      'uptime': r['uptime'] ?? '0s',
      'bytesIn': int.tryParse(r['bytes-in'] ?? '0') ?? 0,
      'bytesOut': int.tryParse(r['bytes-out'] ?? '0') ?? 0,
      'loginBy': r['login-by'] ?? '',
    }).toList();
  }

  /// Toggles (enables/disables) a HotSpot user directly on the router.
  Future<bool> toggleHotspotUser(String username, bool isEnabled) async {
    final records = await executeCommand([
      '/ip/hotspot/user/print',
      '?name=$username',
      '=.proplist=.id',
    ]);

    if (records.isEmpty || records[0]['.id'] == null) {
      throw Exception('المستخدم $username غير موجود على الراوتر');
    }

    final id = records[0]['.id']!;
    await executeCommand([
      '/ip/hotspot/user/set',
      '=.id=$id',
      '=disabled=${isEnabled ? "no" : "yes"}',
    ]);

    return true;
  }

  /// Disconnects an active HotSpot session directly on the router (/ip/hotspot/active/remove).
  Future<bool> disconnectHotspotSession(String username) async {
    final records = await executeCommand([
      '/ip/hotspot/active/print',
      '?user=$username',
      '=.proplist=.id',
    ]);

    if (records.isEmpty || records[0]['.id'] == null) {
      throw Exception('لا توجد جلسة نشطة للمستخدم $username على الراوتر');
    }

    final id = records[0]['.id']!;
    await executeCommand([
      '/ip/hotspot/active/remove',
      '=.id=$id',
    ]);

    return true;
  }

  /// Creates a HotSpot user directly on the router (/ip/hotspot/user/add).
  Future<bool> createHotspotUser({
    required String username,
    required String password,
    required String profile,
    String? comment,
    String? timeLimit,
  }) async {
    final words = [
      '/ip/hotspot/user/add',
      '=name=$username',
      '=password=$password',
      '=profile=$profile',
    ];
    if (comment != null && comment.isNotEmpty) {
      words.add('=comment=$comment');
    }
    if (timeLimit != null && timeLimit.isNotEmpty) {
      words.add('=limit-uptime=$timeLimit');
    }

    await executeCommand(words);
    return true;
  }

  /// Deletes/removes a HotSpot user directly from the router (/ip/hotspot/user/remove).
  /// Enforces full exact name equality (==) to prevent accidental removal of users with similar names.
  Future<bool> removeHotspotUser(String username) async {
    final records = await executeCommand([
      '/ip/hotspot/user/print',
      '?name=$username',
      '=.proplist=.id,name',
    ]);

    if (records.isEmpty) {
      return false;
    }

    bool anyRemoved = false;
    for (final record in records) {
      // Enforce strict full name equality to never touch similar/prefix/suffix names
      final recordName = record['name'];
      if (recordName != null && recordName != username) {
        continue;
      }

      final id = record['.id'];
      if (id != null && id.isNotEmpty) {
        try {
          await executeCommand([
            '/ip/hotspot/user/remove',
            '=.id=$id',
          ]);
          anyRemoved = true;
        } catch (e) {
          final err = e.toString().toLowerCase();
          if (err.contains('no such item')) {
            // Ignored: item was already removed or does not exist
          } else {
            rethrow;
          }
        }
      }
    }

    return anyRemoved;
  }

  /// Parses MikroTik uptime format (e.g. "3w2d1h45m12s" or "1d04:12:30" or "02:14:35") into seconds.
  static int parseRouterOsUptime(dynamic uptimeValue) {
    if (uptimeValue == null) return 0;
    if (uptimeValue is int) return uptimeValue > 0 ? uptimeValue : 0;
    final str = uptimeValue.toString().trim().toLowerCase();
    if (str.isEmpty) return 0;

    int total = 0;
    final weeks = RegExp(r'(\d+)w').firstMatch(str);
    final days = RegExp(r'(\d+)d').firstMatch(str);
    final hours = RegExp(r'(\d+)h').firstMatch(str);
    final minutes = RegExp(r'(\d+)m(?!s)').firstMatch(str);
    final seconds = RegExp(r'(\d+)s').firstMatch(str);

    if (weeks != null && weeks.group(1) != null) {
      total += (int.tryParse(weeks.group(1)!) ?? 0) * 7 * 86400;
    }
    if (days != null && days.group(1) != null) {
      total += (int.tryParse(days.group(1)!) ?? 0) * 86400;
    }
    if (hours != null && hours.group(1) != null) {
      total += (int.tryParse(hours.group(1)!) ?? 0) * 3600;
    }
    if (minutes != null && minutes.group(1) != null) {
      total += (int.tryParse(minutes.group(1)!) ?? 0) * 60;
    }
    if (seconds != null && seconds.group(1) != null) {
      total += int.tryParse(seconds.group(1)!) ?? 0;
    }

    // Fallback for standard hh:mm:ss in compound formats like 1d02:00:00 or standalone 04:12:30
    final timePart = RegExp(r'(\d{1,2}):(\d{2}):(\d{2})').firstMatch(str);
    if (timePart != null && hours == null && minutes == null && seconds == null) {
      final h = int.tryParse(timePart.group(1) ?? '0') ?? 0;
      final m = int.tryParse(timePart.group(2) ?? '0') ?? 0;
      final s = int.tryParse(timePart.group(3) ?? '0') ?? 0;
      total += h * 3600 + m * 60 + s;
    }

    return total;
  }
}

class AuthException implements Exception {
  final String message;
  const AuthException(this.message);

  @override
  String toString() => message;
}
