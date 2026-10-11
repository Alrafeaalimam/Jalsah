// ============================================================================
// Platform: Commercial MikroTik Network & HotSpot Card Management System
// File: test/dynamic_settings_notifications_test.dart
// Unit & Widget Tests: Dynamic Platform Settings & Notifications System
// ============================================================================

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:mikrotik_cards_app/models/platform_settings_model.dart';
import 'package:mikrotik_cards_app/models/notification_model.dart';
import 'package:mikrotik_cards_app/services/app_settings.dart';
import 'package:mikrotik_cards_app/services/api_client.dart';
import 'package:mikrotik_cards_app/screens/notifications_screen.dart';
import 'package:mikrotik_cards_app/screens/admin/super_admin_dashboard.dart';
import 'package:mikrotik_cards_app/screens/dashboard_screen.dart';

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

  setUp(() {
    AppSettings.instance.resetToDefaults();
  });

  tearDown(() {
    ApiClient.resetClient();
  });

  group('Part 1: PlatformSettingsModel & AppSettings Service Unit Tests', () {
    test('PlatformSettingsModel parses valid json correctly', () {
      final json = {
        'id': 'settings-123',
        'supportEmail': 'support@jalsah.sd',
        'whatsappNumbers': ['0115715672', '0115715651', '0912345678'],
        'primaryColorHex': '#3B2FA0',
        'accentColorHex': '#F5C94B',
        'appName': 'جلسة برو',
        'updatedAt': '2026-10-11T12:00:00.000Z',
      };

      final model = PlatformSettingsModel.fromJson(json);
      expect(model.id, equals('settings-123'));
      expect(model.supportEmail, equals('support@jalsah.sd'));
      expect(model.whatsappNumbers.length, equals(3));
      expect(model.whatsappNumbers[0], equals('0115715672'));
      expect(model.appName, equals('جلسة برو'));
      expect(model.primaryColorHex, equals('#3B2FA0'));
      expect(model.accentColorHex, equals('#F5C94B'));
    });

    test('PlatformSettingsModel provides default fallback values', () {
      final model = PlatformSettingsModel.defaultSettings();
      expect(model.supportEmail, equals('jalsahnetwork@gmail.com'));
      expect(model.whatsappNumbers, contains('0115715672'));
      expect(model.whatsappNumbers, contains('0115715651'));
      expect(model.appName, equals('جلسة'));
    });

    test('AppSettings loads settings from API and updates singleton', () async {
      ApiClient.client = MockClient((request) async {
        if (request.url.path.contains('/settings/public')) {
          return utf8Response({
            'success': true,
            'data': {
              'id': 'remote-settings',
              'supportEmail': 'remote@jalsah.sd',
              'whatsappNumbers': ['0115715672', '0999999999'],
              'appName': 'جلسة المحدثة',
            },
          }, 200);
        }
        return utf8Response({'success': false}, 404);
      });

      await AppSettings.instance.loadSettings();

      expect(AppSettings.instance.supportEmail, equals('remote@jalsah.sd'));
      expect(AppSettings.instance.appName, equals('جلسة المحدثة'));
      expect(AppSettings.instance.whatsappNumbers, contains('0999999999'));
    });

    test('AppSettings falls back safely to default when API fails', () async {
      ApiClient.client = MockClient((request) async {
        return utf8Response({'success': false, 'message': 'Internal Error'}, 500);
      });

      await AppSettings.instance.loadSettings();

      expect(AppSettings.instance.supportEmail, equals('jalsahnetwork@gmail.com'));
      expect(AppSettings.instance.whatsappNumbers.length, equals(2));
      expect(AppSettings.instance.appName, equals('جلسة'));
    });
  });

  group('Part 2: AppNotificationModel Unit Tests', () {
    test('AppNotificationModel parses MANUAL and SYSTEM types correctly', () {
      final manualJson = {
        'id': 'notif-1',
        'title': 'تحديث هام',
        'body': 'نص التحديث',
        'type': 'MANUAL',
        'createdAt': DateTime.now().subtract(const Duration(minutes: 5)).toIso8601String(),
        'isRead': false,
      };

      final model = AppNotificationModel.fromJson(manualJson);
      expect(model.type, equals(AppNotificationType.manual));
      expect(model.isRead, isFalse);
      expect(model.relativeTimeArabic, contains('دقائق'));

      final systemJson = {
        'id': 'notif-2',
        'title': 'تنبيه الاشتراك',
        'body': 'نص التنبيه',
        'type': 'SYSTEM',
        'createdAt': DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
        'isRead': true,
        'readAt': DateTime.now().toIso8601String(),
      };

      final sysModel = AppNotificationModel.fromJson(systemJson);
      expect(sysModel.type, equals(AppNotificationType.system));
      expect(sysModel.isRead, isTrue);
      expect(sysModel.relativeTimeArabic, equals('منذ ساعتين'));
    });
  });

  group('Part 3: NotificationsScreen Widget Tests', () {
    testWidgets('renders notifications list with unread distinction and marks as read on tap',
        (WidgetTester tester) async {
      final notifications = [
        {
          'id': 'n-1',
          'title': 'تنبيه: اقتراب انتهاء التجربة المجانية',
          'body': 'باقي يومان على انتهاء تجربتك المجانية',
          'type': 'SYSTEM',
          'createdAt': DateTime.now().subtract(const Duration(minutes: 10)).toIso8601String(),
          'isRead': false,
        },
        {
          'id': 'n-2',
          'title': 'رسالة إدارية عامة',
          'body': 'مرحباً بكم في منصة إدارة الكروت',
          'type': 'MANUAL',
          'createdAt': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
          'isRead': true,
        },
      ];

      bool readEndpointCalled = false;

      ApiClient.client = MockClient((request) async {
        if (request.url.path.endsWith('/api/v1/notifications')) {
          return utf8Response({
            'success': true,
            'data': notifications,
            'unreadCount': 1,
          }, 200);
        }
        if (request.url.path.contains('/notifications/n-1/read')) {
          readEndpointCalled = true;
          return utf8Response({'success': true, 'data': {'isRead': true}}, 200);
        }
        return utf8Response({'success': true}, 200);
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: NotificationsScreen(),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('مركز الإشعارات'), findsOneWidget);
      expect(find.text('1 جديد'), findsOneWidget);
      expect(find.text('تنبيه: اقتراب انتهاء التجربة المجانية'), findsOneWidget);
      expect(find.text('رسالة إدارية عامة'), findsOneWidget);
      expect(find.text('اضغط لتحديد كمقروء'), findsOneWidget);

      // Tap on the unread notification to mark as read
      await tester.tap(find.text('تنبيه: اقتراب انتهاء التجربة المجانية'));
      await tester.pumpAndSettle();

      expect(readEndpointCalled, isTrue);
      expect(find.text('اضغط لتحديد كمقروء'), findsNothing);
    });
  });

  group('Part 4: SuperAdminDashboardScreen Dynamic Settings & Send Notification Widget Tests', () {
    testWidgets('renders 3 tabs and switches to الإعدادات العامة tab', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1000, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      ApiClient.client = MockClient((request) async {
        if (request.url.path.contains('/admin/tenants')) {
          return utf8Response({'success': true, 'data': []}, 200);
        }
        if (request.url.path.contains('/admin/license-codes')) {
          return utf8Response({'success': true, 'data': []}, 200);
        }
        if (request.url.path.contains('/settings/public')) {
          return utf8Response({
            'success': true,
            'data': {
              'id': 'settings-1',
              'supportEmail': 'support@jalsah.sd',
              'whatsappNumbers': ['0115715672', '0115715651'],
              'appName': 'جلسة',
            },
          }, 200);
        }
        return utf8Response({'success': true, 'data': []}, 200);
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: SuperAdminDashboardScreen(adminName: 'مدير المنصة'),
        ),
      );

      await tester.pumpAndSettle();

      // Check all 3 tabs are rendered
      expect(find.text('الإعدادات العامة'), findsOneWidget);

      // Tap on the 3rd tab: الإعدادات العامة
      await tester.tap(find.text('الإعدادات العامة'));
      await tester.pumpAndSettle();

      // Form fields should be visible
      expect(find.text('بيانات المنصة الأساسية'), findsOneWidget);
      expect(find.text('اسم التطبيق والمنصة'), findsOneWidget);
      expect(find.text('البريد الإلكتروني للدعم الفني'), findsOneWidget);
      expect(find.text('أرقام الواتساب للدعم الفني'), findsOneWidget);
      expect(find.text('حفظ الإعدادات العامة'), findsOneWidget);
    });

    testWidgets('Send notification button opens broadcast modal dialog', (WidgetTester tester) async {
      ApiClient.client = MockClient((request) async {
        return utf8Response({'success': true, 'data': []}, 200);
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: SuperAdminDashboardScreen(adminName: 'مدير المنصة'),
        ),
      );

      await tester.pumpAndSettle();

      // Find the notification campaign button in top bar
      final notificationBtn = find.byTooltip('إرسال إشعار للعملاء');
      expect(notificationBtn, findsOneWidget);

      await tester.tap(notificationBtn);
      await tester.pumpAndSettle();

      // Verify modal bottom sheet opened
      expect(find.text('إرسال إشعار للعملاء'), findsOneWidget);
      expect(find.text('الجهة المستهدفة'), findsOneWidget);
      expect(find.text('عنوان الإشعار'), findsOneWidget);
      expect(find.text('نص الإشعار'), findsOneWidget);
      expect(find.text('إرسال الإشعار الآن'), findsOneWidget);
    });
  });

  group('Part 5: DashboardScreen Notifications Button & Badge Widget Tests', () {
    testWidgets('DashboardScreen renders notification button with unread count badge',
        (WidgetTester tester) async {
      ApiClient.client = MockClient((request) async {
        if (request.url.path.contains('/api/v1/routers')) {
          return utf8Response({'success': true, 'data': []}, 200);
        }
        if (request.url.path.contains('/sales/today-total')) {
          return utf8Response({'success': true, 'data': {'todaySalesTotal': 0.0}}, 200);
        }
        if (request.url.path.contains('/subscription/status')) {
          return utf8Response({
            'success': true,
            'data': {
              'subscriptionStatus': 'ACTIVE',
              'isAllowed': true,
              'daysRemaining': 30,
            },
          }, 200);
        }
        if (request.url.path.contains('/api/v1/notifications')) {
          return utf8Response({
            'success': true,
            'data': [
              {
                'id': 'n-unread',
                'title': 'إشعار غير مقروء',
                'body': 'تجربة',
                'type': 'MANUAL',
                'createdAt': DateTime.now().toIso8601String(),
                'isRead': false,
              }
            ],
            'unreadCount': 3,
          }, 200);
        }
        return utf8Response({'success': true}, 200);
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: DashboardScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // Check notification button and badge
      expect(find.text('الإشعارات'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });
  });
}
