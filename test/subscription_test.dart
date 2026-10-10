// ============================================================================
// Platform: Commercial MikroTik Network & HotSpot Card Management System
// File: test/subscription_test.dart
// Unit & Widget Tests: Subscription & Licensing System (Rule 19, Rule 27)
// ============================================================================

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:mikrotik_cards_app/models/subscription_status_model.dart';
import 'package:mikrotik_cards_app/screens/dashboard_screen.dart';
import 'package:mikrotik_cards_app/services/api_client.dart';

http.Response utf8Response(Map<String, dynamic> data, int statusCode) {
  return http.Response.bytes(
    utf8.encode(jsonEncode(data)),
    statusCode,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    GoogleFonts.config.allowRuntimeFetching = false;

    try {
      final fontLoaderCairo = FontLoader('Cairo');
      final arabicFontBytes =
          File('/system/fonts/NotoNaskhArabicUI-Regular.ttf').readAsBytesSync();
      fontLoaderCairo
          .addFont(Future.value(ByteData.sublistView(arabicFontBytes)));

      final robotoBytes = File(
              '/data/data/com.termux/files/home/flutter/bin/cache/dart-sdk/bin/resources/devtools/assets/fonts/Roboto/Roboto-Regular.ttf')
          .readAsBytesSync();
      fontLoaderCairo.addFont(Future.value(ByteData.sublistView(robotoBytes)));
      await fontLoaderCairo.load();

      final iconLoader = FontLoader('MaterialIcons');
      final iconBytes = File(
              '/data/data/com.termux/files/home/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf')
          .readAsBytesSync();
      iconLoader.addFont(Future.value(ByteData.sublistView(iconBytes)));
      await iconLoader.load();
    } catch (_) {}
  });

  tearDown(() {
    ApiClient.resetClient();
  });

  group('SubscriptionStatusModel Tests', () {
    test('parses TRIAL status json correctly', () {
      final json = {
        'subscriptionStatus': 'TRIAL',
        'trialEndsAt': '2026-10-14T03:55:00.000Z',
        'daysRemaining': 7,
        'planName': null,
        'currentRoutersCount': 2,
        'maxRoutersLimit': 5,
      };

      final model = SubscriptionStatusModel.fromJson(json);

      expect(model.subscriptionStatus, equals('TRIAL'));
      expect(model.isTrial, isTrue);
      expect(model.isActive, isFalse);
      expect(model.isExpired, isFalse);
      expect(model.isBlocked, isFalse);
      expect(model.daysRemaining, equals(7));
      expect(model.currentRoutersCount, equals(2));
      expect(model.maxRoutersLimit, equals(5));
      expect(model.planName, isNull);
      expect(model.trialEndsAt, isNotNull);
    });

    test('parses EXPIRED status json correctly', () {
      final json = {
        'subscriptionStatus': 'EXPIRED',
        'trialEndsAt': '2026-10-01T00:00:00.000Z',
        'daysRemaining': 0,
        'planName': null,
        'currentRoutersCount': 3,
        'maxRoutersLimit': 5,
      };

      final model = SubscriptionStatusModel.fromJson(json);

      expect(model.subscriptionStatus, equals('EXPIRED'));
      expect(model.isTrial, isFalse);
      expect(model.isExpired, isTrue);
      expect(model.isBlocked, isTrue);
      expect(model.daysRemaining, equals(0));
    });

    test('parses ACTIVE status json correctly', () {
      final json = {
        'subscriptionStatus': 'ACTIVE',
        'trialEndsAt': null,
        'daysRemaining': 30,
        'planName': 'Professional',
        'currentRoutersCount': 5,
        'maxRoutersLimit': 20,
      };

      final model = SubscriptionStatusModel.fromJson(json);

      expect(model.subscriptionStatus, equals('ACTIVE'));
      expect(model.isActive, isTrue);
      expect(model.isTrial, isFalse);
      expect(model.isBlocked, isFalse);
      expect(model.planName, equals('Professional'));
    });
  });

  group('ApiClient.getSubscriptionStatus Tests', () {
    test('returns subscription model on HTTP 200', () async {
      ApiClient.client = MockClient((request) async {
        expect(request.url.path, equals('/api/v1/subscription/status'));
        return utf8Response({
          'success': true,
          'data': {
            'subscriptionStatus': 'TRIAL',
            'trialEndsAt': '2026-10-14T03:55:00.000Z',
            'daysRemaining': 5,
            'planName': null,
            'currentRoutersCount': 1,
            'maxRoutersLimit': 5,
          },
        }, 200);
      });

      final result = await ApiClient.getSubscriptionStatus();

      expect(result['success'], isTrue);
      expect(result['data'], isA<SubscriptionStatusModel>());
      final model = result['data'] as SubscriptionStatusModel;
      expect(model.daysRemaining, equals(5));
      expect(model.subscriptionStatus, equals('TRIAL'));
    });

    test('handles 401 unauthorized gracefully', () async {
      ApiClient.client = MockClient((request) async {
        return utf8Response({
          'success': false,
          'errorCode': 'UNAUTHORIZED',
          'errorMessage': 'جلسة غير صالحة',
        }, 401);
      });

      final result = await ApiClient.getSubscriptionStatus();

      expect(result['success'], isFalse);
      expect(result['errorCode'], equals('UNAUTHORIZED'));
    });
  });

  group('DashboardScreen Subscription UI Tests', () {
    testWidgets('renders trial banner strip when subscription is TRIAL (> 2 days)',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      ApiClient.client = MockClient((request) async {
        if (request.url.path.contains('subscription/status')) {
          return utf8Response({
            'success': true,
            'data': {
              'subscriptionStatus': 'TRIAL',
              'trialEndsAt': '2026-10-14T03:55:00.000Z',
              'daysRemaining': 6,
              'planName': null,
              'currentRoutersCount': 0,
              'maxRoutersLimit': 5,
            },
          }, 200);
        }
        if (request.url.path.contains('today-sales')) {
          return utf8Response({
            'success': true,
            'data': {'todayTotal': 0.0},
          }, 200);
        }
        return utf8Response({
          'success': true,
          'data': [],
        }, 200);
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: DashboardScreen(),
        ),
      );
      for (int i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.text('باقي 6 أيام من فترتك التجريبية'), findsOneWidget);
      expect(find.text('فترة تجريبية'), findsOneWidget);
      expect(find.text('أجهزة الراوتر والشبكات'), findsOneWidget);
    });

    testWidgets('renders warning red trial banner strip when daysRemaining <= 2',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      ApiClient.client = MockClient((request) async {
        if (request.url.path.contains('subscription/status')) {
          return utf8Response({
            'success': true,
            'data': {
              'subscriptionStatus': 'TRIAL',
              'trialEndsAt': '2026-10-09T03:55:00.000Z',
              'daysRemaining': 2,
              'planName': null,
              'currentRoutersCount': 0,
              'maxRoutersLimit': 5,
            },
          }, 200);
        }
        if (request.url.path.contains('today-sales')) {
          return utf8Response({
            'success': true,
            'data': {'todayTotal': 0.0},
          }, 200);
        }
        return utf8Response({
          'success': true,
          'data': [],
        }, 200);
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: DashboardScreen(),
        ),
      );
      for (int i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.text('باقي 2 أيام من فترتك التجريبية'), findsOneWidget);
      expect(find.text('فترة تجريبية'), findsOneWidget);
    });

    testWidgets('renders full-screen blocking view when subscription is EXPIRED',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      ApiClient.client = MockClient((request) async {
        if (request.url.path.contains('subscription/status')) {
          return utf8Response({
            'success': true,
            'data': {
              'subscriptionStatus': 'EXPIRED',
              'trialEndsAt': '2026-10-01T00:00:00.000Z',
              'daysRemaining': 0,
              'planName': null,
              'currentRoutersCount': 2,
              'maxRoutersLimit': 5,
            },
          }, 200);
        }
        // Backend returns 402 for protected routes
        return utf8Response({
          'success': false,
          'errorCode': 'SUBSCRIPTION_EXPIRED',
          'errorMessage': 'انتهت الفترة التجريبية، يرجى التواصل للاشتراك',
        }, 402);
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: DashboardScreen(),
        ),
      );
      for (int i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Blocking screen must be visible
      expect(find.text('انتهت فترتك التجريبية'), findsOneWidget);
      expect(find.textContaining('SOFT ZONE'), findsOneWidget);
      expect(find.textContaining('0115715672'), findsOneWidget);
      expect(find.text('التحقق من حالة الاشتراك'), findsOneWidget);
      expect(find.text('تسجيل الخروج'), findsOneWidget);

      // Main dashboard content should be blocked / hidden
      expect(find.text('أجهزة الراوتر والشبكات'), findsNothing);
    });
  });
}
