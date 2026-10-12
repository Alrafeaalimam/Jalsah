// ============================================================================
// Platform: Commercial MikroTik Network & HotSpot Card Management System (Jalsah)
// File: lib/screens/verify_device_otp_screen.dart
// Screen: New Device OTP Verification Screen (Rule 14 - Security)
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_client.dart';
import '../theme/app_colors.dart';
import '../widgets/neumorphic_text_field.dart';
import '../widgets/pressable_neumorphic_card.dart';
import 'dashboard_screen.dart';
import 'admin/super_admin_dashboard.dart';
import 'temp_login_screen.dart';

class VerifyDeviceOtpScreen extends StatefulWidget {
  final String tempToken;
  final String deviceFingerprint;
  final String? deviceLabel;
  final String? emailMasked;
  final String? username;

  const VerifyDeviceOtpScreen({
    super.key,
    required this.tempToken,
    required this.deviceFingerprint,
    this.deviceLabel,
    this.emailMasked,
    this.username,
  });

  @override
  State<VerifyDeviceOtpScreen> createState() => _VerifyDeviceOtpScreenState();
}

class _VerifyDeviceOtpScreenState extends State<VerifyDeviceOtpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _otpController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _submitVerification() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final otp = _otpController.text.trim();
    final result = await ApiClient.verifyDeviceOtp(
      tempToken: widget.tempToken,
      otpCode: otp,
      deviceFingerprint: widget.deviceFingerprint,
      deviceLabel: widget.deviceLabel,
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (result['success'] == true) {
      final userData = result['data']?['user'] as Map<String, dynamic>?;
      final fullName = userData?['fullName'] as String? ??
          userData?['username'] as String? ??
          widget.username ??
          'المدير';

      final tokenRole = ApiClient.getUserRole() ?? userData?['role'] as String?;
      if (tokenRole != null && tokenRole.isNotEmpty) {
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_role', tokenRole);
        } catch (_) {}
      }

      if (!mounted) return;

      if (tokenRole == 'SUPER_ADMIN') {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => SuperAdminDashboardScreen(
              adminName: fullName,
            ),
          ),
          (route) => false,
        );
      } else {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => DashboardScreen(
              userName: fullName,
            ),
          ),
          (route) => false,
        );
      }
    } else {
      setState(() {
        _errorMessage = result['errorMessage'] ?? 'كود التحقق غير صحيح أو انتهت صلاحيته';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.pageBg,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Security Icon Badge
                      Center(
                        child: Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.pageBg,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.white.withOpacity(0.9),
                                offset: const Offset(-5, -5),
                                blurRadius: 10,
                              ),
                              BoxShadow(
                                color: const Color(0xFFD1D9E6).withOpacity(0.8),
                                offset: const Offset(5, 5),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.security_rounded,
                              size: 44,
                              color: Color(0xFF2C3E50),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Title
                      Text(
                        'تأكيد الجهاز الجديد',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.cairo(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Explanatory Message Box
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(0xFFBFDBFE),
                            width: 1.2,
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.info_outline_rounded,
                                  color: Color(0xFF2563EB),
                                  size: 22,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'تم إرسال كود تحقق لبريدك لأن هذا جهاز جديد',
                                    style: GoogleFonts.cairo(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF1E40AF),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (widget.emailMasked != null && widget.emailMasked!.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  'تم إرسال الرمز المكون من 6 أرقام إلى: ${widget.emailMasked}',
                                  style: GoogleFonts.cairo(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF3B82F6),
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 6),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                'صلاحية الكود 10 دقائق فقط للاستخدام لمرة واحدة.',
                                style: GoogleFonts.cairo(
                                  fontSize: 12,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Error message if present
                      if (_errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFEBEE),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFFFCDD2)),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline_rounded,
                                color: Color(0xFFD32F2F),
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: GoogleFonts.cairo(
                                    color: const Color(0xFFD32F2F),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // OTP Field
                      NeumorphicTextField(
                        label: 'كود التحقق (OTP)',
                        hintText: 'أدخل الكود المكون من 6 أرقام',
                        controller: _otpController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(6),
                        ],
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'يرجى إدخال كود التحقق';
                          }
                          if (value.trim().length != 6) {
                            return 'كود التحقق يجب أن يتكون من 6 أرقام';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 28),

                      // Confirm & Login Button
                      PressableNeumorphicCard(
                        onTap: _isLoading ? () {} : _submitVerification,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: _isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.textDark),
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.verified_user_rounded,
                                      size: 20,
                                      color: AppColors.textDark,
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      'تأكيد الجهاز والدخول',
                                      style: GoogleFonts.cairo(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.textDark,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Return to Login Link
                      Center(
                        child: TextButton.icon(
                          onPressed: () {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (context) => const TempLoginScreen(),
                              ),
                            );
                          },
                          icon: const Icon(
                            Icons.arrow_back_rounded,
                            size: 18,
                            color: AppColors.textMuted,
                          ),
                          label: Text(
                            'العودة لشاشة تسجيل الدخول',
                            style: GoogleFonts.cairo(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
