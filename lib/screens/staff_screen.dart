// ============================================================================
// Platform: Commercial MikroTik Network & HotSpot Card Management System
// File: lib/screens/staff_screen.dart
// Screen: Staff & Roles Management Screen (Rule 14, Rule 26, Rule 35)
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/staff_user_model.dart';
import '../services/api_client.dart';
import '../theme/app_colors.dart';
import '../widgets/pressable_neumorphic_card.dart';
import 'temp_login_screen.dart';

class StaffScreen extends StatefulWidget {
  const StaffScreen({super.key});

  @override
  State<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends State<StaffScreen> {
  List<StaffUserModel> _staffUsers = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _isRedirectingToLogin = false;

  @override
  void initState() {
    super.initState();
    _loadStaff();
  }

  void _handleUnauthorized() {
    if (!mounted || _isRedirectingToLogin) return;
    _isRedirectingToLogin = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const TempLoginScreen()),
        (route) => false,
      );
    });
  }

  Future<void> _loadStaff() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await ApiClient.getStaffUsers();

    if (!mounted) return;

    if (result['errorCode'] == 'UNAUTHORIZED') {
      _handleUnauthorized();
      return;
    }

    if (result['success'] == true) {
      setState(() {
        _staffUsers = (result['data'] as List<dynamic>).cast<StaffUserModel>();
        _isLoading = false;
        _errorMessage = null;
      });
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage =
            result['errorMessage'] ?? 'تعذر جلب قائمة الموظفين من الخادم';
      });
    }
  }

  void _showAddStaffModal() {
    final formKey = GlobalKey<FormState>();
    final fullNameController = TextEditingController();
    final usernameController = TextEditingController();
    final passwordController = TextEditingController();
    final phoneController = TextEditingController();
    String selectedRole = 'OPERATOR';
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(modalCtx).viewInsets.bottom,
              ),
              child: Container(
                decoration: const BoxDecoration(
                  color: AppColors.pageBg,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                padding: const EdgeInsets.fromLTRB(22, 16, 22, 28),
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Drag handle
                        Center(
                          child: Container(
                            width: 44,
                            height: 4,
                            decoration: BoxDecoration(
                              color: AppColors.textMuted.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Title
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.heroGradientStart
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.person_add_alt_1_rounded,
                                color: AppColors.heroGradientStart,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'إضافة موظف جديد',
                              style: GoogleFonts.cairo(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textDark,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Full Name
                        Text(
                          'الاسم الكامل',
                          style: GoogleFonts.cairo(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 6),
                        _buildInputField(
                          controller: fullNameController,
                          hint: 'مثال: محمد عبد الله',
                          icon: Icons.badge_outlined,
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'يرجى إدخال الاسم الكامل';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        // Username
                        Text(
                          'اسم المستخدم',
                          style: GoogleFonts.cairo(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 6),
                        _buildInputField(
                          controller: usernameController,
                          hint: 'مثال: mohammed_op',
                          icon: Icons.alternate_email_rounded,
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'يرجى إدخال اسم المستخدم';
                            }
                            if (val.trim().length < 3) {
                              return 'اسم المستخدم يجب أن يتكون من 3 أحرف على الأقل';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        // Password
                        Text(
                          'كلمة المرور',
                          style: GoogleFonts.cairo(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 6),
                        _buildInputField(
                          controller: passwordController,
                          hint: 'كلمة مرور قوية (6 خانات على الأقل)',
                          icon: Icons.lock_outline_rounded,
                          isPassword: true,
                          validator: (val) {
                            if (val == null || val.isEmpty) {
                              return 'يرجى إدخال كلمة المرور';
                            }
                            if (val.length < 6) {
                              return 'كلمة المرور يجب ألا تقل عن 6 خانات';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        // Role Dropdown
                        Text(
                          'الدور والصلاحيات',
                          style: GoogleFonts.cairo(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: AppColors.pageBg,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.shadowDark.withValues(alpha: 0.6),
                                offset: const Offset(2, 2),
                                blurRadius: 4,
                              ),
                              const BoxShadow(
                                color: AppColors.shadowLight,
                                offset: Offset(-2, -2),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: selectedRole,
                              isExpanded: true,
                              icon: const Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: AppColors.heroGradientStart,
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'OPERATOR',
                                  child: Text('مشغّل (إدارة الراوترات والكروت)'),
                                ),
                                DropdownMenuItem(
                                  value: 'RESELLER',
                                  child: Text('وكيل بيع (بيع الكروت والتقارير)'),
                                ),
                                DropdownMenuItem(
                                  value: 'ACCOUNTANT',
                                  child: Text('محاسب (تقارير المبيعات والأرباح)'),
                                ),
                                DropdownMenuItem(
                                  value: 'TENANT_ADMIN',
                                  child: Text('مدير شبكة (كامل الصلاحيات)'),
                                ),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setModalState(() {
                                    selectedRole = val;
                                  });
                                }
                              },
                              style: GoogleFonts.cairo(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textDark,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Phone
                        Text(
                          'رقم الهاتف (اختياري)',
                          style: GoogleFonts.cairo(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 6),
                        _buildInputField(
                          controller: phoneController,
                          hint: '09xxxxxxxx',
                          icon: Icons.phone_android_rounded,
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 24),

                        // Submit Button
                        PressableNeumorphicCard(
                          onTap: isSubmitting
                              ? null
                              : () async {
                                  if (!formKey.currentState!.validate()) return;

                                  setModalState(() => isSubmitting = true);

                                  final result =
                                      await ApiClient.createStaffUser(
                                    username: usernameController.text.trim(),
                                    password: passwordController.text,
                                    fullName: fullNameController.text.trim(),
                                    role: selectedRole,
                                    phone: phoneController.text.trim().isNotEmpty
                                        ? phoneController.text.trim()
                                        : null,
                                  );

                                  if (!mounted) return;

                                  if (result['success'] == true) {
                                    if (modalCtx.mounted) {
                                      Navigator.of(modalCtx).pop();
                                    }
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        backgroundColor: AppColors.statusOnline,
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(14),
                                        ),
                                        content: Text(
                                          'تمت إضافة الموظف "${fullNameController.text.trim()}" بنجاح',
                                          style: GoogleFonts.cairo(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    );
                                    _loadStaff();
                                  } else {
                                    setModalState(() => isSubmitting = false);
                                    final err = result['errorMessage'] ??
                                        'فشل إضافة الموظف';
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        backgroundColor:
                                            AppColors.statusOffline,
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(14),
                                        ),
                                        content: Text(
                                          err,
                                          style: GoogleFonts.cairo(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    );
                                  }
                                },
                          backgroundColor: AppColors.accentYellow,
                          borderRadius: BorderRadius.circular(16),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: Center(
                            child: isSubmitting
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: AppColors.textDark,
                                    ),
                                  )
                                : Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.check_circle_outline_rounded,
                                        color: AppColors.textDark,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'حفظ وإضافة الموظف',
                                        style: GoogleFonts.cairo(
                                          fontSize: 14,
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
        },
      ),
    );
  }

  void _confirmDeactivateStaff(StaffUserModel staff) {
    showDialog(
      context: context,
      builder: (dialogCtx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AppColors.pageBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: AppColors.statusOffline,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'تأكيد تعطيل الحساب',
                style: GoogleFonts.cairo(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
          content: Text(
            'هل أنت متأكد من تعطيل حساب الموظف "${staff.fullName}" (@${staff.username})؟\nلن يتمكن الموظف من تسجيل الدخول إلى النظام حتى تتم إعادة تفعيله.',
            style: GoogleFonts.cairo(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: Text(
                'إلغاء',
                style: GoogleFonts.cairo(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMuted,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(dialogCtx).pop();
                _deactivateStaff(staff);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.statusOffline,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: Text(
                'نعم، تعطيل',
                style: GoogleFonts.cairo(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deactivateStaff(StaffUserModel staff) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.heroGradientStart,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'جارٍ تعطيل الحساب...',
              style: GoogleFonts.cairo(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );

    final result = await ApiClient.deactivateStaffUser(staff.id);

    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    if (result['errorCode'] == 'UNAUTHORIZED') {
      _handleUnauthorized();
      return;
    }

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.statusOnline,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          content: Text(
            'تم تعطيل حساب "${staff.fullName}" بنجاح',
            style: GoogleFonts.cairo(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
      _loadStaff();
    } else {
      final err = result['errorMessage'] ?? 'فشل تعطيل حساب الموظف';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.statusOffline,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          content: Text(
            err,
            style: GoogleFonts.cairo(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.pageBg,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowDark.withValues(alpha: 0.6),
            offset: const Offset(2, 2),
            blurRadius: 4,
          ),
          const BoxShadow(
            color: AppColors.shadowLight,
            offset: Offset(-2, -2),
            blurRadius: 4,
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword,
        keyboardType: keyboardType,
        validator: validator,
        style: GoogleFonts.cairo(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textDark,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.cairo(
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            color: AppColors.textMuted,
          ),
          prefixIcon: Icon(
            icon,
            size: 20,
            color: AppColors.heroGradientStart,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final int activeCount = _staffUsers.where((u) => u.isActive).length;
    final int totalCount = _staffUsers.length;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.pageBg,
        body: Column(
          children: [
            // Top Hero Banner
            _buildTopBanner(activeCount: activeCount, totalCount: totalCount),

            // Staff List Header & Content with Pull-To-Refresh
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadStaff,
                color: AppColors.heroGradientStart,
                backgroundColor: AppColors.pageBg,
                child: _buildContent(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBanner({
    required int activeCount,
    required int totalCount,
  }) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.heroGradientStart,
            AppColors.heroGradientEnd,
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x333B2FA0),
            offset: Offset(0, 8),
            blurRadius: 18,
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row with Back button & Add staff button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      // Back Button
                      InkWell(
                        onTap: () => Navigator.of(context).pop(),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.25),
                              width: 1.2,
                            ),
                          ),
                          child: const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'الموظفون والأدوار',
                            style: GoogleFonts.cairo(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.2,
                            ),
                          ),
                          Text(
                            'إدارة المشغلين والوكلاء وصلاحيات الدخول',
                            style: GoogleFonts.cairo(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Add Staff Button
                  InkWell(
                    onTap: _showAddStaffModal,
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.accentYellow,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accentYellow.withValues(alpha: 0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.person_add_rounded,
                            size: 16,
                            color: AppColors.textDark,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'إضافة موظف',
                            style: GoogleFonts.cairo(
                              fontSize: 12,
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
              const SizedBox(height: 18),

              // Staff Stats Row
              Row(
                children: [
                  // Total Staff Card
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.22),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'إجمالي الفريق',
                            style: GoogleFonts.cairo(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$totalCount موظف',
                            style: GoogleFonts.cairo(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Active Staff Card
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.22),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'حسابات نشطة',
                            style: GoogleFonts.cairo(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$activeCount نشط',
                            style: GoogleFonts.cairo(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.statusOnline,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    // 1. Loading State
    if (_isLoading) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Container(
            height: 300,
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 36,
                  height: 36,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: AppColors.heroGradientStart,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'جارٍ تحميل بيانات الموظفين...',
                  style: GoogleFonts.cairo(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    // 2. Error State
    if (_errorMessage != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.pageBg,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                const BoxShadow(
                  color: AppColors.shadowLight,
                  offset: Offset(-4, -4),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
                BoxShadow(
                  color: AppColors.shadowDark.withValues(alpha: 0.7),
                  offset: const Offset(4, 4),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.cloud_off_rounded,
                  size: 48,
                  color: AppColors.statusOffline,
                ),
                const SizedBox(height: 12),
                Text(
                  'فشل تحميل قائمة الموظفين',
                  style: GoogleFonts.cairo(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cairo(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 18),
                PressableNeumorphicCard(
                  onTap: _loadStaff,
                  borderRadius: BorderRadius.circular(14),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.refresh_rounded,
                        size: 18,
                        color: AppColors.heroGradientStart,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'إعادة المحاولة',
                        style: GoogleFonts.cairo(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.heroGradientStart,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    // 3. Empty State
    if (_staffUsers.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: AppColors.pageBg,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                const BoxShadow(
                  color: AppColors.shadowLight,
                  offset: Offset(-4, -4),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
                BoxShadow(
                  color: AppColors.shadowDark.withValues(alpha: 0.7),
                  offset: const Offset(4, 4),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.heroGradientStart.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.group_outlined,
                    size: 32,
                    color: AppColors.heroGradientStart,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'لا يوجد موظفون مسجلون بعد',
                  style: GoogleFonts.cairo(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'ابدأ بإضافة موظفين وتعيين أدوارهم (مشغل، وكيل بيع، محاسب) للعمل معك على إدارة الشبكة.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cairo(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 20),
                PressableNeumorphicCard(
                  onTap: _showAddStaffModal,
                  backgroundColor: AppColors.heroGradientStart,
                  borderRadius: BorderRadius.circular(14),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.add_rounded,
                        size: 18,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'إضافة أول موظف',
                        style: GoogleFonts.cairo(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    // 4. Data State
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      itemCount: _staffUsers.length,
      itemBuilder: (context, index) {
        final staff = _staffUsers[index];
        return _buildStaffCard(staff, index);
      },
    );
  }

  Widget _buildStaffCard(StaffUserModel staff, int index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PressableNeumorphicCard(
        borderRadius: BorderRadius.circular(18),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Role Badge, Full Name, Status Badge
            Row(
              children: [
                // Role Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: staff.roleColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        staff.roleIcon,
                        size: 14,
                        color: staff.roleColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        staff.roleArabic,
                        style: GoogleFonts.cairo(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: staff.roleColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),

                // Full Name
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        staff.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.cairo(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark,
                        ),
                      ),
                      Text(
                        '@${staff.username}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.cairo(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),

                // Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: staff.statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: staff.statusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        staff.statusArabic,
                        style: GoogleFonts.cairo(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: staff.statusColor,
                        ),
                      ),
                    ],
                  ),
                ),

                // Deactivate Action Button (Only if active)
                if (staff.isActive) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(
                      Icons.person_off_outlined,
                      size: 20,
                      color: AppColors.statusOffline,
                    ),
                    tooltip: 'تعطيل الحساب',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    onPressed: () => _confirmDeactivateStaff(staff),
                  ),
                ],
              ],
            ),

            if (staff.phone != null && staff.phone!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(
                    Icons.phone_rounded,
                    size: 13,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    staff.phone!,
                    style: GoogleFonts.cairo(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(delay: (index * 40).ms)
        .slideY(begin: 0.08, duration: 200.ms);
  }
}
