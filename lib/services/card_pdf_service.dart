// ============================================================================
// Platform: Commercial MikroTik Network & HotSpot Card Management System
// File: lib/services/card_pdf_service.dart
// Service: High-Quality PDF Generation & Android System Sharing / Printing
// Master Reference: Rule 26 (MVP: QR, PDF, Printing)
// ============================================================================

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/card_model.dart';
import '../models/package_model.dart';

class CardPdfService {
  static pw.Font? _arabicFont;

  /// Loads Arabic TrueType fonts supporting bidirectional rendering.
  static Future<void> _loadFonts() async {
    if (_arabicFont != null) return;

    try {
      _arabicFont = await PdfGoogleFonts.cairoRegular();
      return;
    } catch (_) {}

    // Fallback: Local Android / Linux system Arabic font
    try {
      const systemFontPath = '/system/fonts/NotoNaskhArabicUI-Regular.ttf';
      final file = File(systemFontPath);
      if (file.existsSync()) {
        final fontData = file.readAsBytesSync().buffer.asByteData();
        _arabicFont = pw.Font.ttf(fontData);
        return;
      }
    } catch (_) {}
  }

  /// Builds a complete multi-page PDF Document containing card vouchers.
  static Future<pw.Document> generateCardsDocument({
    required List<CardModel> cards,
    PackageModel? package,
    String? batchNumber,
  }) async {
    await _loadFonts();
    final baseFont = pw.Font.helvetica();
    final boldFont = pw.Font.helveticaBold();
    final fallbacks = _arabicFont != null ? <pw.Font>[_arabicFont!] : <pw.Font>[];

    final doc = pw.Document(
      title: 'كروت هوتسبوت جلسة - Jalsah Hotspot Cards',
      author: 'Jalsah MikroTik System',
      theme: pw.ThemeData.withFont(
        base: baseFont,
        bold: boldFont,
        fontFallback: fallbacks,
      ),
    );

    const int cardsPerPage = 6; // 2 columns x 3 rows per A4 page
    final int totalPages = (cards.length / cardsPerPage).ceil();

    for (int pageIndex = 0; pageIndex < totalPages; pageIndex++) {
      final startIndex = pageIndex * cardsPerPage;
      final endIndex = (startIndex + cardsPerPage > cards.length)
          ? cards.length
          : startIndex + cardsPerPage;
      final pageCards = cards.sublist(startIndex, endIndex);

      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(20),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                // Page Header
                pw.Container(
                  padding: const pw.EdgeInsets.only(bottom: 8),
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(
                      bottom: pw.BorderSide(color: PdfColors.grey300, width: 1),
                    ),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'جلسة | Jalsah HotSpot Voucher Cards',
                        style: const pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 12,
                          color: PdfColor.fromInt(0xFF2E2370),
                        ),
                      ),
                      pw.Text(
                        'دفعة: ${batchNumber ?? "-"} | صفحة ${pageIndex + 1} من $totalPages',
                        style: const pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 12),

                // Grid of Vouchers (2 columns)
                pw.Expanded(
                  child: pw.Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: pageCards.map((card) {
                      return pw.SizedBox(
                        width: 268,
                        child: _buildVoucherPdfWidget(
                          card: card,
                          package: package,
                        ),
                      );
                    }).toList(),
                  ),
                ),

                // Page Footer (Cutting Guide)
                pw.Container(
                  padding: const pw.EdgeInsets.only(top: 6),
                  alignment: pw.Alignment.center,
                  child: pw.Text(
                    '✂ استخدم خطوط التقطيع لقص الكروت وتوزيعها على المستخدمين',
                    style: const pw.TextStyle(
                      fontSize: 8.5,
                      color: PdfColors.grey600,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      );
    }

    return doc;
  }

