// ============================================================================
// Platform: Commercial MikroTik Network & HotSpot Card Management System
// File: test/api_client_test.dart
// Integration Test: ApiClient to Fastify Backend API Verification with Auth
// Master Reference: Rule 14 (Security), Rule 19 (Auth), Rule 23 (Errors)
// ============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:mikrotik_cards_app/models/package_model.dart';
import 'package:mikrotik_cards_app/models/router_model.dart';
import 'package:mikrotik_cards_app/services/api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dart:io';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    HttpOverrides.global = null;
    SharedPreferences.setMockInitialValues({});
  });

  group('ApiClient Authentication & Session Tests', () {
    test('login with invalid credentials returns UNAUTHORIZED', () async {
      final result = await ApiClient.login(
        username: 'admin',
        password: 'wrong_password_123',
      );

      expect(result['success'], isFalse);
      expect(result['errorCode'], equals('UNAUTHORIZED'));
      expect(result['errorMessage'], contains('بيانات الدخول غير صحيحة'));
      expect(ApiClient.authToken, isNull);
    });

    test('login with valid credentials sets authToken and returns user data', () async {
      final result = await ApiClient.login(
        username: 'admin',
        password: 'E3*NUdX&R==yKrD3',
      );

      expect(result['success'], isTrue,
          reason: 'Login failed: ${result['errorMessage']}');
      expect(result['data'], isNotNull);
      expect(ApiClient.authToken, isNotNull);
      expect(ApiClient.isAuthenticated, isTrue);

      final userData = result['data']['user'];
      expect(userData['username'], equals('admin'));
    });

    test('loadSavedToken restores token from storage', () async {
      // SharedPreferences should have the saved token from previous successful login
      final loadedToken = await ApiClient.loadSavedToken();
      expect(loadedToken, isNotNull);
      expect(loadedToken, equals(ApiClient.authToken));
    });

    test('logout clears in-memory and persistent token', () async {
      await ApiClient.logout();
      expect(ApiClient.authToken, isNull);
      expect(ApiClient.isAuthenticated, isFalse);

      final loaded = await ApiClient.loadSavedToken();
      expect(loaded, isNull);
    });
  });

  group('ApiClient Live Backend Integration Tests (Authenticated)', () {
    setUpAll(() async {
      // Re-login to have active token for authenticated API tests
      final loginResult = await ApiClient.login(
        username: 'admin',
        password: 'E3*NUdX&R==yKrD3',
      );
      expect(loginResult['success'], isTrue);
    });

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

    test('Live Package CRUD lifecycle: create -> getPackages -> delete against live backend', () async {
      // Step 1: Initial getPackages
      final initialGet = await ApiClient.getPackages();
      expect(initialGet['success'], isTrue);
      final initialList = (initialGet['data'] as List).cast<PackageModel>();
      final int initialCount = initialList.length;

      // Step 2: Create a package
      final uniqueCode = 'PKG-TEST-${DateTime.now().millisecondsSinceEpoch}';
      final createResult = await ApiClient.createPackage(
        name: 'باقة اختبار حي',
        code: uniqueCode,
        downloadSpeedLimit: '6M',
        uploadSpeedLimit: '3M',
        durationMinutes: 1440,
        validityDays: 1,
        price: 550,
        hotspotProfileName: 'hs_test_profile',
      );

      expect(createResult['success'], isTrue,
          reason: 'createPackage failed: ${createResult['errorMessage']}');
      expect(createResult['data'], isA<PackageModel>());
      final createdPkg = createResult['data'] as PackageModel;
      expect(createdPkg.id.isNotEmpty, isTrue);
      expect(createdPkg.code, equals(uniqueCode));
      expect(createdPkg.name, equals('باقة اختبار حي'));

      // Step 3: Verify list contains new package
      final afterCreate = await ApiClient.getPackages();
      expect(afterCreate['success'], isTrue);
      final afterCreateList = (afterCreate['data'] as List).cast<PackageModel>();
      expect(afterCreateList.length, equals(initialCount + 1));
      expect(afterCreateList.any((p) => p.id == createdPkg.id), isTrue);

      // Step 4: Delete the package
      final deleteResult = await ApiClient.deletePackage(createdPkg.id);
      expect(deleteResult['success'], isTrue,
          reason: 'deletePackage failed: ${deleteResult['errorMessage']}');

      // Step 5: Verify package is removed
      final afterDelete = await ApiClient.getPackages();
      expect(afterDelete['success'], isTrue);
      final afterDeleteList = (afterDelete['data'] as List).cast<PackageModel>();
      expect(afterDeleteList.length, equals(initialCount));
      expect(afterDeleteList.any((p) => p.id == createdPkg.id), isFalse);
    });
  });
}
