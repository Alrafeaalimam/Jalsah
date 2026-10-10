// ============================================================================
// Platform: Commercial MikroTik Network & HotSpot Card Management System
// File: lib/screens/register_screen.dart
// Screen: Public Tenant Self-Registration (Neumorphic Style)
// Master Reference: Rule 14 (Security), Rule 19 (Auth), Rule 32 (Product Rules)
// ============================================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_client.dart';
import '../theme/app_colors.dart';
import '../widgets/neumorphic_text_field.dart';
import '../widgets/pressable_neumorphic_card.dart';
import 'dashboard_screen.dart';
import 'temp_login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _networkNameController = TextEditingController();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _networkNameController.dispose();
    _fullNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    final networkName = _networkNameController.text.trim();
    final fullName = _fullNameController.text.trim();
    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;
    final phone = _phoneController.text.trim();

    // 1. Client-side validations
    if (networkName.isEmpty ||
        fullName.isEmpty ||
        username.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty) {
      setState(() {
        _errorMessage = 'يرجى ملء جميع الحقول المطلوبة';
      });
      return;
    }

    if (networkName.length < 2) {
      setState(() {
        _errorMessage = 'يجب أن يكون اسم الشبكة حرفين على الأقل';
      });
      return;
    }

    if (username.length < 3) {
      setState(() {
        _errorMessage = 'اسم المستخدم يجب ألا يقل عن 3 أحرف';
      });
      return;
    }

    if (!RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$').hasMatch(email)) {
      setState(() {
        _errorMessage = 'صيغة البريد الإلكتروني غير صحيحة';
      });
      return;
    }

    if (password.length < 8) {
      setState(() {
        _errorMessage = 'يجب ألا تقل كلمة المرور عن 8 أحرف';
      });
      return;
    }

    if (password != confirmPassword) {
      setState(() {
        _errorMessage = 'كلمتا المرور غير متطابقتين';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await ApiClient.registerTenant(
      networkName: networkName,
      adminFullName: fullName,
      username: username,
      email: email,
      password: password,
      phone: phone.isNotEmpty ? phone : null,
    );

    if (!mounted) return;

    if (result['success'] == true) {
      setState(() {
        _isLoading = false;
      });

      // Save role for local session
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_role', 'TENANT_ADMIN');
      } catch (_) {}

      final token = result['data']?['token'] as String?;
      final successMsg = result['data']?['message'] as String? ??
          'تم إرسال طلبك، بانتظار موافقة الإدارة';

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
                  token != null ? 'تم إنشاء الحساب بنجاح! أهلاً بك في نظام سوفت زون' : successMsg,
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

      if (token != null && token.isNotEmpty) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => DashboardScreen(
              userName: fullName,
            ),
          ),
          (route) => false,
        );
      } else {
        await showDialog(
          context: context,
          builder: (ctx) => Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              backgroundColor: AppColors.pageBg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  const Icon(Icons.hourglass_top_rounded, color: AppColors.heroGradientStart),
                  const SizedBox(width: 10),
                  Text(
                    'طلب قيد المراجعة',
                    style: GoogleFonts.cairo(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              content: Text(
                successMsg,
                style: GoogleFonts.cairo(fontSize: 14),
              ),
              actions: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.heroGradientStart,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(
                    'حسناً',
                    style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        );
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const TempLoginScreen()),
          (route) => false,
        );
      }
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = result['errorMessage'] ?? 'تعذر إتمام عملية التسجيل';
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
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Brand Icon
                    Center(
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.pageBg,
                          boxShadow: [
                            const BoxShadow(
                              color: AppColors.shadowLight,
                              offset: Offset(-5, -5),
                              blurRadius: 10,
                              spreadRadius: 1,
                            ),
                            BoxShadow(
                              color: AppColors.shadowDark.withValues(alpha: 0.8),
                              offset: const Offset(5, 5),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.wifi_tethering_rounded,
                            size: 36,
                            color: AppColors.heroGradientStart,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Title
                    Text(
                      'إنشاء حساب شبكة جديدة',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.cairo(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Subtitle with Trial Badge
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'ابدأ فترتك التجريبية المجانية (7 أيام)',
                          style: GoogleFonts.cairo(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.heroGradientStart
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppColors.heroGradientStart
                                  .withValues(alpha: 0.25),
                            ),
                          ),
                          child: Text(
                            'مجاناً',
                            style: GoogleFonts.cairo(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.heroGradientStart,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Error Message Banner
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.statusOffline.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: AppColors.statusOffline.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              color: AppColors.statusOffline,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: GoogleFonts.cairo(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.statusOffline,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                    ],

                    // Network Name
                    NeumorphicTextField(
                      label: 'اسم الشبكة / الشركة',
                      hintText: 'مثلاً: شبكة الأفق اللاسلكية',
                      controller: _networkNameController,
                      prefixIcon: const Icon(
                        Icons.router_rounded,
                        color: AppColors.textMuted,
                        size: 20,
                      ),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 14),

                    // Admin Full Name
                    NeumorphicTextField(
                      label: 'الاسم الكامل للمدير',
                      hintText: 'أدخل اسمك الثلاثي',
                      controller: _fullNameController,
                      prefixIcon: const Icon(
                        Icons.badge_outlined,
                        color: AppColors.textMuted,
                        size: 20,
                      ),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 14),

                    // Username
                    NeumorphicTextField(
                      label: 'اسم المستخدم (للدخول)',
                      hintText: 'أحرف وأرقام بالإنجليزية (مثلاً: ahmed_admin)',
                      controller: _usernameController,
                      prefixIcon: const Icon(
                        Icons.person_outline_rounded,
                        color: AppColors.textMuted,
                        size: 20,
                      ),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 14),

                    // Email
                    NeumorphicTextField(
                      label: 'البريد الإلكتروني',
                      hintText: 'name@example.com',
                      keyboardType: TextInputType.emailAddress,
                      controller: _emailController,
                      prefixIcon: const Icon(
                        Icons.email_outlined,
                        color: AppColors.textMuted,
                        size: 20,
                      ),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 14),

                    // Phone (Optional)
                    NeumorphicTextField(
                      label: 'رقم الهاتف (اختياري)',
                      hintText: 'مثلاً: +249 912345678',
                      keyboardType: TextInputType.phone,
                      controller: _phoneController,
                      prefixIcon: const Icon(
                        Icons.phone_outlined,
                        color: AppColors.textMuted,
                        size: 20,
                      ),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 14),

                    // Password
                    NeumorphicTextField(
                      label: 'كلمة المرور',
                      hintText: '8 أحرف على الأقل',
                      isPassword: true,
                      controller: _passwordController,
                      prefixIcon: const Icon(
                        Icons.lock_outline_rounded,
                        color: AppColors.textMuted,
                        size: 20,
                      ),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 14),

                    // Confirm Password
                    NeumorphicTextField(
                      label: 'تأكيد كلمة المرور',
                      hintText: 'أعد إدخال كلمة المرور',
                      isPassword: true,
                      controller: _confirmPasswordController,
                      prefixIcon: const Icon(
                        Icons.lock_reset_rounded,
                        color: AppColors.textMuted,
                        size: 20,
                      ),
                      textInputAction: TextInputAction.done,
                    ),
                    const SizedBox(height: 24),

                    // Submit Register Button
                    PressableNeumorphicCard(
                      onTap: _isLoading ? null : _handleRegister,
                      backgroundColor: AppColors.heroGradientStart,
                      borderRadius: BorderRadius.circular(16),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: _isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.app_registration_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'إنشاء حساب وبدء التجربة',
                                    style: GoogleFonts.cairo(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Back to Login Link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'لديك حساب بالفعل؟',
                          style: GoogleFonts.cairo(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: Text(
                            'تسجيل الدخول',
                            style: GoogleFonts.cairo(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.heroGradientStart,
                              decoration: TextDecoration.underline,
                              decorationColor: AppColors.heroGradientStart,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
