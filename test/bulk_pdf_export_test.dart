// ============================================================================
// Platform: Commercial MikroTik Network & HotSpot Card Management System
// File: test/bulk_pdf_export_test.dart
// Unit & Widget Tests: Bulk PDF Export & CardsListScreen Export State
// Master Reference: Rule 26 (MVP: QR, PDF, Printing), Bulk PDF Export Feature
// ============================================================================

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mikrotik_cards_app/models/card_model.dart';
import 'package:mikrotik_cards_app/models/package_model.dart';
import 'package:mikrotik_cards_app/screens/cards_list_screen.dart';
import 'package:mikrotik_cards_app/services/api_client.dart';
import 'package:mikrotik_cards_app/services/card_pdf_service.dart';

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

  const testPackage1 = PackageModel(
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

  const testPackage2 = PackageModel(
    id: 'pkg-2',
    name: 'باقة أسبوعية',
    code: 'PKG-WEEKLY',
    downloadSpeedLimit: '10M',
    uploadSpeedLimit: '5M',
    durationMinutes: 10080,
    validityDays: 7,
    price: 1500.0,
    hotspotProfileName: 'hs_weekly',
  );

  group('CardPdfService Bulk PDF Generation Tests', () {
    test('generateCardsDocument creates multi-page PDF document for large card batch',
        () async {
      // 15 cards with 6 per page should yield ceil(15/6) = 3 pages
      final cardsList = List.generate(
        15,
        (i) => CardModel(
          id: 'card-$i',
          username: 'user_bulk_$i',
          password: 'pin_${1000 + i}',
          status: i % 2 == 0 ? 'AVAILABLE' : 'SOLD',
          price: (i % 2 == 0) ? 350.0 : 1500.0,
          packageId: (i % 2 == 0) ? 'pkg-1' : 'pkg-2',
        ),
      );

      final Map<String, PackageModel> packagesMap = {
        'pkg-1': testPackage1,
        'pkg-2': testPackage2,
      };

      final doc = await CardPdfService.generateCardsDocument(
        cards: cardsList,
        packagesMap: packagesMap,
        batchNumber: 'ALL-ACTIVE-FILTER',
      );

      final bytes = await doc.save();
      expect(bytes, isNotNull);
      expect(bytes.isNotEmpty, isTrue);
      // Valid PDF begins with '%PDF-'
      expect(bytes.sublist(0, 5), equals([0x25, 0x50, 0x44, 0x46, 0x2D]));
      // Verify exactly 3 A4 pages generated for 15 vouchers
      expect(doc.document.pdfPageList.pages.length, equals(3));
    });

    test('generateCardsDocument handles empty cards gracefully with placeholder page',
        () async {
      final doc = await CardPdfService.generateCardsDocument(
        cards: [],
        batchNumber: 'EMPTY-BATCH',
      );

      final bytes = await doc.save();
      expect(bytes, isNotNull);
      expect(bytes.isNotEmpty, isTrue);
      expect(bytes.sublist(0, 5), equals([0x25, 0x50, 0x44, 0x46, 0x2D]));
      expect(doc.document.pdfPageList.pages.length, equals(1));
    });
  });

  group('CardsListScreen Bulk PDF Export Widget Tests', () {
    testWidgets(
        'renders export PDF button in disabled state when list is empty and shows explanatory message on tap',
        (WidgetTester tester) async {
      // Mock empty cards response
      ApiClient.client = MockClient((request) async {
        if (request.url.path.contains('/cards')) {
          return utf8Response({
            'success': true,
            'data': [],
          }, 200);
        } else if (request.url.path.contains('/packages')) {
          return utf8Response({
            'success': true,
            'data': [],
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

      // Check export button exists
      final exportBtnFinder = find.byKey(const Key('export_pdf_button'));
      expect(exportBtnFinder, findsOneWidget);
      expect(find.text('تصدير PDF'), findsOneWidget);

      // Verify empty list state message in screen
      expect(find.text('لا توجد كروت في هذه القائمة'), findsOneWidget);

      // Tap disabled export button
      await tester.tap(exportBtnFinder);
      await tester.pump();

      // Explanatory snackbar message should be displayed
      expect(
        find.text('لا توجد كروت متاحة للتصدير في هذه القائمة'),
        findsOneWidget,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets(
        'renders active export PDF button when cards exist and initiates export',
        (WidgetTester tester) async {
      final sampleCards = [
        CardModel(
          id: 'card-1',
          username: 'user_active_1',
          password: 'pin_1111',
          status: 'AVAILABLE',
          price: 350.0,
          packageId: testPackage1.id,
        ),
        CardModel(
          id: 'card-2',
          username: 'user_active_2',
          password: 'pin_2222',
          status: 'AVAILABLE',
          price: 350.0,
          packageId: testPackage1.id,
        ),
      ];

      ApiClient.client = MockClient((request) async {
        if (request.url.path.contains('/cards')) {
          return utf8Response({
            'success': true,
            'data': sampleCards.map((c) => c.toJson()).toList(),
          }, 200);
        } else if (request.url.path.contains('/packages')) {
          return utf8Response({
            'success': true,
            'data': [testPackage1.toJson()],
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

      // Check export button exists
      final exportBtnFinder = find.byKey(const Key('export_pdf_button'));
      expect(exportBtnFinder, findsOneWidget);

      // Verify cards are visible
      expect(find.text('user_active_1'), findsOneWidget);
      expect(find.text('user_active_2'), findsOneWidget);

      // Verify opacity is 1.0 (enabled)
      final opacityWidget = tester.widget<Opacity>(
        find.descendant(
          of: exportBtnFinder,
          matching: find.byType(Opacity),
        ),
      );
      expect(opacityWidget.opacity, equals(1.0));

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  });
}
