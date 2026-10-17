import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mikrotik_cards_app/screens/packages_screen.dart';
import 'package:mikrotik_cards_app/screens/staff_screen.dart';
import 'package:mikrotik_cards_app/screens/cards_list_screen.dart';
import 'package:mikrotik_cards_app/screens/sales_report_screen.dart';
import 'package:mikrotik_cards_app/screens/splash_video_screen.dart';
import 'package:mikrotik_cards_app/screens/dashboard_screen.dart';
import 'package:mikrotik_cards_app/screens/user_profile_screen.dart';
import 'package:mikrotik_cards_app/services/api_client.dart';

http.Response utf8Response(Map<String, dynamic> data, int statusCode) {
  return http.Response.bytes(
    utf8.encode(jsonEncode(data)),
    statusCode,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

const String adminJwt =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VySWQiOiJmYWY0MmQ3MC1kMTIyLTQwZWItODA3NS05OTk0NDFmZDcwOTYiLCJ0ZW5hbnRJZCI6IjM3MmM2ZDg0LWI2N2QtNGFkMC04ODdjLTFhZmNkNmE4ZTViYSIsInJvbGUiOiJURU5BTlRfQURNSU4iLCJpYXQiOjE3OTExMDY1MTAsImV4cCI6MTc5MTE5MjkxMH0.I64Lx82TJeypWEFOrHSTkqmkrSneA99zlISbNgFDGTo';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({'has_seen_onboarding': true});
    GoogleFonts.config.allowRuntimeFetching = false;

    try {
      final fontLoaderCairo = FontLoader('Cairo');
      final arabicFontBytes =
          File('/system/fonts/NotoNaskhArabicUI-Regular.ttf').readAsBytesSync();
      fontLoaderCairo
          .addFont(Future.value(ByteData.sublistView(arabicFontBytes)));
      await fontLoaderCairo.load();

      final iconLoader = FontLoader('MaterialIcons');
      final iconBytes = File(
              '/data/data/com.termux/files/home/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf')
          .readAsBytesSync();
      iconLoader.addFont(Future.value(ByteData.sublistView(iconBytes)));
      await iconLoader.load();
    } catch (e) {
      debugPrint('Font loading notice: $e');
    }
  });

  setUp(() {
    ApiClient.setAuthToken(adminJwt);
  });

  tearDown(() {
    ApiClient.resetClient();
  });

  Future<void> captureWidget({
    required WidgetTester tester,
    required Widget widget,
    required String outputPath,
  }) async {
    final GlobalKey repaintKey = GlobalKey();

    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 2.0;

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: RepaintBoundary(
          key: repaintKey,
          child: widget,
        ),
      ),
    );

    // Pump frames to complete build & future
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    final boundary = repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary != null) {
      await tester.runAsync(() async {
        final ui.Image image = await boundary.toImage(pixelRatio: 1.0);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData != null) {
          File(outputPath).writeAsBytesSync(byteData.buffer.asUint8List());
          debugPrint('Captured screenshot to: $outputPath (${byteData.lengthInBytes} bytes)');
        }
      });
    }

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  }

  testWidgets('Capture PackagesScreen', (tester) async {
    ApiClient.client = MockClient((request) async {
      return utf8Response({
        'success': true,
        'data': [
          {
            'id': 'pkg-1',
            'name': 'باقة 10 جيجا سريعة',
            'profileName': 'profile-10g',
            'price': 15.0,
            'validityDays': 30,
            'trafficLimit': '10 GB',
            'isActive': true,
            'createdAt': DateTime.now().toIso8601String(),
          },
          {
            'id': 'pkg-2',
            'name': 'باقة يومية غير محدودة',
            'profileName': 'profile-unlim-1d',
            'price': 5.0,
            'validityDays': 1,
            'trafficLimit': 'غير محدود',
            'isActive': true,
            'createdAt': DateTime.now().toIso8601String(),
          },
        ],
      }, 200);
    });

    await captureWidget(
      tester: tester,
      widget: const PackagesScreen(),
      outputPath: 'reports/screen_packages.png',
    );
  });

  testWidgets('Capture StaffScreen', (tester) async {
    ApiClient.client = MockClient((request) async {
      return utf8Response({
        'success': true,
        'data': [
          {
            'id': 'user-1',
            'username': 'admin',
            'fullName': 'مدير النظام',
            'role': 'TENANT_ADMIN',
            'status': 'ACTIVE',
            'isActive': true,
            'createdAt': DateTime.now().toIso8601String(),
          },
          {
            'id': 'user-2',
            'username': 'ali_engineer',
            'fullName': 'مهندس الشبكة علي',
            'role': 'OPERATOR',
            'status': 'ACTIVE',
            'isActive': true,
            'createdAt': DateTime.now().toIso8601String(),
          },
        ],
      }, 200);
    });

    await captureWidget(
      tester: tester,
      widget: const StaffScreen(),
      outputPath: 'reports/screen_staff.png',
    );
  });

  testWidgets('Capture CardsListScreen', (tester) async {
    ApiClient.client = MockClient((request) async {
      if (request.url.path.contains('packages')) {
        return utf8Response({
          'success': true,
          'data': [
            {
              'id': 'pkg-1',
              'name': 'باقة 10 جيجا سريعة',
              'profileName': 'profile-10g',
              'price': 15.0,
              'validityDays': 30,
              'trafficLimit': '10 GB',
              'isActive': true,
              'createdAt': DateTime.now().toIso8601String(),
            }
          ],
        }, 200);
      }
      return utf8Response({
        'success': true,
        'data': [
          {
            'id': 'c-1',
            'username': 'card-884920',
            'password': '••••',
            'status': 'AVAILABLE',
            'price': 10.0,
            'packageId': 'pkg-1',
            'batchId': 'batch-01',
            'createdAt': DateTime.now().toIso8601String(),
          },
          {
            'id': 'c-2',
            'username': 'card-331209',
            'password': '••••',
            'status': 'SOLD',
            'price': 15.0,
            'packageId': 'pkg-1',
            'batchId': 'batch-01',
            'createdAt': DateTime.now().toIso8601String(),
          },
        ],
      }, 200);
    });

    await captureWidget(
      tester: tester,
      widget: const CardsListScreen(),
      outputPath: 'reports/screen_cards.png',
    );
  });

  testWidgets('Capture SalesReportScreen', (tester) async {
    ApiClient.client = MockClient((request) async {
      return utf8Response({
        'success': true,
        'data': [
          {
            'id': 's-1',
            'totalAmount': 15.0,
            'paymentMethod': 'CASH',
            'soldByName': 'مهندس الشبكة علي',
            'cardsCount': 1,
            'createdAt': DateTime.now().toIso8601String(),
          },
          {
            'id': 's-2',
            'totalAmount': 5.0,
            'paymentMethod': 'CASH',
            'soldByName': 'مدير النظام',
            'cardsCount': 1,
            'createdAt': DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
          },
        ],
      }, 200);
    });

    await captureWidget(
      tester: tester,
      widget: const SalesReportScreen(),
      outputPath: 'reports/screen_sales.png',
    );
  });

  testWidgets('Capture SplashVideoScreen', (tester) async {
    await captureWidget(
      tester: tester,
      widget: const SplashVideoScreen(),
      outputPath: 'reports/screen_splash.png',
    );
  });

  testWidgets('Capture DashboardScreen', (tester) async {
    ApiClient.client = MockClient((request) async {
      if (request.url.path.contains('sales/today-total')) {
        return utf8Response({
          'success': true,
          'data': {
            'todayTotal': 18400.0,
          },
        }, 200);
      }
      if (request.url.path.contains('routers')) {
        return utf8Response({
          'success': true,
          'data': [
            {
              'id': 'r-1',
              'name': 'الراوتر الرئيسي - صالة 1',
              'host': '192.168.88.1',
              'apiPort': 8728,
              'status': 'ONLINE',
              'boardModel': 'RB4011iGS+',
              'routerOsVersion': 'v7.12',
            },
            {
              'id': 'r-2',
              'name': 'راوتر الفرع الشرقي',
              'host': '192.168.89.1',
              'apiPort': 8728,
              'status': 'ONLINE',
              'boardModel': 'hEX S',
              'routerOsVersion': 'v7.11',
            },
            {
              'id': 'r-3',
              'name': 'راوتر الحديقة الخارجية',
              'host': '192.168.90.1',
              'apiPort': 8728,
              'status': 'OFFLINE',
              'boardModel': 'cAP ac',
              'routerOsVersion': 'v6.49',
            },
          ],
        }, 200);
      }
      return utf8Response({'success': true, 'data': []}, 200);
    });

    await captureWidget(
      tester: tester,
      widget: const DashboardScreen(userName: 'المدير العام'),
      outputPath: 'reports/screen_dashboard.png',
    );
  });

  testWidgets('Capture UserProfileScreen', (tester) async {
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

    await captureWidget(
      tester: tester,
      widget: const UserProfileScreen(),
      outputPath: 'reports/screen_user_profile.png',
    );
  });
}
