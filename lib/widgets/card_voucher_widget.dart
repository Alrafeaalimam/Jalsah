// ============================================================================
// Platform: Commercial MikroTik Network & HotSpot Card Management System
// File: lib/widgets/card_voucher_widget.dart
// Widget: Visual Card Voucher Component with QR Code & Jalsah Branding
// Master Reference: Rule 26 (MVP: QR, PDF, Printing)
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/card_model.dart';
import '../models/package_model.dart';
import '../theme/app_colors.dart';

class CardVoucherWidget extends StatelessWidget {
  final CardModel card;
  final PackageModel? package;
  final String? packageName;
  final String? packageDuration;
  final double? packagePrice;
  final bool showShadow;
  final double? width;

  const CardVoucherWidget({
    super.key,
    required this.card,
    this.package,
    this.packageName,
    this.packageDuration,
    this.packagePrice,
    this.showShadow = true,
    this.width,
  });

  String get _resolvedPackageName {
    if (packageName != null && packageName!.isNotEmpty) return packageName!;
    if (package != null && package!.name.isNotEmpty) return package!.name;
    return 'باقة إنترنت';
  }

  String get _resolvedDuration {
    if (packageDuration != null && packageDuration!.isNotEmpty) {
      return packageDuration!;
    }
    if (package != null) return package!.formattedDuration;
    return 'صلاحية محددة';
  }

  double get _resolvedPrice {
    if (packagePrice != null && packagePrice! > 0) return packagePrice!;
    if (card.price > 0) return card.price;
    if (package != null && package!.price > 0) return package!.price;
    return 0.0;
  }

  void _copyToClipboard(BuildContext context, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.heroGradientStart,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(
          children: [
            const Icon(Icons.check_rounded, color: AppColors.accentYellow, size: 18),
            const SizedBox(width: 8),
            Text(
              'تم نسخ $label: $text',
              style: GoogleFonts.cairo(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double displayPrice = _resolvedPrice;
    final String formattedPriceText = displayPrice > 0
        ? '${displayPrice == displayPrice.truncateToDouble() ? displayPrice.toInt() : displayPrice.toStringAsFixed(2)} SDG'
        : '';

    return Container(
      width: width,
      constraints: const BoxConstraints(maxWidth: 380),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF2E2370), // Deep Purple
            Color(0xFF1E1548), // Dark Indigo
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppColors.accentYellow.withValues(alpha: 0.35),
          width: 1.5,
        ),
        boxShadow: showShadow
            ? [
                BoxShadow(
                  color: const Color(0xFF2E2370).withValues(alpha: 0.35),
                  offset: const Offset(0, 8),
                  blurRadius: 18,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Accent Bar
            Container(
              height: 4,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.accentYellow,
                    Color(0xFFFBBF24),
                    Color(0xFFF59E0B),
                  ],
                ),
              ),
            ),

            // Header Section: Branding + Price
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Logo & Brand Name
                  Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: AppColors.accentYellow,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.accentYellow.withValues(alpha: 0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.wifi_tethering_rounded,
                          color: AppColors.textDark,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'جلسة',
                                style: GoogleFonts.cairo(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  height: 1.1,
                                ),
                              ),
                              Text(
                                ' | Jalsah',
                                style: GoogleFonts.cairo(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.accentYellow,
                                  height: 1.1,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            'شبكة إنترنت هوتسبوت',
                            style: GoogleFonts.cairo(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withValues(alpha: 0.75),
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Price Badge
                  if (formattedPriceText.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.accentYellow,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accentYellow.withValues(alpha: 0.35),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: Text(
                        formattedPriceText,
                        style: GoogleFonts.cairo(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Perforated / Dashed Separator Line
            _buildDashedLine(),

            // Card Body: QR Code + Credentials
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // QR Code
                  Container(
                    width: 96,
                    height: 96,
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: QrImageView(
                        data: card.password.isNotEmpty ? '${card.username}:${card.password}' : card.username,
                        version: QrVersions.auto,
                        size: 86.0,
                        backgroundColor: Colors.white,
                        padding: EdgeInsets.zero,
                        eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: Color(0xFF2E2370),
                        ),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: Color(0xFF1E1548),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Credentials (User & PIN)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Username or Voucher Code
                        Text(
                          card.password.isEmpty ? 'رقم الكرت / Voucher Code' : 'اسم المستخدم / User',
                          style: GoogleFonts.cairo(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                        const SizedBox(height: 1),
                        InkWell(
                          onTap: () => _copyToClipboard(
                            context,
                            card.username,
                            card.password.isEmpty ? 'رقم الكرت' : 'اسم المستخدم',
                          ),
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  card.username,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.cairo(
                                    fontSize: card.password.isEmpty ? 18 : 16,
                                    fontWeight: FontWeight.w900,
                                    color: card.password.isEmpty ? AppColors.accentYellow : Colors.white,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(
                                Icons.copy_rounded,
                                size: 14,
                                color: Colors.white.withValues(alpha: 0.6),
                              ),
                            ],
                          ),
                        ),
                        if (card.password.isNotEmpty) ...[
                          const SizedBox(height: 8),

                          // Password / PIN
                          Text(
                            'كلمة المرور / PIN',
                            style: GoogleFonts.cairo(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                          ),
                          const SizedBox(height: 1),
                          InkWell(
                            onTap: () => _copyToClipboard(
                              context,
                              card.password,
                              'كلمة المرور',
                            ),
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    card.password,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.cairo(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.accentYellow,
                                      letterSpacing: 2.0,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(
                                  Icons.copy_rounded,
                                  size: 14,
                                  color: AppColors.accentYellow,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Card Footer: Package Name & Duration
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.22),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(20),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Package Name
                  Expanded(
                    child: Row(
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 13,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            _resolvedPackageName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.cairo(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Duration
                  Row(
                    children: [
                      const Icon(
                        Icons.access_time_rounded,
                        size: 13,
                        color: AppColors.accentYellow,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _resolvedDuration,
                        style: GoogleFonts.cairo(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.accentYellow,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashedLine() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boxWidth = constraints.constrainWidth();
        const dashWidth = 5.0;
        const dashHeight = 1.0;
        const dashSpace = 4.0;
        final dashCount = (boxWidth / (dashWidth + dashSpace)).floor();
        return SizedBox(
          width: boxWidth,
          height: 6,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(dashCount, (_) {
              return SizedBox(
                width: dashWidth,
                height: dashHeight,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}
