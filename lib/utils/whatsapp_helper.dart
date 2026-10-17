// ============================================================================
// Platform: Commercial MikroTik Network & HotSpot Card Management System (Jalsah)
// File: lib/utils/whatsapp_helper.dart
// Utility: WhatsApp Direct Launch & Support Contacts (Rule 20, Rule 27)
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_colors.dart';
import '../widgets/pressable_neumorphic_card.dart';
import '../services/app_settings.dart';

const String kSupportPhone1 = '0115715672';
const String kSupportPhone2 = '0115715651';

/// Official WhatsApp Brand Color
const Color kWhatsAppBrandColor = Color(0xFF25D366);

/// A pixel-perfect, standalone vector WhatsApp icon widget
class WhatsAppIcon extends StatelessWidget {
  final double size;
  final Color? color;

  const WhatsAppIcon({
    super.key,
    this.size = 20,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _WhatsAppLogoPainter(brandColor: color ?? kWhatsAppBrandColor),
      ),
    );
  }
}

class _WhatsAppLogoPainter extends CustomPainter {
  final Color brandColor;
  const _WhatsAppLogoPainter({required this.brandColor});

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24.0;

    // Green circular background with speech bubble pointer
    final bgPaint = Paint()
      ..color = brandColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final bubblePath = Path();
    bubblePath.addOval(Rect.fromCircle(
      center: Offset(12.0 * scale, 11.5 * scale),
      radius: 9.8 * scale,
    ));

    // Bottom-left speech bubble tail pointer
    final tailPath = Path()
      ..moveTo(6.2 * scale, 17.8 * scale)
      ..lineTo(3.2 * scale, 21.2 * scale)
      ..lineTo(7.6 * scale, 19.8 * scale)
      ..close();
    bubblePath.addPath(tailPath, Offset.zero);

    canvas.drawPath(bubblePath, bgPaint);

    // Handset receiver silhouette in white
    final phonePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final handsetPath = Path();
    handsetPath.moveTo(8.5 * scale, 8.0 * scale);
    handsetPath.cubicTo(8.2 * scale, 8.0 * scale, 7.8 * scale, 8.2 * scale, 7.5 * scale, 8.5 * scale);
    handsetPath.cubicTo(7.1 * scale, 8.9 * scale, 6.5 * scale, 9.7 * scale, 6.5 * scale, 11.0 * scale);
    handsetPath.cubicTo(6.5 * scale, 12.3 * scale, 7.4 * scale, 13.6 * scale, 7.6 * scale, 13.8 * scale);
    handsetPath.cubicTo(7.8 * scale, 14.0 * scale, 9.6 * scale, 16.7 * scale, 12.2 * scale, 17.8 * scale);
    handsetPath.cubicTo(14.4 * scale, 18.7 * scale, 14.8 * scale, 18.5 * scale, 15.3 * scale, 18.4 * scale);
    handsetPath.cubicTo(15.8 * scale, 18.3 * scale, 16.8 * scale, 17.7 * scale, 17.0 * scale, 17.0 * scale);
    handsetPath.cubicTo(17.2 * scale, 16.4 * scale, 17.2 * scale, 15.9 * scale, 17.1 * scale, 15.8 * scale);
    handsetPath.cubicTo(17.0 * scale, 15.6 * scale, 16.8 * scale, 15.5 * scale, 16.5 * scale, 15.4 * scale);
    handsetPath.lineTo(14.9 * scale, 14.6 * scale);
    handsetPath.cubicTo(14.6 * scale, 14.5 * scale, 14.4 * scale, 14.5 * scale, 14.2 * scale, 14.8 * scale);
    handsetPath.lineTo(13.6 * scale, 15.6 * scale);
    handsetPath.cubicTo(13.4 * scale, 15.8 * scale, 13.2 * scale, 15.8 * scale, 12.9 * scale, 15.7 * scale);
    handsetPath.cubicTo(12.3 * scale, 15.4 * scale, 10.9 * scale, 14.8 * scale, 9.9 * scale, 13.2 * scale);
    handsetPath.cubicTo(9.7 * scale, 12.8 * scale, 9.8 * scale, 12.6 * scale, 10.0 * scale, 12.4 * scale);
    handsetPath.lineTo(10.5 * scale, 11.8 * scale);
    handsetPath.cubicTo(10.7 * scale, 11.6 * scale, 10.7 * scale, 11.4 * scale, 10.6 * scale, 11.2 * scale);
    handsetPath.lineTo(9.7 * scale, 9.0 * scale);
    handsetPath.cubicTo(9.5 * scale, 8.5 * scale, 9.3 * scale, 8.6 * scale, 9.1 * scale, 8.6 * scale);
    handsetPath.close();

    canvas.drawPath(handsetPath, phonePaint);
  }

  @override
  bool shouldRepaint(covariant _WhatsAppLogoPainter oldDelegate) =>
      oldDelegate.brandColor != brandColor;
}

/// Returns dynamic WhatsApp numbers from AppSettings or static fallback
List<String> getSupportWhatsAppNumbers() {
  final nums = AppSettings.instance.whatsappNumbers;
  if (nums.isNotEmpty) return nums;
  return const [kSupportPhone1, kSupportPhone2];
}

