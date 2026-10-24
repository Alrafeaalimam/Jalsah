// ============================================================================
// Platform: Commercial MikroTik Network & HotSpot Card Management System
// File: test/auth_test.dart
// Unit & Widget Tests: Temporary Login Flow & Unauthorized Auto-Redirect
// Master Reference: Rule 14 (Security), Rule 19 (Auth), Rule 23 (Errors)
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

import 'package:mikrotik_cards_app/main.dart';
import 'package:mikrotik_cards_app/screens/dashboard_screen.dart';
import 'package:mikrotik_cards_app/screens/temp_login_screen.dart';
import 'package:mikrotik_cards_app/services/api_client.dart';
import 'package:mikrotik_cards_app/widgets/neumorphic_text_field.dart';

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

  group('TempLoginScreen Widget Tests', () {
    testWidgets('renders username field, password field, and login button',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: TempLoginScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('تسجيل الدخول'), findsWidgets);
      expect(find.text('اسم المستخدم أو البريد الإلكتروني'), findsOneWidget);
      expect(find.text('كلمة المرور'), findsOneWidget);
      expect(find.byType(NeumorphicTextField), findsNWidgets(2));
      expect(find.byIcon(Icons.login_rounded), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets('validates empty inputs and displays error message',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: TempLoginScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Tap login without filling fields
      await tester.tap(find.byIcon(Icons.login_rounded));
      await tester.pump();

      expect(find.text('يرجى إدخال اسم المستخدم وكلمة المرور'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets('shows error banner on failed login response',
        (WidgetTester tester) async {
      ApiClient.client = MockClient((request) async {
        return utf8Response({
          'success': false,
          'errorCode': 'INVALID_CREDENTIALS',
          'errorMessage': 'بيانات الدخول غير صحيحة',
        }, 401);
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: TempLoginScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Enter wrong credentials
      await tester.enterText(
        find.widgetWithText(NeumorphicTextField, 'اسم المستخدم أو البريد الإلكتروني'),
        'admin',
      );
      await tester.enterText(
        find.widgetWithText(NeumorphicTextField, 'كلمة المرور'),
        'wrongPass',
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.login_rounded));
      await tester.pumpAndSettle();

      expect(find.text('بيانات الدخول غير صحيحة'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets('navigates to DashboardScreen on successful login',
        (WidgetTester tester) async {
      ApiClient.client = MockClient((request) async {
        if (request.url.path.contains('/auth/login')) {
          return utf8Response({
            'success': true,
            'data': {
              'token': 'test_jwt_token_123',
              'user': {
                'id': 'u-1',
                'username': 'admin',
                'fullName': 'مدير النظام',
                'role': 'TENANT_ADMIN',
                'tenantId': 't-1',
              },
            },
          }, 200);
        } else if (request.url.path.contains('/routers')) {
          return utf8Response({
            'success': true,
            'data': [],
          }, 200);
        } else if (request.url.path.contains('/sales/today-total')) {
          return utf8Response({
            'success': true,
            'data': {'todayTotal': 0.0, 'totalAmount': 0.0},
          }, 200);
        }
        return utf8Response({}, 404);
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: TempLoginScreen(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(NeumorphicTextField, 'اسم المستخدم أو البريد الإلكتروني'),
        'admin',
      );
      await tester.enterText(
        find.widgetWithText(NeumorphicTextField, 'كلمة المرور'),
        'correctPassword',
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.login_rounded));
      await tester.pumpAndSettle();

      // Should have navigated to DashboardScreen with user's name
      expect(find.byType(DashboardScreen), findsOneWidget);
      expect(find.text('مدير النظام'), findsOneWidget);
      expect(ApiClient.authToken, equals('test_jwt_token_123'));

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets('handles slow login (35s) by keeping loading state active and times out after 60s with real error banner',
        (WidgetTester tester) async {
      int loginRequestCount = 0;
      ApiClient.client = MockClient((request) async {
        if (request.url.path.contains('/auth/login')) {
          loginRequestCount++;
          // First attempt hangs for 70s to trigger actual 60s TimeoutException
          if (loginRequestCount == 1) {
            await Future<void>.delayed(const Duration(seconds: 70));
            return utf8Response({'success': true, 'data': {}}, 200);
          }
          // Second attempt takes 35s (>25s, <60s) and succeeds
          await Future<void>.delayed(const Duration(seconds: 35));
          return utf8Response({
            'success': true,
            'data': {
              'token': 'slow_jwt_token_60s',
              'user': {
                'id': 'u-1',
                'username': 'admin',
                'fullName': 'مدير النظام',
                'role': 'TENANT_ADMIN',
                'tenantId': 't-1',
              },
            },
          }, 200);
        }
        return utf8Response({'success': true, 'data': []}, 200);
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: TempLoginScreen(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(NeumorphicTextField, 'اسم المستخدم أو البريد الإلكتروني'),
        'admin',
      );
      await tester.enterText(
        find.widgetWithText(NeumorphicTextField, 'كلمة المرور'),
        'somePass',
      );
      await tester.pump();

      // Trigger 1st login attempt (will hang >60s)
      await tester.tap(find.byIcon(Icons.login_rounded));
      await tester.pump(const Duration(seconds: 30));

      // At 30s: still loading, indicator & waiting text visible, duplicate tap ignored
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('جاري تسجيل الدخول...'), findsOneWidget);
      expect(
        find.text('يرجى الانتظار، جاري الاتصال بالخادم والتحقق من البيانات...'),
        findsOneWidget,
      );
      await tester.tap(find.text('جاري تسجيل الدخول...'));
      expect(loginRequestCount, equals(1));

      // Advance past 60s timeout
      await tester.pump(const Duration(seconds: 31));
      await tester.pumpAndSettle();

      // Loading indicator dismissed and real 60s timeout error message displayed
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(
        find.text('انتهت مهلة الاتصال بالخادم (60 ثانية). يرجى التأكد من استجابة السيرفر.'),
        findsOneWidget,
      );
      // Advance remaining 10s so the first MockClient delayed timer finishes cleanly
      await tester.pump(const Duration(seconds: 10));

      // Trigger 2nd login attempt (takes 35s and succeeds)
      await tester.tap(find.byIcon(Icons.login_rounded));
      await tester.pump(const Duration(seconds: 30));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();

      expect(find.byType(DashboardScreen), findsOneWidget);
      expect(ApiClient.authToken, equals('slow_jwt_token_60s'));

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  });

  group('DashboardScreen 401 UNAUTHORIZED Redirection Tests', () {
    testWidgets('redirects to TempLoginScreen on 401 from getRouters',
        (WidgetTester tester) async {
      ApiClient.setAuthToken('expired_or_invalid_token');

      ApiClient.client = MockClient((request) async {
        if (request.url.path.contains('/routers')) {
          return utf8Response({
            'success': false,
            'errorCode': 'UNAUTHORIZED',
            'errorMessage': 'رمز المصادقة منتهي الصلاحية أو غير صالح',
          }, 401);
        }
        if (request.url.path.contains('/sales/today-total')) {
          return utf8Response({
            'success': true,
            'data': {'todayTotal': 0.0},
          }, 200);
        }
        return utf8Response({}, 404);
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: DashboardScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Should automatically redirect to TempLoginScreen
      expect(find.byType(TempLoginScreen), findsOneWidget);
      expect(find.text('تسجيل الدخول'), findsWidgets);
      expect(ApiClient.authToken, isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets('redirects to TempLoginScreen on 401 from getTodaySalesTotal',
        (WidgetTester tester) async {
      ApiClient.setAuthToken('expired_or_invalid_token');

      ApiClient.client = MockClient((request) async {
        if (request.url.path.contains('/routers')) {
          return utf8Response({
            'success': true,
            'data': [],
          }, 200);
        }
        if (request.url.path.contains('/sales/today-total')) {
          return utf8Response({
            'success': false,
            'errorCode': 'UNAUTHORIZED',
            'errorMessage': 'رمز المصادقة منتهي الصلاحية أو غير صالح',
          }, 401);
        }
        return utf8Response({}, 404);
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: DashboardScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Should automatically redirect to TempLoginScreen
      expect(find.byType(TempLoginScreen), findsOneWidget);
      expect(ApiClient.authToken, isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  });

  group('MikrotikCardsApp Initial Route Tests', () {
    testWidgets('renders TempLoginScreen when no initial token exists',
        (WidgetTester tester) async {
      ApiClient.resetClient();

      await tester.pumpWidget(
        const MikrotikCardsApp(initialToken: null, showSplash: false),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TempLoginScreen), findsOneWidget);
      expect(find.byType(DashboardScreen), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets('renders DashboardScreen directly when valid token exists',
        (WidgetTester tester) async {
      ApiClient.client = MockClient((request) async {
        if (request.url.path.contains('/routers')) {
          return utf8Response({'success': true, 'data': []}, 200);
        }
        if (request.url.path.contains('/sales/today-total')) {
          return utf8Response({'success': true, 'data': {'todayTotal': 0.0}}, 200);
        }
        return utf8Response({}, 404);
      });

      await tester.pumpWidget(
        const MikrotikCardsApp(
            initialToken: 'saved_valid_jwt_token', showSplash: false),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DashboardScreen), findsOneWidget);
      expect(find.byType(TempLoginScreen), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  });
}
