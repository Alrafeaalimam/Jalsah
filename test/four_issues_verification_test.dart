import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:mikrotik_cards_app/models/discovered_router_model.dart';
import 'package:mikrotik_cards_app/screens/add_router_screen.dart';
import 'package:mikrotik_cards_app/screens/admin/super_admin_dashboard.dart';
import 'package:mikrotik_cards_app/screens/subscription_plans_screen.dart';
import 'package:mikrotik_cards_app/screens/user_profile_screen.dart';
import 'package:mikrotik_cards_app/services/api_client.dart';
import 'package:mikrotik_cards_app/services/mikrotik_discovery_service.dart';

http.Response utf8Response(Map<String, dynamic> data, int statusCode) {
  return http.Response.bytes(
    utf8.encode(jsonEncode(data)),
    statusCode,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    ApiClient.setAuthToken('test-token-jwt');
  });

  tearDown(() {
    ApiClient.resetClient();
  });

  // ==========================================================================
  // ISSUE 1: MikroTik Router Discovery & Direct Connection
  // ==========================================================================
  group('Issue 1: MikroTik Router Discovery Tests', () {
    test('isLocalPrivateIp correctly identifies RFC1918 private IPv4 addresses', () {
      // 192.168.x.x
      expect(MikrotikDiscoveryService.isLocalPrivateIp('192.168.88.1'), isTrue);
      expect(MikrotikDiscoveryService.isLocalPrivateIp('192.168.1.1'), isTrue);
      expect(MikrotikDiscoveryService.isLocalPrivateIp('192.168.0.254'), isTrue);

      // 10.x.x.x
      expect(MikrotikDiscoveryService.isLocalPrivateIp('10.0.0.1'), isTrue);
      expect(MikrotikDiscoveryService.isLocalPrivateIp('10.10.10.1'), isTrue);

      // 172.16.x.x - 172.31.x.x
      expect(MikrotikDiscoveryService.isLocalPrivateIp('172.16.0.1'), isTrue);
      expect(MikrotikDiscoveryService.isLocalPrivateIp('172.31.255.254'), isTrue);
      expect(MikrotikDiscoveryService.isLocalPrivateIp('172.32.0.1'), isFalse);

      // Public IPs
      expect(MikrotikDiscoveryService.isLocalPrivateIp('8.8.8.8'), isFalse);
      expect(MikrotikDiscoveryService.isLocalPrivateIp('1.1.1.1'), isFalse);
      expect(MikrotikDiscoveryService.isLocalPrivateIp('alrafeerouter.zone.id'), isFalse);
      expect(MikrotikDiscoveryService.isLocalPrivateIp(''), isFalse);
    });

    test('getCandidateGatewayIps returns default MikroTik IP and common subnets', () async {
      final candidates = await MikrotikDiscoveryService.getCandidateGatewayIps();
      expect(candidates, contains('192.168.88.1'));
      expect(candidates, contains('192.168.1.1'));
      expect(candidates, contains('10.0.0.1'));
      expect(candidates, contains('172.16.0.1'));
    });

    test('DiscoveredRouterModel formats model and version correctly', () {
      final router = DiscoveredRouterModel(
        host: '192.168.88.1',
        port: 80,
        isMikrotik: true,
        identity: 'MikroTik-Main-Office',
        boardName: 'hEX lite (RB750r2)',
        version: '7.12.1 (stable)',
        cpu: 'MIPS 24Kc V7.4',
        uptime: '2w4d',
        platform: 'MikroTik',
        authRequired: true,
      );

      expect(router.displayName, equals('MikroTik-Main-Office'));
      expect(router.displaySpecs, contains('hEX lite (RB750r2)'));
      expect(router.displaySpecs, contains('v7.12.1 (stable)'));

      final json = router.toJson();
      final restored = DiscoveredRouterModel.fromJson(json);
      expect(restored.host, equals('192.168.88.1'));
      expect(restored.identity, equals('MikroTik-Main-Office'));
      expect(restored.isMikrotik, isTrue);
    });

    testWidgets('AddRouterScreen shows radar discovery action and discovery prompt card', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: AddRouterScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Check AppBar has radar discovery action (and card has radar icon)
      expect(find.byIcon(Icons.radar_rounded), findsWidgets);

      // Check Discovery Card is rendered at the top
      expect(find.text('اكتشاف راوتر MikroTik في الشبكة المحلية'), findsOneWidget);
      expect(find.text('بحث واكتشاف الراوتر تلقائياً'), findsOneWidget);
      expect(find.text('إضافة راوتر جديد'), findsOneWidget);
    });
  });

  // ==========================================================================
  // ISSUE 2: Profile Picture Selection and Display
  // ==========================================================================
  group('Issue 2: Profile Picture Selection & Upload Tests', () {
    testWidgets('UserProfileScreen renders change avatar button and modal with gallery/camera options', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      ApiClient.client = MockClient((request) async {
        return utf8Response({
          'success': true,
          'data': {
            'id': 'u-avatar-1',
            'username': 'avatar_user',
            'fullName': 'طارق بشير النور',
            'email': 'tareq@jalsah.sd',
            'role': 'TENANT_ADMIN',
            'networkName': 'شبكة المستقبل',
            'status': 'ACTIVE',
            'avatarUrl': null,
          },
        }, 200);
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: UserProfileScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Find camera edit button
      final cameraIconFinder = find.byIcon(Icons.camera_alt_rounded);
      expect(cameraIconFinder, findsOneWidget);

      // Tap on avatar edit button to open modal bottom sheet
      await tester.tap(cameraIconFinder);
      await tester.pumpAndSettle();

      // Verify gallery and camera picker options are available
      expect(find.text('تغيير الصورة الشخصية'), findsOneWidget);
      expect(find.text('اختيار من معرض الصور'), findsOneWidget);
      expect(find.text('التقاط صورة بالكاميرا'), findsOneWidget);

      // Dismiss sheet by tapping top background
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();
      expect(find.text('تغيير الصورة الشخصية'), findsNothing);
    });
  });

  // ==========================================================================
  // ISSUE 3: Display Subscription Plans with Loading/Empty/Error/Success States
  // ==========================================================================
  group('Issue 3: Subscription Plans Screen Tests', () {
    testWidgets('SubscriptionPlansScreen displays empty state when backend returns 0 plans', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      ApiClient.client = MockClient((request) async {
        if (request.url.path.contains('/api/v1/subscription/plans')) {
          return utf8Response({
            'success': true,
            'data': [],
          }, 200);
        }
        return utf8Response({'success': true, 'data': {}}, 200);
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: SubscriptionPlansScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Verify empty state is rendered clearly
      expect(find.text('لا توجد باقات اشتراك متاحة حالياً'), findsOneWidget);
      expect(find.text('تحديث الباقات'), findsOneWidget);
    });

    testWidgets('SubscriptionPlansScreen displays error state with retry button on network failure', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      ApiClient.client = MockClient((request) async {
        return utf8Response({
          'success': false,
          'message': 'تعذر الاتصال بخادم الاشتراكات',
        }, 500);
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: SubscriptionPlansScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('إعادة المحاولة'), findsOneWidget);
    });

    testWidgets('SubscriptionPlansScreen displays real plans with price, duration, and capacity', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      ApiClient.client = MockClient((request) async {
        if (request.url.path.contains('/api/v1/subscription/plans')) {
          return utf8Response({
            'success': true,
            'data': [
              {
                'id': 'plan-starter-1',
                'name': 'الباقة الأساسية التجارية',
                'durationDays': 30,
                'price': 15000,
                'currency': 'SDG',
                'description': 'مناسبة للشبكات الصغيرة والمتوسطة',
                'maxRoutersLimit': 3,
                'isActive': true,
              },
              {
                'id': 'plan-pro-2',
                'name': 'الباقة الاحترافية غير المحدودة',
                'durationDays': 90,
                'price': 40000,
                'currency': 'SDG',
                'description': 'دعم موسع وعدد راوترات أكبر',
                'maxRoutersLimit': 10,
                'isActive': true,
              },
            ],
          }, 200);
        }
        return utf8Response({'success': true, 'data': {}}, 200);
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: SubscriptionPlansScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('الباقة الأساسية التجارية'), findsOneWidget);
      expect(find.text('الباقة الاحترافية غير المحدودة'), findsOneWidget);
      expect(find.text('15000 SDG'), findsOneWidget);
      expect(find.text('40000 SDG'), findsOneWidget);
      expect(find.textContaining('30 يوم'), findsOneWidget);
      expect(find.textContaining('90 يوم'), findsOneWidget);
      expect(find.textContaining('3 أجهزة راوتر'), findsOneWidget);
      expect(find.textContaining('10 أجهزة راوتر'), findsOneWidget);
    });
  });

  // ==========================================================================
  // ISSUE 4: Super Admin Subscription Plan & Pricing Management
  // ==========================================================================
  group('Issue 4: Super Admin Subscription Plan Management Tests', () {
    testWidgets('SuperAdminDashboardScreen renders 4 tabs including Subscription Plans', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      ApiClient.client = MockClient((request) async {
        final path = request.url.path;
        if (path.contains('/api/v1/admin/tenants')) {
          return utf8Response({'success': true, 'data': []}, 200);
        }
        if (path.contains('/api/v1/admin/license-codes')) {
          return utf8Response({'success': true, 'data': []}, 200);
        }
        if (path.contains('/api/v1/admin/subscription-plans')) {
          return utf8Response({
            'success': true,
            'data': [
              {
                'id': 'plan-adm-1',
                'name': 'باقة رواد الأعمال',
                'durationDays': 30,
                'price': 20000,
                'currency': 'SDG',
                'description': 'إدارة احترافية للشبكات',
                'maxRoutersLimit': 5,
                'isActive': true,
              },
            ],
          }, 200);
        }
        if (path.contains('/api/v1/admin/settings')) {
          return utf8Response({'success': true, 'data': {}}, 200);
        }
        return utf8Response({'success': true, 'data': {}}, 200);
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: SuperAdminDashboardScreen(),
        ),
      );
      for (int i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Verify the 4 tabs are present
      expect(find.textContaining('الشركات والشبكات'), findsWidgets);
      expect(find.textContaining('أكواد الترخيص'), findsWidgets);
      expect(find.textContaining('باقات الاشتراك'), findsWidgets);
      expect(find.textContaining('الإعدادات العامة'), findsWidgets);

      // Tap on Tab index 1: باقات الاشتراك
      await tester.tap(find.byType(Tab).at(1), warnIfMissed: false);
      for (int i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Verify Plan is displayed and Add Plan button exists
      expect(find.text('باقة رواد الأعمال'), findsOneWidget);
      expect(find.text('إضافة باقة اشتراك جديدة'), findsOneWidget);
      expect(find.textContaining('20000 SDG'), findsOneWidget);
      expect(find.textContaining('30 يوم'), findsOneWidget);
    });
  });
}
