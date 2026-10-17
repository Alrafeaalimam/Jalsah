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
import 'package:mikrotik_cards_app/utils/whatsapp_helper.dart';

class MockUrlLauncher extends Fake
    with MockPlatformInterfaceMixin
    implements UrlLauncherPlatform {
  String? launchedUrl;

  @override
  Future<bool> canLaunch(String url) async => true;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launchedUrl = url;
    return true;
  }
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
    ApiClient.setAuthToken('test-token');
  });

  tearDown(() {
    ApiClient.resetClient();
  });

  group('WhatsApp Number Sanitization & Formatting Tests', () {
    test('sanitizeAndFormatWhatsAppNumber formats Sudanese local numbers', () {
      expect(sanitizeAndFormatWhatsAppNumber('0115715672'), equals('249115715672'));
      expect(sanitizeAndFormatWhatsAppNumber('0115715651'), equals('249115715651'));
      expect(sanitizeAndFormatWhatsAppNumber('0912345678'), equals('249912345678'));
    });

    test('sanitizeAndFormatWhatsAppNumber handles international prefixes', () {
      expect(sanitizeAndFormatWhatsAppNumber('+249115715672'), equals('249115715672'));
      expect(sanitizeAndFormatWhatsAppNumber('00249115715672'), equals('249115715672'));
      expect(sanitizeAndFormatWhatsAppNumber('249115715672'), equals('249115715672'));
    });

    test('sanitizeAndFormatWhatsAppNumber rejects invalid/short numbers', () {
      expect(sanitizeAndFormatWhatsAppNumber(''), isNull);
      expect(sanitizeAndFormatWhatsAppNumber('12345'), isNull);
      expect(sanitizeAndFormatWhatsAppNumber('abc'), isNull);
    });
  });

  group('UserProfileScreen UI & Responsive Tests', () {
    testWidgets('renders all user profile data without overflow on standard screens', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      ApiClient.client = MockClient((request) async {
        return utf8Response({
          'success': true,
          'data': {
            'id': 'u-1',
            'username': 'admin_boss',
            'fullName': 'أحمد محمد علي الطيب',
            'email': 'ahmed.boss@jalsah.sd',
            'role': 'TENANT_ADMIN',
            'networkName': 'شبكة النيل للألياف الضوئية',
            'status': 'ACTIVE',
          },
        }, 200);
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: UserProfileScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('الملف الشخصي'), findsOneWidget);
      expect(find.text('أحمد محمد علي الطيب'), findsWidgets);
      expect(find.text('admin_boss'), findsOneWidget);
      expect(find.text('ahmed.boss@jalsah.sd'), findsOneWidget);
      expect(find.text('شبكة النيل للألياف الضوئية'), findsOneWidget);
      expect(find.text('نشط'), findsOneWidget);
      expect(find.text('الدعم الفني والمساعدة'), findsOneWidget);
      expect(find.text('Jalsah'), findsOneWidget);
      expect(find.text('تسجيل الخروج'), findsOneWidget);

      // Verify WhatsApp Icon is present
      expect(find.byType(WhatsAppIcon), findsWidgets);

      // Verify no overflow exception was thrown
      expect(tester.takeException(), isNull);
    });

    testWidgets('handles extremely long email and long name without overflow on small screens (320px)', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      const longEmail =
          'super_ultra_extremely_long_admin_email_for_stress_testing_responsive_design@jalsah-cloud-very-long-domain-name.com';
      const longName =
          'المهندس الاستشاري عبدالرحمن محمد مصطفى الهاشمي القرشي الكواهلي السوداني';

      ApiClient.client = MockClient((request) async {
        return utf8Response({
          'success': true,
          'data': {
            'id': 'u-stress-1',
            'username': 'super_admin_very_long_username_test',
            'fullName': longName,
            'email': longEmail,
            'role': 'SUPER_ADMIN',
            'networkName': 'شبكة مؤسسة الخرطوم الدولية لخدمات الإنترنت المحدودة',
            'status': 'ACTIVE',
          },
        }, 200);
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: UserProfileScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(longName), findsWidgets);
      expect(find.text(longEmail), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tapping WhatsApp phone button launches correct WhatsApp URL', (tester) async {
      ApiClient.client = MockClient((request) async {
        return utf8Response({
          'success': true,
          'data': {
            'id': 'u-1',
            'username': 'test_user',
            'fullName': 'مستخدم تجريبي',
            'email': 'user@jalsah.sd',
            'role': 'TENANT_ADMIN',
            'networkName': 'شبكة تجريبية',
            'status': 'ACTIVE',
          },
        }, 200);
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: UserProfileScreen(),
        ),
      );
      await tester.pumpAndSettle();

      final firstPhoneFinder = find.text(kSupportPhone1);
      expect(firstPhoneFinder, findsOneWidget);

      await tester.tap(firstPhoneFinder);
      await tester.pumpAndSettle();

      expect(mockLauncher.launchedUrl, isNotNull);
      expect(mockLauncher.launchedUrl, contains('https://wa.me/249115715672'));
    });

    testWidgets('tapping logout button shows confirmation dialog and cancels gracefully', (tester) async {
      ApiClient.client = MockClient((request) async {
        return utf8Response({
          'success': true,
          'data': {
            'id': 'u-1',
            'username': 'test_user',
            'fullName': 'مستخدم تجريبي',
            'email': 'user@jalsah.sd',
            'role': 'TENANT_ADMIN',
            'networkName': 'شبكة تجريبية',
            'status': 'ACTIVE',
          },
        }, 200);
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: UserProfileScreen(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('تسجيل الخروج'));
      await tester.pumpAndSettle();

      expect(find.text('هل أنت متأكد من رغبتك في تسجيل الخروج من التطبيق؟'), findsOneWidget);
      expect(find.text('إلغاء'), findsOneWidget);
      expect(find.text('خروج'), findsOneWidget);

      await tester.tap(find.text('إلغاء'));
      await tester.pumpAndSettle();

      expect(find.text('هل أنت متأكد من رغبتك في تسجيل الخروج من التطبيق؟'), findsNothing);
    });
  });
}
