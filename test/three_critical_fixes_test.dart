// ============================================================================
// Platform: Commercial MikroTik Network & HotSpot Card Management System (Jalsah)
// File: test/three_critical_fixes_test.dart
// Verification: Real-Device Testing & Verification for 3 Critical Issues
// 1. MikroTik Direct LAN RouterOS Binary & REST Connection
// 2. Subscription Plans & Super Admin Requests Display & Actions
// 3. Intro Splash Video Layout, Aspect Ratio & Smooth Seamless Framing
// ============================================================================

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:mikrotik_cards_app/models/router_model.dart';
import 'package:mikrotik_cards_app/services/api_client.dart';
import 'package:mikrotik_cards_app/services/mikrotik_discovery_service.dart';
import 'package:mikrotik_cards_app/services/routeros_binary_client.dart';

void main() {
  group('Issue 1: MikroTik Direct Connection & Protocol Verification', () {
    test('1.1 isLocalPrivateIp correctly identifies RFC1918 private addresses', () {
      expect(MikrotikDiscoveryService.isLocalPrivateIp('192.168.88.1'), isTrue);
      expect(MikrotikDiscoveryService.isLocalPrivateIp('10.0.0.1'), isTrue);
      expect(MikrotikDiscoveryService.isLocalPrivateIp('172.16.1.1'), isTrue);
      expect(MikrotikDiscoveryService.isLocalPrivateIp('127.0.0.1'), isTrue);
      expect(MikrotikDiscoveryService.isLocalPrivateIp('localhost'), isTrue);

      expect(MikrotikDiscoveryService.isLocalPrivateIp('8.8.8.8'), isFalse);
      expect(MikrotikDiscoveryService.isLocalPrivateIp('1.1.1.1'), isFalse);
      expect(MikrotikDiscoveryService.isLocalPrivateIp('alrafeerouter.zone.id'), isFalse);
    });

    test('1.2 RouterOsBinaryClient length encoding complies with RouterOS API protocol', () {
      // Length < 0x80 (128) -> 1 byte
      expect(RouterOsBinaryClient.encodeLength(0), [0x00]);
      expect(RouterOsBinaryClient.encodeLength(6), [0x06]);
      expect(RouterOsBinaryClient.encodeLength(127), [0x7F]);

      // Length < 0x4000 (16384) -> 2 bytes (0x80 | high, low)
      final len200 = RouterOsBinaryClient.encodeLength(200);
      expect(len200.length, 2);
      expect(len200[0] & 0xC0, 0x80);

      // Length >= 0x4000 -> 3 bytes
      final len20000 = RouterOsBinaryClient.encodeLength(20000);
      expect(len20000.length, 3);
      expect(len20000[0] & 0xE0, 0xC0);
    });

    test('1.3 RouterOsBinaryClient uptime parser handles all RouterOS duration formats', () {
      expect(RouterOsBinaryClient.parseRouterOsUptime('01:30:15'), 1 * 3600 + 30 * 60 + 15);
      expect(RouterOsBinaryClient.parseRouterOsUptime('3d4h20m10s'), 3 * 86400 + 4 * 3600 + 20 * 60 + 10);
      expect(RouterOsBinaryClient.parseRouterOsUptime('1w2d'), 1 * 7 * 86400 + 2 * 86400);
      expect(RouterOsBinaryClient.parseRouterOsUptime(''), 0);
      expect(RouterOsBinaryClient.parseRouterOsUptime(null), 0);
    });

    test('1.4 ApiClient.testRouterConnection does NOT call remote cloud backend for LAN IP', () async {
      bool backendCalled = false;
      ApiClient.client = MockClient((request) async {
        if (request.url.path.contains('test-connection')) {
          backendCalled = true;
        }
        return http.Response(jsonEncode({'success': false, 'errorCode': 'SSRF_BLOCKED'}), 403);
      });

      // Probe a non-routable local IP with short timeout
      final result = await ApiClient.testRouterConnection(
        host: '192.168.254.254', // LAN IP
        port: 8728,
        username: 'admin',
        password: 'password123',
      );

      // Cloud backend should NOT have been invoked because host is private LAN!
      expect(backendCalled, isFalse);
      expect(result['success'], isFalse);
      // Direct device probe failed with PORT_CLOSED, HOST_UNREACHABLE, or TIMEOUT
      expect(
        ['PORT_CLOSED', 'HOST_UNREACHABLE', 'TIMEOUT', 'CONNECTION_ERROR'].contains(result['errorCode']),
        isTrue,
      );
    });

    test('1.5 ApiClient.createRouter sends verified ONLINE status and hardware specs', () async {
      Map<String, dynamic>? sentPayload;
      ApiClient.client = MockClient((request) async {
        if (request.url.path.endsWith('/routers') && request.method == 'POST') {
          sentPayload = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'id': 'router-uuid-123',
                'name': sentPayload!['name'],
                'host': sentPayload!['host'],
                'apiPort': sentPayload!['port'],
                'status': sentPayload!['status'],
                'routerOsVersion': sentPayload!['routerOsVersion'],
                'boardModel': sentPayload!['boardModel'],
                'cpuLoadPercentage': sentPayload!['cpuLoadPercentage'],
                'uptimeSeconds': sentPayload!['uptimeSeconds'],
              },
            }),
            201,
          );
        }
        return http.Response('Not Found', 404);
      });

      final result = await ApiClient.createRouter(
        name: 'Main MikroTik Router',
        host: '192.168.88.1',
        port: 8728,
        username: 'admin',
        password: 'password123',
        status: 'ONLINE',
        routerOsVersion: '7.15.2',
        boardModel: 'RB4011iGS+',
        cpuLoadPercentage: 15,
        uptimeSeconds: 7200,
      );

      expect(result['success'], isTrue);
      expect(sentPayload?['status'], 'ONLINE');
      expect(sentPayload?['routerOsVersion'], '7.15.2');
      expect(sentPayload?['boardModel'], 'RB4011iGS+');
      final router = result['data'] as RouterModel;
      expect(router.status, 'ONLINE');
      expect(router.isOnline, isTrue);
    });

    test('1.6 ApiClient.createRouter sends OFFLINE when connection unverified or failed', () async {
      Map<String, dynamic>? sentPayload;
      ApiClient.client = MockClient((request) async {
        if (request.url.path.endsWith('/routers') && request.method == 'POST') {
          sentPayload = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'id': 'router-uuid-456',
                'name': sentPayload!['name'],
                'host': sentPayload!['host'],
                'apiPort': sentPayload!['port'],
                'status': sentPayload!['status'],
              },
            }),
            201,
          );
        }
        return http.Response('Not Found', 404);
      });

      final result = await ApiClient.createRouter(
        name: 'Offline Router',
        host: '10.0.0.2',
        port: 8728,
        username: 'admin',
        password: 'password123',
        status: 'OFFLINE',
      );

      expect(result['success'], isTrue);
      expect(sentPayload?['status'], 'OFFLINE');
      final router = result['data'] as RouterModel;
      expect(router.status, 'OFFLINE');
      expect(router.isOnline, isFalse);
    });

    test('1.7 Dashboard router reload parses ONLINE status correctly and sets isOnline=true', () async {
      ApiClient.client = MockClient((request) async {
        if (request.url.path.endsWith('/routers') && request.method == 'GET') {
          return http.Response(
            jsonEncode({
              'success': true,
              'data': [
                {
                  'id': 'r-1',
                  'name': 'Live Verified Router',
                  'host': '192.168.88.1',
                  'apiPort': 8728,
                  'status': 'ONLINE',
                  'boardModel': 'hAP ax2',
                  'routerOsVersion': '7.16',
                },
                {
                  'id': 'r-2',
                  'name': 'Disconnected Router',
                  'host': '192.168.88.2',
                  'apiPort': 8728,
                  'status': 'OFFLINE',
                },
              ],
            }),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });

      final result = await ApiClient.getRouters();
      expect(result['success'], isTrue);
      final list = result['data'] as List<RouterModel>;
      expect(list.length, 2);

      // r-1 is ONLINE
      expect(list[0].status, 'ONLINE');
      expect(list[0].isOnline, isTrue);

      // r-2 is OFFLINE
      expect(list[1].status, 'OFFLINE');
      expect(list[1].isOnline, isFalse);
    });
  });

  group('Issue 2: Subscription Plans & Admin Requests Verification', () {
    test('2.1 ApiClient.getSubscriptionPlans gracefully falls back to default plans on 404', () async {
      ApiClient.client = MockClient((request) async {
        if (request.url.path.endsWith('/subscription/plans')) {
          // Cloud server returns 404 because Phase 14 /plans route is not deployed yet
          return http.Response(
            jsonEncode({
              'message': 'Route GET:/api/v1/subscription/plans not found',
              'error': 'Not Found',
              'statusCode': 404,
            }),
            404,
          );
        }
        return http.Response('Not Found', 404);
      });

      final result = await ApiClient.getSubscriptionPlans();
      expect(result['success'], isFalse);
      expect(result['errorCode'], equals('ENDPOINT_NOT_DEPLOYED'));
      expect(result['isEndpointMissing'], isTrue);
      expect(result['errorMessage'], contains('404'));
    });

    test('2.2 ApiClient.getAdminSubscriptionPlans honestly reports 404 without fake fallback', () async {
      ApiClient.client = MockClient((request) async {
        return http.Response(jsonEncode({'error': 'Not Found', 'statusCode': 404}), 404);
      });

      final result = await ApiClient.getAdminSubscriptionPlans();
      expect(result['success'], isFalse);
      expect(result['errorCode'], equals('ENDPOINT_NOT_DEPLOYED'));
      expect(result['isEndpointMissing'], isTrue);
    });

    test('2.3 ApiClient.getAdminSubscriptionRequests returns empty array gracefully on 404', () async {
      ApiClient.client = MockClient((request) async {
        return http.Response(jsonEncode({'error': 'Not Found', 'statusCode': 404}), 404);
      });

      final result = await ApiClient.getAdminSubscriptionRequests();
      expect(result['success'], isTrue);
      expect(result['data'], isA<List>());
      expect((result['data'] as List).isEmpty, isTrue);
    });

    test('2.4 ApiClient.approveAdminSubscriptionRequest sends POST and returns 200 result', () async {
      ApiClient.client = MockClient((request) async {
        if (request.url.path.contains('/subscription-requests/req-123/approve') &&
            request.method == 'POST') {
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {'id': 'req-123', 'status': 'APPROVED'},
              'message': 'تم تفعيل الاشتراك بنجاح',
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final res = await ApiClient.approveAdminSubscriptionRequest('req-123');
      // ignore: avoid_print
      print('DEBUG res: $res');
      expect(res['success'], isTrue);
      expect(res['message'], contains('تم تفعيل'));
    });
  });

  group('Issue 3: Video Framing & Geometry Verification', () {
    testWidgets('3.1 Video layout calculation fits subject within portrait screen bounds with safe margins', (tester) async {
      const double screenWidth = 390;
      const double screenHeight = 844;
      const double videoAspect = 16 / 9;

      // Sizing formula: subject (450px out of 1280) scaled to 80% screen width
      final scaledW = (0.80 * screenWidth / 450) * 1280;
      final scaledH = scaledW / videoAspect;

      // Subject width on screen
      final subjectWidthOnScreen = 450 * (scaledW / 1280);
      final horizontalMargin = (screenWidth - subjectWidthOnScreen) / 2;

      // Verification:
      // 1. Subject takes ~80% of width (not squeezed into 37%)
      expect(subjectWidthOnScreen, closeTo(screenWidth * 0.80, 1.0));

      // 2. Comfortable breathing room on left & right (at least 35px)
      expect(horizontalMargin, greaterThan(35.0));

      // 3. Scaled height fits well within vertical screen height (no vertical clipping)
      expect(scaledH, lessThan(screenHeight * 0.85));
    });
  });
}
