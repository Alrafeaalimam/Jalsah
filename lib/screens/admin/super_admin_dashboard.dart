// ============================================================================
// Platform: Commercial MikroTik Network & HotSpot Card Management System (Jalsah)
// File: lib/screens/admin/super_admin_dashboard.dart
// Screen: Super Admin Management Dashboard (Rule 14, Rule 26, Rule 27)
// Master Reference: Super Admin Panel & License Code System
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/admin_tenant_model.dart';
import '../../models/license_code_model.dart';
import '../../models/platform_settings_model.dart';
import '../../models/staff_user_model.dart';
import '../../services/api_client.dart';
import '../../services/app_settings.dart';
import '../../theme/app_colors.dart';
import '../../widgets/neumorphic_text_field.dart';
import '../../widgets/pressable_neumorphic_card.dart';
import '../temp_login_screen.dart';

class SuperAdminDashboardScreen extends StatefulWidget {
  final String? adminName;

  const SuperAdminDashboardScreen({
    super.key,
    this.adminName,
  });

  @override
  State<SuperAdminDashboardScreen> createState() =>
      _SuperAdminDashboardScreenState();
}

class _SuperAdminDashboardScreenState extends State<SuperAdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  bool _isLoadingTenants = false;
  bool _isLoadingCodes = false;
  String? _tenantsError;
  String? _codesError;

  List<AdminTenantModel> _tenants = [];
  List<LicenseCodeModel> _codes = [];

  String _tenantSearchQuery = '';
  String _tenantFilter = 'ALL'; // ALL, PENDING, ACTIVE, SUSPENDED
  String _codeFilter = 'ALL'; // ALL, UNUSED, USED

  late TextEditingController _supportEmailController;
  late TextEditingController _appNameController;
  final TextEditingController _newPhoneController = TextEditingController();
  List<String> _whatsappNumbers = [];
  bool _isSavingSettings = false;
  String? _settingsError;

  final Set<String> _loadingActionIds = {};
  bool _isActionLoading(String id) => _loadingActionIds.contains(id);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _supportEmailController =
        TextEditingController(text: AppSettings.instance.supportEmail);
    _appNameController =
        TextEditingController(text: AppSettings.instance.appName);
    _whatsappNumbers = List<String>.from(AppSettings.instance.whatsappNumbers);
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _supportEmailController.dispose();
    _appNameController.dispose();
    _newPhoneController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    await Future.wait([
      _loadTenants(),
      _loadCodes(),
      _loadPlatformSettings(),
    ]);
  }

  Future<void> _loadPlatformSettings() async {
    await AppSettings.instance.loadSettings();
    if (mounted) {
      setState(() {
        _supportEmailController.text = AppSettings.instance.supportEmail;
        _appNameController.text = AppSettings.instance.appName;
        _whatsappNumbers =
            List<String>.from(AppSettings.instance.whatsappNumbers);
      });
    }
  }

  Future<void> _loadTenants() async {
    setState(() {
      _isLoadingTenants = true;
      _tenantsError = null;
    });

    final result = await ApiClient.getAdminTenants();
    if (!mounted) return;

    if (result['success'] == true) {
      setState(() {
        _tenants = result['data'] as List<AdminTenantModel>;
        _isLoadingTenants = false;
      });
    } else {
      setState(() {
        _tenantsError = result['errorMessage'] as String? ?? 'فشل جلب قائمة الشركات';
        _isLoadingTenants = false;
      });
    }
  }

  Future<void> _loadCodes() async {
    setState(() {
      _isLoadingCodes = true;
      _codesError = null;
    });

    final result = await ApiClient.getAdminLicenseCodes();
    if (!mounted) return;

    if (result['success'] == true) {
      setState(() {
        _codes = result['data'] as List<LicenseCodeModel>;
        _isLoadingCodes = false;
      });
    } else {
      setState(() {
        _codesError = result['errorMessage'] as String? ?? 'فشل جلب قائمة أكواد الترخيص';
        _isLoadingCodes = false;
      });
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
            'هل أنت متأكد من رغبتك في تسجيل الخروج من لوحة مدير المنصة؟',
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

  void _showGenerateCodeDialog() {
    final planController = TextEditingController(text: 'الخطة القياسية (Pro)');
    final durationController = TextEditingController(text: '30');
    final routersController = TextEditingController(text: '5');
    bool isSubmitting = false;
    String? dialogError;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.pageBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: Padding(
                padding: EdgeInsets.only(
                  left: 24,
                  right: 24,
                  top: 24,
                  bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 24,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.heroGradientStart.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.vpn_key_rounded,
                              color: AppColors.heroGradientStart,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'توليد كود ترخيص جديد',
                                  style: GoogleFonts.cairo(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textDark,
                                  ),
                                ),
                                Text(
                                  'حدد مواصفات الباقة وصلاحية الترخيص',
                                  style: GoogleFonts.cairo(
                                    fontSize: 12.5,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      if (dialogError != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.statusOffline.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
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
                                  dialogError!,
                                  style: GoogleFonts.cairo(
                                    fontSize: 13,
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

                      // Plan Name
                      NeumorphicTextField(
                        label: 'اسم الخطة / الباقة',
                        hintText: 'مثال: الاحترافية (Professional)',
                        controller: planController,
                        prefixIcon: const Icon(
                          Icons.card_membership_rounded,
                          size: 20,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Quick presets chips for plan
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildPresetChip('الباقة الأساسية', () {
                              setModalState(() {
                                planController.text = 'الباقة الأساسية';
                                durationController.text = '30';
                                routersController.text = '3';
                              });
                            }),
                            const SizedBox(width: 8),
                            _buildPresetChip('باقة المحترفين', () {
                              setModalState(() {
                                planController.text = 'باقة المحترفين (Pro)';
                                durationController.text = '90';
                                routersController.text = '10';
                              });
                            }),
                            const SizedBox(width: 8),
                            _buildPresetChip('باقة المؤسسات السنوية', () {
                              setModalState(() {
                                planController.text = 'باقة المؤسسات (Enterprise)';
                                durationController.text = '365';
                                routersController.text = '25';
                              });
                            }),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Duration in Days
                      NeumorphicTextField(
                        label: 'المدة بالأيام (Duration Days)',
                        hintText: '30',
                        controller: durationController,
                        keyboardType: TextInputType.number,
                        prefixIcon: const Icon(
                          Icons.calendar_today_rounded,
                          size: 20,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Max Routers Limit
                      NeumorphicTextField(
                        label: 'حد أجهزة الراوتر المسموح به',
                        hintText: '5',
                        controller: routersController,
                        keyboardType: TextInputType.number,
                        prefixIcon: const Icon(
                          Icons.router_rounded,
                          size: 20,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Submit Button
                      PressableNeumorphicCard(
                        onTap: isSubmitting
                            ? null
                            : () async {
                                final plan = planController.text.trim();
                                final duration =
                                    int.tryParse(durationController.text.trim());
                                final routers =
                                    int.tryParse(routersController.text.trim());

                                if (plan.isEmpty) {
                                  setModalState(() => dialogError = 'يرجى كتابة اسم الخطة');
                                  return;
                                }
                                if (duration == null || duration <= 0) {
                                  setModalState(() => dialogError = 'يرجى إدخال مدة صالحة بالأيام');
                                  return;
                                }
                                if (routers == null || routers <= 0) {
                                  setModalState(() => dialogError = 'يرجى إدخال حد راوترات صالح');
                                  return;
                                }

                                setModalState(() {
                                  isSubmitting = true;
                                  dialogError = null;
                                });

                                final result = await ApiClient.generateLicenseCode(
                                  planName: plan,
                                  durationDays: duration,
                                  maxRoutersLimit: routers,
                                );

                                if (!mounted) return;

                                if (result['success'] == true) {
                                  Navigator.of(context).pop();
                                  _loadCodes();
                                  _showCodeCreatedSuccessDialog(
                                      result['data'] as LicenseCodeModel);
                                } else {
                                  setModalState(() {
                                    isSubmitting = false;
                                    dialogError = result['errorMessage'] as String? ??
                                        'فشل توليد كود الترخيص';
                                  });
                                }
                              },
                        backgroundColor: AppColors.accentYellow,
                        borderRadius: BorderRadius.circular(16),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: isSubmitting
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
                                      Icons.add_task_rounded,
                                      color: AppColors.textDark,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'توليد الكود فوراً',
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
            );
          },
        );
      },
    );
  }

  Widget _buildPresetChip(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.heroGradientStart.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: AppColors.heroGradientStart.withValues(alpha: 0.2),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.cairo(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: AppColors.heroGradientStart,
          ),
        ),
      ),
    );
  }

  void _showCodeCreatedSuccessDialog(LicenseCodeModel code) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AppColors.pageBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: AppColors.statusOnline,
                size: 28,
              ),
              const SizedBox(width: 10),
              Text(
                'تم توليد الكود بنجاح',
                style: GoogleFonts.cairo(fontWeight: FontWeight.w800, fontSize: 18),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'يمكنك الآن نسخ كود الترخيص وإرساله للعميل لتفعيل اشتراكه:',
                style: GoogleFonts.cairo(fontSize: 13, color: AppColors.textMuted),
              ),
              const SizedBox(height: 18),

              // Highlighted Code Card
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.heroGradientStart.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.heroGradientStart.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  children: [
                    SelectableText(
                      code.code,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2,
                        color: AppColors.heroGradientStart,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${code.planName} • ${code.durationDays} يوماً • حد ${code.maxRoutersLimit} راوترات',
                      style: GoogleFonts.cairo(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.heroGradientStart,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: code.code));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: AppColors.statusOnline,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    content: Text(
                      'تم نسخ كود الترخيص: ${code.code}',
                      style: GoogleFonts.cairo(fontWeight: FontWeight.w600),
                    ),
                  ),
                );
                Navigator.of(ctx).pop();
              },
              icon: const Icon(Icons.copy_rounded, color: Colors.white, size: 18),
              label: Text(
                'نسخ الكود',
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
  }

  Future<void> _handleApproveTenant(AdminTenantModel tenant) async {
    final actionId = '${tenant.id}_approve';
    if (_isActionLoading(actionId)) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AppColors.pageBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('الموافقة على التسجيل', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
          content: Text('هل ترغب في اعتماد والموافقة على شبكة "${tenant.name}" وتفعيلها فوراً؟', style: GoogleFonts.cairo(fontSize: 14)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text('إلغاء', style: GoogleFonts.cairo(color: AppColors.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.statusOnline,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text('موافقة', style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      setState(() => _loadingActionIds.add(actionId));
      try {
        final res = await ApiClient.approveTenant(tenant.id);
        if (!mounted) return;
        if (res['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.statusOnline,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              content: Text(res['data']?['message'] ?? 'تمت الموافقة بنجاح', style: GoogleFonts.cairo(fontWeight: FontWeight.w600)),
            ),
          );
          _loadTenants();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.statusOffline,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              content: Text(res['errorMessage'] ?? 'فشلت الموافقة', style: GoogleFonts.cairo(fontWeight: FontWeight.w600)),
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _loadingActionIds.remove(actionId));
      }
    }
  }

  Future<void> _handleRejectTenant(AdminTenantModel tenant) async {
    final actionId = '${tenant.id}_reject';
    if (_isActionLoading(actionId)) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AppColors.pageBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('رفض طلب التسجيل', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
          content: Text('هل أنت متأكد من رغبتك في رفض طلب شبكة "${tenant.name}"؟', style: GoogleFonts.cairo(fontSize: 14)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text('إلغاء', style: GoogleFonts.cairo(color: AppColors.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.statusOffline,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text('رفض الطلب', style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      setState(() => _loadingActionIds.add(actionId));
      try {
        final res = await ApiClient.rejectTenant(tenant.id);
        if (!mounted) return;
        if (res['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.statusOffline,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              content: Text('تم رفض طلب التسجيل', style: GoogleFonts.cairo(fontWeight: FontWeight.w600)),
            ),
          );
          _loadTenants();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.statusOffline,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              content: Text(res['errorMessage'] ?? 'فشل رفض الطلب', style: GoogleFonts.cairo(fontWeight: FontWeight.w600)),
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _loadingActionIds.remove(actionId));
      }
    }
  }

  Future<void> _handleSuspendTenant(AdminTenantModel tenant) async {
    final actionId = '${tenant.id}_suspend';
    if (_isActionLoading(actionId)) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AppColors.pageBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('إيقاف الحساب مؤقتاً', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
          content: Text('سيتم تعليق اشتراك "${tenant.name}" وإيقاف وصول المشتركين لحين إعادة التفعيل.', style: GoogleFonts.cairo(fontSize: 14)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text('إلغاء', style: GoogleFonts.cairo(color: AppColors.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentYellow,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text('إيقاف مؤقت', style: GoogleFonts.cairo(color: Colors.black, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      setState(() => _loadingActionIds.add(actionId));
      try {
        final res = await ApiClient.suspendTenant(tenant.id);
        if (!mounted) return;
        if (res['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.statusOnline,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              content: Text('تم إيقاف الحساب بنجاح', style: GoogleFonts.cairo(fontWeight: FontWeight.w600)),
            ),
          );
          _loadTenants();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.statusOffline,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              content: Text(res['errorMessage'] ?? 'فشل إيقاف الحساب', style: GoogleFonts.cairo(fontWeight: FontWeight.w600)),
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _loadingActionIds.remove(actionId));
      }
    }
  }

  Future<void> _handleReactivateTenant(AdminTenantModel tenant) async {
    final actionId = '${tenant.id}_reactivate';
    if (_isActionLoading(actionId)) return;

    setState(() => _loadingActionIds.add(actionId));
    try {
      final res = await ApiClient.reactivateTenant(tenant.id);
      if (!mounted) return;
      if (res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.statusOnline,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Text('تمت إعادة تفعيل الحساب بنجاح', style: GoogleFonts.cairo(fontWeight: FontWeight.w600)),
          ),
        );
        _loadTenants();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.statusOffline,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Text(res['errorMessage'] ?? 'فشلت إعادة تفعيل الحساب', style: GoogleFonts.cairo(fontWeight: FontWeight.w600)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingActionIds.remove(actionId));
    }
  }

  Future<void> _handleDeleteTenant(AdminTenantModel tenant) async {
    final actionId = '${tenant.id}_delete';
    if (_isActionLoading(actionId)) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AppColors.pageBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppColors.statusOffline),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'تأكيد إخفاء وحذف الحساب',
                  style: GoogleFonts.cairo(fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ),
            ],
          ),
          content: Text(
            'هذا الإجراء يخفي الحساب ولا يحذف بياناته نهائياً.\n\nلن يظهر هذا الحساب في القوائم العادية ولن يتمكن مستخدموه من تسجيل الدخول، مع الحفاظ الكامل على كافة السجلات والبيانات المالية وفق السياسات الإدارية.',
            style: GoogleFonts.cairo(fontSize: 13.5, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text('إلغاء', style: GoogleFonts.cairo(color: AppColors.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.statusOffline,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(
                'تأكيد الإخفاء والحذف',
                style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      setState(() => _loadingActionIds.add(actionId));
      try {
        final res = await ApiClient.deleteTenant(tenant.id);
        if (!mounted) return;
        if (res['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.statusOnline,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              content: Text('تم إخفاء وحذف الحساب منطقياً بنجاح', style: GoogleFonts.cairo(fontWeight: FontWeight.w600)),
            ),
          );
          _loadTenants();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.statusOffline,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              content: Text(res['errorMessage'] ?? 'فشل حذف الحساب', style: GoogleFonts.cairo(fontWeight: FontWeight.w600)),
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _loadingActionIds.remove(actionId));
      }
    }
  }

  void _showAddSuperAdminDialog() {
    final fullNameController = TextEditingController();
    final usernameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    bool isSubmitting = false;
    String? dialogError;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.pageBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: Padding(
                padding: EdgeInsets.only(
                  left: 24,
                  right: 24,
                  top: 24,
                  bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 24,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.heroGradientStart.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.admin_panel_settings_rounded,
                              color: AppColors.heroGradientStart,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'إضافة مدير منصة جديد',
                                  style: GoogleFonts.cairo(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textDark,
                                  ),
                                ),
                                Text(
                                  'إنشاء حساب جديد بصلاحيات SUPER_ADMIN كاملة',
                                  style: GoogleFonts.cairo(
                                    fontSize: 12,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      if (dialogError != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.statusOffline.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.statusOffline.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            dialogError!,
                            style: GoogleFonts.cairo(color: AppColors.statusOffline, fontSize: 13),
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      NeumorphicTextField(
                        controller: fullNameController,
                        label: 'الاسم الكامل',
                        hintText: 'مثال: م. عبد الرحمن أحمد',
                        prefixIcon: const Icon(Icons.badge_rounded, color: AppColors.textMuted),
                      ),
                      const SizedBox(height: 14),

                      NeumorphicTextField(
                        controller: usernameController,
                        label: 'اسم المستخدم',
                        hintText: 'مثال: superadmin2',
                        prefixIcon: const Icon(Icons.person_outline_rounded, color: AppColors.textMuted),
                      ),
                      const SizedBox(height: 14),

                      NeumorphicTextField(
                        controller: emailController,
                        label: 'البريد الإلكتروني',
                        hintText: 'مثال: admin@jalsah.network',
                        keyboardType: TextInputType.emailAddress,
                        prefixIcon: const Icon(Icons.email_outlined, color: AppColors.textMuted),
                      ),
                      const SizedBox(height: 14),

                      NeumorphicTextField(
                        controller: passwordController,
                        label: 'كلمة المرور',
                        hintText: '8 أحرف على الأقل',
                        isPassword: true,
                        prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.textMuted),
                      ),
                      const SizedBox(height: 22),

                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.heroGradientStart,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                final fullName = fullNameController.text.trim();
                                final username = usernameController.text.trim();
                                final email = emailController.text.trim();
                                final password = passwordController.text;

                                if (fullName.isEmpty || username.isEmpty || email.isEmpty || password.isEmpty) {
                                  setModalState(() => dialogError = 'يرجى إدخال جميع الحقول المطلوبة');
                                  return;
                                }

                                if (password.length < 8) {
                                  setModalState(() => dialogError = 'يجب ألا تقل كلمة المرور عن 8 أحرف');
                                  return;
                                }

                                setModalState(() {
                                  isSubmitting = true;
                                  dialogError = null;
                                });

                                final res = await ApiClient.createSuperAdmin(
                                  fullName: fullName,
                                  username: username,
                                  email: email,
                                  password: password,
                                );

                                if (res['success'] == true) {
                                  if (!mounted) return;
                                  if (ctx.mounted) Navigator.of(ctx).pop();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      backgroundColor: AppColors.statusOnline,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      content: Text('تم إنشاء مدير المنصة بنجاح', style: GoogleFonts.cairo(fontWeight: FontWeight.w600)),
                                    ),
                                  );
                                } else {
                                  setModalState(() {
                                    isSubmitting = false;
                                    dialogError = res['errorMessage'] ?? 'فشل إنشاء مدير المنصة';
                                  });
                                }
                              },
                        child: isSubmitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.person_add_rounded, color: Colors.white, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'إضافة المدير',
                                    style: GoogleFonts.cairo(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showDirectLicenseDialog(AdminTenantModel tenant) {
    final planController = TextEditingController(text: tenant.planName ?? 'الخطة القياسية (Pro)');
    final durationController = TextEditingController(text: '30');
    final routersController = TextEditingController(text: tenant.maxRoutersLimit > 0 ? tenant.maxRoutersLimit.toString() : '5');
    bool isSubmitting = false;
    String? dialogError;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.pageBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: Padding(
                padding: EdgeInsets.only(
                  left: 24,
                  right: 24,
                  top: 24,
                  bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 24,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.statusOnline.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.verified_rounded,
                              color: AppColors.statusOnline,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'تفعيل ترخيص مباشر',
                                  style: GoogleFonts.cairo(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textDark,
                                  ),
                                ),
                                Text(
                                  'تفعيل فوري لـ "${tenant.name}" دون الحاجة لكود',
                                  style: GoogleFonts.cairo(
                                    fontSize: 12,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      if (dialogError != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.statusOffline.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            dialogError!,
                            style: GoogleFonts.cairo(color: AppColors.statusOffline, fontSize: 13),
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      NeumorphicTextField(
                        controller: planController,
                        label: 'اسم الخطة / الباقة',
                        hintText: 'مثال: الباقة القياسية',
                        prefixIcon: const Icon(Icons.card_membership_rounded, color: AppColors.textMuted),
                      ),
                      const SizedBox(height: 14),

                      NeumorphicTextField(
                        controller: durationController,
                        label: 'المدة بالأيام',
                        hintText: 'مثال: 30',
                        keyboardType: TextInputType.number,
                        prefixIcon: const Icon(Icons.calendar_today_rounded, color: AppColors.textMuted),
                      ),
                      const SizedBox(height: 14),

                      NeumorphicTextField(
                        controller: routersController,
                        label: 'الحد الأقصى للراوترات',
                        hintText: 'مثال: 5',
                        keyboardType: TextInputType.number,
                        prefixIcon: const Icon(Icons.router_rounded, color: AppColors.textMuted),
                      ),
                      const SizedBox(height: 22),

                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.heroGradientStart,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                final plan = planController.text.trim();
                                final duration = int.tryParse(durationController.text.trim());
                                final routers = int.tryParse(routersController.text.trim());

                                if (plan.isEmpty || duration == null || duration <= 0 || routers == null || routers <= 0) {
                                  setModalState(() => dialogError = 'يرجى إدخال كافة البيانات بشكل صحيح');
                                  return;
                                }

                                setModalState(() {
                                  isSubmitting = true;
                                  dialogError = null;
                                });

                                final res = await ApiClient.adminActivateTenant(
                                  tenantId: tenant.id,
                                  planName: plan,
                                  durationDays: duration,
                                  maxRoutersLimit: routers,
                                );

                                if (res['success'] == true) {
                                  if (!mounted) return;
                                  if (ctx.mounted) Navigator.of(ctx).pop();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      backgroundColor: AppColors.statusOnline,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      content: Text(res['data']?['message'] ?? 'تم تفعيل الترخيص بنجاح', style: GoogleFonts.cairo(fontWeight: FontWeight.w600)),
                                    ),
                                  );
                                  _loadTenants();
                                } else {
                                  setModalState(() {
                                    isSubmitting = false;
                                    dialogError = res['errorMessage'] ?? 'فشل التفعيل المباشر';
                                  });
                                }
                              },
                        child: isSubmitting
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : Text(
                                'تفعيل الاشتراك فوراً',
                                style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showTenantUsersDialog(AdminTenantModel tenant) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.pageBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return _TenantUsersSheet(
          tenant: tenant,
          onRoleChanged: () => _loadTenants(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeTenants =
        _tenants.where((t) => t.isActive || t.isTrial).length;
    final unusedCodesCount = _codes.where((c) => c.isUnused).length;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.pageBg,
        body: SafeArea(
          child: NestedScrollView(
            headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
              return [
                // Collapsible Header Section (Top Bar + Stats Metrics)
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      // Header Banner
                      _buildTopBar(),

                      // Quick Stats Metrics
                      _buildMetricsBar(
                        totalTenants: _tenants.length,
                        activeTenants: activeTenants,
                        totalCodes: _codes.length,
                        unusedCodes: unusedCodesCount,
                      ),
                    ],
                  ),
                ),

                // Pinned Tab Bar that stays fixed when header collapses
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _SliverTabBarDelegate(
                    Container(
                      color: AppColors.pageBg,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.shadowDark.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: TabBar(
                          controller: _tabController,
                          indicatorSize: TabBarIndicatorSize.tab,
                          indicator: BoxDecoration(
                            color: AppColors.heroGradientStart,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          labelColor: Colors.white,
                          unselectedLabelColor: AppColors.textMuted,
                          labelStyle: GoogleFonts.cairo(
                            fontWeight: FontWeight.w800,
                            fontSize: 13.5,
                          ),
                          tabs: [
                            Tab(
                              icon: const Icon(Icons.apartment_rounded, size: 20),
                              text: 'الشركات والشبكات (${_tenants.length})',
                            ),
                            Tab(
                              icon: const Icon(Icons.vpn_key_rounded, size: 20),
                              text: 'أكواد الترخيص (${_codes.length})',
                            ),
                            const Tab(
                              icon: Icon(Icons.tune_rounded, size: 20),
                              text: 'الإعدادات العامة',
                            ),
                          ],
                        ),
                      ),
                    ),
                    height: 64.0,
                  ),
                ),
              ];
            },
            // Scrollable Tab Views
            body: TabBarView(
              controller: _tabController,
              children: [
                _buildTenantsTab(),
                _buildCodesTab(),
                _buildSettingsTab(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.pageBg,
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowDark.withValues(alpha: 0.15),
            offset: const Offset(0, 3),
            blurRadius: 6,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.heroGradientStart, AppColors.heroGradientEnd],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.admin_panel_settings_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'لوحة تحكم مدير المنصة',
                  style: GoogleFonts.cairo(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
                Text(
                  'SOFT ZONE • الإشراف والاشتراكات',
                  style: GoogleFonts.cairo(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.heroGradientStart,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'إرسال إشعار للعملاء',
            icon: const Icon(Icons.campaign_rounded, color: AppColors.heroGradientStart),
            onPressed: _showSendNotificationDialog,
          ),
          IconButton(
            tooltip: 'إضافة مدير منصة',
            icon: const Icon(Icons.person_add_rounded, color: AppColors.heroGradientStart),
            onPressed: _showAddSuperAdminDialog,
          ),
          IconButton(
            tooltip: 'تحديث البيانات',
            icon: const Icon(Icons.refresh_rounded, color: AppColors.textDark),
            onPressed: _loadAllData,
          ),
          IconButton(
            tooltip: 'تسجيل الخروج',
            icon: const Icon(Icons.logout_rounded, color: AppColors.statusOffline),
            onPressed: _handleLogout,
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsBar({
    required int totalTenants,
    required int activeTenants,
    required int totalCodes,
    required int unusedCodes,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: _buildMetricTile(
              'الشركات',
              '$totalTenants',
              '$activeTenants نشطة',
              Icons.business_rounded,
              AppColors.heroGradientStart,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildMetricTile(
              'أكواد الترخيص',
              '$totalCodes',
              '$unusedCodes غير مستخدم',
              Icons.key_rounded,
              AppColors.statusOnline,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile(
    String title,
    String count,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.pageBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          const BoxShadow(
            color: AppColors.shadowLight,
            offset: Offset(-3, -3),
            blurRadius: 6,
          ),
          BoxShadow(
            color: AppColors.shadowDark.withValues(alpha: 0.4),
            offset: const Offset(3, 3),
            blurRadius: 6,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.cairo(
                    fontSize: 11,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  count,
                  style: GoogleFonts.cairo(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                    height: 1.1,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.cairo(
                    fontSize: 10.5,
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTenantsTab() {
    if (_isLoadingTenants) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_tenantsError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 48, color: AppColors.statusOffline),
            const SizedBox(height: 12),
            Text(_tenantsError!, style: GoogleFonts.cairo(fontSize: 14)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loadTenants,
              child: Text('إعادة المحاولة', style: GoogleFonts.cairo()),
            ),
          ],
        ),
      );
    }

    final pendingCount = _tenants.where((t) => t.isPending).length;

    final filtered = _tenants.where((t) {
      if (_tenantFilter == 'PENDING' && !t.isPending) return false;
      if (_tenantFilter == 'ACTIVE' && !(t.isActive || t.isTrial)) return false;
      if (_tenantFilter == 'SUSPENDED' && !t.isSuspended) return false;

      if (_tenantSearchQuery.isEmpty) return true;
      final q = _tenantSearchQuery.toLowerCase();
      return t.name.toLowerCase().contains(q) || t.slug.toLowerCase().contains(q);
    }).toList();

    return RefreshIndicator(
      onRefresh: _loadTenants,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        children: [
          // Pending requests banner
          if (pendingCount > 0)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.accentYellow.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.accentYellow.withValues(alpha: 0.4),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.notification_important_rounded,
                    color: AppColors.accentYellow,
                    size: 24,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'يوجد $pendingCount طلب تسجيل جديد بانتظار المراجعة والموافقة.',
                      style: GoogleFonts.cairo(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() => _tenantFilter = 'PENDING');
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'عرض الطلبات',
                      style: GoogleFonts.cairo(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.heroGradientStart,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Action button to add new super admin
          PressableNeumorphicCard(
            onTap: _showAddSuperAdminDialog,
            backgroundColor: AppColors.heroGradientStart,
            borderRadius: BorderRadius.circular(16),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.person_add_rounded,
                  color: Colors.white,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Text(
                  'إضافة مدير منصة',
                  style: GoogleFonts.cairo(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Search Bar
          NeumorphicTextField(
            label: 'بحث عن شركة أو شبكة',
            hintText: 'اكتب اسم الشركة أو معرّفها...',
            prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textMuted),
            onChanged: (val) {
              setState(() => _tenantSearchQuery = val);
            },
          ),
          const SizedBox(height: 14),

          // Tenant Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildTenantFilterChip('الكل (${_tenants.length})', 'ALL'),
                const SizedBox(width: 8),
                _buildTenantFilterChip(
                  'طلبات التسجيل ($pendingCount)',
                  'PENDING',
                  badgeColor: pendingCount > 0 ? AppColors.accentYellow : null,
                ),
                const SizedBox(width: 8),
                _buildTenantFilterChip(
                  'النشطة (${_tenants.where((t) => t.isActive || t.isTrial).length})',
                  'ACTIVE',
                ),
                const SizedBox(width: 8),
                _buildTenantFilterChip(
                  'الموقوفة (${_tenants.where((t) => t.isSuspended).length})',
                  'SUSPENDED',
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          if (filtered.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Text(
                  'لا توجد شركات مطابقة للبحث',
                  style: GoogleFonts.cairo(
                    fontSize: 14,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            )
          else
            ...filtered.map((tenant) => _buildTenantCard(tenant)),
        ],
      ),
    );
  }

  Widget _buildTenantFilterChip(String label, String value, {Color? badgeColor}) {
    final isSelected = _tenantFilter == value;
    return InkWell(
      onTap: () => setState(() => _tenantFilter = value),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.heroGradientStart
              : (badgeColor != null ? badgeColor.withValues(alpha: 0.12) : AppColors.shadowDark.withValues(alpha: 0.1)),
          borderRadius: BorderRadius.circular(12),
          border: badgeColor != null && !isSelected
              ? Border.all(color: badgeColor.withValues(alpha: 0.4))
              : null,
        ),
        child: Text(
          label,
          style: GoogleFonts.cairo(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? Colors.white : (badgeColor != null ? AppColors.textDark : AppColors.textMuted),
          ),
        ),
      ),
    );
  }

  Widget _buildTenantCard(AdminTenantModel tenant) {
    Color statusColor;
    String statusText;

    if (tenant.isPending) {
      statusColor = AppColors.accentYellow;
      statusText = 'قيد المراجعة (PENDING)';
    } else if (tenant.isRejected) {
      statusColor = AppColors.statusOffline;
      statusText = 'مرفوض (REJECTED)';
    } else if (tenant.isSuspended) {
      statusColor = const Color(0xFF9333EA);
      statusText = 'موقوف (SUSPENDED)';
    } else if (tenant.isActive) {
      statusColor = AppColors.statusOnline;
      statusText = 'نشط (ACTIVE)';
    } else if (tenant.isTrial) {
      statusColor = AppColors.accentYellow;
      statusText = 'تجريبي (TRIAL)';
    } else if (tenant.isExpired) {
      statusColor = AppColors.statusOffline;
      statusText = 'منتهي (EXPIRED)';
    } else {
      statusColor = AppColors.textMuted;
      statusText = tenant.subscriptionStatus;
    }

    final isApproving = _isActionLoading('${tenant.id}_approve');
    final isRejecting = _isActionLoading('${tenant.id}_reject');
    final isReactivating = _isActionLoading('${tenant.id}_reactivate');
    final isSuspending = _isActionLoading('${tenant.id}_suspend');
    final isDeleting = _isActionLoading('${tenant.id}_delete');
    final isAnyActionRunning = isApproving || isRejecting || isReactivating || isSuspending || isDeleting;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.pageBg,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          const BoxShadow(
            color: AppColors.shadowLight,
            offset: Offset(-3, -3),
            blurRadius: 8,
          ),
          BoxShadow(
            color: AppColors.shadowDark.withValues(alpha: 0.4),
            offset: const Offset(3, 3),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.heroGradientStart.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.business_center_rounded,
                  color: AppColors.heroGradientStart,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tenant.name,
                      style: GoogleFonts.cairo(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                    Text(
                      '@${tenant.slug}',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              // Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                ),
                child: Text(
                  statusText,
                  style: GoogleFonts.cairo(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: AppColors.shadowDark),
          const SizedBox(height: 12),

          // Details row
          Row(
            children: [
              Expanded(
                child: _buildTenantDetailItem(
                  Icons.router_rounded,
                  'الراوترات',
                  '${tenant.routersCount} / ${tenant.maxRoutersLimit}',
                ),
              ),
              Expanded(
                child: _buildTenantDetailItem(
                  Icons.people_rounded,
                  'المستخدمين',
                  '${tenant.usersCount} موظف',
                ),
              ),
              Expanded(
                child: _buildTenantDetailItem(
                  Icons.card_membership_rounded,
                  'الخطة',
                  tenant.planName ?? 'تجريبية',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Joined Date
          Text(
            'تاريخ الانضمام: ${tenant.createdAt.toLocal().toString().substring(0, 10)}',
            style: GoogleFonts.cairo(
              fontSize: 11,
              color: AppColors.textMuted,
            ),
          ),

          // Actions
          if (tenant.isPending) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.accentYellow.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.pending_actions_rounded,
                    color: AppColors.accentYellow,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'طلب تسجيل جديد بانتظار الاعتماد والموافقة الإدارية',
                      style: GoogleFonts.cairo(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.statusOnline,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: isAnyActionRunning ? null : () => _handleApproveTenant(tenant),
                    icon: isApproving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                    label: Text(
                      'موافقة واعتماد',
                      style: GoogleFonts.cairo(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.statusOffline),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: isAnyActionRunning ? null : () => _handleRejectTenant(tenant),
                    icon: isRejecting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.statusOffline),
                          )
                        : const Icon(Icons.cancel_outlined, color: AppColors.statusOffline, size: 18),
                    label: Text(
                      'رفض الطلب',
                      style: GoogleFonts.cairo(
                        color: AppColors.statusOffline,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.heroGradientStart,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onPressed: isAnyActionRunning ? null : () => _showDirectLicenseDialog(tenant),
                  icon: const Icon(Icons.verified_rounded, color: Colors.white, size: 16),
                  label: Text(
                    'تفعيل مباشر',
                    style: GoogleFonts.cairo(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.heroGradientStart.withValues(alpha: 0.5)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onPressed: isAnyActionRunning ? null : () => _showTenantUsersDialog(tenant),
                  icon: const Icon(Icons.manage_accounts_rounded, color: AppColors.heroGradientStart, size: 16),
                  label: Text(
                    'المستخدمين',
                    style: GoogleFonts.cairo(
                      color: AppColors.heroGradientStart,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
                if (tenant.isSuspended)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.statusOnline,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onPressed: isAnyActionRunning ? null : () => _handleReactivateTenant(tenant),
                    icon: isReactivating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 16),
                    label: Text(
                      'إعادة تفعيل',
                      style: GoogleFonts.cairo(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  )
                else
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.accentYellow),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onPressed: isAnyActionRunning ? null : () => _handleSuspendTenant(tenant),
                    icon: isSuspending
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accentYellow),
                          )
                        : const Icon(Icons.pause_rounded, color: AppColors.accentYellow, size: 16),
                    label: Text(
                      'إيقاف مؤقت',
                      style: GoogleFonts.cairo(
                        color: AppColors.textDark,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                IconButton(
                  tooltip: 'إخفاء وحذف منطقي',
                  icon: isDeleting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.statusOffline),
                        )
                      : const Icon(Icons.delete_outline_rounded, color: AppColors.statusOffline, size: 20),
                  onPressed: isAnyActionRunning ? null : () => _handleDeleteTenant(tenant),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTenantDetailItem(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.heroGradientStart),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.cairo(
                fontSize: 10.5,
                color: AppColors.textMuted,
              ),
            ),
            Text(
              value,
              style: GoogleFonts.cairo(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCodesTab() {
    if (_isLoadingCodes) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_codesError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 48, color: AppColors.statusOffline),
            const SizedBox(height: 12),
            Text(_codesError!, style: GoogleFonts.cairo(fontSize: 14)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loadCodes,
              child: Text('إعادة المحاولة', style: GoogleFonts.cairo()),
            ),
          ],
        ),
      );
    }

    final filtered = _codes.where((c) {
      if (_codeFilter == 'UNUSED') return c.isUnused;
      if (_codeFilter == 'USED') return c.isUsed;
      return true;
    }).toList();

    return RefreshIndicator(
      onRefresh: _loadCodes,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        children: [
          // Action button to generate new code
          PressableNeumorphicCard(
            onTap: _showGenerateCodeDialog,
            backgroundColor: AppColors.accentYellow,
            borderRadius: BorderRadius.circular(16),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.add_circle_outline_rounded,
                  color: AppColors.textDark,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Text(
                  'توليد كود ترخيص جديد',
                  style: GoogleFonts.cairo(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Filter chips
          Row(
            children: [
              _buildFilterChip('الكل (${_codes.length})', 'ALL'),
              const SizedBox(width: 8),
              _buildFilterChip(
                'غير مستخدم (${_codes.where((c) => c.isUnused).length})',
                'UNUSED',
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                'مستخدم (${_codes.where((c) => c.isUsed).length})',
                'USED',
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (filtered.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Text(
                  'لا توجد أكواد ترخيص في هذه الفئة',
                  style: GoogleFonts.cairo(
                    fontSize: 14,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            )
          else
            ...filtered.map((code) => _buildCodeCard(code)),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _codeFilter == value;
    return InkWell(
      onTap: () => setState(() => _codeFilter = value),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.heroGradientStart
              : AppColors.shadowDark.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: GoogleFonts.cairo(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? Colors.white : AppColors.textMuted,
          ),
        ),
      ),
    );
  }

  Widget _buildCodeCard(LicenseCodeModel code) {
    Color badgeColor;
    String badgeText;

    if (code.isUnused) {
      badgeColor = AppColors.statusOnline;
      badgeText = 'جاهز للاستخدام';
    } else if (code.isUsed) {
      badgeColor = AppColors.heroGradientStart;
      badgeText = 'مُستخدم';
    } else {
      badgeColor = AppColors.statusOffline;
      badgeText = 'ملغي';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.pageBg,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          const BoxShadow(
            color: AppColors.shadowLight,
            offset: Offset(-3, -3),
            blurRadius: 8,
          ),
          BoxShadow(
            color: AppColors.shadowDark.withValues(alpha: 0.4),
            offset: const Offset(3, 3),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  code.code,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy_rounded, size: 20),
                tooltip: 'نسخ الكود',
                color: AppColors.heroGradientStart,
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: code.code));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: AppColors.statusOnline,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      content: Text(
                        'تم نسخ كود الترخيص: ${code.code}',
                        style: GoogleFonts.cairo(fontWeight: FontWeight.w600),
                      ),
                    ),
                  );
                },
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
                ),
                child: Text(
                  badgeText,
                  style: GoogleFonts.cairo(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: badgeColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                'الخطة: ${code.planName}',
                style: GoogleFonts.cairo(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(width: 14),
              Text(
                '• المدة: ${code.durationDays} يوم',
                style: GoogleFonts.cairo(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(width: 14),
              Text(
                '• السقف: ${code.maxRoutersLimit} راوتر',
                style: GoogleFonts.cairo(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          if (code.isUsed) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.heroGradientStart.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_outline_rounded,
                    size: 16,
                    color: AppColors.heroGradientStart,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'استخدم بواسطة: ${code.usedByTenantName ?? code.usedByTenantId ?? "شركة غير محددة"}'
                      '${code.usedAt != null ? " في ${code.usedAt!.toLocal().toString().substring(0, 10)}" : ""}',
                      style: GoogleFonts.cairo(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.heroGradientStart,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSettingsTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        // Platform Information Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.pageBg,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: AppColors.shadowLight,
                offset: Offset(-3, -3),
                blurRadius: 8,
              ),
              BoxShadow(
                color: AppColors.shadowDark,
                offset: Offset(3, 3),
                blurRadius: 8,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.heroGradientStart.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.settings_suggest_rounded,
                      color: AppColors.heroGradientStart,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'بيانات المنصة الأساسية',
                    style: GoogleFonts.cairo(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              NeumorphicTextField(
                label: 'اسم التطبيق والمنصة',
                controller: _appNameController,
                hintText: 'اسم التطبيق (مثال: جلسة)',
                prefixIcon: const Icon(Icons.badge_outlined),
              ),
              const SizedBox(height: 16),
              NeumorphicTextField(
                label: 'البريد الإلكتروني للدعم الفني',
                controller: _supportEmailController,
                hintText: 'support@example.com',
                prefixIcon: const Icon(Icons.email_outlined),
                keyboardType: TextInputType.emailAddress,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // WhatsApp Numbers Management Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.pageBg,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: AppColors.shadowLight,
                offset: Offset(-3, -3),
                blurRadius: 8,
              ),
              BoxShadow(
                color: AppColors.shadowDark,
                offset: Offset(3, 3),
                blurRadius: 8,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                      Icons.chat_bubble_rounded,
                      color: AppColors.statusOnline,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'أرقام الواتساب للدعم الفني',
                          style: GoogleFonts.cairo(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textDark,
                          ),
                        ),
                        Text(
                          'تظهر تلقائياً في شاشات الدعم والتسجيل والملف الشخصي',
                          style: GoogleFonts.cairo(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Current numbers list
              if (_whatsappNumbers.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'لم يتم تحديد أي رقم واتساب حتى الآن',
                    style: GoogleFonts.cairo(fontSize: 13, color: AppColors.textMuted),
                  ),
                )
              else
                ..._whatsappNumbers.asMap().entries.map((entry) {
                  final index = entry.key;
                  final phone = entry.value;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.shadowDark.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.phone_android_rounded,
                          size: 18,
                          color: AppColors.statusOnline,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            phone,
                            textDirection: TextDirection.ltr,
                            style: GoogleFonts.cairo(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDark,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline_rounded,
                              color: AppColors.statusOffline, size: 20),
                          tooltip: 'حذف الرقم',
                          onPressed: () {
                            if (_whatsappNumbers.length <= 1) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'يجب الإبقاء على رقم واتساب واحد على الأقل',
                                    style: GoogleFonts.cairo(),
                                  ),
                                  backgroundColor: AppColors.statusOffline,
                                ),
                              );
                              return;
                            }
                            setState(() {
                              _whatsappNumbers.removeAt(index);
                            });
                          },
                        ),
                      ],
                    ),
                  );
                }),
              const SizedBox(height: 12),
              // Add new phone row
              Row(
                children: [
                  Expanded(
                    child: NeumorphicTextField(
                      label: 'رقم واتساب جديد',
                      controller: _newPhoneController,
                      hintText: '0115715672',
                      prefixIcon: const Icon(Icons.add_call),
                      keyboardType: TextInputType.phone,
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: () {
                      final newPhone = _newPhoneController.text.trim();
                      if (newPhone.isEmpty) return;
                      if (_whatsappNumbers.contains(newPhone)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('الرقم مضاف بالفعل', style: GoogleFonts.cairo()),
                            backgroundColor: AppColors.statusOffline,
                          ),
                        );
                        return;
                      }
                      setState(() {
                        _whatsappNumbers.add(newPhone);
                        _newPhoneController.clear();
                      });
                    },
                    icon: const Icon(Icons.add, size: 18),
                    label: Text('إضافة', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.statusOnline,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Brand Palette Overview Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.pageBg,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: AppColors.shadowLight,
                offset: Offset(-3, -3),
                blurRadius: 8,
              ),
              BoxShadow(
                color: AppColors.shadowDark,
                offset: Offset(3, 3),
                blurRadius: 8,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.accentYellow.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.palette_outlined,
                      color: Color(0xFFD97706),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'ألوان الهوية المخزنة بالنظام',
                    style: GoogleFonts.cairo(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'اللون الأساسي: ${AppSettings.instance.primaryColorHex ?? "#3B2FA0"} • اللون الثانوي: ${AppSettings.instance.accentColorHex ?? "#F5C94B"} (محفوظة بقاعدة البيانات)',
                style: GoogleFonts.cairo(
                  fontSize: 12,
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),

        // Save Settings Action Button
        PressableNeumorphicCard(
          onTap: _isSavingSettings ? null : _saveSettings,
          backgroundColor: AppColors.heroGradientStart,
          borderRadius: BorderRadius.circular(16),
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Center(
            child: _isSavingSettings
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.save_rounded, color: Colors.white, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        'حفظ الإعدادات العامة',
                        style: GoogleFonts.cairo(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Future<void> _saveSettings() async {
    final email = _supportEmailController.text.trim();
    final name = _appNameController.text.trim();

    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('يرجى إدخال بريد إلكتروني صحيح', style: GoogleFonts.cairo()),
          backgroundColor: AppColors.statusOffline,
        ),
      );
      return;
    }

    if (_whatsappNumbers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('يجب توفير رقم واتساب واحد على الأقل', style: GoogleFonts.cairo()),
          backgroundColor: AppColors.statusOffline,
        ),
      );
      return;
    }

    setState(() {
      _isSavingSettings = true;
      _settingsError = null;
    });

    final res = await ApiClient.updateAdminSettings(
      supportEmail: email,
      whatsappNumbers: _whatsappNumbers,
      appName: name.isNotEmpty ? name : 'جلسة',
    );

    if (!mounted) return;

    if (res['success'] == true) {
      final updated = res['data'] as PlatformSettingsModel;
      AppSettings.instance.updateLocally(updated);
      setState(() {
        _isSavingSettings = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            res['message'] as String? ?? 'تم حفظ الإعدادات بنجاح',
            style: GoogleFonts.cairo(fontWeight: FontWeight.w600),
          ),
          backgroundColor: AppColors.statusOnline,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      setState(() {
        _isSavingSettings = false;
        _settingsError = res['errorMessage'] as String? ?? 'فشل حفظ الإعدادات';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_settingsError!, style: GoogleFonts.cairo()),
          backgroundColor: AppColors.statusOffline,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showSendNotificationDialog() {
    final titleController = TextEditingController();
    final bodyController = TextEditingController();
    String? selectedTenantId;
    bool isSending = false;
    String? dialogError;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.pageBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(modalContext).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.heroGradientStart.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.campaign_rounded,
                            color: AppColors.heroGradientStart,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'إرسال إشعار للعملاء',
                                style: GoogleFonts.cairo(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textDark,
                                ),
                              ),
                              Text(
                                'يمكنك بث إشعار عام للجميع أو لشركة محددة',
                                style: GoogleFonts.cairo(
                                  fontSize: 12,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.of(modalContext).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    if (dialogError != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.statusOffline.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.statusOffline.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          dialogError!,
                          style: GoogleFonts.cairo(
                            color: AppColors.statusOffline,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    Text(
                      'الجهة المستهدفة',
                      style: GoogleFonts.cairo(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppColors.shadowDark.withValues(alpha: 0.35),
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String?>(
                          value: selectedTenantId,
                          isExpanded: true,
                          items: [
                            DropdownMenuItem<String?>(
                              value: null,
                              child: Text(
                                '📢 بث لجميع الشركات والشبكات',
                                style: GoogleFonts.cairo(fontWeight: FontWeight.w700),
                              ),
                            ),
                            ..._tenants.map(
                              (t) => DropdownMenuItem<String?>(
                                value: t.id,
                                child: Text(
                                  '🏢 ${t.name}',
                                  style: GoogleFonts.cairo(fontSize: 13),
                                ),
                              ),
                            ),
                          ],
                          onChanged: (val) {
                            setModalState(() {
                              selectedTenantId = val;
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    NeumorphicTextField(
                      label: 'عنوان الإشعار',
                      controller: titleController,
                      hintText: 'مثال: تحديث أمني هام',
                      prefixIcon: const Icon(Icons.title_rounded),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'نص الإشعار',
                      style: GoogleFonts.cairo(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: bodyController,
                      maxLines: 4,
                      style: GoogleFonts.cairo(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'اكتب نص الإشعار هنا بالتفصيل...',
                        hintStyle: GoogleFonts.cairo(color: AppColors.textMuted, fontSize: 13),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: AppColors.shadowDark.withValues(alpha: 0.35),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: AppColors.shadowDark.withValues(alpha: 0.35),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    PressableNeumorphicCard(
                      onTap: isSending
                          ? null
                          : () async {
                              final t = titleController.text.trim();
                              final b = bodyController.text.trim();
                              if (t.isEmpty || b.isEmpty) {
                                setModalState(() {
                                  dialogError = 'يرجى إدخال عنوان ونص الإشعار';
                                });
                                return;
                              }

                              setModalState(() {
                                isSending = true;
                                dialogError = null;
                              });

                              final res = await ApiClient.sendAdminNotification(
                                title: t,
                                body: b,
                                tenantId: selectedTenantId,
                              );

                              if (res['success'] == true) {
                                if (!mounted) return;
                                if (modalContext.mounted) {
                                  Navigator.of(modalContext).pop();
                                }
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      res['message'] as String? ?? 'تم إرسال الإشعار بنجاح',
                                      style: GoogleFonts.cairo(fontWeight: FontWeight.w700),
                                    ),
                                    backgroundColor: AppColors.statusOnline,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              } else {
                                setModalState(() {
                                  isSending = false;
                                  dialogError =
                                      res['errorMessage'] as String? ?? 'فشل إرسال الإشعار';
                                });
                              }
                            },
                      backgroundColor: AppColors.heroGradientStart,
                      borderRadius: BorderRadius.circular(16),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: isSending
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'إرسال الإشعار الآن',
                                    style: GoogleFonts.cairo(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _TenantUsersSheet extends StatefulWidget {
  final AdminTenantModel tenant;
  final VoidCallback onRoleChanged;

  const _TenantUsersSheet({
    required this.tenant,
    required this.onRoleChanged,
  });

  @override
  State<_TenantUsersSheet> createState() => _TenantUsersSheetState();
}

class _TenantUsersSheetState extends State<_TenantUsersSheet> {
  bool _isLoading = true;
  String? _error;
  String? _updatingUserId;
  List<StaffUserModel> _users = [];

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final res = await ApiClient.getAdminTenantUsers(widget.tenant.id);
    if (!mounted) return;

    if (res['success'] == true) {
      setState(() {
        _users = res['data'] as List<StaffUserModel>;
        _isLoading = false;
      });
    } else {
      setState(() {
        _error = res['errorMessage'] as String? ?? 'فشل جلب المستخدمين';
        _isLoading = false;
      });
    }
  }

  Future<void> _changeRole(StaffUserModel user, String newRole) async {
    setState(() => _updatingUserId = user.id);
    try {
      final res = await ApiClient.updateUserRole(userId: user.id, role: newRole);
      if (!mounted) return;

      if (res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.statusOnline,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Text('تم تحديث دور المستخدم بنجاح', style: GoogleFonts.cairo(fontWeight: FontWeight.w600)),
          ),
        );
        widget.onRoleChanged();
        await _loadUsers();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.statusOffline,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Text(res['errorMessage'] ?? 'فشل تحديث الدور', style: GoogleFonts.cairo(fontWeight: FontWeight.w600)),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _updatingUserId = null);
      }
    }
  }

  void _showRolePicker(StaffUserModel user) {
    const roles = [
      {'key': 'TENANT_ADMIN', 'name': 'مدير (TENANT_ADMIN)'},
      {'key': 'OPERATOR', 'name': 'مشغّل (OPERATOR)'},
      {'key': 'RESELLER', 'name': 'وكيل بيع (RESELLER)'},
      {'key': 'ACCOUNTANT', 'name': 'محاسب (ACCOUNTANT)'},
      {'key': 'SUPER_ADMIN', 'name': 'مدير عام (SUPER_ADMIN)'},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.pageBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'تغيير دور: ${user.fullName}',
                style: GoogleFonts.cairo(fontWeight: FontWeight.w800, fontSize: 16),
              ),
              const SizedBox(height: 12),
              ...roles.map((r) {
                final isCurrent = user.role == r['key'];
                return ListTile(
                  title: Text(r['name']!, style: GoogleFonts.cairo(fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600)),
                  trailing: isCurrent ? const Icon(Icons.check_circle_rounded, color: AppColors.statusOnline) : null,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  tileColor: isCurrent ? AppColors.heroGradientStart.withValues(alpha: 0.08) : null,
                  onTap: () {
                    Navigator.of(ctx).pop();
                    if (!isCurrent) {
                      _changeRole(user, r['key']!);
                    }
                  },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.75,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.heroGradientStart.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.manage_accounts_rounded, color: AppColors.heroGradientStart, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'مستخدمو: ${widget.tenant.name}',
                        style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textDark),
                      ),
                      Text(
                        'إدارة صلاحيات وأدوار الموظفين',
                        style: GoogleFonts.cairo(fontSize: 12, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(_error!, style: GoogleFonts.cairo(color: AppColors.statusOffline)),
                              const SizedBox(height: 8),
                              ElevatedButton(onPressed: _loadUsers, child: Text('إعادة المحاولة', style: GoogleFonts.cairo())),
                            ],
                          ),
                        )
                      : _users.isEmpty
                          ? Center(child: Text('لا يوجد مستخدمين مسجلين', style: GoogleFonts.cairo(color: AppColors.textMuted)))
                          : ListView.separated(
                              itemCount: _users.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 10),
                              itemBuilder: (ctx, index) {
                                final user = _users[index];
                                return Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.pageBg,
                                    borderRadius: BorderRadius.circular(14),
                                    boxShadow: [
                                      const BoxShadow(
                                        color: AppColors.shadowLight,
                                        offset: Offset(-2, -2),
                                        blurRadius: 4,
                                      ),
                                      BoxShadow(
                                        color: AppColors.shadowDark.withValues(alpha: 0.3),
                                        offset: const Offset(2, 2),
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: user.roleColor.withValues(alpha: 0.15),
                                        child: Icon(user.roleIcon, color: user.roleColor, size: 20),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              user.fullName,
                                              style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.w700),
                                            ),
                                            Text(
                                              '@${user.username} ${user.email != null ? "• ${user.email}" : ""}',
                                              style: GoogleFonts.cairo(fontSize: 11, color: AppColors.textMuted),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Builder(
                                        builder: (context) {
                                          final isUpdating = _updatingUserId == user.id;
                                          return InkWell(
                                            onTap: isUpdating ? null : () => _showRolePicker(user),
                                            borderRadius: BorderRadius.circular(8),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                              decoration: BoxDecoration(
                                                color: user.roleColor.withValues(alpha: 0.12),
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: user.roleColor.withValues(alpha: 0.4)),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  if (isUpdating) ...[
                                                    SizedBox(
                                                      width: 12,
                                                      height: 12,
                                                      child: CircularProgressIndicator(strokeWidth: 2, color: user.roleColor),
                                                    ),
                                                    const SizedBox(width: 6),
                                                  ],
                                                  Text(
                                                    user.roleArabic,
                                                    style: GoogleFonts.cairo(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w700,
                                                      color: user.roleColor,
                                                    ),
                                                  ),
                                                  if (!isUpdating) ...[
                                                    const SizedBox(width: 4),
                                                    Icon(Icons.edit_rounded, size: 14, color: user.roleColor),
                                                  ],
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double height;

  _SliverTabBarDelegate(this.child, {this.height = 64.0});

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) => true;
}
