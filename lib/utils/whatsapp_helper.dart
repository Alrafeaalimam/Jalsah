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

const String kSupportPhone1 = '0115715672';
const String kSupportPhone2 = '0115715651';

/// Formats a Sudanese phone number into the international wa.me format.
/// e.g. "0115715672" -> "249115715672"
String formatWhatsAppNumber(String phone) {
  String cleaned = phone.replaceAll(RegExp(r'[^0-9]'), '');
  if (cleaned.startsWith('0')) {
    cleaned = '249${cleaned.substring(1)}';
  } else if (!cleaned.startsWith('249')) {
    cleaned = '249$cleaned';
  }
  return cleaned;
}

/// Opens WhatsApp chat directly via wa.me URL.
/// Falls back to copying phone to clipboard if launch fails.
Future<void> launchWhatsApp(
  BuildContext context,
  String phone, {
  String? initialText,
}) async {
  final intlNumber = formatWhatsAppNumber(phone);
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
Widget buildWhatsAppSupportCard({
  required BuildContext context,
  String title = 'تواصل مع الدعم الفني والمبيعات',
  String subtitle = 'اضغط على أي رقم للمراسلة المباشرة عبر واتساب',
}) {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.pageBg,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        color: AppColors.statusOnline.withValues(alpha: 0.3),
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
                color: AppColors.statusOnline.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.support_agent_rounded,
                color: AppColors.statusOnline,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.cairo(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                    ),
                  ),
                  Text(
                    subtitle,
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
        Row(
          children: [
            Expanded(
              child: _buildPhoneButton(
                context: context,
                phone: kSupportPhone1,
                label: 'الرقم الأول',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildPhoneButton(
                context: context,
                phone: kSupportPhone2,
                label: 'الرقم الثاني',
              ),
            ),
          ],
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
      initialText: 'السلام عليكم، أحتاج مساعدة بخصوص نظام إدارة شبكات المايكروتك (جلسة).',
    ),
    borderRadius: BorderRadius.circular(14),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.chat_bubble_rounded,
          size: 16,
          color: AppColors.statusOnline,
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                phone,
                textDirection: TextDirection.ltr,
                style: GoogleFonts.cairo(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
              ),
              Text(
                label,
                style: GoogleFonts.cairo(
                  fontSize: 10,
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
