// ============================================================================
// Platform: Commercial MikroTik Network & HotSpot Card Management System
// File: test/packages_test.dart
// Unit & Widget Tests: Packages Screen, PackageModel & ApiClient Package CRUD
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:mikrotik_cards_app/models/package_model.dart';
import 'package:mikrotik_cards_app/screens/dashboard_screen.dart';
import 'package:mikrotik_cards_app/screens/packages_screen.dart';
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

  group('PackageModel Unit Tests', () {
    test('fromJson correctly parses all attributes with valid types', () {
      final json = {
        'id': 'pkg-1',
        'name': 'يومية 5 ميجا',
        'code': 'PKG-DAILY-5M',
        'downloadSpeedLimit': '5M',
        'uploadSpeedLimit': '2M',
        'durationMinutes': 1440,
        'validityDays': 1,
        'dataLimitBytes': 5368709120,
        'price': 500.0,
        'hotspotProfileName': 'hs_daily_5m',
        'isActive': true,
        'currency': 'SDG',
        'simultaneousSessions': 1,
      };

      final model = PackageModel.fromJson(json);

      expect(model.id, equals('pkg-1'));
      expect(model.name, equals('يومية 5 ميجا'));
      expect(model.code, equals('PKG-DAILY-5M'));
      expect(model.downloadSpeedLimit, equals('5M'));
      expect(model.uploadSpeedLimit, equals('2M'));
      expect(model.durationMinutes, equals(1440));
      expect(model.validityDays, equals(1));
      expect(model.dataLimitBytes, equals(5368709120));
      expect(model.price, equals(500.0));
      expect(model.hotspotProfileName, equals('hs_daily_5m'));
      expect(model.isActive, isTrue);
      expect(model.formattedPrice, equals('500 SDG'));
      expect(model.formattedSpeed, equals('5M / 2M'));
      expect(model.formattedDuration, equals('1 يوم'));
    });

    test('toJson serializes model correctly', () {
      const model = PackageModel(
        id: 'pkg-2',
        name: 'أسبوعية 10 ميجا',
        code: 'PKG-WEEKLY-10M',
        downloadSpeedLimit: '10M',
        uploadSpeedLimit: '5M',
        durationMinutes: 10080,
        validityDays: 7,
        price: 2500,
        hotspotProfileName: 'hs_weekly_10m',
        isActive: false,
      );

      final json = model.toJson();
      expect(json['id'], equals('pkg-2'));
      expect(json['name'], equals('أسبوعية 10 ميجا'));
      expect(json['durationMinutes'], equals(10080));
      expect(json['isActive'], isFalse);
      expect(model.formattedDuration, equals('7 أيام'));
    });
  });

  group('ApiClient Package CRUD Methods Unit Tests', () {
    test('getPackages returns success with list of PackageModel', () async {
      ApiClient.client = MockClient((request) async {
        expect(request.url.path, endsWith('/api/v1/packages'));
        return utf8Response({
          'success': true,
          'data': [
            {
              'id': 'p1',
              'name': 'باقة 1',
              'code': 'P1',
              'downloadSpeedLimit': '5M',
              'uploadSpeedLimit': '2M',
              'durationMinutes': 60,
              'validityDays': 1,
              'price': 100,
              'hotspotProfileName': 'hs_p1',
              'isActive': true,
            }
          ],
        }, 200);
      });

      final result = await ApiClient.getPackages();
      expect(result['success'], isTrue);
      expect(result['data'], isA<List<PackageModel>>());
      final list = result['data'] as List<PackageModel>;
      expect(list.length, equals(1));
      expect(list.first.name, equals('باقة 1'));
    });

    test('createPackage returns success on 201 Created', () async {
      ApiClient.client = MockClient((request) async {
        expect(request.method, equals('POST'));
        expect(request.url.path, endsWith('/api/v1/packages'));
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['name'], equals('باقة جديدة'));
        return utf8Response({
          'success': true,
          'data': {
            'id': 'new-pkg-id',
            ...body,
          },
        }, 201);
      });

      final result = await ApiClient.createPackage(
        name: 'باقة جديدة',
        code: 'NEW-PKG',
        downloadSpeedLimit: '10M',
        uploadSpeedLimit: '5M',
        durationMinutes: 1440,
        validityDays: 1,
        price: 750,
        hotspotProfileName: 'hs_new',
      );

      expect(result['success'], isTrue);
      expect(result['data'], isA<PackageModel>());
      final pkg = result['data'] as PackageModel;
      expect(pkg.id, equals('new-pkg-id'));
      expect(pkg.name, equals('باقة جديدة'));
    });

    test('createPackage handles 409 code conflict', () async {
      ApiClient.client = MockClient((request) async {
        return utf8Response({
          'success': false,
          'errorCode': 'PACKAGE_CODE_EXISTS',
          'errorMessage': 'A package with this code already exists for this tenant',
        }, 409);
      });

      final result = await ApiClient.createPackage(
        name: 'باقة مكررة',
        code: 'EXISTING-CODE',
        downloadSpeedLimit: '10M',
        uploadSpeedLimit: '5M',
        durationMinutes: 1440,
        validityDays: 1,
        price: 750,
        hotspotProfileName: 'hs_new',
      );

      expect(result['success'], isFalse);
      expect(result['errorCode'], equals('PACKAGE_CODE_EXISTS'));
      expect(result['errorMessage'], contains('كود الباقة مسجل مسبقاً'));
    });

    test('deletePackage returns success on 200 OK', () async {
      ApiClient.client = MockClient((request) async {
        expect(request.method, equals('DELETE'));
        expect(request.url.path, endsWith('/api/v1/packages/pkg-123'));
        return utf8Response({
          'success': true,
          'message': 'Package deleted successfully',
        }, 200);
      });

      final result = await ApiClient.deletePackage('pkg-123');
      expect(result['success'], isTrue);
      expect(result['message'], equals('Package deleted successfully'));
    });
  });

  group('PackagesScreen 4 States Tests (Master Rule 35)', () {
    testWidgets('renders Loading state while fetching packages',
        (WidgetTester tester) async {
      final completer = Completer<http.Response>();
      ApiClient.client = MockClient((request) => completer.future);

      await tester.pumpWidget(
        const MaterialApp(
          home: PackagesScreen(),
        ),
      );
      await tester.pump();

      expect(find.text('جارٍ جلب باقات الإنترنت...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsWidgets);

      completer.complete(utf8Response({'success': true, 'data': []}, 200));
      await tester.pump(const Duration(milliseconds: 50));

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets('renders Empty state when server returns empty package list',
        (WidgetTester tester) async {
      ApiClient.client = MockClient((request) async {
        return utf8Response({'success': true, 'data': []}, 200);
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: PackagesScreen(),
        ),
      );
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.text('لا توجد باقات مسجلة بعد'), findsOneWidget);
      expect(find.text('0 باقة مسجلة'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets('renders Error state and retries on failure',
        (WidgetTester tester) async {
      int requestCount = 0;
      ApiClient.client = MockClient((request) async {
        requestCount++;
        if (requestCount == 1) {
          return utf8Response({
            'success': false,
            'errorCode': 'SERVER_ERROR',
            'errorMessage': 'تعذر الاتصال بقاعدة بيانات الباقات',
          }, 500);
        } else {
          return utf8Response({'success': true, 'data': []}, 200);
        }
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: PackagesScreen(),
        ),
      );
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.text('فشل الاتصال بالخادم'), findsOneWidget);
      expect(find.text('تعذر الاتصال بقاعدة بيانات الباقات'), findsOneWidget);
      expect(find.text('إعادة المحاولة'), findsOneWidget);

      // Tap retry
      await tester.tap(find.text('إعادة المحاولة'));
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(requestCount, equals(2));
      expect(find.text('لا توجد باقات مسجلة بعد'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets('renders Data state with packages cards and active/inactive badges',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mockPackagesData = [
        {
          'id': 'pkg-1',
          'name': 'يومية 5 ميجا',
          'code': 'PKG-DAILY-5M',
          'downloadSpeedLimit': '5M',
          'uploadSpeedLimit': '2M',
          'durationMinutes': 1440,
          'validityDays': 1,
          'price': 500.0,
          'hotspotProfileName': 'hs_daily_5m',
          'isActive': true,
        },
        {
          'id': 'pkg-2',
          'name': 'أسبوعية 10 ميجا',
          'code': 'PKG-WEEKLY-10M',
          'downloadSpeedLimit': '10M',
          'uploadSpeedLimit': '5M',
          'durationMinutes': 10080,
          'validityDays': 7,
          'price': 2500.0,
          'hotspotProfileName': 'hs_weekly_10m',
          'isActive': false,
        },
      ];

      ApiClient.client = MockClient((request) async {
        return utf8Response({
          'success': true,
          'data': mockPackagesData,
        }, 200);
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: PackagesScreen(),
        ),
      );
      for (int i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Check header counts
      expect(find.text('2 باقة مسجلة'), findsOneWidget);
      expect(find.text('يومية 5 ميجا'), findsOneWidget);
      expect(find.text('PKG-DAILY-5M'), findsOneWidget);
      expect(find.text('نشطة'), findsOneWidget);

      expect(find.text('أسبوعية 10 ميجا'), findsOneWidget);
      expect(find.text('PKG-WEEKLY-10M'), findsOneWidget);
      expect(find.text('غير نشطة'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets('shows delete confirmation dialog on delete icon tap',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mockPackagesData = [
        {
          'id': 'pkg-1',
          'name': 'يومية 5 ميجا',
          'code': 'PKG-DAILY-5M',
          'downloadSpeedLimit': '5M',
          'uploadSpeedLimit': '2M',
          'durationMinutes': 1440,
          'validityDays': 1,
          'price': 500.0,
          'hotspotProfileName': 'hs_daily_5m',
          'isActive': true,
        },
      ];

      ApiClient.client = MockClient((request) async {
        if (request.method == 'GET') {
          return utf8Response({
            'success': true,
            'data': mockPackagesData,
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
          home: PackagesScreen(),
        ),
      );
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Tap delete icon
      await tester.tap(find.byIcon(Icons.delete_outline_rounded).first);
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('تأكيد حذف الباقة'), findsOneWidget);
      expect(find.text('نعم، حذف'), findsOneWidget);
      expect(find.text('إلغاء'), findsOneWidget);

      // Tap cancel
      await tester.tap(find.text('إلغاء'));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('تأكيد حذف الباقة'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets('AddPackageSheet validates empty fields before submit',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AddPackageSheet(onPackageAdded: () {}),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Tap submit button without inputting anything
      await tester.tap(find.text('حفظ وإضافة الباقة'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('يرجى إدخال اسم الباقة'), findsOneWidget);
      expect(find.text('يرجى إدخال كود الباقة'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets('AddPackageSheet submits successfully and triggers onPackageAdded callback',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      bool addedCalled = false;
      bool postReceived = false;

      ApiClient.client = MockClient((request) async {
        if (request.method == 'POST' && request.url.path.endsWith('/packages')) {
          postReceived = true;
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          return utf8Response({
            'success': true,
            'data': {
              'id': 'new-p-1',
              ...body,
            },
          }, 201);
        }
        return utf8Response({}, 404);
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AddPackageSheet(onPackageAdded: () {
              addedCalled = true;
            }),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Fill in all 8 fields
      await tester.enterText(
        find.widgetWithText(NeumorphicTextField, 'اسم الباقة'),
        'يومية سريعة',
      );
      await tester.enterText(
        find.widgetWithText(NeumorphicTextField, 'كود الباقة الفريد'),
        'PKG-FAST-1',
      );
      await tester.enterText(
        find.widgetWithText(NeumorphicTextField, 'سرعة التحميل (Download)'),
        '8M',
      );
      await tester.enterText(
        find.widgetWithText(NeumorphicTextField, 'سرعة الرفع (Upload)'),
        '4M',
      );
      await tester.enterText(
        find.widgetWithText(NeumorphicTextField, 'المدة بالدقائق'),
        '1440',
      );
      await tester.enterText(
        find.widgetWithText(NeumorphicTextField, 'أيام الصلاحية'),
        '1',
      );
      await tester.enterText(
        find.widgetWithText(NeumorphicTextField, 'السعر (جنيه سوداني)'),
        '600',
      );
      await tester.enterText(
        find.widgetWithText(NeumorphicTextField, 'اسم بروفايل الهوتسبوت في MikroTik'),
        'hs_fast_1',
      );
      await tester.pump(const Duration(milliseconds: 50));

      // Tap submit
      await tester.tap(find.text('حفظ وإضافة الباقة'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(postReceived, isTrue);
      expect(addedCalled, isTrue);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  });

  group('DashboardScreen Navigation to PackagesScreen', () {
    testWidgets('tap on "الباقات" in Dashboard banner navigates to PackagesScreen',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      ApiClient.client = MockClient((request) async {
        return utf8Response({
          'success': true,
          'data': [],
        }, 200);
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: DashboardScreen(),
        ),
      );
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Check Packages button is present in dashboard
      expect(find.text('الباقات'), findsOneWidget);

      // Tap Packages button
      await tester.tap(find.text('الباقات'));
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Check PackagesScreen is pushed
      expect(find.text('إدارة الباقات'), findsOneWidget);
      expect(find.text('باقات الإنترنت المتوفرة'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  });
}
