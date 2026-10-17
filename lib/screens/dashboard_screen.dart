// ============================================================================
// Platform: Commercial MikroTik Network & HotSpot Card Management System
// File: lib/screens/dashboard_screen.dart
// Screen: Main Operations Dashboard with Real Backend Data & 4 States
// Master Reference: Rule 18 (API Only), Rule 21 (Real Data), Rule 35 (States), Rule 23 (Errors)
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/router_model.dart';
import '../models/subscription_status_model.dart';
import '../services/api_client.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/app_error_state.dart';
import '../widgets/app_loading_state.dart';
import '../widgets/count_up_text.dart';
import '../widgets/neumorphic_text_field.dart';
import '../widgets/pressable_neumorphic_card.dart';
import '../widgets/pulsing_dot.dart';
import 'add_router_screen.dart';
import 'cards_list_screen.dart';
import 'generate_cards_screen.dart';
import 'packages_screen.dart';
import 'sales_report_screen.dart';
import 'staff_screen.dart';
import 'temp_login_screen.dart';
import 'user_profile_screen.dart';
import 'notifications_screen.dart';
import '../services/app_settings.dart';
import '../utils/whatsapp_helper.dart';

class DashboardScreen extends StatefulWidget {
  final String userName;

  const DashboardScreen({
    super.key,
    this.userName = 'المدير',
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<RouterModel> _routers = [];
  bool _isLoading = true;
  String? _errorMessage;
  int _buttonShakeCounter = 0;
  double _todaySalesTotal = 0.0;
  bool _isLoadingSales = true;
  bool _isRedirectingToLogin = false;
  SubscriptionStatusModel? _subscriptionStatus;
  int _unreadNotificationsCount = 0;

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

  @override
  void initState() {
    super.initState();
    _loadRouters();
    _loadTodaySales();
    _loadSubscriptionStatus();
    _loadNotificationsCount();
  }

  Future<void> _loadNotificationsCount() async {
    try {
      final result = await ApiClient.getNotifications();
      if (!mounted) return;
      if (result['success'] == true) {
        setState(() {
          _unreadNotificationsCount = result['unreadCount'] as int? ?? 0;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadSubscriptionStatus() async {
    try {
      final result = await ApiClient.getSubscriptionStatus();

      if (!mounted) return;

      if (result['errorCode'] == 'UNAUTHORIZED') {
        _handleUnauthorized();
        return;
      }

      if (result['success'] == true &&
          result['data'] is SubscriptionStatusModel) {
        setState(() {
          _subscriptionStatus = result['data'] as SubscriptionStatusModel;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadTodaySales() async {
    setState(() {
      _isLoadingSales = true;
    });

    try {
      final result = await ApiClient.getTodaySalesTotal();

      if (!mounted) return;

      if (result['errorCode'] == 'UNAUTHORIZED') {
        _handleUnauthorized();
        return;
      }

      if (result['success'] == true &&
          result['data'] != null &&
          result['data'] is Map<String, dynamic>) {
        final dataMap = result['data'] as Map<String, dynamic>;
        final raw = dataMap['todayTotal'] ?? dataMap['totalAmount'] ?? 0;
        setState(() {
          _todaySalesTotal = (raw is num) ? raw.toDouble() : 0.0;
          _isLoadingSales = false;
        });
      } else {
        setState(() {
          _isLoadingSales = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingSales = false;
        });
      }
    }
  }

  Future<void> _loadRouters() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await ApiClient.getRouters();

    if (!mounted) return;

    if (result['errorCode'] == 'UNAUTHORIZED') {
      _handleUnauthorized();
      return;
    }

    if (result['errorCode'] == 'SUBSCRIPTION_EXPIRED' ||
        result['errorCode'] == 'SUBSCRIPTION_SUSPENDED') {
      setState(() {
        _subscriptionStatus = const SubscriptionStatusModel(
          subscriptionStatus: 'EXPIRED',
          daysRemaining: 0,
          currentRoutersCount: 0,
          maxRoutersLimit: 0,
        );
        _isLoading = false;
      });
      return;
    }

    if (result['success'] == true) {
      setState(() {
        _routers = (result['data'] as List<dynamic>).cast<RouterModel>();
        _isLoading = false;
        _errorMessage = null;
      });
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage =
            result['errorMessage'] ?? 'تعذر الاتصال بالخادم لجلب قائمة الراوترات';
      });
    }
  }

  Future<void> _navigateToAddRouter() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => const AddRouterScreen(),
      ),
    );

    if (result == true) {
      _loadRouters();
    }
  }

  Future<void> _confirmDeleteRouter(RouterModel router) async {
    final confirmed = await showDialog<bool>(
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
                'تأكيد حذف الراوتر',
                style: GoogleFonts.cairo(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
          content: Text(
            'هل أنت متأكد من حذف راوتر "${router.name}" (${router.host})؟\nهذه العملية نهائية ولا يمكن التراجع عنها.',
            style: GoogleFonts.cairo(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(false),
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
              onPressed: () => Navigator.of(dialogCtx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.statusOffline,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: Text(
                'نعم، حذف',
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

    if (confirmed == true) {
      _deleteRouter(router);
    }
  }

  Future<void> _deleteRouter(RouterModel router) async {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
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
              'جارٍ حذف الراوتر...',
              style: GoogleFonts.cairo(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );

    final result = await ApiClient.deleteRouter(router.id);

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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'تم حذف راوتر "${router.name}" بنجاح',
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
      _loadRouters();
    } else {
      final err = result['errorMessage'] ?? 'فشل حذف الراوتر';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.statusOffline,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  err,
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
    }
  }

  void _onGenerateCardsPressed() {
    setState(() {
      _buttonShakeCounter++;
    });

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const GenerateCardsScreen(),
      ),
    );
  }

  void _onRouterCardTapped(RouterModel router) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.textDark,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Text(
          'تم اختيار: ${router.name} (${router.isOnline ? "متصل" : "غير متصل"})',
          style: GoogleFonts.cairo(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_subscriptionStatus != null &&
        (_subscriptionStatus!.isExpired || _subscriptionStatus!.isSuspended)) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: AppColors.pageBg,
          body: _buildExpiredSubscriptionView(),
        ),
      );
    }

    final int onlineCount = _routers.where((r) => r.isOnline).length;
    final int totalCount = _routers.length;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.pageBg,
        body: Column(
          children: [
            // Top Hero Banner
            _buildTopBanner(context, onlineCount: onlineCount, totalCount: totalCount),

            // Subscription Alert Strip (TRIAL only)
            if (_subscriptionStatus != null && _subscriptionStatus!.isTrial)
              _buildTrialBannerStrip(_subscriptionStatus!),

            // Router List Header & List Content with Pull-To-Refresh
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  await Future.wait([
                    _loadRouters(),
                    _loadTodaySales(),
                    _loadSubscriptionStatus(),
                  ]);
                },
                color: AppColors.heroGradientStart,
                backgroundColor: AppColors.pageBg,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  children: [
                    // Section Header
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14, right: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'أجهزة الراوتر والشبكات',
                              style: GoogleFonts.cairo(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textDark,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Count Badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.shadowDark.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$totalCount راوترات مسجلة',
                              style: GoogleFonts.cairo(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Add Router Button in Header
                          InkWell(
                            onTap: _navigateToAddRouter,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.heroGradientStart.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.heroGradientStart.withValues(alpha: 0.25),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.add_rounded,
                                    size: 16,
                                    color: AppColors.heroGradientStart,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'إضافة راوتر',
                                    style: GoogleFonts.cairo(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.heroGradientStart,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // State-driven Content (Loading / Error / Empty / Data)
                    _buildStateContent(),
                  ],
                ),
              ),
            ),

            // Bottom Action Area: "توليد كروت جديدة"
            _buildBottomActionBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildStateContent() {
    // 1. Loading State
    if (_isLoading) {
      return const AppLoadingState(
        message: 'جارٍ جلب بيانات الراوترات...',
      );
    }

    // 2. Error State
    if (_errorMessage != null) {
      return AppErrorState(
        title: 'فشل الاتصال بالخادم',
        errorMessage: _errorMessage!,
        onRetry: _loadRouters,
      );
    }

    // 3. Empty State
    if (_routers.isEmpty) {
      return AppEmptyState(
        icon: Icons.router_outlined,
        title: 'لا توجد راوترات مسجلة بعد',
        description:
            'ابدأ بإضافة أول راوتر مايكروتك للتحكم به وإدارة كروت الهوتسبوت.',
        actionLabel: 'إضافة راوتر',
        actionIcon: Icons.add_circle_outline_rounded,
        onAction: _navigateToAddRouter,
      );
    }

    // 4. Data State
    return Column(
      children: List.generate(_routers.length, (index) {
        final router = _routers[index];
        return _buildRouterCard(router, index);
      }),
    );
  }


  Widget _buildBannerNavButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    int? badgeCount,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.25),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, color: Colors.white, size: 16),
                if (badgeCount != null && badgeCount > 0)
                  Positioned(
                    top: -6,
                    right: -7,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.accentYellow,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 15,
                        minHeight: 15,
                      ),
                      child: Text(
                        badgeCount > 9 ? '9+' : '$badgeCount',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.cairo(
                          color: AppColors.textDark,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          height: 1.1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.cairo(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBanner(
    BuildContext context, {
    required int onlineCount,
    required int totalCount,
  }) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.heroGradientStart,
            AppColors.heroGradientMiddle,
            AppColors.heroGradientEnd,
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(24),
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
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. User Greeting Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'مساء الخير 👋',
                          style: GoogleFonts.cairo(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                        Text(
                          widget.userName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.cairo(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.22),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                color: AppColors.statusOnline,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'نظام متصل',
                              style: GoogleFonts.cairo(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withValues(alpha: 0.9),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => UserProfileScreen(
                                  initialFullName: widget.userName,
                                ),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.35),
                                width: 1.2,
                              ),
                            ),
                            child: const Icon(
                              Icons.person_rounded,
                              size: 17,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // 2. Action Buttons Row (الموظفون / الترخيص / الكروت / الباقات / الإشعارات)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    if (ApiClient.isAdmin) ...[
                      _buildBannerNavButton(
                        icon: Icons.vpn_key_outlined,
                        label: 'الترخيص',
                        onTap: _showRedeemLicenseDialog,
                      ),
                      const SizedBox(width: 8),
                      _buildBannerNavButton(
                        icon: Icons.group_outlined,
                        label: 'الموظفون',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const StaffScreen(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                    ],
                    _buildBannerNavButton(
                      icon: Icons.credit_card_rounded,
                      label: 'الكروت',
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const CardsListScreen(),
                          ),
                        );
                        _loadTodaySales();
                      },
                    ),
                    const SizedBox(width: 8),
                    _buildBannerNavButton(
                      icon: Icons.inventory_2_outlined,
                      label: 'الباقات',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const PackagesScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    _buildBannerNavButton(
                      icon: Icons.notifications_none_rounded,
                      label: 'الإشعارات',
                      badgeCount: _unreadNotificationsCount,
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const NotificationsScreen(),
                          ),
                        );
                        _loadNotificationsCount();
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // 3. Two Stats Cards (Real Device Status + Today's Sales)
              Row(
                children: [
                  // Stat Card 1: Online Status (REAL DATA)
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.25),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: onlineCount > 0
                                        ? AppColors.statusOnline
                                        : AppColors.statusOffline,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: (onlineCount > 0
                                                ? AppColors.statusOnline
                                                : AppColors.statusOffline)
                                            .withValues(alpha: 0.5),
                                        blurRadius: 4,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'حالة الأجهزة',
                                  style: GoogleFonts.cairo(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white.withValues(alpha: 0.95),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  'Online ',
                                  style: GoogleFonts.cairo(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.accentYellow,
                                  ),
                                ),
                                CountUpText(
                                  targetValue: onlineCount,
                                  suffix: '/$totalCount',
                                  style: GoogleFonts.cairo(
                                    fontSize: 18,
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
                  const SizedBox(width: 10),

                  // Stat Card 2: مبيعات اليوم (قابل للنقر لفتح تقارير المبيعات)
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const SalesReportScreen(),
                          ),
                        );
                        _loadTodaySales();
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.25),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.payments_outlined,
                                      size: 13,
                                      color: Colors.white.withValues(alpha: 0.95),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      'مبيعات اليوم',
                                      style: GoogleFonts.cairo(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white.withValues(alpha: 0.95),
                                      ),
                                    ),
                                  ],
                                ),
                                Icon(
                                  Icons.arrow_back_ios_new_rounded,
                                  size: 10,
                                  color: Colors.white.withValues(alpha: 0.7),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),

                            if (_isLoadingSales)
                              const SizedBox(
                                height: 26,
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        AppColors.accentYellow,
                                      ),
                                    ),
                                  ),
                                ),
                              )
                            else
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerRight,
                                child: CountUpText(
                                  targetValue: _todaySalesTotal.round(),
                                  suffix: ' جنيه سوداني',
                                  formatter: (val) {
                                    final formatted = val.toString().replaceAllMapped(
                                      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                                      (Match m) => '${m[1]},',
                                    );
                                    return '$formatted جنيه سوداني';
                                  },
                                  style: GoogleFonts.cairo(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.accentYellow,
                                  ),
                                ),
                              ),
                          ],
                        ),
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


  Widget _buildTrialBannerStrip(SubscriptionStatusModel status) {
    final bool isCritical = status.daysRemaining <= 2;
    final Color alertBg = isCritical
        ? const Color(0xFFEF4444).withValues(alpha: 0.12)
        : AppColors.heroGradientStart.withValues(alpha: 0.10);
    final Color alertBorder = isCritical
        ? const Color(0xFFEF4444).withValues(alpha: 0.38)
        : AppColors.heroGradientStart.withValues(alpha: 0.25);
    final Color alertTextColor = isCritical
        ? const Color(0xFFDC2626)
        : AppColors.heroGradientStart;
    final IconData alertIcon = isCritical
        ? Icons.warning_amber_rounded
        : Icons.timer_outlined;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 10, 20, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: alertBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: alertBorder, width: 1),
      ),
      child: Row(
        children: [
          Icon(
            alertIcon,
            size: 19,
            color: alertTextColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'باقي ${status.daysRemaining} أيام من فترتك التجريبية',
              style: GoogleFonts.cairo(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: alertTextColor,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: alertTextColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'فترة تجريبية',
              style: GoogleFonts.cairo(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: alertTextColor,
              ),
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: _showRedeemLicenseDialog,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.heroGradientStart,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.heroGradientStart.withValues(alpha: 0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.vpn_key_rounded, size: 12, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(
                    'تفعيل كود',
                    style: GoogleFonts.cairo(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }


  void _showRedeemLicenseDialog() {
    final codeController = TextEditingController();
    bool isSubmitting = false;
    String? dialogError;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: AlertDialog(
                backgroundColor: AppColors.pageBg,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                ),
                title: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.heroGradientStart.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.vpn_key_rounded,
                        color: AppColors.heroGradientStart,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'تفعيل كود ترخيص',
                        style: GoogleFonts.cairo(
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                        ),
                      ),
                    ),
                  ],
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'أدخل كود الترخيص المكون من 12 خانة (مثال: XXXX-XXXX-XXXX) لتفعيل أو تمديد اشتراك شبكتك:',
                        style: GoogleFonts.cairo(
                          fontSize: 13,
                          color: AppColors.textMuted,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (dialogError != null) ...[
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.statusOffline.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppColors.statusOffline.withValues(alpha: 0.3),
                            ),
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
                                    fontSize: 12.5,
                                    color: AppColors.statusOffline,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],
                      NeumorphicTextField(
                        label: 'كود الترخيص (License Code)',
                        hintText: 'XXXX-XXXX-XXXX',
                        controller: codeController,
                        prefixIcon: const Icon(
                          Icons.pin_rounded,
                          color: AppColors.textMuted,
                          size: 20,
                        ),
                        onChanged: (val) {
                          if (dialogError != null) {
                            setDialogState(() => dialogError = null);
                          }
                        },
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: isSubmitting
                        ? null
                        : () => Navigator.of(ctx).pop(),
                    child: Text(
                      'إلغاء',
                      style: GoogleFonts.cairo(
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.heroGradientStart,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                    ),
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            final code = codeController.text.trim();
                            if (code.isEmpty) {
                              setDialogState(
                                () => dialogError = 'يرجى إدخال كود الترخيص',
                              );
                              return;
                            }

                            setDialogState(() {
                              isSubmitting = true;
                              dialogError = null;
                            });

                            final result =
                                await ApiClient.redeemLicenseCode(code);
                            if (!mounted) return;

                            if (result['success'] == true) {
                              Navigator.of(ctx).pop();
                              await _loadSubscriptionStatus();
                              await Future.wait([
                                _loadRouters(),
                                _loadTodaySales(),
                              ]);
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: AppColors.statusOnline,
                                  behavior: SnackBarBehavior.floating,
                                  duration: const Duration(seconds: 4),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  content: Row(
                                    children: [
                                      const Icon(Icons.check_circle_rounded,
                                          color: Colors.white),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          result['message'] ??
                                              'تم تفعيل كود الترخيص بنجاح!',
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
                            } else {
                              setDialogState(() {
                                isSubmitting = false;
                                dialogError = result['errorMessage'] as String? ??
                                    'تعذر تفعيل كود الترخيص';
                              });
                            }
                          },
                    child: isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'تفعيل الترخيص',
                            style: GoogleFonts.cairo(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildExpiredSubscriptionView() {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 90,
                height: 90,
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
                      color: AppColors.shadowDark.withValues(alpha: 0.7),
                      offset: const Offset(5, 5),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.lock_clock_rounded,
                    size: 46,
                    color: AppColors.statusOffline,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'انتهت فترتك التجريبية',
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'لقد انتهت فترة الـ 7 أيام التجريبية لنظام إدارة الشبكات والكروت. للاستمرار في استخدام النظام وتفعيل اشتراكك، يمكنك تفعيل كود ترخيص أو التواصل مع فريق الدعم.',
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textMuted,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),

              // خيار تفعيل كود ترخيص (بديل للتواصل مع الدعم)
              PressableNeumorphicCard(
                onTap: _showRedeemLicenseDialog,
                backgroundColor: AppColors.accentYellow,
                borderRadius: BorderRadius.circular(18),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.textDark.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.vpn_key_rounded,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'تفعيل كود ترخيص',
                            style: GoogleFonts.cairo(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'لديك كود ترخيص؟ اضغط هنا لإدخاله وتفعيل حسابك فوراً',
                            style: GoogleFonts.cairo(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textDark.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 16,
                      color: AppColors.textDark,
                    ),
                  ],
                ),
              ),
              buildWhatsAppSupportCard(
                context: context,
                title: 'تواصل للاشتراك وتفعيل الباقات (SOFT ZONE)',
                subtitle: 'تواصل عبر واتساب لتفعيل اشتراك شبكتك فوراً',
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: () async {
                  await _loadSubscriptionStatus();
                  if (mounted && _subscriptionStatus != null && !_subscriptionStatus!.isExpired) {
                    _loadRouters();
                    _loadTodaySales();
                  }
                },
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(
                  'التحقق من حالة الاشتراك',
                  style: GoogleFonts.cairo(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.heroGradientStart,
                  side: const BorderSide(color: AppColors.heroGradientStart, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () async {
                  await ApiClient.logout();
                  if (!mounted) return;
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const TempLoginScreen()),
                    (route) => false,
                  );
                },
                icon: const Icon(Icons.logout_rounded, size: 16),
                label: Text(
                  'تسجيل الخروج',
                  style: GoogleFonts.cairo(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRouterCard(RouterModel router, int index) {
    final bool hasBoardModel =
        router.boardModel != null && router.boardModel!.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PressableNeumorphicCard(
        onTap: () => _onRouterCardTapped(router),
        borderRadius: BorderRadius.circular(18),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            // Status Pulsing Dot (Online green, else red)
            PulsingDot(
              color: router.isOnline
                  ? AppColors.statusOnline
                  : AppColors.statusOffline,
              size: 13,
            ),
            const SizedBox(width: 14),

            // Router Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    router.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.cairo(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (hasBoardModel) ...[
                        Flexible(
                          child: Text(
                            router.boardModel!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.cairo(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 3,
                          height: 3,
                          decoration: const BoxDecoration(
                            color: AppColors.textMuted,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Flexible(
                        child: Text(
                          router.host,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.cairo(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // Status Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: router.isOnline
                    ? AppColors.statusOnline.withValues(alpha: 0.12)
                    : AppColors.statusOffline.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: router.isOnline
                      ? AppColors.statusOnline.withValues(alpha: 0.25)
                      : AppColors.statusOffline.withValues(alpha: 0.20),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    router.isOnline
                        ? Icons.wifi_rounded
                        : Icons.wifi_off_rounded,
                    size: 14,
                    color: router.isOnline
                        ? AppColors.statusOnline
                        : AppColors.statusOffline,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    router.isOnline ? 'متصل' : 'غير متصل',
                    style: GoogleFonts.cairo(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: router.isOnline
                          ? AppColors.statusOnline
                          : AppColors.statusOffline,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // Delete Button with confirmation dialog
            IconButton(
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: AppColors.statusOffline,
                size: 20,
              ),
              tooltip: 'حذف الراوتر',
              splashRadius: 18,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(
                minWidth: 32,
                minHeight: 32,
              ),
              onPressed: () => _confirmDeleteRouter(router),
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(delay: (index * 60).ms)
        .slideY(begin: 0.08, duration: 220.ms);
  }


  Widget _buildBottomActionBar() {
    Widget button = PressableNeumorphicCard(
      onTap: _onGenerateCardsPressed,
      backgroundColor: AppColors.accentYellow,
      borderRadius: BorderRadius.circular(16),
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.add_card_rounded,
            color: AppColors.textDark,
            size: 21,
          ),
          const SizedBox(width: 8),
          Text(
            'توليد كروت جديدة',
            style: GoogleFonts.cairo(
              fontSize: 15.5,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );

    if (_buttonShakeCounter > 0) {
      button = button
          .animate(key: ValueKey(_buttonShakeCounter))
          .shake(duration: 200.ms);
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 14),
      decoration: BoxDecoration(
        color: AppColors.pageBg,
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowDark.withValues(alpha: 0.3),
            offset: const Offset(0, -4),
            blurRadius: 10,
          ),
        ],
      ),

      child: SafeArea(
        top: false,
        child: button,
      ),
    );
  }
}
