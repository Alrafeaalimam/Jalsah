// ============================================================================
// Platform: Commercial MikroTik Network & HotSpot Card Management System (Jalsah)
// File: lib/screens/verify_device_otp_screen.dart
// Screen: New Device OTP Verification Screen (Rule 14 - Security)
// ============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_client.dart';
import '../theme/app_colors.dart';
import '../widgets/bounce_button.dart';
import '../widgets/neumorphic_text_field.dart';
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
  bool _isResending = false;
  int _resendCountdown = 0;
  Timer? _resendTimer;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
  }

  void _startResendTimer() {
    _resendCountdown = 60;
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_resendCountdown > 0) {
          _resendCountdown--;
        } else {
          timer.cancel();
        }
      });
    });
  }

  Future<void> _handleResendOtp() async {
    if (_resendCountdown > 0 || _isResending) return;
    setState(() {
      _isResending = true;
      _errorMessage = null;
    });

    final res = await ApiClient.resendDeviceOtp(
      tempToken: widget.tempToken,
      deviceLabel: widget.deviceLabel,
    );

    if (!mounted) return;
    setState(() {
      _isResending = false;
    });

    if (res['success'] == true) {
      _startResendTimer();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            res['message'] as String? ?? 'تم إرسال رمز تحقق جديد إلى بريدك الإلكتروني',
            style: GoogleFonts.cairo(fontWeight: FontWeight.w600),
          ),
          backgroundColor: AppColors.statusOnline,
        ),
      );
    } else {
      setState(() {
        _errorMessage = res['errorMessage'] as String? ?? 'فشل إعادة إرسال رمز التحقق';
      });
    }
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
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
                                color: Colors.white.withValues(alpha: 0.9),
                                offset: const Offset(-5, -5),
                                blurRadius: 10,
                              ),
                              BoxShadow(
                                color: const Color(0xFFD1D9E6).withValues(alpha: 0.8),
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
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFFBFDBFE),
                            width: 1.2,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.mark_email_read_rounded,
                                  color: Color(0xFF2563EB),
                                  size: 24,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'تم إرسال كود تحقق لبريدك لأن هذا جهاز جديد',
                                        style: GoogleFonts.cairo(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w800,
                                          color: const Color(0xFF1E40AF),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'تم إرسال رمز التحقق إلى بريدك الإلكتروني المرتبط بالحساب لأن هذا الجهاز يتم تسجيل الدخول منه لأول مرة أو يحتاج تأكيد أمان.',
                                        style: GoogleFonts.cairo(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF1E40AF),
                                          height: 1.4,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            if (widget.emailMasked != null && widget.emailMasked!.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFDBEAFE)),
                                ),
                                child: Text(
                                  'تم الإرسال إلى: ${widget.emailMasked}',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.cairo(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF1D4ED8),
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 10),
                            Text(
                              'إذا لم يصلك الرمز، يرجى التأكد من صحة عنوان البريد الإلكتروني، وفحص صندوق الوارد (Inbox) ومجلد الرسائل غير المرغوب فيها (Spam / Junk)، والانتظار قليلاً قبل طلب إعادة الإرسال.',
                              style: GoogleFonts.cairo(
                                fontSize: 12,
                                color: const Color(0xFF334155),
                                height: 1.5,
                              ),
                            ),
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
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                const Icon(
                                  Icons.shield_outlined,
                                  color: Color(0xFFDC2626),
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'أمان الحساب: لا تشارك رمز التحقق مع أي شخص على الإطلاق.',
                                    style: GoogleFonts.cairo(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFFDC2626),
                                    ),
                                  ),
                                ),
                              ],
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
                      BounceButton(
                        onPressed: _isLoading ? null : _submitVerification,
                        isLoading: _isLoading,
                        height: 52,
                        icon: Icons.verified_user_rounded,
                        label: 'تأكيد الجهاز والدخول',
                      ),
                      const SizedBox(height: 16),

                      // Resend OTP Button with countdown timer
                      Center(
                        child: TextButton.icon(
                          onPressed: (_resendCountdown > 0 || _isResending)
                              ? null
                              : _handleResendOtp,
                          icon: _isResending
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Icon(
                                  Icons.refresh_rounded,
                                  size: 18,
                                  color: _resendCountdown > 0
                                      ? AppColors.textMuted
                                      : AppColors.heroGradientStart,
                                ),
                          label: Text(
                            _resendCountdown > 0
                                ? 'إعادة إرسال الرمز بعد ($_resendCountdown ثانية)'
                                : 'إعادة إرسال رمز التحقق الآن',
                            style: GoogleFonts.cairo(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _resendCountdown > 0
                                  ? AppColors.textMuted
                                  : AppColors.heroGradientStart,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

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
