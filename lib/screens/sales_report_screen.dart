// ============================================================================
// Platform: Commercial MikroTik Network & HotSpot Card Management System
// File: lib/screens/sales_report_screen.dart
// Screen: Basic Sales Reports Screen with Date Filters & Aggregated Totals
// Master Reference: Rule 8 (Sales), Rule 26 (MVP Reports), Rule 35 (States)
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/sale_model.dart';
import '../services/api_client.dart';
import '../theme/app_colors.dart';
import '../widgets/count_up_text.dart';
import '../widgets/pressable_neumorphic_card.dart';
import 'temp_login_screen.dart';

enum SalesPeriodFilter {
  today,
  last7Days,
  last30Days,
}

class SalesReportScreen extends StatefulWidget {
  final SalesPeriodFilter initialFilter;

  const SalesReportScreen({
    super.key,
    this.initialFilter = SalesPeriodFilter.today,
  });

  @override
  State<SalesReportScreen> createState() => _SalesReportScreenState();
}

class _SalesReportScreenState extends State<SalesReportScreen> {
  late SalesPeriodFilter _selectedFilter;
  List<SaleModel> _sales = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _isRedirectingToLogin = false;

  @override
  void initState() {
    super.initState();
    _selectedFilter = widget.initialFilter;
    _loadSales();
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

  String get _activeFilterLabel {
    switch (_selectedFilter) {
      case SalesPeriodFilter.today:
        return 'اليوم';
      case SalesPeriodFilter.last7Days:
        return 'آخر 7 أيام';
      case SalesPeriodFilter.last30Days:
        return 'آخر 30 يوم';
    }
  }

  DateTime? get _calculatedDateFrom {
    final now = DateTime.now();
    switch (_selectedFilter) {
      case SalesPeriodFilter.today:
        return DateTime(now.year, now.month, now.day);
      case SalesPeriodFilter.last7Days:
        return DateTime(now.year, now.month, now.day)
            .subtract(const Duration(days: 7));
      case SalesPeriodFilter.last30Days:
        return DateTime(now.year, now.month, now.day)
            .subtract(const Duration(days: 30));
    }
  }

  double get _totalSalesAmount {
    return _sales.fold<double>(0.0, (sum, sale) => sum + sale.totalAmount);
  }

  int get _totalCardsSold {
    return _sales.fold<int>(0, (sum, sale) => sum + sale.cardsCount);
  }

  Future<void> _loadSales() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await ApiClient.getSales(
      dateFrom: _calculatedDateFrom,
    );

    if (!mounted) return;

    if (result['errorCode'] == 'UNAUTHORIZED') {
      _handleUnauthorized();
      return;
    }

    if (result['success'] == true) {
      setState(() {
        _sales = (result['data'] as List<dynamic>).cast<SaleModel>();
        _isLoading = false;
        _errorMessage = null;
      });
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage =
            result['errorMessage'] ?? 'تعذر الاتصال بالخادم لجلب تقارير المبيعات';
      });
    }
  }

  void _onFilterSelected(SalesPeriodFilter filter) {
    if (_selectedFilter == filter) return;
    setState(() {
      _selectedFilter = filter;
    });
    _loadSales();
  }

  void _showSaleDetailsSheet(SaleModel sale) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.pageBg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 28),
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
              const SizedBox(height: 18),

              // Title
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'تفاصيل معاملة البيع',
                    style: GoogleFonts.cairo(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: sale.paymentMethodColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          sale.paymentMethodIcon,
                          size: 14,
                          color: sale.paymentMethodColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          sale.paymentMethodArabic,
                          style: GoogleFonts.cairo(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: sale.paymentMethodColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Amount Card
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      AppColors.heroGradientStart,
                      AppColors.heroGradientEnd,
                    ],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.heroGradientStart.withValues(alpha: 0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      'المبلغ الإجمالي',
                      style: GoogleFonts.cairo(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      sale.formattedTotalAmount,
                      style: GoogleFonts.cairo(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.accentYellow,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Detail items
              _buildDetailRow(
                icon: Icons.tag_rounded,
                label: 'رقم المعاملة',
                value: sale.id,
                isMonospace: true,
                canCopy: true,
              ),
              const Divider(height: 18, color: AppColors.shadowDark),
              _buildDetailRow(
                icon: Icons.calendar_today_rounded,
                label: 'التاريخ والوقت',
                value: sale.formattedDate,
              ),
              const Divider(height: 18, color: AppColors.shadowDark),
              _buildDetailRow(
                icon: Icons.credit_card_rounded,
                label: 'عدد الكروت المباعة',
                value: sale.cardsCountArabic,
              ),
              if (sale.soldByName != null && sale.soldByName!.isNotEmpty) ...[
                const Divider(height: 18, color: AppColors.shadowDark),
                _buildDetailRow(
                  icon: Icons.person_outline_rounded,
                  label: 'البائع',
                  value: sale.soldByName!,
                ),
              ],
              const SizedBox(height: 24),

              // Close Button
              PressableNeumorphicCard(
                onTap: () => Navigator.of(ctx).pop(),
                backgroundColor: AppColors.heroGradientStart,
                borderRadius: BorderRadius.circular(14),
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'إغلاق',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cairo(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    bool isMonospace = false,
    bool canCopy = false,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textMuted),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.cairo(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textMuted,
          ),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.left,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.cairo(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
        ),
        if (canCopy) ...[
          const SizedBox(width: 6),
          InkWell(
            onTap: () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: AppColors.heroGradientStart,
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  content: Text(
                    'تم نسخ رقم المعاملة',
                    style: GoogleFonts.cairo(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            },
            child: const Icon(
              Icons.copy_rounded,
              size: 16,
              color: AppColors.heroGradientStart,
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.pageBg,
        body: Column(
          children: [
            // Top Hero Banner with back button and Stats card
            _buildTopBanner(),

            // Period Filter Chips
            _buildFilterChips(),

            // Content Area with RefreshIndicator
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadSales,
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

  Widget _buildTopBanner() {
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
              // Navigation & Title Row
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'تقارير المبيعات',
                          style: GoogleFonts.cairo(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.2,
                          ),
                        ),
                        Text(
                          'متابعة المعاملات والإيرادات المحققة',
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
              const SizedBox(height: 12),

              // Aggregated Sales Total Stat Card (Matching Dashboard Style)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.22),
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
                            const Icon(
                              Icons.payments_outlined,
                              size: 16,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'إجمالي مبيعات الفترة ($_activeFilterLabel)',
                              style: GoogleFonts.cairo(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withValues(alpha: 0.95),
                              ),
                            ),
                          ],
                        ),
                        if (!_isLoading)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.accentYellow.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: AppColors.accentYellow.withValues(alpha: 0.4),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              '${_sales.length} معاملة',
                              style: GoogleFonts.cairo(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.accentYellow,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (_isLoading)
                      const SizedBox(
                        height: 36,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
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
                          targetValue: _totalSalesAmount.round(),
                          suffix: ' جنيه سوداني',
                          formatter: (val) {
                            final formatted = val.toString().replaceAllMapped(
                              RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                              (Match m) => '${m[1]},',
                            );
                            return '$formatted جنيه سوداني';
                          },
                          style: GoogleFonts.cairo(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: AppColors.accentYellow,
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.credit_card_rounded,
                          size: 13,
                          color: Colors.white.withValues(alpha: 0.75),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'إجمالي الكروت المباعة: $_totalCardsSold كرت',
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
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
      child: Row(
        children: [
          _buildFilterChip(SalesPeriodFilter.today, 'اليوم'),
          const SizedBox(width: 8),
          _buildFilterChip(SalesPeriodFilter.last7Days, 'آخر 7 أيام'),
          const SizedBox(width: 8),
          _buildFilterChip(SalesPeriodFilter.last30Days, 'آخر 30 يوم'),
        ],
      ),
    );
  }

  Widget _buildFilterChip(SalesPeriodFilter filter, String label) {
    final isSelected = _selectedFilter == filter;

    return Expanded(
      child: InkWell(
        onTap: () => _onFilterSelected(filter),
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.heroGradientStart : AppColors.pageBg,
            borderRadius: BorderRadius.circular(14),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.heroGradientStart.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : [
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
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(
              fontSize: 12.5,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color: isSelected ? Colors.white : AppColors.textDark,
            ),
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
            height: 280,
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
                  'جارٍ تحميل تقارير المبيعات...',
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
                  'فشل تحميل تقارير المبيعات',
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
                  onTap: _loadSales,
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
    if (_sales.isEmpty) {
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
                    Icons.receipt_long_outlined,
                    size: 32,
                    color: AppColors.heroGradientStart,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'لا توجد مبيعات في هذه الفترة',
                  style: GoogleFonts.cairo(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'لم يتم تسجيل أي معاملات بيع خلال $_activeFilterLabel. يمكنك بيع كروت جديدة من شاشة إدارة الكروت.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cairo(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textMuted,
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
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 24),
      itemCount: _sales.length,
      itemBuilder: (context, index) {
        final sale = _sales[index];
        return _buildSaleCard(sale, index);
      },
    );
  }

  Widget _buildSaleCard(SaleModel sale, int index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PressableNeumorphicCard(
        onTap: () => _showSaleDetailsSheet(sale),
        borderRadius: BorderRadius.circular(18),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Payment Method Badge & Total Amount
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Payment Method Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: sale.paymentMethodColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        sale.paymentMethodIcon,
                        size: 15,
                        color: sale.paymentMethodColor,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        sale.paymentMethodArabic,
                        style: GoogleFonts.cairo(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: sale.paymentMethodColor,
                        ),
                      ),
                    ],
                  ),
                ),

                // Amount
                Text(
                  sale.formattedTotalAmount,
                  style: GoogleFonts.cairo(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Bottom Row: Date/Time, Cards count, Sold by
            Row(
              children: [
                // Date & Time
                Icon(
                  Icons.access_time_rounded,
                  size: 14,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: 4),
                Text(
                  sale.formattedDate,
                  style: GoogleFonts.cairo(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(width: 10),

                // Dot divider
                Container(
                  width: 3.5,
                  height: 3.5,
                  decoration: const BoxDecoration(
                    color: AppColors.textMuted,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),

                // Cards Count
                Icon(
                  Icons.credit_card_rounded,
                  size: 14,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: 4),
                Text(
                  sale.cardsCountArabic,
                  style: GoogleFonts.cairo(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                  ),
                ),

                if (sale.soldByName != null && sale.soldByName!.isNotEmpty) ...[
                  const SizedBox(width: 10),
                  Container(
                    width: 3.5,
                    height: 3.5,
                    decoration: const BoxDecoration(
                      color: AppColors.textMuted,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      sale.soldByName!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.cairo(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(delay: (index * 40).ms)
        .slideY(begin: 0.08, duration: 200.ms);
  }
}
