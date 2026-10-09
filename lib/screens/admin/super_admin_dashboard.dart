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
import '../../services/api_client.dart';
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
  String _codeFilter = 'ALL'; // ALL, UNUSED, USED

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    await Future.wait([
      _loadTenants(),
      _loadCodes(),
    ]);
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
          builder: (context, setModalState) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: Padding(
                padding: EdgeInsets.only(
                  left: 24,
                  right: 24,
                  top: 24,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 24,
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

              // Tab Bar
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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
                  ],
                ),
              ),

              // Tab Views
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildTenantsTab(),
                    _buildCodesTab(),
                  ],
                ),
              ),
            ],
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

    final filtered = _tenants.where((t) {
      if (_tenantSearchQuery.isEmpty) return true;
      final q = _tenantSearchQuery.toLowerCase();
      return t.name.toLowerCase().contains(q) || t.slug.toLowerCase().contains(q);
    }).toList();

    return RefreshIndicator(
      onRefresh: _loadTenants,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        children: [
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

  Widget _buildTenantCard(AdminTenantModel tenant) {
    Color statusColor;
    String statusText;

    if (tenant.isActive) {
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
      statusText = 'موقوف (${tenant.subscriptionStatus})';
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
}
