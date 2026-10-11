// ============================================================================
// Platform: Commercial MikroTik Network & HotSpot Card Management System
// File: test/super_admin_license_test.dart
// Unit & Widget Tests: Super Admin Dashboard & License Code Redemption System
// Master Reference: Rule 14, Rule 19, Rule 26, Rule 27
// ============================================================================

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:mikrotik_cards_app/models/admin_tenant_model.dart';
import 'package:mikrotik_cards_app/models/license_code_model.dart';
import 'package:mikrotik_cards_app/screens/admin/super_admin_dashboard.dart';
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

  group('LicenseCodeModel & AdminTenantModel Unit Tests', () {
    test('LicenseCodeModel parses UNUSED code correctly', () {
      final json = {
        'id': 'code-1',
        'code': 'A1B2-C3D4-E5F6',
        'planName': 'Professional',
        'durationDays': 30,
        'maxRoutersLimit': 10,
        'status': 'UNUSED',
        'createdByUserId': 'admin-super',
        'usedByTenantId': null,
        'usedByTenantName': null,
        'usedByTenantSlug': null,
        'usedAt': null,
        'createdAt': '2026-10-08T12:00:00.000Z',
      };

      final model = LicenseCodeModel.fromJson(json);

      expect(model.id, equals('code-1'));
      expect(model.code, equals('A1B2-C3D4-E5F6'));
      expect(model.planName, equals('Professional'));
      expect(model.durationDays, equals(30));
      expect(model.maxRoutersLimit, equals(10));
      expect(model.isUnused, isTrue);
      expect(model.isUsed, isFalse);
      expect(model.isRevoked, isFalse);
      expect(model.usedByTenantId, isNull);
    });

    test('LicenseCodeModel parses USED code correctly', () {
      final json = {
        'id': 'code-2',
        'code': 'G7H8-J9K0-L1M2',
        'planName': 'Enterprise',
        'durationDays': 90,
        'maxRoutersLimit': 25,
        'status': 'USED',
        'createdByUserId': 'admin-super',
        'usedByTenantId': 'tenant-99',
        'usedByTenantName': 'SpeedNet ISP',
        'usedByTenantSlug': 'speednet',
        'usedAt': '2026-10-08T14:00:00.000Z',
        'createdAt': '2026-10-08T12:00:00.000Z',
      };

      final model = LicenseCodeModel.fromJson(json);

      expect(model.isUnused, isFalse);
      expect(model.isUsed, isTrue);
      expect(model.usedByTenantName, equals('SpeedNet ISP'));
      expect(model.usedAt, isNotNull);
    });

    test('AdminTenantModel parses tenant summary correctly', () {
      final json = {
        'id': 'tenant-abc',
        'name': 'Al-Amal Telecom',
        'slug': 'alamal-isp',
        'contactEmail': 'info@alamal.sd',
        'contactPhone': '+249123456789',
        'currency': 'SDG',
        'status': 'ACTIVE',
        'subscriptionStatus': 'ACTIVE',
        'trialEndsAt': '2026-10-15T00:00:00.000Z',
        'subscriptionEndsAt': '2026-11-15T00:00:00.000Z',
        'planName': 'Professional',
        'maxRoutersLimit': 10,
        'usersCount': 3,
        'routersCount': 4,
        'createdAt': '2026-10-01T00:00:00.000Z',
      };

      final model = AdminTenantModel.fromJson(json);

      expect(model.id, equals('tenant-abc'));
      expect(model.name, equals('Al-Amal Telecom'));
      expect(model.slug, equals('alamal-isp'));
      expect(model.isActive, isTrue);
      expect(model.isTrial, isFalse);
      expect(model.usersCount, equals(3));
      expect(model.routersCount, equals(4));
      expect(model.maxRoutersLimit, equals(10));
      expect(model.subscriptionEndsAt, isNotNull);
    });
  });

  group('ApiClient Admin & License Methods Tests', () {
    test('isSuperAdmin returns true for SUPER_ADMIN role JWT', () {
      // Craft JWT token with SUPER_ADMIN role
      const header = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9';
      final payload = base64Url.encode(utf8.encode(jsonEncode({
        'userId': 'u1',
        'tenantId': 't1',
        'role': 'SUPER_ADMIN',
      }))).replaceAll('=', '');
      const signature = 'testsignature';
      final token = '$header.$payload.$signature';

      ApiClient.setAuthToken(token);
      expect(ApiClient.getUserRole(), equals('SUPER_ADMIN'));
      expect(ApiClient.isSuperAdmin, isTrue);
      expect(ApiClient.isAdmin, isTrue);
    });

    test('isSuperAdmin returns false for TENANT_ADMIN role JWT', () {
      const header = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9';
      final payload = base64Url.encode(utf8.encode(jsonEncode({
        'userId': 'u2',
        'tenantId': 't2',
        'role': 'TENANT_ADMIN',
      }))).replaceAll('=', '');
      const signature = 'testsignature';
      final token = '$header.$payload.$signature';

      ApiClient.setAuthToken(token);
      expect(ApiClient.getUserRole(), equals('TENANT_ADMIN'));
      expect(ApiClient.isSuperAdmin, isFalse);
      expect(ApiClient.isAdmin, isTrue);
    });

    test('redeemLicenseCode sends request and handles success response', () async {
      ApiClient.client = MockClient((request) async {
        expect(request.url.path, equals('/api/v1/subscription/redeem'));
        final body = jsonDecode(request.body);
        expect(body['code'], equals('XXXX-YYYY-ZZZZ'));

        return utf8Response({
          'success': true,
          'data': {
            'code': 'XXXX-YYYY-ZZZZ',
            'planName': 'Enterprise',
            'durationDays': 30,
            'maxRoutersLimit': 15,
            'subscriptionStatus': 'ACTIVE',
            'message': 'تم تفعيل كود الترخيص بنجاح!',
          },
        }, 200);
      });

      final result = await ApiClient.redeemLicenseCode('xxxx-yyyy-zzzz');
      expect(result['success'], isTrue);
      expect(result['data']['subscriptionStatus'], equals('ACTIVE'));
      expect(result['data']['planName'], equals('Enterprise'));
    });

    test('getAdminTenants returns list of AdminTenantModel', () async {
      ApiClient.client = MockClient((request) async {
        expect(request.url.path, equals('/api/v1/admin/tenants'));
        return utf8Response({
          'success': true,
          'data': [
            {
              'id': 't1',
              'name': 'Company A',
              'slug': 'comp-a',
              'status': 'ACTIVE',
              'subscriptionStatus': 'ACTIVE',
              'planName': 'Starter',
              'maxRoutersLimit': 5,
              'usersCount': 2,
              'routersCount': 1,
              'createdAt': '2026-10-01T00:00:00.000Z',
            }
          ],
        }, 200);
      });

      final result = await ApiClient.getAdminTenants();
      expect(result['success'], isTrue);
      final List<AdminTenantModel> tenants = result['data'];
      expect(tenants.length, equals(1));
      expect(tenants.first.name, equals('Company A'));
    });

    test('generateLicenseCode sends parameters and returns LicenseCodeModel', () async {
      ApiClient.client = MockClient((request) async {
        expect(request.url.path, equals('/api/v1/admin/license-codes'));
        final body = jsonDecode(request.body);
        expect(body['planName'], equals('VIP Plan'));
        expect(body['durationDays'], equals(60));
        expect(body['maxRoutersLimit'], equals(20));

        return utf8Response({
          'success': true,
          'data': {
            'id': 'new-code-id',
            'code': 'VIP1-VIP2-VIP3',
            'planName': 'VIP Plan',
            'durationDays': 60,
            'maxRoutersLimit': 20,
            'status': 'UNUSED',
            'createdByUserId': 'admin-1',
            'createdAt': '2026-10-08T12:00:00.000Z',
          },
        }, 201);
      });

      final result = await ApiClient.generateLicenseCode(
        planName: 'VIP Plan',
        durationDays: 60,
        maxRoutersLimit: 20,
      );

      expect(result['success'], isTrue);
      final LicenseCodeModel code = result['data'];
      expect(code.code, equals('VIP1-VIP2-VIP3'));
      expect(code.planName, equals('VIP Plan'));
      expect(code.isUnused, isTrue);
    });
  });

  group('SuperAdminDashboardScreen Widget Tests', () {
    testWidgets('renders top bar, stats metrics, and companies list',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      ApiClient.client = MockClient((request) async {
        if (request.url.path.contains('admin/tenants')) {
          return utf8Response({
            'success': true,
            'data': [
              {
                'id': 't1',
                'name': 'شبكة النيل السريعة',
                'slug': 'nile-net',
                'status': 'ACTIVE',
                'subscriptionStatus': 'ACTIVE',
                'planName': 'باقة المحترفين',
                'maxRoutersLimit': 10,
                'usersCount': 2,
                'routersCount': 3,
                'createdAt': '2026-10-01T00:00:00.000Z',
              },
            ],
          }, 200);
        }
        if (request.url.path.contains('admin/license-codes')) {
          return utf8Response({
            'success': true,
            'data': [
              {
                'id': 'c1',
                'code': 'K8R3-9P2W-5X7M',
                'planName': 'الخطة القياسية',
                'durationDays': 30,
                'maxRoutersLimit': 5,
                'status': 'UNUSED',
                'createdByUserId': 'superadmin',
                'createdAt': '2026-10-08T10:00:00.000Z',
              },
            ],
          }, 200);
        }
        return utf8Response({'success': true, 'data': []}, 200);
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: SuperAdminDashboardScreen(),
        ),
      );

      for (int i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Verify header and metrics
      expect(find.text('لوحة تحكم مدير المنصة'), findsOneWidget);
      expect(find.textContaining('SOFT ZONE'), findsOneWidget);
      expect(find.text('الشركات'), findsOneWidget);
      expect(find.text('أكواد الترخيص'), findsOneWidget);

      // Verify company card in tab 1
      expect(find.text('شبكة النيل السريعة'), findsOneWidget);
      expect(find.text('@nile-net'), findsOneWidget);
      expect(find.text('نشط (ACTIVE)'), findsOneWidget);
    });

    testWidgets('switches to License Codes tab and opens generate code sheet',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      ApiClient.client = MockClient((request) async {
        if (request.url.path.contains('admin/tenants')) {
          return utf8Response({'success': true, 'data': []}, 200);
        }
        if (request.url.path.contains('admin/license-codes')) {
          return utf8Response({
            'success': true,
            'data': [
              {
                'id': 'c1',
                'code': 'K8R3-9P2W-5X7M',
                'planName': 'الخطة القياسية',
                'durationDays': 30,
                'maxRoutersLimit': 5,
                'status': 'UNUSED',
                'createdByUserId': 'superadmin',
                'createdAt': '2026-10-08T10:00:00.000Z',
              },
            ],
          }, 200);
        }
        return utf8Response({'success': true, 'data': []}, 200);
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: SuperAdminDashboardScreen(),
        ),
      );

      for (int i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Tap on Tab 2: أكواد الترخيص
      await tester.tap(find.byType(Tab).at(1), warnIfMissed: false);
      await tester.pumpAndSettle();

      // Verify existing code is shown
      expect(find.text('K8R3-9P2W-5X7M'), findsOneWidget);
      expect(find.text('جاهز للاستخدام'), findsOneWidget);

      // Tap "توليد كود ترخيص جديد"
      await tester.tap(find.text('توليد كود ترخيص جديد').first);
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Modal bottom sheet should appear with form fields
      expect(find.text('توليد كود ترخيص جديد'), findsWidgets);
      expect(find.text('اسم الخطة / الباقة'), findsOneWidget);
      expect(find.text('المدة بالأيام (Duration Days)'), findsOneWidget);
      expect(find.text('حد أجهزة الراوتر المسموح به'), findsOneWidget);
      expect(find.text('توليد الكود فوراً'), findsOneWidget);
    });
  });

  group('DashboardScreen License Redemption Dialog Tests', () {
    testWidgets('shows "تفعيل كود ترخيص" button on expired screen and opens dialog',
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
              'currentRoutersCount': 1,
              'maxRoutersLimit': 5,
            },
          }, 200);
        }
        return utf8Response({'success': true, 'data': []}, 200);
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: DashboardScreen(),
        ),
      );

      for (int i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Expired screen shows
      expect(find.text('انتهت فترتك التجريبية'), findsOneWidget);
      expect(find.text('تفعيل كود ترخيص'), findsOneWidget);

      // Tap on "تفعيل كود ترخيص"
      await tester.tap(find.text('تفعيل كود ترخيص'));
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Dialog should open
      expect(find.text('كود الترخيص (License Code)'), findsOneWidget);
      expect(find.text('تفعيل الترخيص'), findsOneWidget);
      expect(find.text('إلغاء'), findsOneWidget);
    });
  });
}
