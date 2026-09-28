// ============================================================================
// Platform: Commercial MikroTik Network & HotSpot Card Management System
// File: test/api_client_test.dart
// Integration Test: ApiClient to Fastify Backend API Verification
// ============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:mikrotik_cards_app/models/router_model.dart';
import 'package:mikrotik_cards_app/services/api_client.dart';

void main() {
  group('ApiClient Live Backend Integration Tests', () {
    test('testRouterConnection returns success with RouterInfo for valid host', () async {
      final result = await ApiClient.testRouterConnection(
        host: '192.168.88.1',
        port: 8728,
        username: 'admin',
        password: 'test',
      );

      expect(result['success'], isTrue);
      expect(result['data'], isNotNull);
      expect(result['data']['identity'], equals('MOCK-ROUTER-01'));
      expect(result['data']['version'], equals('RouterOS v7.14.3'));
      expect(result['data']['boardName'], equals('RB4011iGS+'));
    });

    test('testRouterConnection returns failure for fail.test host', () async {
      final result = await ApiClient.testRouterConnection(
        host: 'fail.test',
        port: 8728,
        username: 'admin',
        password: 'test',
      );

      expect(result['success'], isFalse);
      expect(result['errorCode'], equals('CONNECTION_REFUSED'));
      expect(result['errorMessage'], contains('Connection refused'));
    });

    test('Live CRUD lifecycle: create -> getRouters -> delete against live backend', () async {
      // Step 1: Initial getRouters call
      final initialGetResult = await ApiClient.getRouters();
      expect(initialGetResult['success'], isTrue);
      final initialList = (initialGetResult['data'] as List).cast<RouterModel>();
      final int initialCount = initialList.length;

      // Step 2: Create a new router
      final uniqueName = 'راوتر فحص الربط ${DateTime.now().millisecondsSinceEpoch}';
      final createResult = await ApiClient.createRouter(
        name: uniqueName,
        host: '192.168.88.200',
        port: 8728,
        username: 'admin',
        password: 'securePassword123',
      );

      expect(createResult['success'], isTrue,
          reason: 'createRouter failed: ${createResult['errorMessage']}');
      expect(createResult['data'], isA<RouterModel>());
      final createdRouter = createResult['data'] as RouterModel;
      expect(createdRouter.id.isNotEmpty, isTrue);
      expect(createdRouter.name, equals(uniqueName));
      expect(createdRouter.host, equals('192.168.88.200'));

      // Step 3: Verify router list count increased and contains the new router
      final afterCreateResult = await ApiClient.getRouters();
      expect(afterCreateResult['success'], isTrue);
      final afterCreateList = (afterCreateResult['data'] as List).cast<RouterModel>();
      expect(afterCreateList.length, equals(initialCount + 1));
      expect(afterCreateList.any((r) => r.id == createdRouter.id), isTrue);

      // Step 4: Delete the newly created router
      final deleteResult = await ApiClient.deleteRouter(createdRouter.id);
      expect(deleteResult['success'], isTrue,
          reason: 'deleteRouter failed: ${deleteResult['errorMessage']}');

      // Step 5: Verify router list count returned to initialCount and router is gone
      final afterDeleteResult = await ApiClient.getRouters();
      expect(afterDeleteResult['success'], isTrue);
      final afterDeleteList = (afterDeleteResult['data'] as List).cast<RouterModel>();
      expect(afterDeleteList.length, equals(initialCount));
      expect(afterDeleteList.any((r) => r.id == createdRouter.id), isFalse);
    });
  });
}
