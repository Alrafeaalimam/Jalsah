// ============================================================================
// Platform: Commercial MikroTik Network & HotSpot Card Management System
// File: test/cards_test.dart
// Unit & Widget Tests: CardModel, CardBatchModel, ApiClient & Cards Screens
// ============================================================================

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:mikrotik_cards_app/models/card_batch_model.dart';
import 'package:mikrotik_cards_app/models/card_model.dart';
import 'package:mikrotik_cards_app/screens/cards_list_screen.dart';
import 'package:mikrotik_cards_app/screens/dashboard_screen.dart';
import 'package:mikrotik_cards_app/screens/generate_cards_screen.dart';
import 'package:mikrotik_cards_app/screens/packages_screen.dart';
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

  group('CardModel & CardBatchModel Unit Tests', () {
    test('CardModel fromJson & toJson parse correctly', () {
      final json = {
        'id': 'card-123',
        'username': 'VIP8844',
        'password': '9921',
        'status': 'GENERATED',
        'batchId': 'batch-001',
        'packageId': 'pkg-1',
        'price': 15.5,
        'createdAt': '2026-10-02T10:00:00.000Z',
      };

      final card = CardModel.fromJson(json);
      expect(card.id, equals('card-123'));
      expect(card.username, equals('VIP8844'));
      expect(card.password, equals('9921'));
      expect(card.status, equals('GENERATED'));
      expect(card.statusTextArabic, equals('تم التوليد'));
      expect(card.price, equals(15.5));
      expect(card.formattedPrice, equals('15.50'));
      expect(card.statusColor, isNotNull);

      final encoded = card.toJson();
      expect(encoded['username'], equals('VIP8844'));
      expect(encoded['price'], equals(15.5));
    });

    test('CardModel statusTextArabic covers all state machine statuses', () {
      final statuses = {
        'GENERATED': 'تم التوليد',
        'AVAILABLE': 'متاح للبيع',
        'SOLD': 'تم البيع',
        'ACTIVE': 'نشط',
        'EXPIRED': 'منتهي',
        'CANCELLED': 'ملغي',
        'SUSPENDED': 'معلق',
        'REVOKED': 'مسحوب',
      };

      for (final entry in statuses.entries) {
        final card = CardModel(
          id: 'test',
          username: 'user',
          password: 'pin',
          status: entry.key,
        );
        expect(card.statusTextArabic, equals(entry.value));
        expect(card.statusColor, isNotNull);
      }
    });

    test('CardBatchModel fromJson & toJson parse correctly', () {
      final json = {
        'id': 'batch-001',
        'batchNumber': 'BATCH-TEST-01',
        'name': 'دفعة الباقة السريعة',
        'quantity': 100,
        'packageId': 'pkg-1',
        'prefix': 'VIP',
        'unitPrice': 10.0,
        'totalPrice': 1000.0,
        'createdAt': '2026-10-02T10:00:00.000Z',
      };

      final batch = CardBatchModel.fromJson(json);
      expect(batch.id, equals('batch-001'));
      expect(batch.batchNumber, equals('BATCH-TEST-01'));
      expect(batch.quantity, equals(100));
      expect(batch.prefix, equals('VIP'));
      expect(batch.formattedTotalPrice, equals('1000'));

      final encoded = batch.toJson();
      expect(encoded['batchNumber'], equals('BATCH-TEST-01'));
      expect(encoded['totalPrice'], equals(1000.0));
    });
  });

  group('ApiClient Card API Unit Tests', () {
    test('generateCardBatch sends valid payload and parses response', () async {
      ApiClient.client = MockClient((request) async {
        expect(request.url.path, equals('/api/v1/cards/generate-batch'));
        expect(request.method, equals('POST'));

        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['packageId'], equals('pkg-1'));
        expect(body['quantity'], equals(10));
        expect(body['prefix'], equals('VIP'));

        return utf8Response({
          'success': true,
          'data': {
            'batch': {
              'id': 'batch-uuid',
              'batchNumber': 'BATCH-ABC',
              'quantity': 10,
              'packageId': 'pkg-1',
              'totalPrice': 150.0,
            },
            'cards': [
              {
                'id': 'card-1',
                'username': 'VIP111',
                'password': '1234',
                'status': 'GENERATED',
                'batchId': 'batch-uuid',
                'packageId': 'pkg-1',
                'price': 15.0,
              },
            ],
          },
        }, 201);
      });

      final result = await ApiClient.generateCardBatch(
        packageId: 'pkg-1',
        quantity: 10,
        prefix: 'VIP',
      );

      expect(result['success'], isTrue);
      final data = result['data'] as Map<String, dynamic>;
      expect(data['batch'], isA<CardBatchModel>());
      expect(data['cards'], isA<List<CardModel>>());
      final cards = data['cards'] as List<CardModel>;
      expect(cards.length, equals(1));
      expect(cards.first.username, equals('VIP111'));
    });

    test('generateCardBatch handles 404 PACKAGE_NOT_FOUND', () async {
      ApiClient.client = MockClient((request) async {
        return utf8Response({
          'success': false,
          'errorCode': 'PACKAGE_NOT_FOUND',
          'errorMessage': 'Package not found',
        }, 404);
      });

      final result = await ApiClient.generateCardBatch(
        packageId: 'unknown-id',
        quantity: 10,
      );

      expect(result['success'], isFalse);
      expect(result['errorCode'], equals('PACKAGE_NOT_FOUND'));
    });

    test('generateCardBatch handles 422 PACKAGE_INACTIVE', () async {
      ApiClient.client = MockClient((request) async {
        return utf8Response({
          'success': false,
          'errorCode': 'PACKAGE_INACTIVE',
          'errorMessage': 'Package is inactive',
        }, 422);
      });

      final result = await ApiClient.generateCardBatch(
        packageId: 'inactive-id',
        quantity: 10,
      );

      expect(result['success'], isFalse);
      expect(result['errorCode'], equals('PACKAGE_INACTIVE'));
    });

    test('getCards sends query parameters and parses list', () async {
      ApiClient.client = MockClient((request) async {
        expect(request.url.path, equals('/api/v1/cards'));
        expect(request.url.queryParameters['status'], equals('GENERATED'));
        expect(request.url.queryParameters['batchId'], equals('b-1'));

        return utf8Response({
          'success': true,
          'data': [
            {
              'id': 'card-1',
              'username': 'USER100',
              'password': '4321',
              'status': 'GENERATED',
            },
            {
              'id': 'card-2',
              'username': 'USER200',
              'password': '8765',
              'status': 'GENERATED',
            },
          ],
        }, 200);
      });

      final result = await ApiClient.getCards(
        status: 'GENERATED',
        batchId: 'b-1',
      );

      expect(result['success'], isTrue);
      final cards = result['data'] as List<CardModel>;
      expect(cards.length, equals(2));
      expect(cards[0].username, equals('USER100'));
      expect(cards[1].username, equals('USER200'));
    });

    test('updateCardStatus handles 422 INVALID_CARD_TRANSITION', () async {
      ApiClient.client = MockClient((request) async {
        return utf8Response({
          'success': false,
          'errorCode': 'INVALID_CARD_TRANSITION',
          'errorMessage': 'Invalid transition',
        }, 422);
      });

      final result = await ApiClient.updateCardStatus(
        cardId: 'card-1',
        newStatus: 'ACTIVE',
      );

      expect(result['success'], isFalse);
      expect(result['errorCode'], equals('INVALID_CARD_TRANSITION'));
    });
  });

  group('GenerateCardsScreen Widget Tests', () {
    testWidgets('renders empty state when no packages exist and navigates to PackagesScreen',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      ApiClient.client = MockClient((request) async {
        if (request.url.path == '/api/v1/packages') {
          return utf8Response({'success': true, 'data': []}, 200);
        }
        return utf8Response({'success': false}, 404);
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: GenerateCardsScreen(),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pumpAndSettle();

      expect(find.text('لا توجد باقات إنترنت معرّفة'), findsOneWidget);
      expect(find.text('الذهاب لإضافة باقة إنترنت'), findsOneWidget);

      await tester.tap(find.text('الذهاب لإضافة باقة إنترنت'));
      await tester.pumpAndSettle();

      expect(find.byType(PackagesScreen), findsOneWidget);
    });

    testWidgets('renders form with packages, presets, validates, and generates batch',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mockPackages = [
        {
          'id': 'pkg-1',
          'name': 'باقة 5 ميجا',
          'code': 'P5M',
          'downloadSpeedLimit': '5M',
          'uploadSpeedLimit': '2M',
          'durationMinutes': 1440,
          'validityDays': 1,
          'price': 50.0,
          'hotspotProfileName': 'prof_5m',
          'isActive': true,
        },
      ];

      ApiClient.client = MockClient((request) async {
        if (request.url.path == '/api/v1/packages') {
          return utf8Response({'success': true, 'data': mockPackages}, 200);
        }
        if (request.url.path == '/api/v1/cards/generate-batch') {
          return utf8Response({
            'success': true,
            'data': {
              'batch': {
                'id': 'batch-new-1',
                'batchNumber': 'BATCH-ALPHA-01',
                'quantity': 10,
                'packageId': 'pkg-1',
                'totalPrice': 500.0,
              },
              'cards': List.generate(
                5,
                (i) => {
                  'id': 'c-$i',
                  'username': 'VIP${1000 + i}',
                  'password': '${2000 + i}',
                  'status': 'GENERATED',
                  'batchId': 'batch-new-1',
                  'packageId': 'pkg-1',
                  'price': 50.0,
                },
              ),
            },
          }, 201);
        }
        return utf8Response({'success': false}, 404);
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: GenerateCardsScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // Form should be rendered
      expect(find.text('اختر باقة الإنترنت *'), findsOneWidget);
      expect(find.text('بدء توليد دفعة الكروت الآن'), findsOneWidget);

      // Tap generate button
      await tester.tap(find.text('بدء توليد دفعة الكروت الآن'));
      await tester.pumpAndSettle();

      // Success section should be displayed
      expect(find.text('تم توليد الكروت بنجاح! 🎉'), findsOneWidget);
      expect(find.text('BATCH-ALPHA-01'), findsOneWidget);
      expect(find.text('معاينة أول 5 كروت مولّدة:'), findsOneWidget);
      expect(find.text('VIP1000'), findsOneWidget);
      expect(find.text('2000'), findsOneWidget);
      expect(find.text('عرض كل الكروت'), findsOneWidget);

      // Tap View All Cards
      await tester.tap(find.text('عرض كل الكروت'));
      await tester.pumpAndSettle();

      expect(find.byType(CardsListScreen), findsOneWidget);
    });
  });

  group('CardsListScreen Widget Tests', () {
    testWidgets('renders cards list with status badge and copy actions',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mockCards = [
        {
          'id': 'card-1',
          'username': 'VIP9988',
          'password': '4411',
          'status': 'GENERATED',
          'price': 20.0,
        },
        {
          'id': 'card-2',
          'username': 'VIP9989',
          'password': '4412',
          'status': 'AVAILABLE',
          'price': 20.0,
        },
      ];

      ApiClient.client = MockClient((request) async {
        if (request.url.path == '/api/v1/cards') {
          return utf8Response({'success': true, 'data': mockCards}, 200);
        }
        return utf8Response({'success': false}, 404);
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: CardsListScreen(),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pumpAndSettle();

      expect(find.text('كروت الهوتسبوت'), findsOneWidget);
      expect(find.text('VIP9988'), findsOneWidget);
      expect(find.text('VIP9989'), findsOneWidget);
      expect(find.text('تم التوليد'), findsWidgets);
      expect(find.text('متاح للبيع'), findsWidgets);

      // Test copy action
      await tester.tap(find.byIcon(Icons.copy_rounded).first);
      await tester.pump();
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('renders empty state when cards list is empty', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      ApiClient.client = MockClient((request) async {
        if (request.url.path == '/api/v1/cards') {
          return utf8Response({'success': true, 'data': []}, 200);
        }
        return utf8Response({'success': false}, 404);
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: CardsListScreen(),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('لا توجد كروت في هذه القائمة'), findsOneWidget);
      expect(find.text('توليد كروت جديدة'), findsWidgets);
    });
  });

  group('DashboardScreen Cards Navigation Integration Tests', () {
    testWidgets('tapping "الكروت" in Dashboard banner navigates to CardsListScreen',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      ApiClient.client = MockClient((request) async {
        if (request.url.path == '/api/v1/routers') {
          return utf8Response({'success': true, 'data': []}, 200);
        }
        if (request.url.path == '/api/v1/cards') {
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

      expect(find.text('الكروت'), findsOneWidget);
      await tester.tap(find.text('الكروت'));
      await tester.pumpAndSettle();

      expect(find.byType(CardsListScreen), findsOneWidget);
    });

    testWidgets('tapping "توليد كروت جديدة" in Dashboard navigates to GenerateCardsScreen',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      ApiClient.client = MockClient((request) async {
        if (request.url.path == '/api/v1/routers') {
          return utf8Response({'success': true, 'data': []}, 200);
        }
        if (request.url.path == '/api/v1/packages') {
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

      final generateButton = find.text('توليد كروت جديدة');
      expect(generateButton, findsOneWidget);
      await tester.tap(generateButton);
      await tester.pumpAndSettle();

      expect(find.byType(GenerateCardsScreen), findsOneWidget);
    });
  });
}
