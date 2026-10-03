// ============================================================================
// Platform: Commercial MikroTik Network & HotSpot Card Management System
// File: test/cards_qr_pdf_test.dart
// Unit & Widget Tests: QR Code Voucher, PDF Generation & Export Flow
// Master Reference: Rule 26 (MVP: QR, PDF, Printing)
// ============================================================================

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mikrotik_cards_app/models/card_batch_model.dart';
import 'package:mikrotik_cards_app/models/card_model.dart';
import 'package:mikrotik_cards_app/models/package_model.dart';
import 'package:mikrotik_cards_app/screens/cards_list_screen.dart';
import 'package:mikrotik_cards_app/screens/generate_cards_screen.dart';
import 'package:mikrotik_cards_app/services/api_client.dart';
import 'package:mikrotik_cards_app/services/card_pdf_service.dart';
import 'package:mikrotik_cards_app/widgets/card_voucher_widget.dart';

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
    SharedPreferences.setMockInitialValues({});

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

  final testCard = CardModel(
    id: 'c-101',
    username: 'user_test_88',
    password: 'pin_4321',
    status: 'AVAILABLE',
    price: 350.0,
    packageId: 'pkg-1',
  );

  final testPackage = const PackageModel(
    id: 'pkg-1',
    name: 'باقة اليوم السريع',
    code: 'PKG-DAILY',
    downloadSpeedLimit: '10M',
    uploadSpeedLimit: '5M',
    durationMinutes: 1440,
    validityDays: 1,
    price: 350.0,
    hotspotProfileName: 'hs_fast',
  );

  group('CardVoucherWidget Tests', () {
    testWidgets('renders Jalsah branding, QR code, and credentials',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: CardVoucherWidget(
                card: testCard,
                package: testPackage,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Branding
      expect(find.text('جلسة'), findsOneWidget);
      expect(find.text(' | Jalsah'), findsOneWidget);
      expect(find.text('شبكة إنترنت هوتسبوت'), findsOneWidget);

      // Verify QR Code
      expect(find.byType(QrImageView), findsOneWidget);

      // Verify Credentials
      expect(find.text('user_test_88'), findsOneWidget);
      expect(find.text('pin_4321'), findsOneWidget);

      // Verify Package & Price Details
      expect(find.text('باقة اليوم السريع'), findsOneWidget);
      expect(find.text('1 يوم'), findsOneWidget);
      expect(find.text('350 SDG'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  });

  group('CardPdfService Unit Tests', () {
    test('generateCardsDocument creates multi-page PDF document with barcodes',
        () async {
      final sampleCards = List.generate(
        8,
        (i) => CardModel(
          id: 'card-$i',
          username: 'user_$i',
          password: 'pass_$i',
          status: 'AVAILABLE',
          price: 200.0,
        ),
      );

      final doc = await CardPdfService.generateCardsDocument(
        cards: sampleCards,
        package: testPackage,
        batchNumber: 'BATCH-2026-001',
      );

      final bytes = await doc.save();
      expect(bytes, isNotNull);
      expect(bytes.isNotEmpty, isTrue);
      // Valid PDF begins with '%PDF-'
      expect(bytes.sublist(0, 5), equals([0x25, 0x50, 0x44, 0x46, 0x2D]));
      // 8 cards with 6 per page should yield 2 pages
      expect(doc.document.pdfPageList.pages.length, equals(2));
    });
  });

  group('CardsListScreen Voucher Preview Modal Tests', () {
    testWidgets('shows voucher modal with QR and print button on icon tap',
        (WidgetTester tester) async {
      ApiClient.client = MockClient((request) async {
        if (request.url.path.contains('/cards')) {
          return utf8Response({
            'success': true,
            'data': [testCard.toJson()],
          }, 200);
        } else if (request.url.path.contains('/packages')) {
          return utf8Response({
            'success': true,
            'data': [testPackage.toJson()],
          }, 200);
        }
        return utf8Response({}, 404);
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: CardsListScreen(),
        ),
      );
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Check card is rendered with QR button
      expect(find.text('user_test_88'), findsOneWidget);
      final qrButtonFinder = find.byIcon(Icons.qr_code_2_rounded);
      expect(qrButtonFinder, findsOneWidget);

      // Tap QR voucher preview button
      await tester.tap(qrButtonFinder);
      await tester.pumpAndSettle();

      // Modal should show CardVoucherWidget and single PDF print button
      expect(find.byType(CardVoucherWidget), findsOneWidget);
      expect(find.text('جلسة'), findsOneWidget);
      expect(find.text('مشاركة / طباعة هذا الكرت (PDF)'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  });

  group('GenerateCardsScreen PDF Export Tests', () {
    testWidgets('displays batch PDF export button and voucher previews on success',
        (WidgetTester tester) async {
      final mockBatch = CardBatchModel(
        id: 'b-1',
        batchNumber: 'BATCH-2026-99',
        packageId: testPackage.id,
        quantity: 2,
        totalPrice: 700.0,
        createdAt: DateTime.now(),
      );

      ApiClient.client = MockClient((request) async {
        if (request.method == 'GET' && request.url.path.contains('/packages')) {
          return utf8Response({
            'success': true,
            'data': [testPackage.toJson()],
          }, 200);
        } else if (request.method == 'POST' &&
            request.url.path.contains('/generate-batch')) {
          return utf8Response({
            'success': true,
            'data': {
              'batch': mockBatch.toJson(),
              'cards': [
                testCard.toJson(),
                testCard.copyWith(id: 'c-102', username: 'user_test_89').toJson(),
              ],
            },
          }, 201);
        }
        return utf8Response({}, 404);
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: GenerateCardsScreen(),
        ),
      );
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Tap Generate button
      await tester.tap(find.text('بدء توليد دفعة الكروت الآن'));
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Check success section is displayed
      expect(find.text('تم توليد الكروت بنجاح! 🎉'), findsOneWidget);

      // Verify Batch PDF export button is present
      expect(
        find.textContaining('تحميل / مشاركة PDF لكل الدفعة'),
        findsOneWidget,
      );

      // Verify QR voucher preview button is present on preview cards
      expect(find.byIcon(Icons.qr_code_2_rounded), findsNWidgets(2));

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  });
}

extension CardModelCopy on CardModel {
  CardModel copyWith({String? id, String? username}) {
    return CardModel(
      id: id ?? this.id,
      username: username ?? this.username,
      password: password,
      status: status,
      price: price,
      packageId: packageId,
    );
  }
}
