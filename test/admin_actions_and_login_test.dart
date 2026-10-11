// ============================================================================
// Platform: Commercial MikroTik Network & HotSpot Card Management System
// File: test/admin_actions_and_login_test.dart
// Unit & Widget Tests: Admin Action Reactivity, Pending Screen, Flexible Login, Add Super Admin
// Master Reference: Rule 14, Rule 20, Rule 26, Rule 30
// ============================================================================

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:mikrotik_cards_app/screens/admin/super_admin_dashboard.dart';
import 'package:mikrotik_cards_app/screens/pending_approval_screen.dart';
import 'package:mikrotik_cards_app/screens/temp_login_screen.dart';
import 'package:mikrotik_cards_app/screens/user_profile_screen.dart';
import 'package:mikrotik_cards_app/utils/whatsapp_helper.dart';
import 'package:mikrotik_cards_app/services/api_client.dart';
import 'package:mikrotik_cards_app/widgets/pressable_neumorphic_card.dart';

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

  group('ApiClient Super Admin Creation & Flexible Login', () {
    test('createSuperAdmin sends POST to /admin/super-admins with required payload', () async {
      ApiClient.client = MockClient((request) async {
        expect(request.method, equals('POST'));
        expect(request.url.path, equals('/api/v1/admin/super-admins'));
        final body = jsonDecode(request.body);
        expect(body['fullName'], equals('م. خالد أحمد'));
        expect(body['username'], equals('khaled_admin'));
        expect(body['email'], equals('khaled@jalsah.network'));
        expect(body['password'], equals('SuperPassword123!'));

        return utf8Response({
          'success': true,
          'data': {
            'id': 'u-super-new',
            'username': 'khaled_admin',
            'fullName': 'م. خالد أحمد',
            'role': 'SUPER_ADMIN',
            'message': 'تم إنشاء مدير المنصة بنجاح',
          },
        }, 201);
      });

      final res = await ApiClient.createSuperAdmin(
        fullName: 'م. خالد أحمد',
        username: 'khaled_admin',
        email: 'khaled@jalsah.network',
        password: 'SuperPassword123!',
      );

      expect(res['success'], isTrue);
      expect(res['data']['username'], equals('khaled_admin'));
      expect(res['data']['role'], equals('SUPER_ADMIN'));
    });

    test('login sends identifier and captures ACCOUNT_PENDING_APPROVAL error', () async {
      ApiClient.client = MockClient((request) async {
        expect(request.method, equals('POST'));
        expect(request.url.path, equals('/api/v1/auth/login'));
        final body = jsonDecode(request.body);
        expect(body['identifier'], equals('owner@network.com'));
        expect(body['password'], equals('Secret123!'));

        return utf8Response({
          'success': false,
          'errorCode': 'ACCOUNT_PENDING_APPROVAL',
          'message': 'حسابك قيد المراجعة من قبل إدارة المنصة',
        }, 403);
      });

      final res = await ApiClient.login(
        username: 'owner@network.com',
        password: 'Secret123!',
      );
      expect(res['success'], isFalse);
      expect(res['errorCode'], equals('ACCOUNT_PENDING_APPROVAL'));
      expect(res['errorMessage'], contains('قيد المراجعة'));
    });
  });

  group('PendingApprovalScreen UI & Interaction Tests', () {
    testWidgets('renders PendingApprovalScreen elements and app identity correctly',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: PendingApprovalScreen(
            identifier: 'test_user',
            password: 'secret_password',
            networkName: 'شبكة النورس',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('حسابك قيد المراجعة'), findsOneWidget);
      expect(find.text('شبكة النورس'), findsOneWidget);
      expect(find.text('تحقق مرة أخرى'), findsOneWidget);
      expect(find.text('تسجيل الدخول بحساب آخر'), findsOneWidget);
      expect(find.textContaining('jalsahnetwork@gmail.com'), findsOneWidget);
    });

    testWidgets('PendingApprovalScreen retry button checks status and shows snackbar if still pending',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      ApiClient.client = MockClient((request) async {
        return utf8Response({
          'success': false,
          'errorCode': 'ACCOUNT_PENDING_APPROVAL',
          'message': 'حسابك قيد المراجعة من قبل إدارة المنصة',
        }, 403);
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: PendingApprovalScreen(
            identifier: 'pending_user',
            password: 'pass',
          ),
        ),
      );
      await tester.pumpAndSettle();

      final retryButton = find.text('تحقق مرة أخرى');
      expect(retryButton, findsOneWidget);

      await tester.tap(retryButton);
      await tester.pump(); // Start spinner
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(find.text('ما زال الحساب قيد المراجعة والتدقيق من قبل الإدارة'), findsOneWidget);
    });
  });

  group('TempLoginScreen Flexible Identifier & Redirection Test', () {
    testWidgets('displays flexible login label and redirects to PendingApprovalScreen',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      ApiClient.client = MockClient((request) async {
        return utf8Response({
          'success': false,
          'errorCode': 'ACCOUNT_PENDING_APPROVAL',
          'message': 'حسابك قيد المراجعة من قبل إدارة المنصة',
        }, 403);
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: TempLoginScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Verify label reflects flexible login
      expect(find.text('اسم المستخدم أو البريد الإلكتروني'), findsOneWidget);

      // Enter credentials
      final textFields = find.byType(TextField);
      expect(textFields, findsNWidgets(2));
      await tester.enterText(textFields.at(0), 'admin@jalsah.network');
      await tester.enterText(textFields.at(1), 'password123');

      // Tap login
      final loginButton = find.widgetWithText(PressableNeumorphicCard, 'تسجيل الدخول');
      await tester.tap(loginButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      // Verify transition to PendingApprovalScreen
      expect(find.text('حسابك قيد المراجعة'), findsOneWidget);
      expect(find.text('تحقق مرة أخرى'), findsOneWidget);
    });
  });

  group('SuperAdminDashboard Reactive Action Buttons', () {
    testWidgets('Super Admin dashboard provides add platform admin button',
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
                'id': 't-pending-2',
                'name': 'شبكة أم القرى',
                'slug': 'um-qura',
                'status': 'ACTIVE',
                'subscriptionStatus': 'TRIAL',
                'approvalStatus': 'PENDING',
                'maxRoutersLimit': 5,
                'usersCount': 1,
                'routersCount': 0,
                'createdAt': '2026-10-09T08:00:00.000Z',
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

      // Check "إضافة مدير منصة" action button is available in the dashboard
      expect(find.text('إضافة مدير منصة'), findsOneWidget);

      // Check tenant card action buttons
      expect(find.text('موافقة واعتماد'), findsOneWidget);
      expect(find.text('رفض الطلب'), findsOneWidget);
    });

    test('ApiClient tenant PATCH actions supply body "{}" and read backend error message', () async {
      ApiClient.client = MockClient((request) async {
        expect(request.method, equals('PATCH'));
        expect(request.headers['content-type'], contains('application/json'));
        expect(request.body, equals('{}'));

        if (request.url.path.contains('/delete')) {
          return utf8Response({
            'success': false,
            'errorCode': 'OPERATION_FAILED',
            'message': 'لا يمكن حذف الحساب الافتراضي للمنصة',
          }, 400);
        }

        return utf8Response({'success': true, 'data': {'id': 't-1'}}, 200);
      });

      final approveRes = await ApiClient.approveTenant('t-1');
      expect(approveRes['success'], isTrue);

      final deleteRes = await ApiClient.deleteTenant('t-default');
      expect(deleteRes['success'], isFalse);
      expect(deleteRes['errorMessage'], equals('لا يمكن حذف الحساب الافتراضي للمنصة'));
    });

    testWidgets('SuperAdminDashboardScreen utilizes NestedScrollView for collapsible header',
        (WidgetTester tester) async {
      ApiClient.client = MockClient((request) async {
        return utf8Response({'success': true, 'data': []}, 200);
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: SuperAdminDashboardScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(NestedScrollView), findsOneWidget);
      expect(find.byType(SliverPersistentHeader), findsOneWidget);
    });

    testWidgets('UserProfileScreen renders user details and logout option',
        (WidgetTester tester) async {
      ApiClient.client = MockClient((request) async {
        if (request.url.path == '/api/v1/auth/me') {
          return utf8Response({
            'success': true,
            'data': {
              'id': 'u-prof-1',
              'username': 'ahmed_boss',
              'fullName': 'أحمد محمد علي',
              'email': 'ahmed@jalsah.sd',
              'role': 'TENANT_ADMIN',
              'networkName': 'شبكة النيل الأزرق',
              'status': 'ACTIVE',
            },
          }, 200);
        }
        return utf8Response({'success': true, 'data': {}}, 200);
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: UserProfileScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('الملف الشخصي'), findsOneWidget);
      expect(find.text('أحمد محمد علي'), findsWidgets);
      expect(find.text('ahmed_boss'), findsOneWidget);
      expect(find.text('ahmed@jalsah.sd'), findsOneWidget);
      expect(find.text('شبكة النيل الأزرق'), findsOneWidget);
      expect(find.text('تسجيل الخروج'), findsOneWidget);
    });

    testWidgets('buildWhatsAppSupportCard renders both support numbers 0115715672 and 0115715651',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => buildWhatsAppSupportCard(context: context),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(kSupportPhone1), findsOneWidget);
      expect(find.text(kSupportPhone2), findsOneWidget);
      expect(find.text('0115715672'), findsOneWidget);
      expect(find.text('0115715651'), findsOneWidget);
    });
  });
}

