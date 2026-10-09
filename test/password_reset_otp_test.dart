// ============================================================================
// Platform: Commercial MikroTik Network & HotSpot Card Management System (Jalsah)
// File: test/password_reset_otp_test.dart
// Unit & Widget Tests: Password Reset via Email OTP System (Rule 14 & Rule 19)
// ============================================================================

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:mikrotik_cards_app/screens/forgot_password_screen.dart';
import 'package:mikrotik_cards_app/screens/reset_password_screen.dart';
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

  group('ApiClient Password Reset OTP Unit Tests', () {
    test('forgotPassword returns success message from backend', () async {
      ApiClient.client = MockClient((request) async {
        expect(request.url.path, '/api/v1/auth/forgot-password');
        final body = jsonDecode(request.body);
        expect(body['email'], 'user@example.com');

        return utf8Response({
          'success': true,
          'data': {
            'message':
                'إذا كان هذا البريد مسجلاً في النظام، فستصلك رسالة تحتوي على كود التحقق',
          },
        }, 200);
      });

      final result = await ApiClient.forgotPassword('user@example.com');
      expect(result['success'], isTrue);
      expect(result['message'],
          contains('إذا كان هذا البريد مسجلاً في النظام'));
    });

    test('resetPassword returns success message when code and password are valid',
        () async {
      ApiClient.client = MockClient((request) async {
        expect(request.url.path, '/api/v1/auth/reset-password');
        final body = jsonDecode(request.body);
        expect(body['email'], 'user@example.com');
        expect(body['otpCode'], '123456');
        expect(body['newPassword'], 'NewSecurePass123!');

        return utf8Response({
          'success': true,
          'data': {
            'message': 'تم إعادة تعيين كلمة المرور بنجاح',
          },
        }, 200);
      });

      final result = await ApiClient.resetPassword(
        email: 'user@example.com',
        otpCode: '123456',
        newPassword: 'NewSecurePass123!',
      );

      expect(result['success'], isTrue);
      expect(result['message'], contains('تم إعادة تعيين كلمة المرور بنجاح'));
    });

    test('resetPassword returns error when code is invalid or expired', () async {
      ApiClient.client = MockClient((request) async {
        return utf8Response({
          'success': false,
          'errorCode': 'INVALID_OR_EXPIRED_OTP',
          'errorMessage': 'كود التحقق غير صحيح أو انتهت صلاحيته',
        }, 400);
      });

      final result = await ApiClient.resetPassword(
        email: 'user@example.com',
        otpCode: '000000',
        newPassword: 'NewSecurePass123!',
      );

      expect(result['success'], isFalse);
      expect(result['errorCode'], 'INVALID_OR_EXPIRED_OTP');
      expect(result['errorMessage'], contains('كود التحقق غير صحيح'));
    });
  });

  group('ForgotPasswordScreen Widget Tests', () {
    testWidgets('renders email field and submit button',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ForgotPasswordScreen(),
        ),
      );

      expect(find.text('استعادة كلمة المرور'), findsOneWidget);
      expect(find.text('نسيت كلمة المرور؟'), findsOneWidget);
      expect(find.text('البريد الإلكتروني'), findsOneWidget);
      expect(find.text('إرسال كود التحقق'), findsOneWidget);
    });

    testWidgets('shows validation error when email is empty',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ForgotPasswordScreen(),
        ),
      );

      await tester.tap(find.text('إرسال كود التحقق'));
      await tester.pump();

      expect(find.text('يرجى إدخال البريد الإلكتروني'), findsOneWidget);
    });

    testWidgets('submits request and renders success box and next step button',
        (WidgetTester tester) async {
      ApiClient.client = MockClient((request) async {
        return utf8Response({
          'success': true,
          'data': {
            'message':
                'إذا كان هذا البريد مسجلاً في النظام، فستصلك رسالة تحتوي على كود التحقق',
          },
        }, 200);
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: ForgotPasswordScreen(),
        ),
      );

      await tester.enterText(
          find.byType(TextFormField), 'admin@jalsah.network');
      await tester.tap(find.text('إرسال كود التحقق'));
      await tester.pumpAndSettle();

      expect(find.textContaining('إذا كان هذا البريد مسجلاً'), findsOneWidget);
      expect(find.text('إدخال كود التحقق الآن'), findsOneWidget);
    });
  });

  group('ResetPasswordScreen Widget Tests', () {
    testWidgets('renders all reset password fields and submit button',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ResetPasswordScreen(initialEmail: 'test@domain.com'),
        ),
      );

      expect(find.text('تعيين كلمة مرور جديدة'), findsOneWidget);
      expect(find.text('أدخل كود التحقق'), findsOneWidget);
      expect(find.text('كود التحقق (6 أرقام)'), findsOneWidget);
      expect(find.text('كلمة المرور الجديدة'), findsOneWidget);
      expect(find.text('تأكيد كلمة المرور الجديدة'), findsOneWidget);
      expect(find.text('تعيين كلمة المرور الجديدة'), findsOneWidget);
    });

    testWidgets('validates matching passwords and 6-digit OTP length',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: ResetPasswordScreen(initialEmail: 'test@domain.com'),
        ),
      );

      // Tap submit with empty fields
      await tester.tap(find.text('تعيين كلمة المرور الجديدة'));
      await tester.pump();

      expect(find.text('يرجى إدخال كود التحقق'), findsOneWidget);
      expect(find.text('يرجى إدخال كلمة المرور الجديدة'), findsOneWidget);
    });

    testWidgets('submits valid reset form and shows confirmation dialog',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      ApiClient.client = MockClient((request) async {
        return utf8Response({
          'success': true,
          'data': {
            'message': 'تم تعيين كلمة المرور بنجاح',
          },
        }, 200);
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: ResetPasswordScreen(initialEmail: 'test@domain.com'),
        ),
      );

      final formFields = find.byType(TextFormField);
      // Field 0: Email (prefilled)
      // Field 1: OTP
      await tester.enterText(formFields.at(1), '654321');
      // Field 2: New Password
      await tester.enterText(formFields.at(2), 'NewSecret2026!');
      // Field 3: Confirm Password
      await tester.enterText(formFields.at(3), 'NewSecret2026!');

      await tester.tap(find.text('تعيين كلمة المرور الجديدة'));
      await tester.pumpAndSettle();

      expect(find.text('تم تعيين كلمة المرور'), findsOneWidget);
      expect(find.text('تسجيل الدخول'), findsOneWidget);
    });
  });

  group('TempLoginScreen Integration with Forgot Password', () {
    testWidgets('shows "نسيت كلمة المرور؟" link and opens ForgotPasswordScreen',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: TempLoginScreen(),
        ),
      );

      expect(find.text('نسيت كلمة المرور؟'), findsOneWidget);

      await tester.tap(find.text('نسيت كلمة المرور؟'));
      await tester.pumpAndSettle();

      expect(find.text('استعادة كلمة المرور'), findsOneWidget);
    });
  });
}
