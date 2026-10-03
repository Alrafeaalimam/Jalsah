// ============================================================================
// Platform: Commercial MikroTik Network & HotSpot Card Management System
// File: test/sales_report_test.dart
// Unit & Widget Tests: Basic Sales Report Screen, SaleModel, ApiClient, Navigation
// Master Reference: Rule 8 (Sales), Rule 26 (MVP Reports), Rule 35 (States)
// ============================================================================

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:mikrotik_cards_app/models/sale_model.dart';
import 'package:mikrotik_cards_app/screens/dashboard_screen.dart';
import 'package:mikrotik_cards_app/screens/sales_report_screen.dart';
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

  group('SaleModel Unit Tests', () {
    test('fromJson correctly parses full backend record with items', () {
      final json = {
        'id': 'sale-uuid-1',
        'tenantId': 'tenant-uuid',
        'soldById': 'user-uuid',
        'totalAmount': 1500.0,
        'paymentMethod': 'CASH',
        'createdAt': '2026-10-03T10:30:00.000Z',
        'soldByName': 'المشرف أحمد',
        'items': [
          {'id': 'item-1', 'cardId': 'card-1', 'unitPrice': 500.0},
          {'id': 'item-2', 'cardId': 'card-2', 'unitPrice': 1000.0},
        ],
      };

      final sale = SaleModel.fromJson(json);

      expect(sale.id, equals('sale-uuid-1'));
      expect(sale.totalAmount, equals(1500.0));
      expect(sale.paymentMethod, equals('CASH'));
      expect(sale.cardsCount, equals(2));
      expect(sale.soldByName, equals('المشرف أحمد'));
      expect(sale.paymentMethodArabic, equals('نقدي'));
      expect(sale.paymentMethodIcon, equals(Icons.payments_rounded));
      expect(sale.formattedTotalAmount, equals('1,500 جنيه سوداني'));
      expect(sale.cardsCountArabic, equals('كرتان'));
    });

    test('fromJson parses BANK_TRANSFER and MOBILE_MONEY correctly', () {
      final bankSale = SaleModel.fromJson({
        'id': 'sale-bank',
        'totalAmount': 20000.0,
        'paymentMethod': 'BANK_TRANSFER',
        'createdAt': '2026-10-01T14:15:00.000Z',
        'cardsCount': 5,
      });

      expect(bankSale.paymentMethodArabic, equals('تحويل بنكي'));
      expect(bankSale.paymentMethodIcon, equals(Icons.account_balance_rounded));
      expect(bankSale.formattedTotalAmount, equals('20,000 جنيه سوداني'));
      expect(bankSale.cardsCountArabic, equals('5 كروت'));

      final walletSale = SaleModel.fromJson({
        'id': 'sale-wallet',
        'totalAmount': 350.5,
        'paymentMethod': 'MOBILE_MONEY',
        'createdAt': '2026-10-02T16:00:00.000Z',
        'cardsCount': 1,
      });

      expect(walletSale.paymentMethodArabic, equals('محفظة إلكترونية'));
      expect(walletSale.paymentMethodIcon, equals(Icons.phone_android_rounded));
      expect(walletSale.formattedTotalAmount, equals('350.50 جنيه سوداني'));
      expect(walletSale.cardsCountArabic, equals('كرت واحد'));
    });

    test('toJson serializes model accurately', () {
      final date = DateTime.parse('2026-10-03T12:00:00.000Z');
      final sale = SaleModel(
        id: 'sale-test',
        totalAmount: 750.0,
        paymentMethod: 'CASH',
        createdAt: date,
        cardsCount: 3,
        soldByName: 'محمد',
      );

      final map = sale.toJson();
      expect(map['id'], equals('sale-test'));
      expect(map['totalAmount'], equals(750.0));
      expect(map['paymentMethod'], equals('CASH'));
      expect(map['cardsCount'], equals(3));
      expect(map['soldByName'], equals('محمد'));
    });
  });

  group('ApiClient.getSales Unit Tests', () {
    test('getSales sends GET request with date filters and auth header', () async {
      late http.Request capturedRequest;
      ApiClient.setAuthToken('test-jwt-token');

      ApiClient.client = MockClient((request) async {
        capturedRequest = request;
        return utf8Response({
          'success': true,
          'data': [
            {
              'id': 'sale-1',
              'totalAmount': 1000.0,
              'paymentMethod': 'CASH',
              'createdAt': '2026-10-03T09:00:00.000Z',
              'items': [
                {'id': 'i1', 'cardId': 'c1', 'unitPrice': 1000.0},
              ],
            },
          ],
        }, 200);
      });

      final dateFrom = DateTime(2026, 10, 3);
      final result = await ApiClient.getSales(dateFrom: dateFrom);

      expect(result['success'], isTrue);
      expect(capturedRequest.method, equals('GET'));
      expect(capturedRequest.url.path, equals('/api/v1/sales'));
      expect(capturedRequest.url.queryParameters['dateFrom'], equals(dateFrom.toIso8601String()));
      expect(capturedRequest.headers['Authorization'], equals('Bearer test-jwt-token'));

      final list = result['data'] as List<SaleModel>;
      expect(list.length, equals(1));
      expect(list.first.id, equals('sale-1'));
      expect(list.first.totalAmount, equals(1000.0));
    });

    test('getSales handles 401 and resets auth token', () async {
      ApiClient.setAuthToken('expired-jwt');

      ApiClient.client = MockClient((request) async {
        return utf8Response({
          'success': false,
          'errorCode': 'UNAUTHORIZED',
          'errorMessage': 'الجلسة منتهية',
        }, 401);
      });

      final result = await ApiClient.getSales();

      expect(result['success'], isFalse);
      expect(result['errorCode'], equals('UNAUTHORIZED'));
      expect(ApiClient.authToken, isNull);
    });

    test('getSales handles 500 server error', () async {
      ApiClient.client = MockClient((request) async {
        return utf8Response({
          'success': false,
          'errorCode': 'INTERNAL_ERROR',
          'errorMessage': 'حدث خطأ في قاعدة البيانات',
        }, 500);
      });

      final result = await ApiClient.getSales();

      expect(result['success'], isFalse);
      expect(result['errorCode'], equals('INTERNAL_ERROR'));
    });
  });

  group('SalesReportScreen Widget Tests', () {
    testWidgets('renders top hero banner, filter chips, aggregated total, and transaction items', (tester) async {
      ApiClient.client = MockClient((request) async {
        return utf8Response({
          'success': true,
          'data': [
            {
              'id': 'sale-101',
              'totalAmount': 2500.0,
              'paymentMethod': 'CASH',
              'createdAt': '2026-10-03T11:00:00.000Z',
              'items': [
                {'id': 'i1', 'cardId': 'c1', 'unitPrice': 1250.0},
                {'id': 'i2', 'cardId': 'c2', 'unitPrice': 1250.0},
              ],
            },
            {
              'id': 'sale-102',
              'totalAmount': 1000.0,
              'paymentMethod': 'BANK_TRANSFER',
              'createdAt': '2026-10-03T12:30:00.000Z',
              'items': [
                {'id': 'i3', 'cardId': 'c3', 'unitPrice': 1000.0},
              ],
            },
          ],
        }, 200);
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: SalesReportScreen(),
        ),
      );

      // Initial loading
      expect(find.byType(CircularProgressIndicator), findsWidgets);
      await tester.pumpAndSettle();

      // Screen title and subtitle
      expect(find.text('تقارير المبيعات'), findsOneWidget);
      expect(find.text('متابعة المعاملات والإيرادات المحققة'), findsOneWidget);

      // Period filter chips
      expect(find.text('اليوم'), findsWidgets);
      expect(find.text('آخر 7 أيام'), findsOneWidget);
      expect(find.text('آخر 30 يوم'), findsOneWidget);

      // Stat card details
      expect(find.text('2 معاملة'), findsOneWidget);
      expect(find.text('إجمالي الكروت المباعة: 3 كرت'), findsOneWidget);

      // Transaction items rendered
      expect(find.text('نقدي'), findsOneWidget);
      expect(find.text('تحويل بنكي'), findsOneWidget);
      expect(find.text('2,500 جنيه سوداني'), findsOneWidget);
      expect(find.text('1,000 جنيه سوداني'), findsOneWidget);
    });

    testWidgets('tapping a transaction card opens detail bottom sheet', (tester) async {
      ApiClient.client = MockClient((request) async {
        return utf8Response({
          'success': true,
          'data': [
            {
              'id': 'sale-detail-xyz',
              'totalAmount': 5000.0,
              'paymentMethod': 'MOBILE_MONEY',
              'createdAt': '2026-10-03T10:00:00.000Z',
              'soldByName': 'المحاسب عثمان',
              'items': [
                {'id': 'i1', 'cardId': 'c1', 'unitPrice': 5000.0},
              ],
            },
          ],
        }, 200);
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: SalesReportScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Tap transaction card
      await tester.tap(find.text('محفظة إلكترونية'));
      await tester.pumpAndSettle();

      // Verify bottom sheet appears
      expect(find.text('تفاصيل معاملة البيع'), findsOneWidget);
      expect(find.text('رقم المعاملة'), findsOneWidget);
      expect(find.text('sale-detail-xyz'), findsOneWidget);
      expect(find.text('المحاسب عثمان'), findsNWidgets(2));
      expect(find.text('إغلاق'), findsOneWidget);

      // Close bottom sheet
      await tester.tap(find.text('إغلاق'));
      await tester.pumpAndSettle();

      expect(find.text('تفاصيل معاملة البيع'), findsNothing);
    });

    testWidgets('shows empty state when no sales exist for the period', (tester) async {
      ApiClient.client = MockClient((request) async {
        return utf8Response({
          'success': true,
          'data': [],
        }, 200);
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: SalesReportScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('لا توجد مبيعات في هذه الفترة'), findsOneWidget);
      expect(find.byIcon(Icons.receipt_long_outlined), findsOneWidget);
    });

    testWidgets('shows error state on failure and allows retry', (tester) async {
      int callCount = 0;
      ApiClient.client = MockClient((request) async {
        callCount++;
        if (callCount == 1) {
          return utf8Response({
            'success': false,
            'errorMessage': 'فشل الاتصال بقاعدة البيانات',
          }, 500);
        } else {
          return utf8Response({
            'success': true,
            'data': [
              {
                'id': 'sale-retry-ok',
                'totalAmount': 1200.0,
                'paymentMethod': 'CASH',
                'createdAt': '2026-10-03T11:00:00.000Z',
                'items': [
                  {'id': 'i1', 'cardId': 'c1', 'unitPrice': 1200.0},
                ],
              },
            ],
          }, 200);
        }
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: SalesReportScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('فشل تحميل تقارير المبيعات'), findsOneWidget);
      expect(find.text('فشل الاتصال بقاعدة البيانات'), findsOneWidget);
      expect(find.text('إعادة المحاولة'), findsOneWidget);

      // Tap retry
      await tester.tap(find.text('إعادة المحاولة'));
      await tester.pumpAndSettle();

      expect(callCount, equals(2));
      expect(find.text('1,200 جنيه سوداني'), findsWidgets);
    });

    testWidgets('tapping filter chips reloads data with corresponding date range', (tester) async {
      final List<String?> capturedQueries = [];

      ApiClient.client = MockClient((request) async {
        capturedQueries.add(request.url.queryParameters['dateFrom']);
        return utf8Response({
          'success': true,
          'data': [],
        }, 200);
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: SalesReportScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(capturedQueries.length, equals(1));

      // Tap 'آخر 7 أيام'
      await tester.tap(find.text('آخر 7 أيام'));
      await tester.pumpAndSettle();

      expect(capturedQueries.length, equals(2));

      // Tap 'آخر 30 يوم'
      await tester.tap(find.text('آخر 30 يوم'));
      await tester.pumpAndSettle();

      expect(capturedQueries.length, equals(3));
    });
  });

  group('Dashboard to SalesReport Navigation Test', () {
    testWidgets('tapping today sales card in Dashboard opens SalesReportScreen', (tester) async {
      ApiClient.client = MockClient((request) async {
        if (request.url.path.contains('/api/v1/routers')) {
          return utf8Response({'success': true, 'data': []}, 200);
        }
        if (request.url.path.contains('/api/v1/sales/today-total')) {
          return utf8Response({
            'success': true,
            'data': {'todayTotal': 15000.0},
          }, 200);
        }
        if (request.url.path == '/api/v1/sales') {
          return utf8Response({
            'success': true,
            'data': [
              {
                'id': 'sale-nav-1',
                'totalAmount': 15000.0,
                'paymentMethod': 'CASH',
                'createdAt': '2026-10-03T12:00:00.000Z',
                'items': [
                  {'id': 'i1', 'cardId': 'c1', 'unitPrice': 15000.0},
                ],
              },
            ],
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

      // Today sales card is visible
      expect(find.text('مبيعات اليوم'), findsOneWidget);

      // Tap "مبيعات اليوم" card
      await tester.tap(find.text('مبيعات اليوم'));
      await tester.pumpAndSettle();

      // Verify SalesReportScreen is opened
      expect(find.byType(SalesReportScreen), findsOneWidget);
      expect(find.text('تقارير المبيعات'), findsOneWidget);
    });
  });
}
