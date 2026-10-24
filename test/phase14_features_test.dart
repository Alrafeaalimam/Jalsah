// ============================================================================
// Platform: Commercial MikroTik Network & HotSpot Card Management System (Jalsah)
// File: test/phase14_features_test.dart
// Tests: Phase 14 UI/UX, BounceButton, SubscriptionPlans, Numbers-Only Cards & Trial Lock
// ============================================================================

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:mikrotik_cards_app/models/card_model.dart';
import 'package:mikrotik_cards_app/screens/generate_cards_screen.dart';
import 'package:mikrotik_cards_app/screens/subscription_plans_screen.dart';
import 'package:mikrotik_cards_app/services/api_client.dart';
import 'package:mikrotik_cards_app/widgets/bounce_button.dart';
import 'package:mikrotik_cards_app/widgets/card_voucher_widget.dart';

http.Response _jsonResponse(dynamic body, int statusCode) {
  return http.Response(
    jsonEncode(body),
    statusCode,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    ApiClient.resetClient();
    ApiClient.setAuthToken('test-phase14-token');
  });

  tearDown(() {
    ApiClient.resetClient();
  });

  group('Phase 14: BounceButton Micro-interactive Widget Tests', () {
    testWidgets('renders BounceButton label, icon, and responds to taps', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: BounceButton(
                label: 'زر تجريبي',
                icon: Icons.check,
                onPressed: () {
                  tapped = true;
                },
              ),
            ),
          ),
        ),
      );

      expect(find.text('زر تجريبي'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsOneWidget);

      await tester.tap(find.text('زر تجريبي'));
      await tester.pump();
      expect(tapped, isTrue);
    });

    testWidgets('BounceButton shows progress indicator when isLoading is true and ignores taps', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: BounceButton(
                label: 'زر التحميل',
                isLoading: true,
                onPressed: () {
                  tapped = true;
                },
              ),
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('زر التحميل'), findsNothing);

      await tester.tap(find.byType(BounceButton));
      await tester.pump();
      expect(tapped, isFalse);
    });
  });

  group('Phase 14: Numbers-Only Card Voucher Display Tests', () {
    testWidgets('CardVoucherWidget in numbers-only mode shows single voucher code without PIN row', (tester) async {
      final card = CardModel(
        id: 'card-123',
        batchId: 'batch-456',
        username: '984728194',
        password: '', // Numbers-only mode has empty password
        price: 50.0,
        status: 'AVAILABLE',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: CardVoucherWidget(
                card: card,
                packageName: 'باقة جلسة الفاخرة',
              ),
            ),
          ),
        ),
      );

      // Verify username/code is rendered
      expect(find.text('984728194'), findsOneWidget);
      // Verify label specifies voucher/card code
      expect(find.text('رقم الكرت / Voucher Code'), findsOneWidget);
      // Verify password row is NOT rendered
      expect(find.text('كلمة المرور / PIN'), findsNothing);
    });
  });

  group('Phase 14: SubscriptionPlansScreen Tests', () {
    testWidgets('loads and renders subscription plans, status banner, and submits activation request', (tester) async {
      ApiClient.client = MockClient((request) async {
        if (request.url.path.contains('/subscription/plans')) {
          return _jsonResponse({
            'success': true,
            'data': [
              {
                'id': 'plan-1m',
                'name': 'باقة الشهر الواحد',
                'durationDays': 30,
                'price': 15.0,
                'currency': 'USD',
                'description': 'اشتراك شهر كامل لجميع الراوترات',
                'maxRoutersLimit': 5,
              },
              {
                'id': 'plan-3m',
                'name': 'باقة 3 أشهر',
                'durationDays': 90,
                'price': 40.0,
                'currency': 'USD',
                'description': 'اشتراك 3 أشهر مع خصم',
                'maxRoutersLimit': 10,
              },
            ],
          }, 200);
        } else if (request.url.path.contains('/subscription/status')) {
          return _jsonResponse({
            'success': true,
            'data': {
              'subscriptionStatus': 'TRIAL',
              'daysRemaining': 5,
              'planName': 'باقة تجريبية',
              'currentRoutersCount': 1,
              'maxRoutersLimit': 5,
            },
          }, 200);
        } else if (request.url.path.contains('/subscription/my-requests')) {
          return _jsonResponse({
            'success': true,
            'data': [],
          }, 200);
        } else if (request.url.path.contains('/subscription/request-activation')) {
          return _jsonResponse({
            'success': true,
            'message': 'تم إرسال طلب التفعيل بنجاح وسيتم مراجعته',
          }, 201);
        }
        return _jsonResponse({}, 404);
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: SubscriptionPlansScreen(openDirectlyForTrialLock: true),
        ),
      );
      await tester.pumpAndSettle();

      // Verify trial warning banner is displayed
      expect(
        find.textContaining('يمكنك استخدام وظائف Jalsah خلال الفترة التجريبية'),
        findsOneWidget,
      );

      // Verify both plans are displayed
      expect(find.text('باقة الشهر الواحد'), findsOneWidget);
      expect(find.text('باقة 3 أشهر'), findsOneWidget);

      // Tap on plan to select it
      await tester.tap(find.text('باقة الشهر الواحد'));
      await tester.pumpAndSettle();

      // Scroll to activation button
      await tester.scrollUntilVisible(find.text('طلب التفعيل والاشتراك'), 200);
      await tester.pumpAndSettle();

      // Submit activation request
      await tester.tap(find.text('طلب التفعيل والاشتراك'));
      await tester.pumpAndSettle();

      // Dialog confirmation appears
      expect(find.text('طلب تفعيل اشتراك Jalsah'), findsOneWidget);
      await tester.tap(find.text('تأكيد وإرسال الطلب'));
      await tester.pumpAndSettle();

      // Snackbar success is shown
      expect(find.text('تم إرسال طلب التفعيل بنجاح وسيتم مراجعته'), findsOneWidget);
    });
  });

  group('Phase 14: GenerateCardsScreen Trial Lock and Mode Toggle Tests', () {
    testWidgets('GenerateCardsScreen renders segment toggle for username/password vs numbers only', (tester) async {
      ApiClient.client = MockClient((request) async {
        if (request.url.path.contains('/routers')) {
          return _jsonResponse({
            'success': true,
            'data': [
              {
                'id': 'r-1',
                'name': 'الراوتر الرئيسي',
                'host': '192.168.88.1',
                'status': 'ONLINE',
              }
            ],
          }, 200);
        } else if (request.url.path.contains('/packages')) {
          return _jsonResponse({
            'success': true,
            'data': [
              {
                'id': 'p-1',
                'name': 'باقة 1 ساعة',
                'price': 100.0,
                'currency': 'SDG',
              }
            ],
          }, 200);
        } else if (request.url.path.contains('/subscription/status')) {
          return _jsonResponse({
            'success': true,
            'data': {
              'subscriptionStatus': 'ACTIVE',
              'daysRemaining': 25,
            },
          }, 200);
        }
        return _jsonResponse({}, 404);
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: GenerateCardsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Verify segment mode toggles
      expect(find.text('اسم مستخدم وكلمة مرور'), findsOneWidget);
      expect(find.text('أرقام فقط (بدون كلمة سر)'), findsOneWidget);

      // Switch to numbers-only mode
      await tester.tap(find.text('أرقام فقط (بدون كلمة سر)'));
      await tester.pumpAndSettle();

      // Verify toggle selected state
      expect(find.text('أرقام فقط (بدون كلمة سر)'), findsOneWidget);
    });
  });
}
