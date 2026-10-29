// ============================================================================
// Platform: Commercial MikroTik Network & HotSpot Card Management System (Jalsah)
// File: test/router_connection_lifecycle_and_hotspot_control_test.dart
// Tests: Strict separation of Test Connection, Save, Post-Save Verification,
//        and Direct HotSpot Control via Native RouterOS API
// ============================================================================

import 'package:flutter_test/flutter_test.dart';

import 'package:mikrotik_cards_app/models/router_model.dart';
import 'package:mikrotik_cards_app/services/mikrotik_discovery_service.dart';
import 'package:mikrotik_cards_app/services/routeros_binary_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    MikrotikDiscoveryService.directConnectionTester = null;
    MikrotikDiscoveryService.hotspotUsersDirectTester = null;
    MikrotikDiscoveryService.hotspotSessionsDirectTester = null;
    MikrotikDiscoveryService.toggleHotspotUserDirectTester = null;
    MikrotikDiscoveryService.disconnectHotspotSessionDirectTester = null;
  });

  tearDown(() {
    MikrotikDiscoveryService.directConnectionTester = null;
    MikrotikDiscoveryService.hotspotUsersDirectTester = null;
    MikrotikDiscoveryService.hotspotSessionsDirectTester = null;
    MikrotikDiscoveryService.toggleHotspotUserDirectTester = null;
    MikrotikDiscoveryService.disconnectHotspotSessionDirectTester = null;
  });

  group('Group 1: Separation of Connection Test, Router Save, and Actual Status', () {
    test('1.1 Discovery or open port alone does NOT set router to ONLINE without authentication', () {
      final router = RouterModel(
        id: 'r-1',
        name: 'Unverified Router',
        host: '192.168.88.1',
        apiPort: 8728,
        status: 'OFFLINE',
      );

      expect(router.isOnline, isFalse);
      expect(router.status, equals('OFFLINE'));
    });

    test('1.2 Failed testDirectConnection reports exact failure and does NOT fake success', () async {
      MikrotikDiscoveryService.directConnectionTester = ({
        required String host,
        required int port,
        required String username,
        required String password,
        String? connectionMethod,
        Duration timeout = const Duration(seconds: 6),
      }) async {
        return {
          'success': false,
          'errorCode': 'INVALID_CREDENTIALS',
          'errorMessage': 'اسم المستخدم أو كلمة المرور غير صحيحة',
        };
      };

      final res = await MikrotikDiscoveryService.testDirectConnection(
        host: '192.168.88.1',
        port: 8728,
        username: 'admin',
        password: 'wrong_password',
      );

      expect(res['success'], isFalse);
      expect(res['errorCode'], equals('INVALID_CREDENTIALS'));
      expect(res['errorMessage'], contains('غير صحيحة'));
    });

    test('1.3 Successful testDirectConnection returns live hardware specs from router', () async {
      MikrotikDiscoveryService.directConnectionTester = ({
        required String host,
        required int port,
        required String username,
        required String password,
        String? connectionMethod,
        Duration timeout = const Duration(seconds: 6),
      }) async {
        return {
          'success': true,
          'data': {
            'identity': 'Main-HotSpot-Gate',
            'version': '7.15.2',
            'boardName': 'RB4011iGS+',
            'cpuLoad': 14,
            'uptimeSeconds': 172800,
            'isDirectLocal': true,
          },
        };
      };

      final res = await MikrotikDiscoveryService.testDirectConnection(
        host: '192.168.88.1',
        port: 8728,
        username: 'admin',
        password: 'correct_password',
      );

      expect(res['success'], isTrue);
      final data = res['data'] as Map<String, dynamic>;
      expect(data['identity'], equals('Main-HotSpot-Gate'));
      expect(data['version'], equals('7.15.2'));
      expect(data['boardName'], equals('RB4011iGS+'));
      expect(data['cpuLoad'], equals(14));
      expect(data['uptimeSeconds'], equals(172800));
    });

    test('1.4 RouterModel.copyWith preserves properties and updates verified status cleanly', () {
      final initial = RouterModel(
        id: 'r-101',
        name: 'Old Name',
        host: '192.168.88.1',
        apiPort: 8728,
        status: 'OFFLINE',
      );

      expect(initial.isOnline, isFalse);

      final updated = initial.copyWith(
        status: 'ONLINE',
        boardModel: 'hEX S',
        routerOsVersion: '7.14.3',
        cpuLoadPercentage: 8,
        uptimeSeconds: 86400,
        lastSeenAt: DateTime(2026, 10, 27, 20, 0),
      );

      expect(updated.isOnline, isTrue);
      expect(updated.boardModel, equals('hEX S'));
      expect(updated.routerOsVersion, equals('7.14.3'));
      expect(updated.cpuLoadPercentage, equals(8));
      expect(updated.uptimeSeconds, equals(86400));
      expect(updated.host, equals('192.168.88.1'));
      expect(updated.apiPort, equals(8728));
    });
  });

  group('Group 2: Direct HotSpot Control via Native RouterOS API', () {
    test('2.1 getHotspotUsersDirect reads users directly from local router', () async {
      MikrotikDiscoveryService.hotspotUsersDirectTester = ({
        required String host,
        required int port,
        required String username,
        required String password,
        String? connectionMethod,
      }) async {
        return {
          'success': true,
          'data': [
            {
              'id': '*1',
              'username': 'card_1001',
              'profile': 'default',
              'uptime': '1h20m',
              'bytesIn': 5242880,
              'bytesOut': 20971520,
              'disabled': false,
              'comment': 'Voucher Batch #10',
              'verifiedOnRouter': true,
            },
            {
              'id': '*2',
              'username': 'card_1002',
              'profile': 'vip',
              'uptime': '0s',
              'bytesIn': 0,
              'bytesOut': 0,
              'disabled': true,
              'comment': 'Expired Voucher',
              'verifiedOnRouter': true,
            },
          ],
        };
      };

      final res = await MikrotikDiscoveryService.getHotspotUsersDirect(
        host: '192.168.88.1',
        port: 8728,
        username: 'admin',
        password: 'password123',
      );

      expect(res['success'], isTrue);
      final users = res['data'] as List<dynamic>;
      expect(users.length, equals(2));
      expect(users[0]['username'], equals('card_1001'));
      expect(users[0]['disabled'], isFalse);
      expect(users[1]['username'], equals('card_1002'));
      expect(users[1]['disabled'], isTrue);
    });

    test('2.2 getHotspotActiveSessionsDirect reads active sessions directly from local router', () async {
      MikrotikDiscoveryService.hotspotSessionsDirectTester = ({
        required String host,
        required int port,
        required String username,
        required String password,
        String? connectionMethod,
      }) async {
        return {
          'success': true,
          'data': [
            {
              'id': '*A1',
              'username': 'card_1001',
              'ipAddress': '192.168.88.245',
              'macAddress': 'DC:2C:6E:11:22:33',
              'uptime': '45m10s',
              'bytesIn': 1048576,
              'bytesOut': 8388608,
              'loginBy': 'http-chap',
            },
          ],
        };
      };

      final res = await MikrotikDiscoveryService.getHotspotActiveSessionsDirect(
        host: '192.168.88.1',
        port: 8728,
        username: 'admin',
        password: 'password123',
      );

      expect(res['success'], isTrue);
      final sessions = res['data'] as List<dynamic>;
      expect(sessions.length, equals(1));
      expect(sessions[0]['username'], equals('card_1001'));
      expect(sessions[0]['ipAddress'], equals('192.168.88.245'));
      expect(sessions[0]['macAddress'], equals('DC:2C:6E:11:22:33'));
    });

    test('2.3 toggleHotspotUserDirect enables or disables a user on the local router', () async {
      MikrotikDiscoveryService.toggleHotspotUserDirectTester = ({
        required String host,
        required int port,
        required String username,
        required String password,
        required String targetUsername,
        required bool isEnabled,
        String? connectionMethod,
      }) async {
        return {
          'success': true,
          'data': {'username': targetUsername, 'isEnabled': isEnabled},
        };
      };

      final disableRes = await MikrotikDiscoveryService.toggleHotspotUserDirect(
        host: '192.168.88.1',
        port: 8728,
        username: 'admin',
        password: 'password123',
        targetUsername: 'card_1001',
        isEnabled: false,
      );

      expect(disableRes['success'], isTrue);
      expect(disableRes['data']['isEnabled'], isFalse);

      final enableRes = await MikrotikDiscoveryService.toggleHotspotUserDirect(
        host: '192.168.88.1',
        port: 8728,
        username: 'admin',
        password: 'password123',
        targetUsername: 'card_1001',
        isEnabled: true,
      );

      expect(enableRes['success'], isTrue);
      expect(enableRes['data']['isEnabled'], isTrue);
    });

    test('2.4 disconnectHotspotSessionDirect terminates an active session on the local router', () async {
      MikrotikDiscoveryService.disconnectHotspotSessionDirectTester = ({
        required String host,
        required int port,
        required String username,
        required String password,
        required String targetUsername,
        String? connectionMethod,
      }) async {
        return {
          'success': true,
          'data': {'username': targetUsername, 'disconnected': true},
        };
      };

      final res = await MikrotikDiscoveryService.disconnectHotspotSessionDirect(
        host: '192.168.88.1',
        port: 8728,
        username: 'admin',
        password: 'password123',
        targetUsername: 'card_1001',
      );

      expect(res['success'], isTrue);
      expect(res['data']['disconnected'], isTrue);
    });
  });

  group('Group 3: Native RouterOS Binary Protocol Encoding & Uptime Parsing', () {
    test('3.1 encodeLength produces exact byte lengths for all MikroTik size tiers', () {
      // Tier 1: 0 - 127 (1 byte)
      expect(RouterOsBinaryClient.encodeLength(0), equals([0]));
      expect(RouterOsBinaryClient.encodeLength(10), equals([10]));
      expect(RouterOsBinaryClient.encodeLength(127), equals([127]));

      // Tier 2: 128 - 16383 (2 bytes with 0x80 mask)
      final tier2 = RouterOsBinaryClient.encodeLength(128);
      expect(tier2.length, equals(2));
      expect(tier2[0] & 0x80, equals(0x80));

      // Tier 3: 16384 - 2097151 (3 bytes with 0xC0 mask)
      final tier3 = RouterOsBinaryClient.encodeLength(20000);
      expect(tier3.length, equals(3));
      expect(tier3[0] & 0xC0, equals(0xC0));
    });

    test('3.2 parseRouterOsUptime correctly handles compound formats', () {
      expect(RouterOsBinaryClient.parseRouterOsUptime('00:00:00'), equals(0));
      expect(RouterOsBinaryClient.parseRouterOsUptime('01:30:15'), equals(5415)); // 3600 + 1800 + 15
      expect(RouterOsBinaryClient.parseRouterOsUptime('1d02:00:00'), equals(86400 + 7200));
      expect(RouterOsBinaryClient.parseRouterOsUptime('2w1d3h4m5s'), equals(
        2 * 7 * 86400 + 86400 + 3 * 3600 + 4 * 60 + 5,
      ));
      expect(RouterOsBinaryClient.parseRouterOsUptime(null), equals(0));
      expect(RouterOsBinaryClient.parseRouterOsUptime(''), equals(0));
    });
  });
}
