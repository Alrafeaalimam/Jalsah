// ============================================================================
// Platform: Commercial MikroTik Network & HotSpot Card Management System (Jalsah)
// File: test/device_verification_test.dart
// Unit & Widget Tests: New Device Login Verification via OTP (Rule 14 - Security)
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
import 'package:mikrotik_cards_app/screens/admin/super_admin_dashboard.dart';
import 'package:mikrotik_cards_app/screens/temp_login_screen.dart';
import 'package:mikrotik_cards_app/screens/verify_device_otp_screen.dart';
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

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ApiClient.resetClient();
  });

  tearDown(() {
    ApiClient.resetClient();
  });

  group('ApiClient Device Fingerprint & Verification Unit Tests', () {
    test('getDeviceFingerprint generates and persists fingerprint', () async {
      SharedPreferences.setMockInitialValues({});
      ApiClient.resetClient();

      final fp1 = await ApiClient.getDeviceFingerprint();
      expect(fp1, isNotEmpty);
      expect(fp1, startsWith('dev_'));

      // Second call returns identical fingerprint
      final fp2 = await ApiClient.getDeviceFingerprint();
      expect(fp2, equals(fp1));

      // Overriding in memory works
      ApiClient.setDeviceFingerprint('custom_fingerprint_test');
      expect(await ApiClient.getDeviceFingerprint(), equals('custom_fingerprint_test'));
    });

    test('login sends deviceFingerprint and handles requiresDeviceVerification: true', () async {
      ApiClient.setDeviceFingerprint('new_test_device_fp');

      ApiClient.client = MockClient((request) async {
        expect(request.url.path, '/api/v1/auth/login');
        final body = jsonDecode(request.body);
        expect(body['username'], 'admin');
        expect(body['deviceFingerprint'], 'new_test_device_fp');

        return utf8Response({
          'success': true,
          'data': {
            'requiresDeviceVerification': true,
            'tempToken': 'temp_jwt_token_device_otp',
            'emailMasked': 'a***n@jalsah.network',
            'message': 'تم إرسال كود تحقق لبريدك لأن هذا جهاز جديد',
          },
        }, 200);
      });

      final result = await ApiClient.login(
        username: 'admin',
        password: 'Password123!',
      );

      expect(result['success'], isTrue);
      expect(result['requiresDeviceVerification'], isTrue);
      expect(result['tempToken'], equals('temp_jwt_token_device_otp'));
      expect(result['emailMasked'], equals('a***n@jalsah.network'));
      expect(ApiClient.authToken, isNull); // Full JWT token not saved yet
    });

    test('login with trusted device passes directly and saves auth token', () async {
      ApiClient.setDeviceFingerprint('known_trusted_fp');

      ApiClient.client = MockClient((request) async {
        expect(request.url.path, '/api/v1/auth/login');
        return utf8Response({
          'success': true,
          'data': {
            'token': 'full_jwt_token_granted',
            'user': {
              'id': 'u1',
              'username': 'admin',
              'role': 'TENANT_ADMIN',
            },
          },
        }, 200);
      });

      final result = await ApiClient.login(
        username: 'admin',
        password: 'Password123!',
      );

      expect(result['success'], isTrue);
      expect(result['requiresDeviceVerification'], isNull);
      expect(ApiClient.authToken, equals('full_jwt_token_granted'));
    });

    test('verifyDeviceOtp sends payload and saves token upon success', () async {
      ApiClient.client = MockClient((request) async {
        expect(request.url.path, '/api/v1/auth/verify-device-otp');
        final body = jsonDecode(request.body);
        expect(body['tempToken'], 'valid_temp_token');
        expect(body['otpCode'], '654321');
        expect(body['deviceFingerprint'], 'custom_fp');
        expect(body['deviceLabel'], 'My Test Device');

        return utf8Response({
          'success': true,
          'data': {
            'token': 'verified_device_jwt_token',
            'user': {
              'id': 'u1',
              'username': 'admin',
              'role': 'TENANT_ADMIN',
            },
          },
        }, 200);
      });

      final result = await ApiClient.verifyDeviceOtp(
        tempToken: 'valid_temp_token',
        otpCode: '654321',
        deviceFingerprint: 'custom_fp',
        deviceLabel: 'My Test Device',
      );

      expect(result['success'], isTrue);
      expect(ApiClient.authToken, equals('verified_device_jwt_token'));
    });

    test('verifyDeviceOtp returns error message on invalid or expired OTP', () async {
      ApiClient.client = MockClient((request) async {
        expect(request.url.path, '/api/v1/auth/verify-device-otp');
        return utf8Response({
          'success': false,
          'errorCode': 'INVALID_OR_EXPIRED_OTP',
          'errorMessage': 'كود التحقق غير صحيح أو انتهت صلاحيته',
        }, 400);
      });

      final result = await ApiClient.verifyDeviceOtp(
        tempToken: 'valid_temp_token',
        otpCode: '000000',
        deviceFingerprint: 'custom_fp',
      );

      expect(result['success'], isFalse);
      expect(result['errorCode'], equals('INVALID_OR_EXPIRED_OTP'));
      expect(result['errorMessage'], contains('كود التحقق غير صحيح'));
      expect(ApiClient.authToken, isNull);
    });
  });

  group('VerifyDeviceOtpScreen Widget Tests', () {
    testWidgets('renders all screen elements, explanation banner, and masked email',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: VerifyDeviceOtpScreen(
            tempToken: 'mock_temp_token',
            deviceFingerprint: 'fp_123',
            deviceLabel: 'Chrome on Android',
            emailMasked: 'adm***@jalsah.network',
            username: 'admin',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('تأكيد الجهاز الجديد'), findsOneWidget);
      expect(
        find.text('تم إرسال كود تحقق لبريدك لأن هذا جهاز جديد'),
        findsOneWidget,
      );
      expect(
        find.textContaining('adm***@jalsah.network'),
        findsOneWidget,
      );
      expect(
        find.text('صلاحية الكود 10 دقائق فقط للاستخدام لمرة واحدة.'),
        findsOneWidget,
      );
      expect(find.text('كود التحقق (OTP)'), findsOneWidget);
      expect(find.text('تأكيد الجهاز والدخول'), findsOneWidget);
      expect(find.text('العودة لشاشة تسجيل الدخول'), findsOneWidget);
      expect(find.byIcon(Icons.security_rounded), findsOneWidget);
    });

    testWidgets('validates empty or incomplete OTP input',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: VerifyDeviceOtpScreen(
            tempToken: 'mock_temp_token',
            deviceFingerprint: 'fp_123',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap submit with empty field
      await tester.tap(find.text('تأكيد الجهاز والدخول'));
      await tester.pump();
      expect(find.text('يرجى إدخال كود التحقق'), findsOneWidget);

      // Enter fewer than 6 digits
      await tester.enterText(
        find.widgetWithText(NeumorphicTextField, 'كود التحقق (OTP)'),
        '123',
      );
      await tester.tap(find.text('تأكيد الجهاز والدخول'));
      await tester.pump();
      expect(find.text('كود التحقق يجب أن يتكون من 6 أرقام'), findsOneWidget);
    });

    testWidgets('displays error banner when verification fails',
        (WidgetTester tester) async {
      ApiClient.client = MockClient((request) async {
        return utf8Response({
          'success': false,
          'errorCode': 'INVALID_OR_EXPIRED_OTP',
          'errorMessage': 'رمز التحقق غير صحيح أو انتهت صلاحيته',
        }, 400);
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: VerifyDeviceOtpScreen(
            tempToken: 'mock_temp_token',
            deviceFingerprint: 'fp_123',
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(NeumorphicTextField, 'كود التحقق (OTP)'),
        '999999',
      );
      await tester.tap(find.text('تأكيد الجهاز والدخول'));
      await tester.pumpAndSettle();

      expect(find.text('رمز التحقق غير صحيح أو انتهت صلاحيته'), findsOneWidget);
      expect(find.byType(DashboardScreen), findsNothing);
    });

    testWidgets('successfully verifies OTP and navigates to DashboardScreen',
        (WidgetTester tester) async {
      ApiClient.client = MockClient((request) async {
        if (request.url.path.contains('/verify-device-otp')) {
          return utf8Response({
            'success': true,
            'data': {
              'token': 'mock_jwt_verified',
              'user': {
                'id': 'u1',
                'username': 'tenant_user',
                'fullName': 'مدير الشبكة',
                'role': 'TENANT_ADMIN',
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
          home: VerifyDeviceOtpScreen(
            tempToken: 'valid_temp_token',
            deviceFingerprint: 'fp_123',
            emailMasked: 't***@example.com',
            username: 'tenant_user',
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(NeumorphicTextField, 'كود التحقق (OTP)'),
        '123456',
      );
      await tester.tap(find.text('تأكيد الجهاز والدخول'));
      await tester.pumpAndSettle();

      expect(find.byType(DashboardScreen), findsOneWidget);
      expect(find.text('مدير الشبكة'), findsOneWidget);
      expect(ApiClient.authToken, equals('mock_jwt_verified'));

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  });

  group('TempLoginScreen Device Verification Integration Flow', () {
    testWidgets('navigates to VerifyDeviceOtpScreen when requiresDeviceVerification is true',
        (WidgetTester tester) async {
      ApiClient.client = MockClient((request) async {
        if (request.url.path.contains('/auth/login')) {
          return utf8Response({
            'success': true,
            'data': {
              'requiresDeviceVerification': true,
              'tempToken': 'flow_temp_token_123',
              'emailMasked': 'adm***@domain.com',
              'message': 'تم إرسال كود تحقق لبريدك لأن هذا جهاز جديد',
            },
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
        'MySecretPass123',
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.login_rounded));
      await tester.pumpAndSettle();

      // Verify that navigation transferred directly to VerifyDeviceOtpScreen
      expect(find.byType(VerifyDeviceOtpScreen), findsOneWidget);
      expect(find.text('تأكيد الجهاز الجديد'), findsOneWidget);
      expect(
        find.text('تم إرسال كود تحقق لبريدك لأن هذا جهاز جديد'),
        findsOneWidget,
      );
      expect(find.textContaining('adm***@domain.com'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  });
}
