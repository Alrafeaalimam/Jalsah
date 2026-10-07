// ============================================================================
// Platform: Commercial MikroTik Network & HotSpot Card Management System
// File: test/register_test.dart
// Unit & Widget Tests: Public Self-Registration for New Tenants & Admins (Rule 19, Rule 32)
// ============================================================================

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mikrotik_cards_app/screens/dashboard_screen.dart';
import 'package:mikrotik_cards_app/screens/register_screen.dart';
import 'package:mikrotik_cards_app/screens/temp_login_screen.dart';
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
    SharedPreferences.setMockInitialValues({});

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

  group('ApiClient.registerTenant Unit Tests', () {
    test('sends registration payload and stores JWT token on HTTP 201',
        () async {
      SharedPreferences.setMockInitialValues({});

      ApiClient.client = MockClient((request) async {
        expect(request.url.path, equals('/api/v1/auth/register'));
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['networkName'], equals('شبكة تجريبية'));
        expect(body['username'], equals('test_owner'));
        expect(body['email'], equals('owner@test.com'));

        return utf8Response({
          'success': true,
          'data': {
            'token': 'mock.jwt.token',
            'tenant': {
              'id': 't-123',
              'name': 'شبكة تجريبية',
              'slug': 'test-slug',
              'subscriptionStatus': 'TRIAL',
              'trialEndsAt': '2026-10-14T00:00:00.000Z',
              'maxRoutersLimit': 2,
            },
            'user': {
              'id': 'u-123',
              'username': 'test_owner',
              'fullName': 'أحمد محمد',
              'role': 'TENANT_ADMIN',
              'tenantId': 't-123',
            },
          },
        }, 201);
      });

      final result = await ApiClient.registerTenant(
        networkName: 'شبكة تجريبية',
        adminFullName: 'أحمد محمد',
        username: 'test_owner',
        email: 'owner@test.com',
        password: 'Password123!',
      );

      expect(result['success'], isTrue);
      expect(ApiClient.authToken, equals('mock.jwt.token'));
      expect(ApiClient.isAuthenticated, isTrue);
    });

    test('handles 409 conflict when username or email is already taken',
        () async {
      ApiClient.client = MockClient((request) async {
        return utf8Response({
          'success': false,
          'errorCode': 'USERNAME_ALREADY_EXISTS',
          'errorMessage': 'اسم المستخدم مستخدم بالفعل، يرجى اختيار اسم آخر',
        }, 409);
      });

      final result = await ApiClient.registerTenant(
        networkName: 'شبكة تجريبية',
        adminFullName: 'أحمد محمد',
        username: 'duplicate_user',
        email: 'owner@test.com',
        password: 'Password123!',
      );

      expect(result['success'], isFalse);
      expect(result['errorCode'], equals('USERNAME_ALREADY_EXISTS'));
      expect(result['errorMessage'], contains('اسم المستخدم مستخدم بالفعل'));
    });
  });

  group('RegisterScreen Widget Tests', () {
    testWidgets('renders all registration form fields and buttons',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: RegisterScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('إنشاء حساب شبكة جديدة'), findsOneWidget);
      expect(find.text('اسم الشبكة / الشركة'), findsOneWidget);
      expect(find.text('الاسم الكامل للمدير'), findsOneWidget);
      expect(find.text('اسم المستخدم (للدخول)'), findsOneWidget);
      expect(find.text('البريد الإلكتروني'), findsOneWidget);
      expect(find.text('كلمة المرور'), findsOneWidget);
      expect(find.text('تأكيد كلمة المرور'), findsOneWidget);
      expect(find.text('إنشاء حساب وبدء التجربة'), findsOneWidget);
      expect(find.text('تسجيل الدخول'), findsOneWidget);
    });

    testWidgets('shows validation error when required fields are empty',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: RegisterScreen(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('إنشاء حساب وبدء التجربة'));
      await tester.pumpAndSettle();

      expect(find.text('يرجى ملء جميع الحقول المطلوبة'), findsOneWidget);
    });

    testWidgets('shows validation error when passwords do not match',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: RegisterScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Enter fields
      await tester.enterText(
          find.widgetWithText(TextField, 'مثلاً: شبكة الأفق اللاسلكية'), 'شبكة الهدى');
      await tester.enterText(
          find.widgetWithText(TextField, 'أدخل اسمك الثلاثي'), 'عثمان علي');
      await tester.enterText(
          find.widgetWithText(TextField, 'أحرف وأرقام بالإنجليزية (مثلاً: ahmed_admin)'),
          'osman_admin');
      await tester.enterText(
          find.widgetWithText(TextField, 'name@example.com'), 'osman@test.com');
      await tester.enterText(
          find.widgetWithText(TextField, '8 أحرف على الأقل'), 'Password123');
      await tester.enterText(
          find.widgetWithText(TextField, 'أعد إدخال كلمة المرور'), 'DifferentPassword123');

      await tester.tap(find.text('إنشاء حساب وبدء التجربة'));
      await tester.pumpAndSettle();

      expect(find.text('كلمتا المرور غير متطابقتين'), findsOneWidget);
    });

    testWidgets('submits registration successfully and navigates to DashboardScreen',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      ApiClient.client = MockClient((request) async {
        if (request.url.path.contains('auth/register')) {
          return utf8Response({
            'success': true,
            'data': {
              'token': 'reg.valid.token',
              'tenant': {
                'id': 'new-t-id',
                'name': 'شبكة الهدى',
                'slug': 'al-huda-123',
                'subscriptionStatus': 'TRIAL',
                'trialEndsAt': '2026-10-14T00:00:00.000Z',
                'maxRoutersLimit': 2,
              },
              'user': {
                'id': 'new-u-id',
                'username': 'osman_admin',
                'fullName': 'عثمان علي',
                'role': 'TENANT_ADMIN',
                'tenantId': 'new-t-id',
              },
            },
          }, 201);
        }
        if (request.url.path.contains('subscription/status')) {
          return utf8Response({
            'success': true,
            'data': {
              'subscriptionStatus': 'TRIAL',
              'trialEndsAt': '2026-10-14T00:00:00.000Z',
              'daysRemaining': 7,
              'planName': null,
              'currentRoutersCount': 0,
              'maxRoutersLimit': 2,
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
          home: RegisterScreen(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
          find.widgetWithText(TextField, 'مثلاً: شبكة الأفق اللاسلكية'), 'شبكة الهدى');
      await tester.enterText(
          find.widgetWithText(TextField, 'أدخل اسمك الثلاثي'), 'عثمان علي');
      await tester.enterText(
          find.widgetWithText(TextField, 'أحرف وأرقام بالإنجليزية (مثلاً: ahmed_admin)'),
          'osman_admin');
      await tester.enterText(
          find.widgetWithText(TextField, 'name@example.com'), 'osman@test.com');
      await tester.enterText(
          find.widgetWithText(TextField, '8 أحرف على الأقل'), 'Password123');
      await tester.enterText(
          find.widgetWithText(TextField, 'أعد إدخال كلمة المرور'), 'Password123');

      await tester.tap(find.text('إنشاء حساب وبدء التجربة'));
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Check transition to DashboardScreen
      expect(find.byType(DashboardScreen), findsOneWidget);
      expect(find.text('أجهزة الراوتر والشبكات'), findsOneWidget);
    });
  });

  group('TempLoginScreen Register Navigation Tests', () {
    testWidgets('shows register link and navigates to RegisterScreen on tap',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: TempLoginScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ليس لديك حساب؟'), findsOneWidget);
      expect(find.text('أنشئ حساباً جديداً'), findsOneWidget);

      await tester.tap(find.text('أنشئ حساباً جديداً'));
      await tester.pumpAndSettle();

      expect(find.byType(RegisterScreen), findsOneWidget);
      expect(find.text('إنشاء حساب شبكة جديدة'), findsOneWidget);
    });
  });
}
