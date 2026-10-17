// ============================================================================
// Platform: Commercial MikroTik Network & HotSpot Card Management System
// File: lib/screens/packages_screen.dart
// Screen: Packages Management Screen with 4 States & Neumorphic Design
// Master Reference: Rule 18 (API Only), Rule 21 (Real Data), Rule 35 (States), Rule 23 (Errors)
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/package_model.dart';
import '../services/api_client.dart';
import '../theme/app_colors.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/app_error_state.dart';
import '../widgets/app_loading_state.dart';
import '../widgets/neumorphic_text_field.dart';
import '../widgets/pressable_neumorphic_card.dart';

class PackagesScreen extends StatefulWidget {
  const PackagesScreen({super.key});

  @override
  State<PackagesScreen> createState() => _PackagesScreenState();
}

class _PackagesScreenState extends State<PackagesScreen> {
  List<PackageModel> _packages = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadPackages();
  }

  Future<void> _loadPackages() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await ApiClient.getPackages();

    if (!mounted) return;

    if (result['success'] == true) {
      setState(() {
        _packages = (result['data'] as List<dynamic>).cast<PackageModel>();
        _isLoading = false;
        _errorMessage = null;
      });
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage =
            result['errorMessage'] ?? 'تعذر الاتصال بالخادم لجلب قائمة الباقات';
      });
    }
  }

  Future<void> _confirmDeletePackage(PackageModel package) async {
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
                'تأكيد حذف الباقة',
                style: GoogleFonts.cairo(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
          content: Text(
            'هل أنت متأكد من حذف باقة "${package.name}" (${package.code})؟\nهذه العملية نهائية ولا يمكن التراجع عنها.',
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
      _deletePackage(package);
    }
  }

  Future<void> _deletePackage(PackageModel package) async {
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
              'جارٍ حذف الباقة...',
              style: GoogleFonts.cairo(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );

    final result = await ApiClient.deletePackage(package.id);

    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.statusOnline,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'تم حذف باقة "${package.name}" بنجاح',
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
      _loadPackages();
    } else {
      final err = result['errorMessage'] ?? 'فشل حذف الباقة';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.statusOffline,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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

  void _openAddPackageModal() {
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AddPackageSheet(
          onPackageAdded: () {
            _loadPackages();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final int activeCount = _packages.where((p) => p.isActive).length;
    final int totalCount = _packages.length;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.pageBg,
        body: Column(
          children: [
            // Top Hero Banner
            _buildTopBanner(activeCount: activeCount, totalCount: totalCount),

            // Packages List Header & List Content with Pull-To-Refresh
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadPackages,
                color: AppColors.heroGradientStart,
                backgroundColor: AppColors.pageBg,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  children: [
                    // Section Header Row
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14, right: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'باقات الإنترنت المتوفرة',
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
                              color:
                                  AppColors.shadowDark.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$totalCount باقة مسجلة',
                              style: GoogleFonts.cairo(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Add Package Button in Header
                          InkWell(
                            onTap: _openAddPackageModal,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.heroGradientStart
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.heroGradientStart
                                      .withValues(alpha: 0.25),
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
                                    'إضافة باقة',
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
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Navigation and Title Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
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
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'إدارة الباقات',
                                style: GoogleFonts.cairo(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: 0.2,
                                ),
                              ),
                              Text(
                                'تعريف وتخصيص باقات الكروت والسرعات',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.cairo(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white.withValues(alpha: 0.85),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Add Package Quick Action Button
                  InkWell(
                    onTap: _openAddPackageModal,
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
                            color: Colors.black.withValues(alpha: 0.15),
                            offset: const Offset(0, 3),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.add_rounded,
                            color: AppColors.textDark,
                            size: 18,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'باقة جديدة',
                            style: GoogleFonts.cairo(
                              fontSize: 12.5,
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
              const SizedBox(height: 12),

              // Two Stats Cards
              Row(
                children: [
                  // Stat Card 1: Active Packages
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
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
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: AppColors.statusOnline,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'الباقات النشطة',
                                  style: GoogleFonts.cairo(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white.withValues(alpha: 0.9),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  '$activeCount',
                                  style: GoogleFonts.cairo(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  ' / $totalCount باقة',
                                  style: GoogleFonts.cairo(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white.withValues(alpha: 0.8),
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

                  // Stat Card 2: Hotspot Integration Info
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
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
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.tune_rounded,
                                  size: 14,
                                  color: AppColors.accentYellow,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  'بروفايلات الهوتسبوت',
                                  style: GoogleFonts.cairo(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white.withValues(alpha: 0.9),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Text(
                              'متوافقة مع MikroTik',
                              style: GoogleFonts.cairo(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.accentYellow,
                              ),
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

  Widget _buildStateContent() {
    // 1. Loading State
    if (_isLoading) {
      return const AppLoadingState(
        message: 'جارٍ جلب باقات الإنترنت...',
      );
    }

    // 2. Error State
    if (_errorMessage != null) {
      return AppErrorState(
        title: 'فشل الاتصال بالخادم',
        errorMessage: _errorMessage!,
        onRetry: _loadPackages,
      );
    }

    // 3. Empty State
    if (_packages.isEmpty) {
      return AppEmptyState(
        icon: Icons.inventory_2_outlined,
        title: 'لا توجد باقات مسجلة بعد',
        description: 'ابدأ بإضافة باقات الإنترنت وتحديد السرعات والأسعار.',
        actionLabel: 'إضافة باقة',
        actionIcon: Icons.add_circle_outline_rounded,
        onAction: _openAddPackageModal,
      );
    }

    // 4. Data State
    return Column(
      children: List.generate(_packages.length, (index) {
        final package = _packages[index];
        return _buildPackageCard(package, index);
      }),
    );
  }


  Widget _buildPackageCard(PackageModel package, int index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: PressableNeumorphicCard(
        borderRadius: BorderRadius.circular(20),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Name, Code, Active Badge, Delete Button
            Row(
              children: [
                // Package Name & Code
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              package.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.cairo(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textDark,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Code Badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.shadowDark.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              package.code,
                              style: GoogleFonts.cairo(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'بروفايل: ${package.hotspotProfileName}',
                        style: GoogleFonts.cairo(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),

                // Active / Inactive Badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: package.isActive
                        ? AppColors.statusOnline.withValues(alpha: 0.12)
                        : AppColors.statusOffline.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        package.isActive
                            ? Icons.check_circle_outline_rounded
                            : Icons.cancel_outlined,
                        size: 14,
                        color: package.isActive
                            ? AppColors.statusOnline
                            : AppColors.statusOffline,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        package.isActive ? 'نشطة' : 'غير نشطة',
                        style: GoogleFonts.cairo(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: package.isActive
                              ? AppColors.statusOnline
                              : AppColors.statusOffline,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 6),

                // Delete Button
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.statusOffline,
                    size: 20,
                  ),
                  tooltip: 'حذف الباقة',
                  splashRadius: 18,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  onPressed: () => _confirmDeletePackage(package),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Divider line
            Container(
              height: 1,
              color: AppColors.shadowDark.withValues(alpha: 0.35),
            ),

            const SizedBox(height: 12),

            // Row 2: Speed Limits, Duration, Price
            Row(
              children: [
                // Speed Limit
                Expanded(
                  flex: 4,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: AppColors.heroGradientStart
                              .withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.speed_rounded,
                          size: 16,
                          color: AppColors.heroGradientStart,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'السرعة',
                              style: GoogleFonts.cairo(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textMuted,
                              ),
                            ),
                            Text(
                              '${package.downloadSpeedLimit} / ${package.uploadSpeedLimit}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.cairo(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Duration & Validity
                Expanded(
                  flex: 3,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: AppColors.heroGradientStart
                              .withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.timer_outlined,
                          size: 16,
                          color: AppColors.heroGradientStart,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'المدة',
                              style: GoogleFonts.cairo(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textMuted,
                              ),
                            ),
                            Text(
                              package.formattedDuration,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.cairo(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Price
                Expanded(
                  flex: 3,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.accentYellow.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color:
                                AppColors.accentYellow.withValues(alpha: 0.5),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          package.formattedPrice,
                          style: GoogleFonts.cairo(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(delay: (index * 70).ms)
        .slideY(begin: 0.1, duration: 240.ms);
  }
}

// ============================================================================
// Add Package Modal Bottom Sheet
// ============================================================================

class AddPackageSheet extends StatefulWidget {
  final VoidCallback onPackageAdded;

  const AddPackageSheet({
    super.key,
    required this.onPackageAdded,
  });

  @override
  State<AddPackageSheet> createState() => _AddPackageSheetState();
}

class _AddPackageSheetState extends State<AddPackageSheet> {
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  final _downloadSpeedController = TextEditingController();
  final _uploadSpeedController = TextEditingController();
  final _durationMinutesController = TextEditingController();
  final _validityDaysController = TextEditingController(text: '1');
  final _priceController = TextEditingController();
  final _hotspotProfileController = TextEditingController();

  String? _nameError;
  String? _codeError;
  String? _downloadSpeedError;
  String? _uploadSpeedError;
  String? _durationMinutesError;
  String? _validityDaysError;
  String? _priceError;
  String? _hotspotProfileError;

  bool _isSaving = false;
  String? _serverErrorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _downloadSpeedController.dispose();
    _uploadSpeedController.dispose();
    _durationMinutesController.dispose();
    _validityDaysController.dispose();
    _priceController.dispose();
    _hotspotProfileController.dispose();
    super.dispose();
  }

  bool _validate() {
    bool isValid = true;
    setState(() {
      _nameError = null;
      _codeError = null;
      _downloadSpeedError = null;
      _uploadSpeedError = null;
      _durationMinutesError = null;
      _validityDaysError = null;
      _priceError = null;
      _hotspotProfileError = null;
      _serverErrorMessage = null;

      final name = _nameController.text.trim();
      if (name.isEmpty) {
        _nameError = 'يرجى إدخال اسم الباقة';
        isValid = false;
      }

      final code = _codeController.text.trim();
      if (code.isEmpty) {
        _codeError = 'يرجى إدخال كود الباقة';
        isValid = false;
      }

      final dl = _downloadSpeedController.text.trim();
      if (dl.isEmpty) {
        _downloadSpeedError = 'يرجى إدخال سرعة التحميل (مثال: 5M)';
        isValid = false;
      }

      final ul = _uploadSpeedController.text.trim();
      if (ul.isEmpty) {
        _uploadSpeedError = 'يرجى إدخال سرعة الرفع (مثال: 2M)';
        isValid = false;
      }

      final durationStr = _durationMinutesController.text.trim();
      final durationVal = int.tryParse(durationStr);
      if (durationStr.isEmpty) {
        _durationMinutesError = 'يرجى إدخال المدة بالدقائق';
        isValid = false;
      } else if (durationVal == null || durationVal <= 0) {
        _durationMinutesError = 'المدة يجب أن تكون رقماً موجباً بالدقائق';
        isValid = false;
      }

      final validityStr = _validityDaysController.text.trim();
      final validityVal = int.tryParse(validityStr);
      if (validityStr.isEmpty) {
        _validityDaysError = 'يرجى إدخال أيام الصلاحية';
        isValid = false;
      } else if (validityVal == null || validityVal <= 0) {
        _validityDaysError = 'أيام الصلاحية يجب أن تكون رقماً موجباً';
        isValid = false;
      }

      final priceStr = _priceController.text.trim();
      final priceVal = double.tryParse(priceStr);
      if (priceStr.isEmpty) {
        _priceError = 'يرجى إدخال سعر الباقة';
        isValid = false;
      } else if (priceVal == null || priceVal <= 0) {
        _priceError = 'السعر يجب أن يكون رقماً موجباً';
        isValid = false;
      }

      final profile = _hotspotProfileController.text.trim();
      if (profile.isEmpty) {
        _hotspotProfileError = 'يرجى إدخال اسم بروفايل الهوتسبوت';
        isValid = false;
      }
    });

    return isValid;
  }

  Future<void> _submit() async {
    if (_isSaving) return;

    if (!_validate()) return;

    setState(() {
      _isSaving = true;
      _serverErrorMessage = null;
    });

    final result = await ApiClient.createPackage(
      name: _nameController.text.trim(),
      code: _codeController.text.trim(),
      downloadSpeedLimit: _downloadSpeedController.text.trim(),
      uploadSpeedLimit: _uploadSpeedController.text.trim(),
      durationMinutes: int.parse(_durationMinutesController.text.trim()),
      validityDays: int.parse(_validityDaysController.text.trim()),
      price: double.parse(_priceController.text.trim()),
      hotspotProfileName: _hotspotProfileController.text.trim(),
    );

    if (!mounted) return;

    setState(() {
      _isSaving = false;
    });

    if (result['success'] == true) {
      Navigator.of(context).pop(true);
      widget.onPackageAdded();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.statusOnline,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white),
              const SizedBox(width: 10),
              Text(
                'تمت إضافة باقة "${_nameController.text.trim()}" بنجاح',
                style: GoogleFonts.cairo(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      final err = result['errorMessage'] ?? 'فشل إضافة الباقة';
      setState(() {
        _serverErrorMessage = err;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.statusOffline,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      margin: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: AppColors.pageBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Color(0x332B2A4C),
            offset: Offset(0, -6),
            blurRadius: 20,
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.shadowDark,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),

            // Header Row
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.heroGradientStart
                              .withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.add_card_rounded,
                          size: 20,
                          color: AppColors.heroGradientStart,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'إضافة باقة إنترنت جديدة',
                        style: GoogleFonts.cairo(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: AppColors.textMuted),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Form Fields List
            Flexible(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                children: [
                  // Server error banner
                  if (_serverErrorMessage != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.statusOffline.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
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
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _serverErrorMessage!,
                              style: GoogleFonts.cairo(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.statusOffline,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // 1. Name
                  NeumorphicTextField(
                    label: 'اسم الباقة',
                    hintText: 'مثال: يومية 5 ميجا',
                    controller: _nameController,
                    errorText: _nameError,
                    prefixIcon: const Icon(
                      Icons.label_outline_rounded,
                      color: AppColors.textMuted,
                      size: 20,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 2. Code
                  NeumorphicTextField(
                    label: 'كود الباقة الفريد',
                    hintText: 'مثال: PKG-DAILY-5M',
                    controller: _codeController,
                    errorText: _codeError,
                    textDirection: TextDirection.ltr,
                    prefixIcon: const Icon(
                      Icons.qr_code_rounded,
                      color: AppColors.textMuted,
                      size: 20,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 3 & 4. Speeds Row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: NeumorphicTextField(
                          label: 'سرعة التحميل (Download)',
                          hintText: 'مثال: 5M',
                          controller: _downloadSpeedController,
                          errorText: _downloadSpeedError,
                          textDirection: TextDirection.ltr,
                          prefixIcon: const Icon(
                            Icons.arrow_downward_rounded,
                            color: AppColors.textMuted,
                            size: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: NeumorphicTextField(
                          label: 'سرعة الرفع (Upload)',
                          hintText: 'مثال: 2M',
                          controller: _uploadSpeedController,
                          errorText: _uploadSpeedError,
                          textDirection: TextDirection.ltr,
                          prefixIcon: const Icon(
                            Icons.arrow_upward_rounded,
                            color: AppColors.textMuted,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // 5 & 6. Duration & Validity
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: NeumorphicTextField(
                          label: 'المدة بالدقائق',
                          hintText: 'مثال: 1440',
                          controller: _durationMinutesController,
                          errorText: _durationMinutesError,
                          keyboardType: TextInputType.number,
                          textDirection: TextDirection.ltr,
                          prefixIcon: const Icon(
                            Icons.schedule_rounded,
                            color: AppColors.textMuted,
                            size: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: NeumorphicTextField(
                          label: 'أيام الصلاحية',
                          hintText: 'مثال: 1',
                          controller: _validityDaysController,
                          errorText: _validityDaysError,
                          keyboardType: TextInputType.number,
                          textDirection: TextDirection.ltr,
                          prefixIcon: const Icon(
                            Icons.calendar_today_rounded,
                            color: AppColors.textMuted,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // 7. Price
                  NeumorphicTextField(
                    label: 'السعر (جنيه سوداني)',
                    hintText: 'مثال: 500',
                    controller: _priceController,
                    errorText: _priceError,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    textDirection: TextDirection.ltr,
                    prefixIcon: const Icon(
                      Icons.payments_outlined,
                      color: AppColors.textMuted,
                      size: 20,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 8. Hotspot Profile Name
                  NeumorphicTextField(
                    label: 'اسم بروفايل الهوتسبوت في MikroTik',
                    hintText: 'مثال: hs_daily_5m',
                    controller: _hotspotProfileController,
                    errorText: _hotspotProfileError,
                    textDirection: TextDirection.ltr,
                    textInputAction: TextInputAction.done,
                    prefixIcon: const Icon(
                      Icons.wifi_tethering_rounded,
                      color: AppColors.textMuted,
                      size: 20,
                    ),
                  ),
                  const SizedBox(height: 22),

                  // Submit Button
                  PressableNeumorphicCard(
                    onTap: _isSaving ? null : _submit,
                    backgroundColor: AppColors.accentYellow,
                    borderRadius: BorderRadius.circular(16),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_isSaving)
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.textDark,
                            ),
                          )
                        else
                          const Icon(
                            Icons.save_rounded,
                            size: 20,
                            color: AppColors.textDark,
                          ),
                        const SizedBox(width: 8),
                        Text(
                          _isSaving ? 'جارٍ الحفظ...' : 'حفظ وإضافة الباقة',
                          style: GoogleFonts.cairo(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
