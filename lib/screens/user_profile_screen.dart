// ============================================================================
// Platform: Commercial MikroTik Network & HotSpot Card Management System (Jalsah)
// File: lib/screens/user_profile_screen.dart
// Screen: User Profile & Subscription Management Screen (Rule 14, Rule 20, Rule 26, Phase 14)
// ============================================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/subscription_plan_model.dart';
import '../models/subscription_status_model.dart';
import '../services/api_client.dart';
import '../services/app_settings.dart';
import '../theme/app_colors.dart';
import '../utils/whatsapp_helper.dart';
import '../widgets/bounce_button.dart';
import 'subscription_plans_screen.dart';
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
  String _phone = '';
  String _avatarUrl = '';
  String _role = '';
  String _networkName = '';
  String _status = 'ACTIVE';

  SubscriptionStatusModel? _subscriptionStatus;
  List<SubscriptionRequestModel> _myRequests = [];
  bool _isLoadingRequests = false;

  static const List<String> _avatarPresets = [
    'assets/avatars/avatar_1.png',
    'assets/avatars/avatar_2.png',
    'assets/avatars/avatar_3.png',
    'assets/avatars/avatar_4.png',
    'assets/avatars/avatar_5.png',
    'assets/avatars/avatar_6.png',
  ];

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

    try {
      final results = await Future.wait([
        ApiClient.getCurrentUserProfile(),
        ApiClient.getSubscriptionStatus(),
        ApiClient.getMySubscriptionRequests(),
      ]);

      if (!mounted) return;

      final profileRes = results[0];
      final subRes = results[1];
      final reqRes = results[2];

      if (profileRes['success'] == true && profileRes['data'] != null) {
        final data = profileRes['data'] as Map<String, dynamic>;
        _fullName = (data['fullName'] as String?)?.trim() ?? _fullName;
        _username = (data['username'] as String?)?.trim() ?? _username;
        _email = (data['email'] as String?)?.trim() ?? 'غير مسجل';
        _phone = (data['phone'] as String?)?.trim() ?? '';
        _avatarUrl = (data['avatarUrl'] as String?)?.trim() ?? '';
        _role = (data['role'] as String?)?.trim() ?? ApiClient.getUserRole() ?? 'TENANT_ADMIN';
        _networkName = (data['networkName'] as String?)?.trim() ?? 'شبكة جلسة';
        _status = (data['status'] as String?)?.trim() ?? 'ACTIVE';
      } else {
        _errorMessage = profileRes['errorMessage'] as String? ?? 'تعذر تحميل بيانات الملف الشخصي';
      }

      if (subRes['success'] == true && subRes['data'] != null) {
        if (subRes['data'] is SubscriptionStatusModel) {
          _subscriptionStatus = subRes['data'] as SubscriptionStatusModel;
        } else if (subRes['data'] is Map<String, dynamic>) {
          _subscriptionStatus = SubscriptionStatusModel.fromJson(subRes['data'] as Map<String, dynamic>);
        }
      }

      if (reqRes['success'] == true) {
        final list = reqRes['data'] ?? reqRes['requests'];
        if (list is List) {
          _myRequests = list
              .map((r) => r is SubscriptionRequestModel
                  ? r
                  : SubscriptionRequestModel.fromJson(r as Map<String, dynamic>))
              .toList();
        }
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'خطأ أثناء تحميل البيانات: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchRequests() async {
    setState(() => _isLoadingRequests = true);
    try {
      final res = await ApiClient.getMySubscriptionRequests();
      final list = res['data'] ?? res['requests'];
      if (res['success'] == true && list is List) {
        if (mounted) {
          setState(() {
            _myRequests = list
                .map((r) => r is SubscriptionRequestModel
                    ? r
                    : SubscriptionRequestModel.fromJson(r as Map<String, dynamic>))
                .toList();
          });
        }
      }
    } catch (_) {
      // Graceful fallback
    } finally {
      if (mounted) {
        setState(() => _isLoadingRequests = false);
      }
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

  void _showAvatarPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.pageBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'اختر الصورة الرمزية',
                style: GoogleFonts.cairo(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                alignment: WrapAlignment.center,
                children: _avatarPresets.map((avatar) {
                  final isSelected = _avatarUrl == avatar;
                  return GestureDetector(
                    onTap: () async {
                      Navigator.pop(ctx);
                      await _updateAvatar(avatar);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? AppColors.heroGradientStart : Colors.black12,
                          width: isSelected ? 3 : 1,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 26,
                        backgroundColor: AppColors.heroGradientStart.withValues(alpha: 0.15),
                        child: const Icon(
                          Icons.person_rounded,
                          color: AppColors.heroGradientStart,
                          size: 28,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _updateAvatar(String newAvatar) async {
    final res = await ApiClient.updateUserProfile(avatarUrl: newAvatar);
    if (!mounted) return;

    if (res['success'] == true) {
      setState(() => _avatarUrl = newAvatar);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم تحديث الصورة الرمزية بنجاح', style: GoogleFonts.cairo()),
          backgroundColor: AppColors.statusOnline,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['errorMessage'] as String? ?? 'تعذر تحديث الصورة', style: GoogleFonts.cairo()),
          backgroundColor: AppColors.statusOffline,
        ),
      );
    }
  }

  void _showEditProfileDialog() {
    final nameCtrl = TextEditingController(text: _fullName);
    final phoneCtrl = TextEditingController(text: _phone);
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: AppColors.pageBg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(
              'تعديل البيانات الشخصية',
              style: GoogleFonts.cairo(fontWeight: FontWeight.w800, fontSize: 17),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: 'الاسم الكامل',
                    labelStyle: GoogleFonts.cairo(color: AppColors.textMuted),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  style: GoogleFonts.cairo(fontSize: 14),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'رقم الهاتف',
                    labelStyle: GoogleFonts.cairo(color: AppColors.textMuted),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  style: GoogleFonts.cairo(fontSize: 14),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(dialogCtx),
                child: Text('إلغاء', style: GoogleFonts.cairo(color: AppColors.textMuted)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.heroGradientStart,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: isSaving
                    ? null
                    : () async {
                        setDialogState(() => isSaving = true);
                        final res = await ApiClient.updateUserProfile(
                          fullName: nameCtrl.text.trim(),
                          phone: phoneCtrl.text.trim(),
                        );
                        if (!mounted) return;
                        if (res['success'] == true) {
                          if (dialogCtx.mounted) {
                            Navigator.pop(dialogCtx);
                          }
                          setState(() {
                            _fullName = nameCtrl.text.trim();
                            _phone = phoneCtrl.text.trim();
                          });
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('تم تحديث البيانات بنجاح', style: GoogleFonts.cairo()),
                                backgroundColor: AppColors.statusOnline,
                              ),
                            );
                          }
                        } else {
                          setDialogState(() => isSaving = false);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(res['errorMessage'] as String? ?? 'تعذر التحديث', style: GoogleFonts.cairo()),
                                backgroundColor: AppColors.statusOffline,
                              ),
                            );
                          }
                        }
                      },
                child: isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        'حفظ',
                        style: GoogleFonts.cairo(fontWeight: FontWeight.w700, color: Colors.white),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _cancelRequest(String requestId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'إلغاء طلب التفعيل',
            style: GoogleFonts.cairo(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          content: Text(
            'هل أنت متأكد من رغبتك في إلغاء هذا الطلب المعلق؟',
            style: GoogleFonts.cairo(fontSize: 13.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('تراجع', style: GoogleFonts.cairo(color: AppColors.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.statusOffline,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(
                'نعم، إلغاء الطلب',
                style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isLoadingRequests = true);
    final res = await ApiClient.cancelSubscriptionRequest(requestId);
    if (!mounted) return;

    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم إلغاء الطلب بنجاح', style: GoogleFonts.cairo()),
          backgroundColor: AppColors.statusOnline,
        ),
      );
      await _loadProfile();
    } else {
      setState(() => _isLoadingRequests = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['errorMessage'] as String? ?? 'تعذر إلغاء الطلب', style: GoogleFonts.cairo()),
          backgroundColor: AppColors.statusOffline,
        ),
      );
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
              : RefreshIndicator(
                  onRefresh: _loadProfile,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
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

                        // Subscription Status Card
                        _buildSubscriptionCard(),
                        const SizedBox(height: 20),

                        // Profile Details Card
                        _buildDetailsCard(),
                        const SizedBox(height: 20),

                        // Activation Requests Card
                        _buildRequestsHistoryCard(),
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
                        const SizedBox(height: 24),

                        // Tactile Micro-interactive Logout Button
                        BounceButton(
                          onPressed: _handleLogout,
                          label: 'تسجيل الخروج',
                          icon: Icons.logout_rounded,
                          style: BounceButtonStyle.danger,
                          height: 52,
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
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
          Stack(
            children: [
              Container(
                width: 76,
                height: 76,
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
                    size: 44,
                    color: Colors.white,
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: InkWell(
                  onTap: _showAvatarPicker,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: AppColors.accentYellow,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.camera_alt_rounded,
                      size: 14,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ),
            ],
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
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.edit_outlined, size: 15, color: Colors.white),
            label: Text(
              'تعديل البيانات الشخصية',
              style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.white.withValues(alpha: 0.6)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            ),
            onPressed: _showEditProfileDialog,
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionCard() {
    final status = _subscriptionStatus?.subscriptionStatus ?? 'TRIAL';
    final isTrial = status.toUpperCase() == 'TRIAL';
    final remainingDays = _subscriptionStatus?.daysRemaining ?? 0;
    final planName = _subscriptionStatus?.planName ?? (isTrial ? 'باقة تجريبية (Trial)' : 'باقة مخصصة');

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.pageBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isTrial ? const Color(0xFFD97706) : AppColors.statusOnline.withValues(alpha: 0.5),
          width: 1.2,
        ),
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
          Row(
            children: [
              Icon(
                isTrial ? Icons.hourglass_top_rounded : Icons.verified_user_rounded,
                color: isTrial ? const Color(0xFFD97706) : AppColors.statusOnline,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isTrial ? 'الاشتراك التجريبي (Trial)' : 'الاشتراك النشط (Active)',
                  style: GoogleFonts.cairo(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: isTrial ? const Color(0xFFD97706) : AppColors.statusOnline,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: (isTrial ? const Color(0xFFD97706) : AppColors.statusOnline).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: GoogleFonts.cairo(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: isTrial ? const Color(0xFFD97706) : AppColors.statusOnline,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildInfoRow(
            icon: Icons.card_membership_rounded,
            label: 'الباقة الحالية',
            value: planName,
          ),
          const Divider(height: 16, color: AppColors.shadowDark),
          _buildInfoRow(
            icon: Icons.access_time_rounded,
            label: 'الأيام المتبقية في الاشتراك',
            value: '$remainingDays يوم',
            valueColor: remainingDays <= 2 ? AppColors.statusOffline : AppColors.textDark,
          ),
          if (isTrial) ...[
            const SizedBox(height: 10),
            Text(
              'تنبيه: لتوليد بطاقات HotSpot وطباعتها، يتطلب النظام اشتراكاً نشطاً.',
              style: GoogleFonts.cairo(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFB45309),
              ),
            ),
          ],
          const SizedBox(height: 16),
          BounceButton(
            label: isTrial ? 'ترقية وتنشيط الاشتراك الآن' : 'تجديد أو ترقية الاشتراك',
            icon: Icons.workspace_premium_rounded,
            height: 46,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SubscriptionPlansScreen()),
              ).then((_) {
                _loadProfile();
                _fetchRequests();
              });
            },
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
          if (_phone.isNotEmpty) ...[
            const Divider(height: 20, color: AppColors.shadowDark),
            _buildInfoRow(
              icon: Icons.phone_android_rounded,
              label: 'رقم الهاتف',
              value: _phone,
            ),
          ],
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

  Widget _buildRequestsHistoryCard() {
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
          Row(
            children: [
              const Icon(Icons.history_rounded, color: AppColors.heroGradientStart, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'طلبات التفعيل السابقة',
                  style: GoogleFonts.cairo(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              if (_isLoadingRequests)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.heroGradientStart),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (_myRequests.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'لا توجد طلبات سابقة لتنشيط الحساب.',
                style: GoogleFonts.cairo(fontSize: 12.5, color: AppColors.textMuted),
              ),
            )
          else
            ..._myRequests.map((req) {
              final status = req.status.toUpperCase();
              final planName = req.planName;
              final price = req.formattedPrice;
              final currency = req.currency;

              Color badgeColor = const Color(0xFFD97706);
              String badgeText = 'قيد المراجعة';
              if (status == 'APPROVED') {
                badgeColor = AppColors.statusOnline;
                badgeText = 'تم التفعيل';
              } else if (status == 'REJECTED') {
                badgeColor = AppColors.statusOffline;
                badgeText = 'مرفوض';
              } else if (status == 'CANCELLED') {
                badgeColor = AppColors.textMuted;
                badgeText = 'تم الإلغاء';
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.shadowDark.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          planName,
                          style: GoogleFonts.cairo(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textDark,
                          ),
                        ),
                        Text(
                          '$price $currency',
                          style: GoogleFonts.cairo(fontSize: 11, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (status == 'PENDING' && req.id.isNotEmpty) ...[
                          TextButton(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: () => _cancelRequest(req.id),
                            child: Text(
                              'إلغاء',
                              style: GoogleFonts.cairo(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.statusOffline,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: badgeColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            badgeText,
                            style: GoogleFonts.cairo(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: badgeColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
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
