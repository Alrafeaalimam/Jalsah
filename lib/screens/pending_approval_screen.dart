// ============================================================================
// Platform: Commercial MikroTik Network & HotSpot Card Management System (Jalsah)
// File: lib/screens/pending_approval_screen.dart
// Screen: Account Pending Approval Screen (Rule 14, Rule 20, Rule 26)
// Master Reference: App Identity & Pending Registration Workflow
// ============================================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_client.dart';
import '../theme/app_colors.dart';
import '../widgets/pressable_neumorphic_card.dart';
import 'admin/super_admin_dashboard.dart';
import 'dashboard_screen.dart';
import 'temp_login_screen.dart';
import '../utils/whatsapp_helper.dart';

class PendingApprovalScreen extends StatefulWidget {
  final String? username;
  final String? identifier;
  final String? password;
  final String? networkName;

  const PendingApprovalScreen({
    super.key,
    this.username,
    this.identifier,
    this.password,
    this.networkName,
  });

  String? get activeIdentifier => identifier ?? username;

  @override
  State<PendingApprovalScreen> createState() => _PendingApprovalScreenState();
}

class _PendingApprovalScreenState extends State<PendingApprovalScreen> {
  bool _isChecking = false;
  String? _statusFeedback;

  Future<void> _handleRecheck() async {
    if (_isChecking) return;

    final id = widget.activeIdentifier;
    if (id == null ||
        id.isEmpty ||
        widget.password == null ||
        widget.password!.isEmpty) {
      // Return to login screen if credentials are not held in state
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const TempLoginScreen()),
        (route) => false,
      );
      return;
    }

    setState(() {
      _isChecking = true;
      _statusFeedback = null;
    });

    final result = await ApiClient.login(
      username: id,
      password: widget.password!,
    );

    if (!mounted) return;

    setState(() {
      _isChecking = false;
    });

    if (result['success'] == true) {
      final userData = result['data']?['user'] as Map<String, dynamic>?;
      final fullName = userData?['fullName'] as String? ??
          userData?['username'] as String? ??
          'المدير';
      final tokenRole = ApiClient.getUserRole() ?? userData?['role'] as String?;

      if (tokenRole != null && tokenRole.isNotEmpty) {
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_role', tokenRole);
        } catch (_) {}
      }

      if (!mounted) return;

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
                  'تمت الموافقة على حسابك وتفعيله بنجاح! مرحباً بك',
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

      if (tokenRole == 'SUPER_ADMIN') {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => SuperAdminDashboardScreen(adminName: fullName),
          ),
          (route) => false,
        );
      } else {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => DashboardScreen(userName: fullName),
          ),
          (route) => false,
        );
      }
    } else if (result['errorCode'] == 'ACCOUNT_PENDING_APPROVAL') {
      setState(() {
        _statusFeedback = 'ما زال الحساب قيد المراجعة من قبل الإدارة، يرجى الانتظار قليلاً.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.accentYellow,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          content: Text(
            'ما زال الحساب قيد المراجعة والتدقيق من قبل الإدارة',
            style: GoogleFonts.cairo(
              color: AppColors.textDark,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    } else {
      setState(() {
        _statusFeedback = result['errorMessage'] as String? ??
            'تعذر التحقق من حالة الحساب، يرجى المحاولة لاحقاً';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.statusOffline,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          content: Text(
            result['errorMessage'] as String? ?? 'فشل الاتصال بالخادم',
            style: GoogleFonts.cairo(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }
  }

  void _navigateToLogin() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const TempLoginScreen()),
      (route) => false,
    );
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
                  // Neumorphic Icon Container
                  Center(
                    child: Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        color: AppColors.pageBg,
                        shape: BoxShape.circle,
                        boxShadow: [
                          const BoxShadow(
                            color: AppColors.shadowLight,
                            offset: Offset(-6, -6),
                            blurRadius: 12,
                          ),
                          BoxShadow(
                            color: AppColors.shadowDark.withValues(alpha: 0.5),
                            offset: const Offset(6, 6),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.hourglass_top_rounded,
                          size: 48,
                          color: AppColors.accentYellow,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Main Title
                  Text(
                    'حسابك قيد المراجعة',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.cairo(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                    ),
                  ),
                  if (widget.networkName != null && widget.networkName!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      widget.networkName!,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.cairo(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.heroGradientStart,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),

                  // Subtitle / Description
                  Text(
                    'طلب تسجيل شبكتك قيد المراجعة والتدقيق حالياً من قبل إدارة المنصة وسيتم تفعيله قريباً.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.cairo(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textMuted,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Status Info Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.pageBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.accentYellow.withValues(alpha: 0.35),
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
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.accentYellow.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.access_time_filled_rounded,
                                color: AppColors.accentYellow,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'حالة الحساب: بانتظار الاعتماد',
                                    style: GoogleFonts.cairo(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textDark,
                                    ),
                                  ),
                                  Text(
                                    'ستتم مراجعة الطلب من الإدارة في أقرب وقت',
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
                        const SizedBox(height: 12),
                        const Divider(height: 1, color: AppColors.shadowDark),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(
                              Icons.email_outlined,
                              size: 16,
                              color: AppColors.heroGradientStart,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'لأي استفسار: jalsahnetwork@gmail.com',
                                style: GoogleFonts.cairo(
                                  fontSize: 12,
                                  color: AppColors.heroGradientStart,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // WhatsApp Direct Support Card
                  buildWhatsAppSupportCard(
                    context: context,
                    title: 'تواصل مباشر مع الإدارة لتفعيل الحساب',
                    subtitle: 'راسلنا مباشرة عبر واتساب للمراجعة والاعتماد الفوري',
                  ),

                  if (_statusFeedback != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.accentYellow.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.accentYellow.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        _statusFeedback!,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.cairo(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 32),

                  // Re-check Button
                  PressableNeumorphicCard(
                    onTap: _isChecking ? null : _handleRecheck,
                    backgroundColor: AppColors.heroGradientStart,
                    borderRadius: BorderRadius.circular(16),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: _isChecking
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
                                  Icons.refresh_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'تحقق مرة أخرى',
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
                  const SizedBox(height: 14),

                  // Login with another account button
                  TextButton.icon(
                    onPressed: _isChecking ? null : _navigateToLogin,
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      size: 18,
                      color: AppColors.textMuted,
                    ),
                    label: Text(
                      'تسجيل الدخول بحساب آخر',
                      style: GoogleFonts.cairo(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMuted,
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
