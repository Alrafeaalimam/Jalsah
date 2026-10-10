// ============================================================================
// Platform: Commercial MikroTik Network & HotSpot Card Management System
// File: test/super_admin_phase2_test.dart
// Unit & Widget Tests: Super Admin Phase 2 (Approval, Full Management, Licensing)
// Master Reference: Rule 14, Rule 26, Rule 27, Rule 30
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
import 'package:mikrotik_cards_app/models/staff_user_model.dart';
import 'package:mikrotik_cards_app/screens/admin/super_admin_dashboard.dart';
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

  group('AdminTenantModel Phase 2 Properties', () {
    test('AdminTenantModel parses approvalStatus and isPending correctly', () {
      final json = {
        'id': 't-pending',
        'name': 'Pending Telecom',
        'slug': 'pending-telecom',
        'status': 'ACTIVE',
        'subscriptionStatus': 'TRIAL',
        'approvalStatus': 'PENDING',
        'isDeleted': false,
        'usersCount': 1,
        'routersCount': 0,
        'maxRoutersLimit': 3,
        'createdAt': '2026-10-09T10:00:00.000Z',
      };

      final tenant = AdminTenantModel.fromJson(json);

      expect(tenant.id, equals('t-pending'));
      expect(tenant.approvalStatus, equals('PENDING'));
      expect(tenant.isPending, isTrue);
      expect(tenant.isApproved, isFalse);
      expect(tenant.isRejected, isFalse);
      expect(tenant.isDeleted, isFalse);
    });

    test('AdminTenantModel parses APPROVED and REJECTED status', () {
      final approved = AdminTenantModel.fromJson({
        'id': 't-approved',
        'name': 'Approved Net',
        'slug': 'approved-net',
        'status': 'ACTIVE',
        'subscriptionStatus': 'ACTIVE',
        'approvalStatus': 'APPROVED',
        'usersCount': 2,
        'routersCount': 2,
        'maxRoutersLimit': 5,
        'createdAt': '2026-10-09T10:00:00.000Z',
      });
      expect(approved.isApproved, isTrue);
      expect(approved.isPending, isFalse);

      final rejected = AdminTenantModel.fromJson({
        'id': 't-rejected',
        'name': 'Rejected Net',
        'slug': 'rejected-net',
        'status': 'INACTIVE',
        'subscriptionStatus': 'EXPIRED',
        'approvalStatus': 'REJECTED',
        'usersCount': 1,
        'routersCount': 0,
        'maxRoutersLimit': 0,
        'createdAt': '2026-10-09T10:00:00.000Z',
      });
      expect(rejected.isRejected, isTrue);
      expect(rejected.isPending, isFalse);
    });
  });

  group('ApiClient Phase 2 Admin Methods', () {
    test('approveTenant sends PATCH request to /admin/tenants/:id/approve', () async {
      ApiClient.client = MockClient((request) async {
        expect(request.method, equals('PATCH'));
        expect(request.url.path, equals('/api/v1/admin/tenants/t-123/approve'));
        return utf8Response({
          'success': true,
          'data': {'message': 'تمت الموافقة على الحساب بنجاح وتفعيله'},
        }, 200);
      });

      final result = await ApiClient.approveTenant('t-123');
      expect(result['success'], isTrue);
      expect(result['data']['message'], contains('تمت الموافقة'));
    });

    test('rejectTenant sends PATCH request to /admin/tenants/:id/reject', () async {
      ApiClient.client = MockClient((request) async {
        expect(request.method, equals('PATCH'));
        expect(request.url.path, equals('/api/v1/admin/tenants/t-123/reject'));
        return utf8Response({
          'success': true,
          'data': {'message': 'تم رفض طلب تسجيل الحساب بنجاح'},
        }, 200);
      });

      final result = await ApiClient.rejectTenant('t-123');
      expect(result['success'], isTrue);
    });

    test('suspendTenant sends PATCH request to /admin/tenants/:id/suspend', () async {
      ApiClient.client = MockClient((request) async {
        expect(request.method, equals('PATCH'));
        expect(request.url.path, equals('/api/v1/admin/tenants/t-123/suspend'));
        return utf8Response({
          'success': true,
          'data': {'message': 'تم إيقاف الاشتراك مؤقتاً بنجاح'},
        }, 200);
      });

      final result = await ApiClient.suspendTenant('t-123');
      expect(result['success'], isTrue);
    });

    test('reactivateTenant sends PATCH request to /admin/tenants/:id/reactivate', () async {
      ApiClient.client = MockClient((request) async {
        expect(request.method, equals('PATCH'));
        expect(request.url.path, equals('/api/v1/admin/tenants/t-123/reactivate'));
        return utf8Response({
          'success': true,
          'data': {'message': 'تمت إعادة تفعيل الاشتراك بنجاح'},
        }, 200);
      });

      final result = await ApiClient.reactivateTenant('t-123');
      expect(result['success'], isTrue);
    });

    test('deleteTenant sends PATCH request to /admin/tenants/:id/delete (soft delete)', () async {
      ApiClient.client = MockClient((request) async {
        expect(request.method, equals('PATCH'));
        expect(request.url.path, equals('/api/v1/admin/tenants/t-123/delete'));
        return utf8Response({
          'success': true,
          'data': {'message': 'تم حذف وإخفاء الحساب بنجاح مع الحفاظ على البيانات'},
        }, 200);
      });

      final result = await ApiClient.deleteTenant('t-123');
      expect(result['success'], isTrue);
    });

    test('adminActivateTenant sends POST with activation params', () async {
      ApiClient.client = MockClient((request) async {
        expect(request.method, equals('POST'));
        expect(request.url.path, equals('/api/v1/admin/tenants/t-123/activate-license'));
        final body = jsonDecode(request.body);
        expect(body['planName'], equals('باقة المحترفين'));
        expect(body['durationDays'], equals(45));
        expect(body['maxRoutersLimit'], equals(12));

        return utf8Response({
          'success': true,
          'data': {'message': 'تم تفعيل ترخيص الحساب بنجاح حتى 2026-11-25'},
        }, 200);
      });

      final result = await ApiClient.adminActivateTenant(
        tenantId: 't-123',
        planName: 'باقة المحترفين',
        durationDays: 45,
        maxRoutersLimit: 12,
      );
      expect(result['success'], isTrue);
      expect(result['data']['message'], contains('تم تفعيل ترخيص'));
    });

    test('getAdminTenantUsers and updateUserRole work correctly', () async {
      ApiClient.client = MockClient((request) async {
        if (request.url.path.contains('/users/u-1/role')) {
          expect(request.method, equals('PATCH'));
          final body = jsonDecode(request.body);
          expect(body['role'], equals('OPERATOR'));
          return utf8Response({
            'success': true,
            'data': {'message': 'تم تعديل دور المستخدم بنجاح'},
          }, 200);
        }

        if (request.url.path.contains('/admin/tenants/t-123/users')) {
          expect(request.method, equals('GET'));
          return utf8Response({
            'success': true,
            'data': [
              {
                'id': 'u-1',
                'username': 'ahmed',
                'fullName': 'أحمد علي',
                'role': 'TENANT_ADMIN',
                'status': 'ACTIVE',
              }
            ],
          }, 200);
        }

        return utf8Response({'success': false}, 400);
      });

      final usersRes = await ApiClient.getAdminTenantUsers('t-123');
      expect(usersRes['success'], isTrue);
      final List<StaffUserModel> users = usersRes['data'];
      expect(users.length, equals(1));
      expect(users.first.username, equals('ahmed'));

      final roleRes = await ApiClient.updateUserRole(userId: 'u-1', role: 'OPERATOR');
      expect(roleRes['success'], isTrue);
    });
  });

  group('SuperAdminDashboard Phase 2 UI Tests', () {
    testWidgets('displays pending registration banner and approval buttons',
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
                'id': 't-pending-1',
                'name': 'شبكة الروابي الجديدة',
                'slug': 'rawabi-net',
                'status': 'ACTIVE',
                'subscriptionStatus': 'TRIAL',
                'approvalStatus': 'PENDING',
                'maxRoutersLimit': 3,
                'usersCount': 1,
                'routersCount': 0,
                'createdAt': '2026-10-09T08:00:00.000Z',
              },
            ],
          }, 200);
        }
        if (request.url.path.contains('admin/license-codes')) {
          return utf8Response({'success': true, 'data': []}, 200);
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

      // Verify pending notification banner is visible
      expect(find.textContaining('طلب تسجيل جديد بانتظار المراجعة'), findsOneWidget);
      expect(find.text('عرض الطلبات'), findsOneWidget);

      // Verify pending tenant card
      expect(find.text('شبكة الروابي الجديدة'), findsOneWidget);
      expect(find.text('قيد المراجعة (PENDING)'), findsOneWidget);

      // Verify action buttons for pending tenant
      expect(find.text('موافقة واعتماد'), findsOneWidget);
      expect(find.text('رفض الطلب'), findsOneWidget);
    });

    testWidgets('displays active tenant management buttons (direct license, users, suspend)',
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
                'id': 't-active-1',
                'name': 'شبكة الخرطوم للاتصالات',
                'slug': 'khartoum-net',
                'status': 'ACTIVE',
                'subscriptionStatus': 'ACTIVE',
                'approvalStatus': 'APPROVED',
                'maxRoutersLimit': 10,
                'usersCount': 4,
                'routersCount': 6,
                'planName': 'الخطة القياسية',
                'createdAt': '2026-10-01T08:00:00.000Z',
              },
            ],
          }, 200);
        }
        if (request.url.path.contains('admin/license-codes')) {
          return utf8Response({'success': true, 'data': []}, 200);
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

      // Verify active tenant card
      expect(find.text('شبكة الخرطوم للاتصالات'), findsOneWidget);
      expect(find.text('نشط (ACTIVE)'), findsOneWidget);

      // Verify administrative control buttons
      expect(find.widgetWithText(ElevatedButton, 'تفعيل مباشر'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'المستخدمين'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'إيقاف مؤقت'), findsOneWidget);
    });
  });
}
