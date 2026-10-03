// ============================================================================
// Platform: Commercial MikroTik Network & HotSpot Card Management System
// File: test/staff_test.dart
// Unit & Widget Tests: Staff & Roles Management, RBAC, StaffUserModel, ApiClient
// Master Reference: Rule 14 (Security Rules), Rule 19 (RBAC), Rule 26 (MVP Roles)
// ============================================================================

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:mikrotik_cards_app/models/staff_user_model.dart';
import 'package:mikrotik_cards_app/screens/dashboard_screen.dart';
import 'package:mikrotik_cards_app/screens/staff_screen.dart';
import 'package:mikrotik_cards_app/services/api_client.dart';

http.Response utf8Response(Map<String, dynamic> data, int statusCode) {
  return http.Response.bytes(
    utf8.encode(jsonEncode(data)),
    statusCode,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

String makeTestJwt({
  required String role,
  String userId = 'user-uuid-1',
  String tenantId = 'tenant-uuid-1',
}) {
  final header = base64Url
      .encode(utf8.encode(jsonEncode({'alg': 'HS256', 'typ': 'JWT'})))
      .replaceAll('=', '');
  final payload = base64Url
      .encode(utf8.encode(jsonEncode({
        'userId': userId,
        'tenantId': tenantId,
        'role': role,
        'iat': 1600000000,
        'exp': 1800000000,
      })))
      .replaceAll('=', '');
  return '$header.$payload.mock_signature';
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    GoogleFonts.config.allowRuntimeFetching = false;
    Animate.restartOnHotReload = false;

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

  group('StaffUserModel Unit Tests', () {
    test('fromJson accurately parses all user roles and active status', () {
      final jsonAdmin = {
        'id': 'user-1',
        'username': 'admin_ahmed',
        'fullName': 'أحمد إبراهيم',
        'role': 'TENANT_ADMIN',
        'status': 'ACTIVE',
        'phone': '0912345678',
        'createdAt': '2026-10-01T08:00:00.000Z',
      };

      final admin = StaffUserModel.fromJson(jsonAdmin);
      expect(admin.id, equals('user-1'));
      expect(admin.username, equals('admin_ahmed'));
      expect(admin.fullName, equals('أحمد إبراهيم'));
      expect(admin.role, equals('TENANT_ADMIN'));
      expect(admin.roleArabic, equals('مدير'));
      expect(admin.status, equals('ACTIVE'));
      expect(admin.statusArabic, equals('نشط'));
      expect(admin.isActive, isTrue);
      expect(admin.phone, equals('0912345678'));
    });

    test('roleArabic and roleIcon return proper Arabic labels for all roles', () {
      final superAdmin = StaffUserModel.fromJson({
        'id': '1',
        'username': 'sa',
        'fullName': 'Super Admin',
        'role': 'SUPER_ADMIN',
        'status': 'ACTIVE',
      });
      expect(superAdmin.roleArabic, equals('مدير عام'));
      expect(superAdmin.roleIcon, equals(Icons.admin_panel_settings_rounded));

      final operator = StaffUserModel.fromJson({
        'id': '2',
        'username': 'op',
        'fullName': 'Operator',
        'role': 'OPERATOR',
        'status': 'ACTIVE',
      });
      expect(operator.roleArabic, equals('مشغّل'));
      expect(operator.roleIcon, equals(Icons.engineering_rounded));

      final reseller = StaffUserModel.fromJson({
        'id': '3',
        'username': 'resell',
        'fullName': 'Reseller',
        'role': 'RESELLER',
        'status': 'INACTIVE',
      });
      expect(reseller.roleArabic, equals('وكيل بيع'));
      expect(reseller.roleIcon, equals(Icons.storefront_rounded));
      expect(reseller.statusArabic, equals('معطّل'));
      expect(reseller.isActive, isFalse);

      final accountant = StaffUserModel.fromJson({
        'id': '4',
        'username': 'acc',
        'fullName': 'Accountant',
        'role': 'ACCOUNTANT',
        'status': 'SUSPENDED',
      });
      expect(accountant.roleArabic, equals('محاسب'));
      expect(accountant.roleIcon, equals(Icons.account_balance_wallet_rounded));
      expect(accountant.statusArabic, equals('موقوف'));
    });

    test('toJson serializes model accurately', () {
      final user = StaffUserModel(
        id: 'user-json',
        username: 'testuser',
        fullName: 'اسم تجريبي',
        role: 'OPERATOR',
        status: 'ACTIVE',
        phone: '0999999999',
        createdAt: DateTime.parse('2026-10-02T10:00:00.000Z'),
      );

      final map = user.toJson();
      expect(map['id'], equals('user-json'));
      expect(map['username'], equals('testuser'));
      expect(map['fullName'], equals('اسم تجريبي'));
      expect(map['role'], equals('OPERATOR'));
      expect(map['status'], equals('ACTIVE'));
      expect(map['phone'], equals('0999999999'));
    });
  });

  group('ApiClient Staff & Role Management Unit Tests', () {
    test('getUserRole extracts role directly from JWT payload', () {
      ApiClient.setAuthToken(makeTestJwt(role: 'TENANT_ADMIN'));
      expect(ApiClient.getUserRole(), equals('TENANT_ADMIN'));
      expect(ApiClient.isAdmin, isTrue);

      ApiClient.setAuthToken(makeTestJwt(role: 'SUPER_ADMIN'));
      expect(ApiClient.getUserRole(), equals('SUPER_ADMIN'));
      expect(ApiClient.isAdmin, isTrue);

      ApiClient.setAuthToken(makeTestJwt(role: 'OPERATOR'));
      expect(ApiClient.getUserRole(), equals('OPERATOR'));
      expect(ApiClient.isAdmin, isFalse);

      ApiClient.setAuthToken(makeTestJwt(role: 'RESELLER'));
      expect(ApiClient.getUserRole(), equals('RESELLER'));
      expect(ApiClient.isAdmin, isFalse);

      ApiClient.setAuthToken(makeTestJwt(role: 'ACCOUNTANT'));
      expect(ApiClient.getUserRole(), equals('ACCOUNTANT'));
      expect(ApiClient.isAdmin, isFalse);

      ApiClient.setAuthToken(null);
      expect(ApiClient.getUserRole(), isNull);
      expect(ApiClient.isAdmin, isFalse);
    });

    test('getStaffUsers sends GET /api/v1/users with auth header', () async {
      late http.Request capturedRequest;
      ApiClient.setAuthToken(makeTestJwt(role: 'TENANT_ADMIN'));

      ApiClient.client = MockClient((request) async {
        capturedRequest = request;
        return utf8Response({
          'success': true,
          'data': [
            {
              'id': 'u1',
              'username': 'staff1',
              'fullName': 'المشغل علي',
              'role': 'OPERATOR',
              'status': 'ACTIVE',
              'createdAt': '2026-10-03T10:00:00.000Z',
            },
          ],
        }, 200);
      });

      final result = await ApiClient.getStaffUsers();

      expect(result['success'], isTrue);
      expect(capturedRequest.method, equals('GET'));
      expect(capturedRequest.url.path, equals('/api/v1/users'));
      expect(capturedRequest.headers['Authorization'],
          startsWith('Bearer eyJhbGciOiJIUzI1Ni'));

      final list = result['data'] as List<StaffUserModel>;
      expect(list.length, equals(1));
      expect(list.first.username, equals('staff1'));
      expect(list.first.fullName, equals('المشغل علي'));
      expect(list.first.roleArabic, equals('مشغّل'));
    });

    test('createStaffUser sends POST /api/v1/users with correct payload', () async {
      late http.Request capturedRequest;
      ApiClient.setAuthToken(makeTestJwt(role: 'TENANT_ADMIN'));

      ApiClient.client = MockClient((request) async {
        capturedRequest = request;
        return utf8Response({
          'success': true,
          'data': {
            'id': 'new-user-id',
            'username': 'salim_op',
            'fullName': 'سالم عثمان',
            'role': 'OPERATOR',
            'status': 'ACTIVE',
            'phone': '0912121212',
            'createdAt': '2026-10-03T11:00:00.000Z',
          },
        }, 201);
      });

      final result = await ApiClient.createStaffUser(
        username: 'salim_op',
        password: 'Password123!',
        fullName: 'سالم عثمان',
        role: 'OPERATOR',
        phone: '0912121212',
      );

      expect(result['success'], isTrue);
      expect(capturedRequest.method, equals('POST'));
      expect(capturedRequest.url.path, equals('/api/v1/users'));

      final body = jsonDecode(capturedRequest.body);
      expect(body['username'], equals('salim_op'));
      expect(body['password'], equals('Password123!'));
      expect(body['fullName'], equals('سالم عثمان'));
      expect(body['role'], equals('OPERATOR'));
      expect(body['phone'], equals('0912121212'));

      final created = result['data'] as StaffUserModel;
      expect(created.id, equals('new-user-id'));
      expect(created.fullName, equals('سالم عثمان'));
    });

    test('deactivateStaffUser sends PATCH /api/v1/users/:id/deactivate', () async {
      late http.Request capturedRequest;
      ApiClient.setAuthToken(makeTestJwt(role: 'TENANT_ADMIN'));

      ApiClient.client = MockClient((request) async {
        capturedRequest = request;
        return utf8Response({
          'success': true,
          'data': {
            'id': 'user-deactivated-1',
            'username': 'inactive_op',
            'fullName': 'موظف معطل',
            'role': 'OPERATOR',
            'status': 'INACTIVE',
          },
        }, 200);
      });

      final result = await ApiClient.deactivateStaffUser('user-deactivated-1');

      expect(result['success'], isTrue);
      expect(capturedRequest.method, equals('PATCH'));
      expect(capturedRequest.url.path,
          equals('/api/v1/users/user-deactivated-1/deactivate'));

      final updated = result['data'] as StaffUserModel;
      expect(updated.status, equals('INACTIVE'));
      expect(updated.isActive, isFalse);
    });

    test('getStaffUsers returns FORBIDDEN error when role is non-admin', () async {
      ApiClient.setAuthToken(makeTestJwt(role: 'OPERATOR'));

      ApiClient.client = MockClient((request) async {
        return utf8Response({
          'success': false,
          'errorCode': 'FORBIDDEN',
          'errorMessage': 'ليس لديك صلاحية للوصول إلى هذا المورد',
        }, 403);
      });

      final result = await ApiClient.getStaffUsers();
      expect(result['success'], isFalse);
      expect(result['errorCode'], equals('FORBIDDEN'));
    });
  });

  group('StaffScreen Widget Tests', () {
    testWidgets('renders hero banner, stats, and list of staff with badges', (tester) async {
      ApiClient.setAuthToken(makeTestJwt(role: 'TENANT_ADMIN'));

      ApiClient.client = MockClient((request) async {
        return utf8Response({
          'success': true,
          'data': [
            {
              'id': 'u1',
              'username': 'admin_root',
              'fullName': 'مدير الفرع الأول',
              'role': 'TENANT_ADMIN',
              'status': 'ACTIVE',
              'phone': '0911111111',
              'createdAt': '2026-10-01T08:00:00.000Z',
            },
            {
              'id': 'u2',
              'username': 'op_khalid',
              'fullName': 'خالد المشرف',
              'role': 'OPERATOR',
              'status': 'ACTIVE',
              'phone': '0922222222',
              'createdAt': '2026-10-02T09:30:00.000Z',
            },
            {
              'id': 'u3',
              'username': 'reseller_tarig',
              'fullName': 'طارق الوكيل',
              'role': 'RESELLER',
              'status': 'INACTIVE',
              'createdAt': '2026-10-03T10:15:00.000Z',
            },
          ],
        }, 200);
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: StaffScreen(),
        ),
      );

      // Loading state
      expect(find.byType(CircularProgressIndicator), findsWidgets);
      await tester.pumpAndSettle();

      // Screen title and subtitle
      expect(find.text('الموظفون والأدوار'), findsOneWidget);
      expect(find.text('إدارة المشغلين والوكلاء وصلاحيات الدخول'), findsOneWidget);

      // Stats counters
      expect(find.text('3 موظف'), findsOneWidget); // إجمالي الفريق
      expect(find.text('2 نشط'), findsWidgets); // حسابات نشطة

      // Staff names
      expect(find.text('مدير الفرع الأول'), findsOneWidget);
      expect(find.text('خالد المشرف'), findsOneWidget);
      expect(find.text('طارق الوكيل'), findsOneWidget);

      // Role badges
      expect(find.text('مدير'), findsOneWidget);
      expect(find.text('مشغّل'), findsOneWidget);
      expect(find.text('وكيل بيع'), findsOneWidget);

      // Status badges
      expect(find.text('نشط'), findsNWidgets(2));
      expect(find.text('معطّل'), findsWidgets);
    });

    testWidgets('shows empty state when no staff members exist', (tester) async {
      ApiClient.setAuthToken(makeTestJwt(role: 'TENANT_ADMIN'));

      ApiClient.client = MockClient((request) async {
        return utf8Response({
          'success': true,
          'data': [],
        }, 200);
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: StaffScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('لا يوجد موظفون مسجلون بعد'), findsOneWidget);
      expect(find.text('إضافة أول موظف'), findsOneWidget);
    });

    testWidgets('shows error state and retries successfully', (tester) async {
      ApiClient.setAuthToken(makeTestJwt(role: 'TENANT_ADMIN'));
      int callCount = 0;

      ApiClient.client = MockClient((request) async {
        callCount++;
        if (callCount == 1) {
          return utf8Response({
            'success': false,
            'errorMessage': 'تعذر جلب بيانات الموظفين',
          }, 500);
        } else {
          return utf8Response({
            'success': true,
            'data': [
              {
                'id': 'u10',
                'username': 'staff_retry',
                'fullName': 'الموظف المحمل بنجاح',
                'role': 'ACCOUNTANT',
                'status': 'ACTIVE',
              },
            ],
          }, 200);
        }
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: StaffScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('فشل تحميل قائمة الموظفين'), findsOneWidget);
      expect(find.text('تعذر جلب بيانات الموظفين'), findsOneWidget);
      expect(find.text('إعادة المحاولة'), findsOneWidget);

      // Retry
      await tester.tap(find.text('إعادة المحاولة'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));

      expect(callCount, equals(2));
      expect(find.text('الموظف المحمل بنجاح'), findsOneWidget);
      expect(find.text('محاسب'), findsOneWidget);
    });

    testWidgets('tapping "إضافة موظف" opens modal sheet and validates empty fields', (tester) async {
      ApiClient.setAuthToken(makeTestJwt(role: 'TENANT_ADMIN'));

      ApiClient.client = MockClient((request) async {
        return utf8Response({'success': true, 'data': []}, 200);
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: StaffScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Tap "إضافة موظف" in header
      await tester.tap(find.text('إضافة موظف'));
      await tester.pumpAndSettle();

      // Modal bottom sheet should be visible
      expect(find.text('إضافة موظف جديد'), findsOneWidget);
      expect(find.text('الاسم الكامل'), findsOneWidget);
      expect(find.text('اسم المستخدم'), findsOneWidget);
      expect(find.text('كلمة المرور'), findsOneWidget);
      expect(find.text('الدور والصلاحيات'), findsOneWidget);

      // Tap submit with empty fields -> validation errors
      await tester.tap(find.text('حفظ وإضافة الموظف'));
      await tester.pumpAndSettle();

      expect(find.text('يرجى إدخال الاسم الكامل'), findsOneWidget);
      expect(find.text('يرجى إدخال اسم المستخدم'), findsOneWidget);
      expect(find.text('يرجى إدخال كلمة المرور'), findsOneWidget);
    });

    testWidgets('successfully creates staff user and reloads list', (tester) async {
      ApiClient.setAuthToken(makeTestJwt(role: 'TENANT_ADMIN'));
      final List<StaffUserModel> currentList = [];

      ApiClient.client = MockClient((request) async {
        if (request.method == 'GET' && request.url.path == '/api/v1/users') {
          return utf8Response({
            'success': true,
            'data': currentList.map((e) => e.toJson()).toList(),
          }, 200);
        }
        if (request.method == 'POST' && request.url.path == '/api/v1/users') {
          final payload = jsonDecode(request.body);
          final newUser = StaffUserModel(
            id: 'new-staff-created',
            username: payload['username'],
            fullName: payload['fullName'],
            role: payload['role'],
            status: 'ACTIVE',
            phone: payload['phone'],
            createdAt: DateTime.now(),
          );
          currentList.add(newUser);
          return utf8Response({
            'success': true,
            'data': newUser.toJson(),
          }, 201);
        }
        return utf8Response({'success': false}, 404);
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: StaffScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Empty initial state
      expect(find.text('لا يوجد موظفون مسجلون بعد'), findsOneWidget);

      // Open add staff modal via header button
      await tester.tap(find.text('إضافة موظف'));
      await tester.pumpAndSettle();

      // Enter fields:
      // index 0: Full Name, index 1: Username, index 2: Password, index 3: Phone
      await tester.enterText(find.byType(TextFormField).at(0), 'ياسين أحمد');
      await tester.enterText(find.byType(TextFormField).at(1), 'new_reseller');
      await tester.enterText(find.byType(TextFormField).at(2), 'SecretPass123!');

      // Tap submit
      await tester.tap(find.text('حفظ وإضافة الموظف'));
      await tester.pumpAndSettle();

      // List should now display the new staff member
      expect(find.text('ياسين أحمد'), findsOneWidget);
      expect(find.text('مشغّل'), findsOneWidget); // default role in dropdown
    });

    testWidgets('deactivate dialog confirms and deactivates staff member', (tester) async {
      ApiClient.setAuthToken(makeTestJwt(role: 'TENANT_ADMIN'));
      final user = StaffUserModel(
        id: 'u-deact',
        username: 'staff_to_deactivate',
        fullName: 'عمر الموظف',
        role: 'OPERATOR',
        status: 'ACTIVE',
        createdAt: DateTime.now(),
      );

      ApiClient.client = MockClient((request) async {
        if (request.method == 'GET' && request.url.path == '/api/v1/users') {
          return utf8Response({
            'success': true,
            'data': [user.toJson()],
          }, 200);
        }
        if (request.method == 'PATCH' &&
            request.url.path == '/api/v1/users/u-deact/deactivate') {
          return utf8Response({
            'success': true,
            'data': {
              'id': 'u-deact',
              'username': 'staff_to_deactivate',
              'fullName': 'عمر الموظف',
              'role': 'OPERATOR',
              'status': 'INACTIVE',
            },
          }, 200);
        }
        return utf8Response({'success': false}, 404);
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: StaffScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('عمر الموظف'), findsOneWidget);
      expect(find.text('نشط'), findsWidgets);

      // Find and tap deactivate button
      final offIcon = find.byIcon(Icons.person_off_outlined);
      expect(offIcon, findsOneWidget);
      await tester.tap(offIcon);
      await tester.pumpAndSettle();

      // Confirmation dialog should be displayed
      expect(find.text('تأكيد تعطيل الحساب'), findsOneWidget);
      expect(find.textContaining('عمر الموظف'), findsWidgets);

      // Confirm deactivation
      await tester.tap(find.text('نعم، تعطيل'));
      await tester.pumpAndSettle();

      // Deactivation completed
      expect(find.textContaining('تم تعطيل حساب'), findsOneWidget);
    });
  });

  group('DashboardScreen RBAC Widget Tests', () {
    testWidgets('shows "الموظفون" button when user is TENANT_ADMIN and navigates to StaffScreen', (tester) async {
      ApiClient.setAuthToken(makeTestJwt(role: 'TENANT_ADMIN'));

      ApiClient.client = MockClient((request) async {
        if (request.url.path.contains('/api/v1/routers')) {
          return utf8Response({'success': true, 'data': []}, 200);
        }
        if (request.url.path.contains('/api/v1/sales/today-total')) {
          return utf8Response({
            'success': true,
            'data': {'todayTotal': 5000.0},
          }, 200);
        }
        if (request.url.path == '/api/v1/users') {
          return utf8Response({'success': true, 'data': []}, 200);
        }
        return utf8Response({'success': false}, 404);
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: DashboardScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // "الموظفون" button is visible
      expect(find.text('الموظفون'), findsOneWidget);

      // Tap "الموظفون"
      await tester.tap(find.text('الموظفون'));
      await tester.pumpAndSettle();

      // Should open StaffScreen
      expect(find.byType(StaffScreen), findsOneWidget);
      expect(find.text('الموظفون والأدوار'), findsOneWidget);
    });

    testWidgets('hides "الموظفون" button when user is OPERATOR', (tester) async {
      ApiClient.setAuthToken(makeTestJwt(role: 'OPERATOR'));

      ApiClient.client = MockClient((request) async {
        if (request.url.path.contains('/api/v1/routers')) {
          return utf8Response({'success': true, 'data': []}, 200);
        }
        if (request.url.path.contains('/api/v1/sales/today-total')) {
          return utf8Response({
            'success': true,
            'data': {'todayTotal': 5000.0},
          }, 200);
        }
        return utf8Response({'success': false}, 404);
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: DashboardScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // "الموظفون" button must NOT be visible for OPERATOR
      expect(find.text('الموظفون'), findsNothing);
    });

    testWidgets('hides "الموظفون" button when no token is present', (tester) async {
      ApiClient.setAuthToken(null);

      ApiClient.client = MockClient((request) async {
        if (request.url.path.contains('/api/v1/routers')) {
          return utf8Response({'success': true, 'data': []}, 200);
        }
        if (request.url.path.contains('/api/v1/sales/today-total')) {
          return utf8Response({
            'success': true,
            'data': {'todayTotal': 0.0},
          }, 200);
        }
        return utf8Response({'success': false}, 404);
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: DashboardScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('الموظفون'), findsNothing);
    });
  });
}
