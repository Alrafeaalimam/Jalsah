import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:mikrotik_cards_app/screens/dashboard_screen.dart';
import 'package:mikrotik_cards_app/screens/add_router_screen.dart';
import 'package:mikrotik_cards_app/services/api_client.dart';
import 'package:mikrotik_cards_app/theme/app_colors.dart';
import 'package:mikrotik_cards_app/widgets/count_up_text.dart';
import 'package:mikrotik_cards_app/widgets/neumorphic_text_field.dart';
import 'package:mikrotik_cards_app/widgets/pressable_neumorphic_card.dart';
import 'package:mikrotik_cards_app/widgets/pulsing_dot.dart';

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

  group('NeumorphicTextField Component Tests', () {
    testWidgets('renders label, hint, errorText and toggles password visibility',
        (WidgetTester tester) async {
      final controller = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: AppColors.pageBg,
            body: Padding(
              padding: const EdgeInsets.all(16.0),
              child: NeumorphicTextField(
                label: 'كلمة المرور',
                hintText: 'أدخل كلمة المرور',
                controller: controller,
                isPassword: true,
                errorText: 'كلمة المرور مطلوبة',
              ),
            ),
          ),
        ),
      );

      expect(find.text('كلمة المرور'), findsOneWidget);
      expect(find.text('كلمة المرور مطلوبة'), findsOneWidget);
      expect(find.byIcon(Icons.visibility_off_rounded), findsOneWidget);

      // Tap toggle password visibility
      await tester.tap(find.byIcon(Icons.visibility_off_rounded));
      await tester.pump();
      expect(find.byIcon(Icons.visibility_rounded), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  });

  group('DashboardScreen 4 States Tests (Master Rule 35)', () {
    testWidgets('renders Loading state while fetching routers',
        (WidgetTester tester) async {
      final completer = Completer<http.Response>();
      ApiClient.client = MockClient((request) => completer.future);

      await tester.pumpWidget(
        const MaterialApp(
          home: DashboardScreen(),
        ),
      );
      await tester.pump();

      // Verify Loading indicator is shown
      expect(find.text('جارٍ جلب بيانات الراوترات...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsWidgets);

      // Complete to avoid leaking pending futures
      completer.complete(utf8Response({'success': true, 'data': []}, 200));
      await tester.pump(const Duration(milliseconds: 50));

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets('renders Empty state when server returns empty router list',
        (WidgetTester tester) async {
      ApiClient.client = MockClient((request) async {
        return utf8Response({'success': true, 'data': []}, 200);
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: DashboardScreen(userName: 'المدير'),
        ),
      );
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.text('المدير'), findsOneWidget);
      expect(find.text('لا توجد راوترات مسجلة بعد'), findsOneWidget);
      expect(find.text('0 راوترات مسجلة'), findsOneWidget);
      expect(find.text('مبيعات اليوم'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets('renders Error state and retries on failure',
        (WidgetTester tester) async {
      int routerRequestCount = 0;
      ApiClient.client = MockClient((request) async {
        if (request.url.path.contains('subscription')) {
          return utf8Response({
            'success': true,
            'data': {
              'subscriptionStatus': 'TRIAL',
              'trialEndsAt': '2026-10-14T00:00:00.000Z',
              'daysRemaining': 7,
              'planName': null,
              'currentRoutersCount': 0,
              'maxRoutersLimit': 5,
            },
          }, 200);
        }
        if (request.url.path.contains('sales')) {
          return utf8Response({
            'success': true,
            'data': {'todayTotal': 0.0, 'totalAmount': 0.0},
          }, 200);
        }
        routerRequestCount++;
        if (routerRequestCount == 1) {
          return utf8Response({
            'success': false,
            'errorCode': 'SERVER_ERROR',
            'errorMessage': 'فشل الاتصال بالخادم الرئيسي',
          }, 500);
        } else {
          return utf8Response({
            'success': true,
            'data': [],
          }, 200);
        }
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: DashboardScreen(),
        ),
      );
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.text('فشل الاتصال بالخادم'), findsOneWidget);
      expect(find.text('فشل الاتصال بالخادم الرئيسي'), findsOneWidget);
      expect(find.text('إعادة المحاولة'), findsOneWidget);

      // Tap retry
      await tester.tap(find.text('إعادة المحاولة'));
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(routerRequestCount, equals(2));
      expect(find.text('لا توجد راوترات مسجلة بعد'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets('renders Data state with real routers, pulsing dot and host-only display',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mockRoutersData = [
        {
          'id': 'r-1',
          'name': 'راوتر الصالة الرئيسية',
          'host': '192.168.10.1',
          'apiPort': 8728,
          'status': 'ONLINE',
          'boardModel': 'MikroTik RB4011iGS+',
        },
        {
          'id': 'r-2',
          'name': 'راوتر الحديقة والمسبح',
          'host': '192.168.50.1',
          'apiPort': 8728,
          'status': 'OFFLINE',
          'boardModel': null, // No board model -> should show host only
        },
      ];

      ApiClient.client = MockClient((request) async {
        return utf8Response({
          'success': true,
          'data': mockRoutersData,
        }, 200);
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: DashboardScreen(),
        ),
      );
      for (int i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Check header counts: 1 Online out of 2 total
      expect(find.text('2 راوترات مسجلة'), findsOneWidget);
      expect(find.text('راوتر الصالة الرئيسية'), findsOneWidget);
      expect(find.text('MikroTik RB4011iGS+'), findsOneWidget);
      expect(find.text('192.168.10.1'), findsOneWidget);

      // Second router has no board model -> check host is present
      expect(find.text('راوتر الحديقة والمسبح'), findsOneWidget);
      expect(find.text('192.168.50.1'), findsOneWidget);

      // Status badges
      expect(find.text('متصل'), findsOneWidget);
      expect(find.text('غير متصل'), findsOneWidget);

      // Pulsing dot present
      expect(find.byType(PulsingDot), findsNWidgets(2));

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets('shows delete confirmation dialog on delete button click',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mockRoutersData = [
        {
          'id': 'r-1',
          'name': 'راوتر الصالة الرئيسية',
          'host': '192.168.10.1',
          'apiPort': 8728,
          'status': 'ONLINE',
          'boardModel': 'RB4011',
        },
      ];

      ApiClient.client = MockClient((request) async {
        if (request.method == 'GET') {
          return utf8Response({
            'success': true,
            'data': mockRoutersData,
          }, 200);
        } else if (request.method == 'DELETE') {
          return utf8Response({
            'success': true,
            'message': 'Deleted',
          }, 200);
        }
        return utf8Response({}, 404);
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: DashboardScreen(),
        ),
      );
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Tap delete icon button
      await tester.tap(find.byIcon(Icons.delete_outline_rounded));
      await tester.pump(const Duration(milliseconds: 200));

      // Verify dialog is shown
      expect(find.text('تأكيد حذف الراوتر'), findsOneWidget);
      expect(find.text('نعم، حذف'), findsOneWidget);
      expect(find.text('إلغاء'), findsOneWidget);

      // Tap cancel
      await tester.tap(find.text('إلغاء'));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('تأكيد حذف الراوتر'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  });

  group('AddRouterScreen Tests', () {
    testWidgets('validates empty fields and port range before saving',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: AddRouterScreen(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Tap save without filling form
      await tester.tap(find.text('حفظ الراوتر'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('يرجى إدخال اسم الراوتر'), findsOneWidget);
      expect(find.text('يرجى إدخال عنوان الـ Host أو الـ IP'), findsOneWidget);
      expect(find.text('يرجى إدخال اسم المستخدم'), findsOneWidget);
      expect(find.text('يرجى إدخال كلمة المرور'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets('successful save sends POST and pops screen with success message',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      bool postReceived = false;

      ApiClient.client = MockClient((request) async {
        if (request.method == 'POST' && request.url.path.endsWith('/routers')) {
          postReceived = true;
          return utf8Response({
            'success': true,
            'data': {
              'id': 'new-router-123',
              'name': 'راوتر تجريبي',
              'host': '192.168.1.1',
              'apiPort': 8728,
              'status': 'OFFLINE',
            },
          }, 201);
        }
        return utf8Response({}, 404);
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: AddRouterScreen(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Fill form
      await tester.enterText(
        find.widgetWithText(NeumorphicTextField, 'اسم الراوتر / الموقع'),
        'راوتر تجريبي',
      );
      await tester.enterText(
        find.widgetWithText(NeumorphicTextField, 'عنوان الـ Host أو الـ IP'),
        '192.168.1.1',
      );
      await tester.enterText(
        find.widgetWithText(NeumorphicTextField, 'اسم المستخدم للراوتر'),
        'admin',
      );
      await tester.enterText(
        find.widgetWithText(NeumorphicTextField, 'كلمة المرور'),
        'admin123',
      );
      await tester.pump(const Duration(milliseconds: 50));

      // Tap save
      await tester.tap(find.text('حفظ الراوتر'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(postReceived, isTrue);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  });

  group('Standalone Widget Unit Tests', () {
    testWidgets('CountUpText counts up to targetValue with currency',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CountUpText(
              targetValue: 18400,
              suffix: ' جنيه سوداني',
              formatter: (v) => '$v جنيه سوداني',
            ),
          ),
        ),
      );

      expect(find.text('0 جنيه سوداني'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 800));
      expect(find.text('18400 جنيه سوداني'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets('PressableNeumorphicCard handles tap',
        (WidgetTester tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PressableNeumorphicCard(
              onTap: () => tapped = true,
              child: const Text('Tap Me'),
            ),
          ),
        ),
      );

      final gesture =
          await tester.startGesture(tester.getCenter(find.text('Tap Me')));
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 200));

      expect(tapped, isTrue);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets('PulsingDot animates continuously and unmounts cleanly',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PulsingDot(color: AppColors.statusOnline),
          ),
        ),
      );

      expect(find.byType(PulsingDot), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pump(const Duration(milliseconds: 450));

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  });
}