/// Validates and sanitizes a phone number into international WhatsApp format (e.g. "249115715672").
/// Returns null if the phone number is invalid or cannot be formatted.
String? sanitizeAndFormatWhatsAppNumber(String phone) {
  String digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return null;

  // Remove leading double zeros '00'
  if (digits.startsWith('00')) {
    digits = digits.substring(2);
  }

  // Sudanese local format: 10 digits starting with '0' (e.g. 0115715672 or 0912345678)
  if (digits.startsWith('0') && digits.length == 10) {
    digits = '249${digits.substring(1)}';
  } else if (!digits.startsWith('249') &&
      digits.length == 9 &&
      (digits.startsWith('1') || digits.startsWith('9'))) {
    // 9 digits without leading zero (e.g. 115715672)
    digits = '249$digits';
  }

  // Valid international length should be between 9 and 15 digits
  if (digits.length < 9 || digits.length > 15) {
    return null;
  }

  return digits;
}

/// Formats a Sudanese phone number into the international wa.me format.
/// Backwards-compatible wrapper around [sanitizeAndFormatWhatsAppNumber].
String formatWhatsAppNumber(String phone) {
  return sanitizeAndFormatWhatsAppNumber(phone) ?? phone.replaceAll(RegExp(r'[^0-9]'), '');
}

/// Opens WhatsApp chat directly via wa.me URL for the specified phone number.
/// Validates the number first; falls back to copying phone to clipboard if launch fails.
Future<void> launchWhatsApp(
  BuildContext context,
  String phone, {
  String? initialText,
}) async {
  final intlNumber = sanitizeAndFormatWhatsAppNumber(phone);

  if (intlNumber == null) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.statusOffline,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'رقم الهاتف غير صالح لمراسلة واتساب: $phone',
                style: GoogleFonts.cairo(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    return;
  }

  final query = (initialText != null && initialText.isNotEmpty)
      ? '?text=${Uri.encodeComponent(initialText)}'
      : '';
  final uri = Uri.parse('https://wa.me/$intlNumber$query');

  bool launched = false;
  try {
    launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
  } catch (_) {
    launched = false;
  }

  if (!launched) {
    await Clipboard.setData(ClipboardData(text: phone));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.statusOnline,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'تم نسخ رقم الدعم: $phone (تعذر فتح تطبيق واتساب مباشرة)',
                style: GoogleFonts.cairo(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Builds a responsive Neumorphic support card with both WhatsApp contact numbers.
/// Supports [englishTag] to cleanly display English brand/system names in LTR without RTL bidi conflicts.
Widget buildWhatsAppSupportCard({
  required BuildContext context,
  String title = 'تواصل مع الدعم الفني والمبيعات',
  String subtitle = 'اضغط على أي رقم للمراسلة المباشرة عبر واتساب',
  String? englishTag,
}) {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.pageBg,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        color: kWhatsAppBrandColor.withValues(alpha: 0.3),
        width: 1.5,
      ),
      boxShadow: [
        const BoxShadow(
          color: AppColors.shadowLight,
          offset: Offset(-3, -3),
          blurRadius: 6,
        ),
        BoxShadow(
          color: AppColors.shadowDark.withValues(alpha: 0.3),
          offset: const Offset(3, 3),
          blurRadius: 6,
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: kWhatsAppBrandColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const WhatsAppIcon(size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          textAlign: TextAlign.right,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.cairo(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textDark,
                          ),
                        ),
                      ),
                      if (englishTag != null && englishTag.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: AppColors.heroGradientStart.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Directionality(
                            textDirection: TextDirection.ltr,
                            child: Text(
                              englishTag,
                              style: GoogleFonts.cairo(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppColors.heroGradientStart,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    textAlign: TextAlign.right,
                    style: GoogleFonts.cairo(
                      fontSize: 11.5,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Builder(
          builder: (context) {
            final numbers = getSupportWhatsAppNumbers();
            if (numbers.length <= 2) {
              return Row(
                children: [
                  for (int i = 0; i < numbers.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(
                      child: _buildPhoneButton(
                        context: context,
                        phone: numbers[i],
                        label: i == 0 ? 'الرقم الأول' : 'الرقم الثاني',
                      ),
                    ),
                  ],
                ],
              );
            }
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (int i = 0; i < numbers.length; i++)
                  SizedBox(
                    width: 145,
                    child: _buildPhoneButton(
                      context: context,
                      phone: numbers[i],
                      label: 'رقم الدعم ${i + 1}',
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    ),
  );
}

Widget _buildPhoneButton({
  required BuildContext context,
  required String phone,
  required String label,
}) {
  return PressableNeumorphicCard(
    onTap: () => launchWhatsApp(
      context,
      phone,
      initialText:
          'السلام عليكم، أحتاج مساعدة بخصوص نظام إدارة شبكات المايكروتك (${AppSettings.instance.appName}).',
    ),
    borderRadius: BorderRadius.circular(14),
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const WhatsAppIcon(size: 19),
        const SizedBox(width: 5),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  phone,
                  textDirection: TextDirection.ltr,
                  style: GoogleFonts.cairo(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  label,
                  style: GoogleFonts.cairo(
                    fontSize: 10,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

