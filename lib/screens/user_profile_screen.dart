// ============================================================================
// Platform: Commercial MikroTik Network & HotSpot Card Management System (Jalsah)
// File: lib/screens/user_profile_screen.dart
// Screen: User Profile & Logout Screen (Rule 14, Rule 20, Rule 26)
// ============================================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/api_client.dart';
import '../services/app_settings.dart';
import '../theme/app_colors.dart';
import '../utils/whatsapp_helper.dart';
import '../widgets/pressable_neumorphic_card.dart';
import 'temp_login_screen.dart';

class UserProfileScreen extends StatefulWidget {
  final String? initialFullName;
  final String? initialUsername;

  const UserProfileScreen({
    super.key,
    this.initialFullName,
    this.initialUsername,
  });

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  bool _isLoading = true;
  String? _errorMessage;

  String _fullName = '';
  String _username = '';
  String _email = '';
  String _role = '';
  String _networkName = '';
  String _status = 'ACTIVE';

  @override
  void initState() {
    super.initState();
    _fullName = widget.initialFullName ?? '';
    _username = widget.initialUsername ?? '';
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await ApiClient.getCurrentUserProfile();
    if (!mounted) return;

    if (result['success'] == true && result['data'] != null) {
      final data = result['data'] as Map<String, dynamic>;
      setState(() {
        _fullName = (data['fullName'] as String?)?.trim() ?? _fullName;
        _username = (data['username'] as String?)?.trim() ?? _username;
        _email = (data['email'] as String?)?.trim() ?? 'غير محدد';
        _role = (data['role'] as String?)?.trim() ?? ApiClient.getUserRole() ?? 'TENANT_ADMIN';
        _networkName = (data['networkName'] as String?)?.trim() ?? 'شبكة جلسة';
        _status = (data['status'] as String?)?.trim() ?? 'ACTIVE';
        _isLoading = false;
      });
    } else {
      setState(() {
        _errorMessage = result['errorMessage'] as String? ?? 'تعذر تحميل بيانات الملف الشخصي';
        _isLoading = false;
      });
    }
  }

  String _formatRole(String role) {
    switch (role.toUpperCase()) {
      case 'SUPER_ADMIN':
        return 'مدير المنصة العام (SUPER ADMIN)';
      case 'TENANT_ADMIN':
        return 'مدير النظام والشبكة (Admin)';
      case 'OPERATOR':
        return 'فني / مشغل الشبكة (Operator)';
      case 'CASHIER':
        return 'كاشير / موظف مبيعات (Cashier)';
      default:
        return role;
    }
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AppColors.pageBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'تسجيل الخروج',
            style: GoogleFonts.cairo(fontWeight: FontWeight.w700),
          ),
          content: Text(
            'هل أنت متأكد من رغبتك في تسجيل الخروج من التطبيق؟',
            style: GoogleFonts.cairo(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                'إلغاء',
                style: GoogleFonts.cairo(color: AppColors.textMuted),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.statusOffline,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(
                'خروج',
                style: GoogleFonts.cairo(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      await ApiClient.logout();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const TempLoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.pageBg,
        appBar: AppBar(
          backgroundColor: AppColors.pageBg,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_forward_rounded, color: AppColors.textDark),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            'الملف الشخصي',
            style: GoogleFonts.cairo(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: AppColors.textDark),
              tooltip: 'تحديث',
              onPressed: _loadProfile,
            ),
          ],
        ),
        body: SafeArea(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.heroGradientStart),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Column(
                    children: [
                      // User Avatar & Greeting Header
                      _buildHeaderCard(),
                      const SizedBox(height: 20),

                      if (_errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.statusOffline.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline_rounded,
                                color: AppColors.statusOffline,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: GoogleFonts.cairo(
                                    fontSize: 12.5,
                                    color: AppColors.statusOffline,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Profile Details Card
                      _buildDetailsCard(),
                      const SizedBox(height: 20),

                      // WhatsApp Support Card
                      buildWhatsAppSupportCard(
                        context: context,
                        title: 'الدعم الفني والمساعدة',
                        englishTag: AppSettings.instance.appName.contains(RegExp(r'[a-zA-Z]'))
                            ? AppSettings.instance.appName
                            : 'Jalsah',
                        subtitle: 'هل تحتاج مساعدة في إدارة شبكتك أو بطاقاتك؟',
                      ),
                      const SizedBox(height: 10),
                      Center(
                        child: Text(
                          'البريد الإلكتروني للدعم: ${AppSettings.instance.supportEmail}',
                          style: GoogleFonts.cairo(
                            fontSize: 12,
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Logout Button
                      PressableNeumorphicCard(
                        onTap: _handleLogout,
                        backgroundColor: AppColors.statusOffline,
                        borderRadius: BorderRadius.circular(16),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.logout_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'تسجيل الخروج',
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
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            AppColors.heroGradientStart,
            AppColors.heroGradientMiddle,
            AppColors.heroGradientEnd,
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.heroGradientStart.withValues(alpha: 0.16),
            offset: const Offset(0, 5),
            blurRadius: 12,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        children: [
          // Avatar Icon
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.4),
                width: 2,
              ),
            ),
            child: const Center(
              child: Icon(
                Icons.person_rounded,
                size: 40,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _fullName.isNotEmpty ? _fullName : _username,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _formatRole(_role),
              style: GoogleFonts.cairo(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.pageBg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          const BoxShadow(
            color: AppColors.shadowLight,
            offset: Offset(-4, -4),
            blurRadius: 8,
          ),
          BoxShadow(
            color: AppColors.shadowDark.withValues(alpha: 0.35),
            offset: const Offset(4, 4),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'بيانات الحساب',
            textAlign: TextAlign.right,
            style: GoogleFonts.cairo(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            icon: Icons.account_circle_outlined,
            label: 'اسم المستخدم',
            value: _username,
          ),
          const Divider(height: 20, color: AppColors.shadowDark),
          _buildInfoRow(
            icon: Icons.badge_outlined,
            label: 'الاسم الكامل',
            value: _fullName,
          ),
          const Divider(height: 20, color: AppColors.shadowDark),
          _buildInfoRow(
            icon: Icons.email_outlined,
            label: 'البريد الإلكتروني',
            value: _email.isNotEmpty ? _email : 'غير مسجل',
          ),
          const Divider(height: 20, color: AppColors.shadowDark),
          _buildInfoRow(
            icon: Icons.wifi_rounded,
            label: 'اسم الشبكة / المؤسسة',
            value: _networkName,
          ),
          const Divider(height: 20, color: AppColors.shadowDark),
          _buildInfoRow(
            icon: Icons.verified_user_outlined,
            label: 'حالة الحساب',
            value: _status == 'ACTIVE' ? 'نشط' : 'معطل',
            valueColor: _status == 'ACTIVE' ? AppColors.statusOnline : AppColors.statusOffline,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.heroGradientStart.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Icon(
              icon,
              size: 18,
              color: AppColors.heroGradientStart,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                label,
                textAlign: TextAlign.right,
                style: GoogleFonts.cairo(
                  fontSize: 11.5,
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                value,
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.cairo(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: valueColor ?? AppColors.textDark,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
