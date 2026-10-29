// ============================================================================
// Platform: Commercial MikroTik Network & HotSpot Card Management System (Jalsah)
// File: test/subscription_request_model_fix_test.dart
// Description: Unit & Widget tests verifying fix for SubscriptionRequestModel type
//              safety in UserProfileScreen, covering:
//              1. Empty requests list (no type cast errors, renders empty message)
//              2. Single request (SubscriptionRequestModel parsed correctly)
//              3. priceSnapshot and currencySnapshot JSON compatibility & clean formatting (e.g. 50 instead of 50.0)
//              4. Error response (handled gracefully without screen crash)
//              5. Direct model parsing unit tests
// ============================================================================

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
// ignore: depend_on_referenced_packages
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';
// ignore: depend_on_referenced_packages
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'package:mikrotik_cards_app/screens/user_profile_screen.dart';
import 'package:mikrotik_cards_app/services/api_client.dart';
import 'package:mikrotik_cards_app/models/subscription_plan_model.dart';

class MockUrlLauncher extends Fake
    with MockPlatformInterfaceMixin
    implements UrlLauncherPlatform {
  @override
  Future<bool> canLaunch(String url) async => true;
  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async => true;
}

http.Response utf8Response(Map<String, dynamic> data, int statusCode) {
  return http.Response.bytes(
    utf8.encode(jsonEncode(data)),
    statusCode,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

void main() {
  late MockUrlLauncher mockLauncher;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    mockLauncher = MockUrlLauncher();
    UrlLauncherPlatform.instance = mockLauncher;
    ApiClient.resetClient();
    ApiClient.setAuthToken('test-valid-token');
  });

  tearDown(() {
    ApiClient.resetClient();
  });

  Map<String, dynamic> mockUserProfileResponse() {
    return {
      'success': true,
      'data': {
        'id': 'user-101',
        'username': 'network_admin',
        'fullName': 'عبدالله محمد الطيب',
        'email': 'abdallah@jalsah.sd',
        'role': 'TENANT_ADMIN',
        'networkName': 'شبكة الروابي',
        'status': 'ACTIVE',
      },
    };
  }

  Map<String, dynamic> mockSubscriptionStatusResponse() {
    return {
      'success': true,
      'data': {
        'tenantId': 'tenant-101',
        'isTrial': false,
        'isActive': true,
        'planName': 'الباقة الاحترافية',
        'daysRemaining': 25,
      },
    };
  }

  group('SubscriptionRequestModel Type Safety Tests in UserProfileScreen', () {
    testWidgets('1. Empty list: UserProfileScreen loads and renders empty state without casting error', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      ApiClient.client = MockClient((request) async {
        final path = request.url.path;
        if (path.contains('/auth/profile') || path.contains('/user/profile')) {
          return utf8Response(mockUserProfileResponse(), 200);
        }
        if (path.contains('/subscription/status')) {
          return utf8Response(mockSubscriptionStatusResponse(), 200);
        }
        if (path.contains('/subscription/my-requests')) {
          return utf8Response({
            'success': true,
            'data': [], // Empty list
          }, 200);
        }
        return utf8Response({'success': true, 'data': {}}, 200);
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: UserProfileScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Verify no exception was thrown during data loading
      expect(tester.takeException(), isNull);

      // Verify empty requests placeholder is shown
      expect(find.text('لا توجد طلبات سابقة لتنشيط الحساب.'), findsOneWidget);
    });

    testWidgets('2. Single request: UserProfileScreen parses SubscriptionRequestModel without type error', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // Backend returns one subscription request
      ApiClient.client = MockClient((request) async {
        final path = request.url.path;
        if (path.contains('/auth/profile') || path.contains('/user/profile')) {
          return utf8Response(mockUserProfileResponse(), 200);
        }
        if (path.contains('/subscription/status')) {
          return utf8Response(mockSubscriptionStatusResponse(), 200);
        }
        if (path.contains('/subscription/my-requests')) {
          return utf8Response({
            'success': true,
            'data': [
              {
                'id': 'req-sub-99',
                'status': 'PENDING',
                'planName': 'باقة النخبة السنوية',
                'price': 150000.0,
                'currency': 'SDG',
                'durationDays': 365,
                'createdAt': '2026-10-29T10:00:00.000Z',
              }
            ],
          }, 200);
        }
        return utf8Response({'success': true, 'data': {}}, 200);
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: UserProfileScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Verify that NO type 'SubscriptionRequestModel' is not a subtype of type 'Map<String, dynamic>' occurred
      expect(tester.takeException(), isNull);

      // Verify the request details are displayed accurately on screen with formatted price
      expect(find.text('باقة النخبة السنوية'), findsOneWidget);
      expect(find.text('150000 SDG'), findsOneWidget);
      expect(find.text('قيد المراجعة'), findsOneWidget);
      expect(find.text('إلغاء'), findsOneWidget);
    });

    testWidgets('3. Handles priceSnapshot and currencySnapshot correctly and renders 50 USD without .0', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      ApiClient.client = MockClient((request) async {
        final path = request.url.path;
        if (path.contains('/auth/profile') || path.contains('/user/profile')) {
          return utf8Response(mockUserProfileResponse(), 200);
        }
        if (path.contains('/subscription/status')) {
          return utf8Response(mockSubscriptionStatusResponse(), 200);
        }
        if (path.contains('/subscription/my-requests')) {
          return utf8Response({
            'success': true,
            'data': [
              {
                'id': 'req-snap-101',
                'status': 'PENDING',
                'priceSnapshot': 50,
                'currencySnapshot': 'USD',
                'durationDaysSnapshot': 30,
                'plan': {
                  'id': 'p-1',
                  'name': 'باقة رواد الأعمال',
                  'price': 60,
                  'currency': 'SDG',
                },
                'createdAt': '2026-10-29T10:00:00.000Z',
              }
            ],
          }, 200);
        }
        return utf8Response({'success': true, 'data': {}}, 200);
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: UserProfileScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      // Verify plan name from plan['name']
      expect(find.text('باقة رواد الأعمال'), findsOneWidget);

      // Verify priceSnapshot (50) and currencySnapshot ('USD') rendered cleanly as '50 USD'
      expect(find.text('50 USD'), findsOneWidget);
      expect(find.text('50.0 USD'), findsNothing);
    });

    testWidgets('4. Error response: UserProfileScreen handles backend error gracefully without crash', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      ApiClient.client = MockClient((request) async {
        final path = request.url.path;
        if (path.contains('/auth/profile') || path.contains('/user/profile')) {
          return utf8Response(mockUserProfileResponse(), 200);
        }
        if (path.contains('/subscription/status')) {
          return utf8Response(mockSubscriptionStatusResponse(), 200);
        }
        if (path.contains('/subscription/my-requests')) {
          return utf8Response({
            'success': false,
            'errorCode': 'DATABASE_ERROR',
            'errorMessage': 'فشل جلب طلبات الاشتراك من الخادم',
          }, 500);
        }
        return utf8Response({'success': true, 'data': {}}, 200);
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: UserProfileScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Verify screen did not crash and no unhandled exception occurred
      expect(tester.takeException(), isNull);

      // Since requests failed, empty list placeholder is shown gracefully
      expect(find.text('لا توجد طلبات سابقة لتنشيط الحساب.'), findsOneWidget);
    });

    test('5. Model unit test: SubscriptionRequestModel.fromJson parses snapshots, fallbacks and formats price', () {
      // Case A: Full snapshots matching Prisma schema
      final jsonA = {
        'id': 'r-1',
        'status': 'PENDING',
        'priceSnapshot': 50,
        'currencySnapshot': 'USD',
        'durationDaysSnapshot': 30,
        'plan': {
          'name': 'باقة النيل',
        },
      };
      final modelA = SubscriptionRequestModel.fromJson(jsonA);
      expect(modelA.planName, equals('باقة النيل'));
      expect(modelA.price, equals(50.0));
      expect(modelA.currency, equals('USD'));
      expect(modelA.formattedPrice, equals('50'));

      // Case B: Fallback to plan.price and plan.currency
      final jsonB = {
        'id': 'r-2',
        'status': 'APPROVED',
        'plan': {
          'name': 'باقة الفايبر',
          'price': 75.5,
          'currency': 'EUR',
        },
      };
      final modelB = SubscriptionRequestModel.fromJson(jsonB);
      expect(modelB.planName, equals('باقة الفايبر'));
      expect(modelB.price, equals(75.5));
      expect(modelB.currency, equals('EUR'));
      expect(modelB.formattedPrice, equals('75.5'));

      // Case C: Missing all plan details -> safe defaults
      final jsonC = <String, dynamic>{
        'id': 'r-3',
        'status': 'REJECTED',
      };
      final modelC = SubscriptionRequestModel.fromJson(jsonC);
      expect(modelC.planName, equals('باقة اشتراك'));
      expect(modelC.price, equals(0.0));
      expect(modelC.currency, equals('USD'));
      expect(modelC.formattedPrice, equals('0'));
    });
  });
}