  /// Builds a single voucher card styled with purple theme and yellow accents for PDF.
  static pw.Widget _buildVoucherPdfWidget({
    required CardModel card,
    PackageModel? package,
  }) {
    const purpleColor = PdfColor.fromInt(0xFF2E2370);
    const yellowColor = PdfColor.fromInt(0xFFFACC15);
    const darkBg = PdfColor.fromInt(0xFF1E1548);

    final double price = card.price > 0
        ? card.price
        : (package?.price ?? 0.0);
    final String formattedPrice = price > 0
        ? '${price == price.truncateToDouble() ? price.toInt() : price.toStringAsFixed(2)} SDG'
        : '';
    final String pkgName = package?.name ?? 'باقة هوتسبوت';
    final String pkgDuration = package?.formattedDuration ?? 'صلاحية محددة';

    return pw.Container(
      decoration: pw.BoxDecoration(
        color: purpleColor,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
        border: pw.Border.all(color: yellowColor, width: 1.2),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          // Header Bar
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: const pw.BoxDecoration(
              color: darkBg,
              borderRadius: pw.BorderRadius.vertical(
                top: pw.Radius.circular(9),
              ),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Row(
                  children: [
                    pw.Container(
                      width: 14,
                      height: 14,
                      alignment: pw.Alignment.center,
                      decoration: const pw.BoxDecoration(
                        color: yellowColor,
                        shape: pw.BoxShape.circle,
                      ),
                      child: pw.Text(
                        'W',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 9,
                          color: purpleColor,
                        ),
                      ),
                    ),
                    pw.SizedBox(width: 5),
                    pw.Text(
                      'جلسة | Jalsah',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 10,
                        color: PdfColors.white,
                      ),
                    ),
                  ],
                ),
                if (formattedPrice.isNotEmpty)
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: const pw.BoxDecoration(
                      color: yellowColor,
                      borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
                    ),
                    child: pw.Text(
                      formattedPrice,
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 8.5,
                        color: purpleColor,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Body: QR Code + Credentials
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                // QR Code
                pw.Container(
                  width: 60,
                  height: 60,
                  padding: const pw.EdgeInsets.all(3),
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.white,
                    borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
                  ),
                  child: pw.BarcodeWidget(
                    barcode: pw.Barcode.qrCode(),
                    data: '${card.username}:${card.password}',
                    width: 54,
                    height: 54,
                  ),
                ),
                pw.SizedBox(width: 10),

                // Credentials Column
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'اسم المستخدم (User):',
                        style: const pw.TextStyle(
                          fontSize: 7.5,
                          color: PdfColors.grey300,
                        ),
                      ),
                      pw.Text(
                        card.username,
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 12,
                          color: PdfColors.white,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'كلمة المرور (PIN):',
                        style: const pw.TextStyle(
                          fontSize: 7.5,
                          color: yellowColor,
                        ),
                      ),
                      pw.Text(
                        card.password,
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 13,
                          color: yellowColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Footer: Package details
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: const pw.BoxDecoration(
              color: darkBg,
              borderRadius: pw.BorderRadius.vertical(
                bottom: pw.Radius.circular(9),
              ),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  pkgName,
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 8,
                    color: PdfColors.white,
                  ),
                ),
                pw.Text(
                  pkgDuration,
                  style: const pw.TextStyle(
                    fontSize: 8,
                    color: yellowColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Exports and triggers the system share/print dialog for a batch of cards.
  static Future<void> shareBatchCardsPdf({
    required List<CardModel> cards,
    PackageModel? package,
    String? batchNumber,
  }) async {
    final doc = await generateCardsDocument(
      cards: cards,
      package: package,
      batchNumber: batchNumber,
    );

    final Uint8List pdfBytes = await doc.save();
    final filename =
        'jalsah-batch-${batchNumber ?? DateTime.now().millisecondsSinceEpoch}.pdf';

    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: filename,
    );
  }

  /// Exports and triggers the system share/print dialog for a single card.
  static Future<void> shareSingleCardPdf({
    required CardModel card,
    PackageModel? package,
  }) async {
    final doc = await generateCardsDocument(
      cards: [card],
      package: package,
      batchNumber: 'single',
    );

    final Uint8List pdfBytes = await doc.save();
    final filename = 'jalsah-card-${card.username}.pdf';

    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: filename,
    );
  }

  /// Direct print layout for batch cards using standard Android printing preview.
  static Future<void> printBatchCardsPdf({
    required List<CardModel> cards,
    PackageModel? package,
    String? batchNumber,
  }) async {
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async {
        final doc = await generateCardsDocument(
          cards: cards,
          package: package,
          batchNumber: batchNumber,
        );
        return doc.save();
      },
      name: 'jalsah-batch-${batchNumber ?? "cards"}',
    );
  }

  /// Direct print layout for a single card.
  static Future<void> printSingleCardPdf({
    required CardModel card,
    PackageModel? package,
  }) async {
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async {
        final doc = await generateCardsDocument(
          cards: [card],
          package: package,
          batchNumber: 'card-${card.username}',
        );
        return doc.save();
      },
      name: 'jalsah-card-${card.username}',
    );
  }
}
