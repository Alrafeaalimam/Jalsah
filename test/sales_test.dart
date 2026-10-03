// ============================================================================
// Platform: Commercial MikroTik Network & HotSpot Card Management System
// File: test/sales_test.dart
// Unit & Widget Tests: Sales Flow, Multi-Selection, BottomSheet, Dashboard Total
// ============================================================================

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:mikrotik_cards_app/screens/cards_list_screen.dart';
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

  group('ApiClient Sales Unit Tests', () {
    test('createSale sends POST request with cardIds and paymentMethod', () async {
      late http.Request capturedRequest;

      ApiClient.client = MockClient((request) async {
        capturedRequest = request;
        return utf8Response({
          'success': true,
          'data': {
            'sale': {
              'id': 'sale-123',
              'totalAmount': 500.0,
              'paymentMethod': 'CASH',
              'status': 'COMPLETED',
            },
          },
        }, 201);
      });

      final result = await ApiClient.createSale(
        cardIds: ['card-uuid-1', 'card-uuid-2'],
        paymentMethod: 'CASH',
      );

      expect(result['success'], isTrue);
      expect(capturedRequest.method, equals('POST'));
      expect(capturedRequest.url.path, equals('/api/v1/sales'));

      final body = jsonDecode(capturedRequest.body) as Map<String, dynamic>;
      expect(body['cardIds'], equals(['card-uuid-1', 'card-uuid-2']));
      expect(body['paymentMethod'], equals('CASH'));
    });

    test('createSale handles 422 error when card is not available', () async {
      ApiClient.client = MockClient((request) async {
        return utf8Response({
          'success': false,
          'errorCode': 'INVALID_CARD_STATE',
          'errorMessage': 'الكرت card-uuid-1 بحالة GENERATED ولا يمكن بيعه',
        }, 422);
      });

      final result = await ApiClient.createSale(
        cardIds: ['card-uuid-1'],
        paymentMethod: 'BANK_TRANSFER',
      );

      expect(result['success'], isFalse);
      expect(result['errorCode'], equals('INVALID_CARD_STATE'));
      expect(result['errorMessage'], contains('لا يمكن بيعه'));
    });

    test('getTodaySalesTotal fetches totalAmount and todayTotal', () async {
      late http.Request capturedRequest;

      ApiClient.client = MockClient((request) async {
        capturedRequest = request;
        return utf8Response({
          'success': true,
          'data': {
            'todayTotal': 12500.0,
            'totalAmount': 12500.0,
            'count': 25,
          },
        }, 200);
      });

      final result = await ApiClient.getTodaySalesTotal();

      expect(result['success'], isTrue);
      expect(capturedRequest.method, equals('GET'));
      expect(capturedRequest.url.path, equals('/api/v1/sales/today-total'));
      expect(result['data']['todayTotal'], equals(12500.0));
    });

    test('getTodaySalesTotal handles server error gracefully', () async {
      ApiClient.client = MockClient((request) async {
        return utf8Response({
          'success': false,
          'errorCode': 'SERVER_ERROR',
          'errorMessage': 'فشل الاتصال بقاعدة البيانات',
        }, 500);
      });

      final result = await ApiClient.getTodaySalesTotal();

      expect(result['success'], isFalse);
      expect(result['errorCode'], equals('SERVER_ERROR'));
    });
  });

  group('CardsListScreen Multi-Selection & Sale Flow', () {
    final availableCard1 = {
      'id': 'card-1',
      'batchId': 'batch-1',
      'username': 'user001',
      'password': 'pass001',
      'status': 'AVAILABLE',
      'price': 500.0,
      'sellingPrice': 500.0,
      'createdAt': '2026-03-01T10:00:00Z',
    };

    final availableCard2 = {
      'id': 'card-2',
      'batchId': 'batch-1',
      'username': 'user002',
      'password': 'pass002',
      'status': 'AVAILABLE',
      'price': 1000.0,
      'sellingPrice': 1000.0,
      'createdAt': '2026-03-01T10:00:00Z',
    };

    final soldCard = {
      'id': 'card-3',
      'batchId': 'batch-1',
      'username': 'user003',
      'password': 'pass003',
      'status': 'SOLD',
      'price': 750.0,
      'sellingPrice': 750.0,
      'createdAt': '2026-03-01T10:00:00Z',
    };

    testWidgets('renders checkboxes ONLY for AVAILABLE cards and shows floating bar on select',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      ApiClient.client = MockClient((request) async {
        if (request.url.path.contains('/api/v1/cards')) {
          return utf8Response({
            'success': true,
            'data': [availableCard1, availableCard2, soldCard],
            'meta': {'total': 3, 'page': 1, 'limit': 50, 'totalPages': 1},
          }, 200);
        }
        return utf8Response({'success': true, 'data': []}, 200);
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: CardsListScreen(),
        ),
      );

      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Verify usernames rendered
      expect(find.text('user001'), findsOneWidget);
      expect(find.text('user002'), findsOneWidget);
      expect(find.text('user003'), findsOneWidget);

      // Only 2 Checkbox widgets should be present (for AVAILABLE cards)
      expect(find.byType(Checkbox), findsNWidgets(2));

      // Floating bottom bar should NOT be visible when nothing selected
      expect(find.textContaining('بيع ('), findsNothing);
      expect(find.text('إلغاء'), findsNothing);

      // Select first card
      await tester.tap(find.byType(Checkbox).first);
      await tester.pumpAndSettle();

      // Floating bar should now appear with count 1
      expect(find.text('بيع (1) كرت'), findsOneWidget);
      expect(find.text('500 SDG'), findsNWidgets(2));

      // Select second card
      await tester.tap(find.byType(Checkbox).at(1));
      await tester.pumpAndSettle();

      // Floating bar should update to count 2 and total 1500
      expect(find.text('بيع (2) كروت'), findsOneWidget);
      expect(find.text('1500 SDG'), findsOneWidget);

      // Deselect second card by tapping its checkbox again
      await tester.tap(find.byType(Checkbox).at(1));
      await tester.pumpAndSettle();
      expect(find.text('بيع (1) كرت'), findsOneWidget);

      // Deselect first card by tapping its checkbox again
      await tester.tap(find.byType(Checkbox).first);
      await tester.pumpAndSettle();

      // Floating bar disappears
      expect(find.textContaining('بيع ('), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets('completes sale via BottomSheet with payment method selection',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      bool saleRequestSent = false;
      String? sentPaymentMethod;
      List<dynamic>? sentCardIds;
      int fetchCardsCount = 0;

      ApiClient.client = MockClient((request) async {
        if (request.method == 'GET' && request.url.path.contains('/api/v1/cards')) {
          fetchCardsCount++;
          // First fetch returns available cards; second fetch returns sold
          final cardsList = fetchCardsCount == 1
              ? [availableCard1, availableCard2]
              : [
                  {...availableCard1, 'status': 'SOLD'},
                  {...availableCard2, 'status': 'SOLD'},
                ];
          return utf8Response({
            'success': true,
            'data': cardsList,
            'meta': {'total': 2, 'page': 1, 'limit': 50, 'totalPages': 1},
          }, 200);
        }

        if (request.method == 'POST' && request.url.path.contains('/api/v1/sales')) {
          saleRequestSent = true;
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          sentPaymentMethod = body['paymentMethod'] as String?;
          sentCardIds = body['cardIds'] as List<dynamic>?;

          return utf8Response({
            'success': true,
            'data': {
              'sale': {
                'id': 'sale-999',
                'totalAmount': 1500.0,
                'paymentMethod': sentPaymentMethod,
                'status': 'COMPLETED',
              },
            },
          }, 201);
        }

        return utf8Response({'success': true, 'data': []}, 200);
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: CardsListScreen(),
        ),
      );

      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Select both cards
      await tester.tap(find.byType(Checkbox).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Checkbox).at(1));
      await tester.pumpAndSettle();

      expect(find.text('بيع (2) كروت'), findsOneWidget);

      // Tap sale action button to open BottomSheet
      await tester.tap(find.text('بيع (2) كروت'));
      await tester.pumpAndSettle();

      // Verify BottomSheet contents
      expect(find.text('إتمام عملية البيع'), findsOneWidget);
      expect(find.text('نقداً (كاش)'), findsOneWidget);
      expect(find.text('تحويل بنكي (بنكك / فوري)'), findsOneWidget);
      expect(find.text('محفظة إلكترونية'), findsOneWidget);
      expect(find.text('تأكيد البيع'), findsOneWidget);

      // Switch payment method to MOBILE_MONEY
      await tester.tap(find.text('محفظة إلكترونية'));
      await tester.pumpAndSettle();

      // Tap confirm sale
      await tester.tap(find.text('تأكيد البيع'));
      for (int i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Verify request payload
      expect(saleRequestSent, isTrue);
      expect(sentPaymentMethod, equals('MOBILE_MONEY'));
      expect(sentCardIds, equals(['card-1', 'card-2']));

      // Verify SnackBar success message
      expect(find.textContaining('تم بيع 2 كروت بنجاح'), findsOneWidget);

      // Verify cards list was reloaded
      expect(fetchCardsCount, greaterThanOrEqualTo(2));

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  });

  group('DashboardScreen Sales Total & Demo Badge Removal Tests', () {
    testWidgets('loads and renders real today sales total without demo badge',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      ApiClient.client = MockClient((request) async {
        if (request.url.path.contains('/api/v1/sales/today-total')) {
          return utf8Response({
            'success': true,
            'data': {
              'todayTotal': 35000.0,
              'totalAmount': 35000.0,
              'count': 14,
            },
          }, 200);
        }
        if (request.url.path.contains('/api/v1/routers')) {
          return utf8Response({
            'success': true,
            'data': [],
          }, 200);
        }
        return utf8Response({'success': true, 'data': []}, 200);
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: DashboardScreen(),
        ),
      );

      for (int i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Verify sales card title is present
      expect(find.text('مبيعات اليوم'), findsOneWidget);

      // Verify demo badge "تجريبي" is COMPLETELY ABSENT (Rule 21)
      expect(find.text('تجريبي'), findsNothing);

      // Verify sales total rendered
      expect(find.textContaining('35,000'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  });
}
