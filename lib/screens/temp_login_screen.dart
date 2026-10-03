// ============================================================================
// Platform: Commercial MikroTik Network & HotSpot Card Management System
// File: lib/screens/temp_login_screen.dart
// Screen: Temporary Functional Login Screen (Neumorphic Style)
// Master Reference: Rule 14 (Security), Rule 19 (Auth), Rule 23 (Error Handling)
// ============================================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_client.dart';
import '../theme/app_colors.dart';
import '../widgets/neumorphic_text_field.dart';
import '../widgets/pressable_neumorphic_card.dart';
import 'dashboard_screen.dart';

class TempLoginScreen extends StatefulWidget {
  const TempLoginScreen({super.key});

  @override
  State<TempLoginScreen> createState() => _TempLoginScreenState();
}

class _TempLoginScreenState extends State<TempLoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = 'يرجى إدخال اسم المستخدم وكلمة المرور';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await ApiClient.login(
      username: username,
      password: password,
    );

    if (!mounted) return;

    if (result['success'] == true) {
      setState(() {
        _isLoading = false;
      });

      final userData = result['data']?['user'] as Map<String, dynamic>?;
      final fullName = userData?['fullName'] as String? ??
          userData?['username'] as String? ??
          'المدير';

      // Store extracted role from token
      final tokenRole = ApiClient.getUserRole() ?? userData?['role'] as String?;
      if (tokenRole != null && tokenRole.isNotEmpty) {
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_role', tokenRole);
        } catch (_) {}
      }

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => DashboardScreen(
            userName: fullName,
          ),
        ),
      );
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = result['errorMessage'] ?? 'بيانات الدخول غير صحيحة';
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
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // App Icon / Logo Placeholder
                  Center(
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppColors.pageBg,
                        shape: BoxShape.circle,
                        boxShadow: [
                          const BoxShadow(
                            color: AppColors.shadowLight,
                            offset: Offset(-5, -5),
                            blurRadius: 10,
                          ),
                          BoxShadow(
                            color: AppColors.shadowDark.withValues(alpha: 0.6),
                            offset: const Offset(5, 5),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.wifi_tethering_rounded,
                        size: 42,
                        color: AppColors.heroGradientStart,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Title
                  Text(
                    'تسجيل الدخول',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.cairo(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'نظام إدارة كروت وشبكات مايكروتك',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.cairo(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Error Banner
                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.statusOffline.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppColors.statusOffline.withValues(alpha: 0.3),
                          width: 1,
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
                    const SizedBox(height: 20),
                  ],

                  // Username Field
                  NeumorphicTextField(
                    label: 'اسم المستخدم',
                    hintText: 'أدخل اسم المستخدم (مثلاً: admin)',
                    controller: _usernameController,
                    prefixIcon: const Icon(
                      Icons.person_outline_rounded,
                      color: AppColors.textMuted,
                      size: 20,
                    ),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 18),

                  // Password Field
                  NeumorphicTextField(
                    label: 'كلمة المرور',
                    hintText: 'أدخل كلمة المرور',
                    isPassword: true,
                    controller: _passwordController,
                    prefixIcon: const Icon(
                      Icons.lock_outline_rounded,
                      color: AppColors.textMuted,
                      size: 20,
                    ),
                    textInputAction: TextInputAction.done,
                  ),
                  const SizedBox(height: 28),

                  // Login Button
                  PressableNeumorphicCard(
                    onTap: _isLoading ? null : _handleLogin,
                    backgroundColor: AppColors.accentYellow,
                    borderRadius: BorderRadius.circular(16),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: _isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: AppColors.textDark,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.login_rounded,
                                  color: AppColors.textDark,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'تسجيل الدخول',
                                  style: GoogleFonts.cairo(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textDark,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
