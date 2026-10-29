// ============================================================================
// Platform: Commercial MikroTik Network & HotSpot Card Management System (Jalsah)
// File: lib/screens/subscription_plans_screen.dart
// Screen: Subscription Plans & License Activation Requests (Rule 20, Rule 27)
// Master Reference: Phase 14 Licensing & Subscriptions
// ============================================================================

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../models/subscription_status_model.dart';
import '../models/subscription_plan_model.dart';
import '../services/api_client.dart';
import '../theme/app_colors.dart';
import '../widgets/bounce_button.dart';

class SubscriptionPlansScreen extends StatefulWidget {
  final bool openDirectlyForTrialLock;

  const SubscriptionPlansScreen({
    super.key,
    this.openDirectlyForTrialLock = false,
  });

  @override
  State<SubscriptionPlansScreen> createState() => _SubscriptionPlansScreenState();
}

class _SubscriptionPlansScreenState extends State<SubscriptionPlansScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  SubscriptionStatusModel? _subscriptionStatus;
  List<SubscriptionPlanModel> _plans = [];
  List<ManualPaymentMethodModel> _paymentMethods = [];
  List<SubscriptionRequestModel> _myRequests = [];
  String? _selectedPlanId;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        ApiClient.getSubscriptionStatus(),
        ApiClient.getSubscriptionPlans(),
        ApiClient.getMySubscriptionRequests(),
        ApiClient.getManualPaymentMethods(),
      ]);

      if (!mounted) return;

      final statusRes = results[0];
      final plansRes = results[1];
      final requestsRes = results[2];
      final paymentMethodsRes = results[3];

      SubscriptionStatusModel? subStatus;
      if (statusRes['success'] == true && statusRes['data'] != null) {
        if (statusRes['data'] is SubscriptionStatusModel) {
          subStatus = statusRes['data'] as SubscriptionStatusModel;
        } else if (statusRes['data'] is Map<String, dynamic>) {
          subStatus = SubscriptionStatusModel.fromJson(statusRes['data'] as Map<String, dynamic>);
        }
      }

      List<SubscriptionPlanModel> plansList = [];
      if (plansRes['success'] == true && plansRes['data'] is List) {
        plansList = (plansRes['data'] as List)
            .map((p) => p is SubscriptionPlanModel
                ? p
                : SubscriptionPlanModel.fromJson(p as Map<String, dynamic>))
            .where((p) => p.isActive)
            .toList();
      } else if (plansRes['success'] != true) {
        _errorMessage = plansRes['errorMessage'] as String? ?? 'تعذر تحميل باقات الاشتراك';
      }

      List<SubscriptionRequestModel> reqsList = [];
      if (requestsRes['success'] == true && requestsRes['data'] is List) {
        reqsList = (requestsRes['data'] as List)
            .map((r) => r is SubscriptionRequestModel
                ? r
                : SubscriptionRequestModel.fromJson(r as Map<String, dynamic>))
            .toList();
      }

      List<ManualPaymentMethodModel> methodsList = [];
      if (paymentMethodsRes['success'] == true && paymentMethodsRes['data'] is List) {
        methodsList = (paymentMethodsRes['data'] as List)
            .map((m) => m is ManualPaymentMethodModel
                ? m
                : ManualPaymentMethodModel.fromJson(m as Map<String, dynamic>))
            .where((m) => m.isActive)
            .toList();
      }

      setState(() {
        _subscriptionStatus = subStatus;
        _plans = plansList;
        _myRequests = reqsList;
        _paymentMethods = methodsList;
        if (_plans.isNotEmpty && _selectedPlanId == null) {
          _selectedPlanId = _plans.first.id;
        }
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'تعذر تحميل بيانات الباقات والتراخيص: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _openActivationDialog() async {
    if (_selectedPlanId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('يرجى اختيار إحدى الباقات أولاً', style: GoogleFonts.cairo()),
          backgroundColor: AppColors.statusOffline,
        ),
      );
      return;
    }

    final selectedPlan = _plans.firstWhere((p) => p.id == _selectedPlanId);

    final success = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ActivationRequestSheet(
        plan: selectedPlan,
        paymentMethods: _paymentMethods,
      ),
    );

    if (success == true) {
      _loadAllData();
    }
  }

  Widget _buildTrialNoticeBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDE68A), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline_rounded, color: Color(0xFFD97706), size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'يمكنك استخدام وظائف Jalsah خلال الفترة التجريبية. لتوليد كروت الإنترنت، يرجى الاشتراك في إحدى الباقات أو طلب تفعيل حسابك من الإدارة.',
                  style: GoogleFonts.cairo(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF92400E),
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusHeader() {
    final status = _subscriptionStatus?.subscriptionStatus ?? 'TRIAL';
    final days = _subscriptionStatus?.daysRemaining ?? 0;

    String statusText;
    IconData statusIcon;

    switch (status.toUpperCase()) {
      case 'ACTIVE':
        statusText = 'الاشتراك نشط';
        statusIcon = Icons.verified_rounded;
        break;
      case 'TRIAL':
        statusText = 'فترة تجريبية';
        statusIcon = Icons.hourglass_top_rounded;
        break;
      case 'EXPIRED':
        statusText = 'الاشتراك منتهي';
        statusIcon = Icons.error_outline_rounded;
        break;
      default:
        statusText = 'في انتظار التفعيل';
        statusIcon = Icons.pending_actions_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            AppColors.heroGradientStart,
            AppColors.heroGradientMiddle,
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.heroGradientStart.withValues(alpha: 0.35),
            offset: const Offset(0, 6),
            blurRadius: 16,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, color: Colors.white, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      statusText,
                      style: GoogleFonts.cairo(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              if (_subscriptionStatus?.planName != null)
                Text(
                  _subscriptionStatus!.planName!,
                  style: GoogleFonts.cairo(
                    color: const Color(0xFFF5C94B),
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'الأيام المتبقية',
                    style: GoogleFonts.cairo(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    '$days يوم',
                    style: GoogleFonts.cairo(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'سقف الراوترات',
                    style: GoogleFonts.cairo(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    '${_subscriptionStatus?.maxRoutersLimit ?? 5} أجهزة',
                    style: GoogleFonts.cairo(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard(SubscriptionPlanModel plan) {
    final planId = plan.id;
    final isSelected = _selectedPlanId == planId;
    final name = plan.name;
    final currency = plan.currency;
    final durationDays = plan.durationDays;
    final maxRouters = plan.maxRoutersLimit;
    final description = plan.description;

    return GestureDetector(
      onTap: () => setState(() => _selectedPlanId = planId),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.heroGradientStart.withValues(alpha: 0.06)
              : AppColors.pageBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.heroGradientStart : AppColors.shadowDark,
            width: isSelected ? 2 : 1,
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
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? AppColors.heroGradientStart : AppColors.textMuted,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.heroGradientStart,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: GoogleFonts.cairo(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textDark,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.heroGradientStart.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${plan.formattedPrice} $currency',
                          style: GoogleFonts.cairo(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.heroGradientStart,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'المدة: $durationDays يوم • حتى $maxRouters أجهزة راوتر',
                    style: GoogleFonts.cairo(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                    ),
                  ),
                  if (description != null && description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: GoogleFonts.cairo(
                        fontSize: 11.5,
                        color: AppColors.textMuted.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showReceiptPreview(String receiptUrl) {
    Widget imageWidget;
    if (receiptUrl.startsWith('data:image/')) {
      try {
        final commaIdx = receiptUrl.indexOf(',');
        final base64Str = commaIdx != -1 ? receiptUrl.substring(commaIdx + 1) : receiptUrl;
        final Uint8List bytes = base64Decode(base64Str);
        imageWidget = Image.memory(
          bytes,
          fit: BoxFit.contain,
          errorBuilder: (c, e, s) => _buildReceiptErrorWidget(),
        );
      } catch (_) {
        imageWidget = _buildReceiptErrorWidget();
      }
    } else {
      final fullUrl = receiptUrl.startsWith('http')
          ? receiptUrl
          : '${ApiClient.baseUrl}$receiptUrl';
      imageWidget = Image.network(
        fullUrl,
        headers: ApiClient.authHeaders,
        fit: BoxFit.contain,
        loadingBuilder: (c, child, progress) {
          if (progress == null) return child;
          return const Padding(
            padding: EdgeInsets.all(40),
            child: Center(
              child: CircularProgressIndicator(color: AppColors.heroGradientStart),
            ),
          );
        },
        errorBuilder: (c, error, stack) => _buildReceiptErrorWidget(),
      );
    }

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'معاينة إشعار التحويل',
                      style: GoogleFonts.cairo(fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              ClipRRect(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                child: imageWidget,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReceiptErrorWidget() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.broken_image_outlined, size: 48, color: AppColors.statusOffline),
          const SizedBox(height: 8),
          Text(
            'تعذر تحميل صورة الإشعار',
            style: GoogleFonts.cairo(fontSize: 13, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestsHistory() {
    if (_myRequests.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        Text(
          'سجل طلبات التفعيل السابقة',
          style: GoogleFonts.cairo(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 10),
        ..._myRequests.map((req) {
          final isApproved = req.isApproved;
          final isRejected = req.isRejected;

          Color statusBg = const Color(0xFFFEF3C7);
          Color statusTextColor = const Color(0xFF92400E);
          if (isApproved) {
            statusBg = const Color(0xFFD1FAE5);
            statusTextColor = const Color(0xFF065F46);
          } else if (isRejected) {
            statusBg = const Color(0xFFFEE2E2);
            statusTextColor = const Color(0xFF991B1B);
          }

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.shadowDark.withValues(alpha: 0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            req.planName,
                            style: GoogleFonts.cairo(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textDark,
                            ),
                          ),
                          Text(
                            '${req.price.toStringAsFixed(0)} ${req.currency} • ${req.durationDays} يوم',
                            style: GoogleFonts.cairo(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        req.statusArabic,
                        style: GoogleFonts.cairo(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: statusTextColor,
                        ),
                      ),
                    ),
                  ],
                ),
                if (req.referenceNumber != null || req.senderName != null) ...[
                  const Divider(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (req.referenceNumber != null)
                        Expanded(
                          child: Text(
                            'رقم الإشعار: ${req.referenceNumber}',
                            style: GoogleFonts.cairo(fontSize: 11.5, color: AppColors.textDark, fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      if (req.senderName != null)
                        Text(
                          'المحول: ${req.senderName}',
                          style: GoogleFonts.cairo(fontSize: 11.5, color: AppColors.textMuted),
                        ),
                    ],
                  ),
                ],
                if (req.receiptUrl != null && req.receiptUrl!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        side: const BorderSide(color: AppColors.heroGradientStart),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => _showReceiptPreview(req.receiptUrl!),
                      icon: const Icon(Icons.receipt_long_rounded, size: 16, color: AppColors.heroGradientStart),
                      label: Text(
                        'معاينة صورة الإشعار',
                        style: GoogleFonts.cairo(fontSize: 11.5, color: AppColors.heroGradientStart, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
                if (req.reviewNotes != null && req.reviewNotes!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'ملاحظة الإدارة: ${req.reviewNotes}',
                      style: GoogleFonts.cairo(fontSize: 11.5, color: const Color(0xFF991B1B)),
                    ),
                  ),
                ],
              ],
            ),
          );
        }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.pageBg,
        appBar: AppBar(
          title: Text(
            'باقات الاشتراك والتراخيص',
            style: GoogleFonts.cairo(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          backgroundColor: AppColors.pageBg,
          foregroundColor: AppColors.textDark,
          elevation: 0,
        ),
        body: _isLoading
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: AppColors.heroGradientStart),
                    const SizedBox(height: 16),
                    Text(
                      'جاري تحميل باقات الاشتراك...',
                      style: GoogleFonts.cairo(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              )
            : _errorMessage != null && _plans.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.statusOffline.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.cloud_off_rounded,
                              size: 48,
                              color: AppColors.statusOffline,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'تعذر تحميل باقات الاشتراك',
                            style: GoogleFonts.cairo(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.cairo(
                              fontSize: 13,
                              color: AppColors.textMuted,
                            ),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.heroGradientStart,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            ),
                            onPressed: _loadAllData,
                            icon: const Icon(Icons.refresh_rounded, size: 20),
                            label: Text(
                              'إعادة المحاولة',
                              style: GoogleFonts.cairo(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadAllData,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
                      children: [
                        if (_errorMessage != null)
                          Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.statusOffline.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline_rounded, color: AppColors.statusOffline, size: 20),
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
                                TextButton(
                                  onPressed: _loadAllData,
                                  child: Text('تحديث', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
                                ),
                              ],
                            ),
                          ),
                        if (widget.openDirectlyForTrialLock ||
                            (_subscriptionStatus != null && _subscriptionStatus!.isTrial))
                          _buildTrialNoticeBanner(),
                        _buildStatusHeader(),
                        const SizedBox(height: 24),
                        Text(
                          'اختر الباقة المناسبة لشبكتك',
                          style: GoogleFonts.cairo(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (_plans.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(28),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: AppColors.shadowDark.withValues(alpha: 0.5)),
                            ),
                            child: Column(
                              children: [
                                const Icon(
                                  Icons.inventory_2_outlined,
                                  size: 48,
                                  color: AppColors.textMuted,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'لا توجد باقات اشتراك متاحة حالياً',
                                  style: GoogleFonts.cairo(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textDark,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'لم تقم الإدارة بتفعيل باقات تجارية حتى الآن. يرجى المحاولة لاحقاً أو التواصل مع الدعم الفني.',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.cairo(
                                    fontSize: 12,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.heroGradientStart,
                                    side: const BorderSide(color: AppColors.heroGradientStart),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  onPressed: _loadAllData,
                                  icon: const Icon(Icons.refresh_rounded, size: 18),
                                  label: Text('تحديث الباقات', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
                                ),
                              ],
                            ),
                          )
                        else ...[
                          ..._plans.map(_buildPlanCard),
                          const SizedBox(height: 20),
                          BounceButton(
                            onPressed: _openActivationDialog,
                            icon: Icons.send_rounded,
                            label: 'طلب التفعيل والاشتراك',
                            height: 52,
                          ),
                        ],
                        _buildRequestsHistory(),
                      ],
                    ),
                  ),
      ),
    );
  }
}

// ============================================================================
// Activation Request Bottom Sheet with Manual Payment Proof
// ============================================================================

class _ActivationRequestSheet extends StatefulWidget {
  final SubscriptionPlanModel plan;
  final List<ManualPaymentMethodModel> paymentMethods;

  const _ActivationRequestSheet({
    required this.plan,
    required this.paymentMethods,
  });

  @override
  State<_ActivationRequestSheet> createState() => _ActivationRequestSheetState();
}

class _ActivationRequestSheetState extends State<_ActivationRequestSheet> {
  final _senderNameController = TextEditingController();
  final _referenceNumberController = TextEditingController();
  final _notesController = TextEditingController();

  ManualPaymentMethodModel? _selectedMethod;
  Uint8List? _receiptBytes;
  String? _receiptMimeType;
  bool _isSubmitting = false;
  String? _submitError;

  @override
  void initState() {
    super.initState();
    if (widget.paymentMethods.isNotEmpty) {
      _selectedMethod = widget.paymentMethods.first;
    }
  }

  @override
  void dispose() {
    _senderNameController.dispose();
    _referenceNumberController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickReceiptImage() async {
    try {
      final picker = ImagePicker();
      final XFile? file = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 80,
      );

      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;

      setState(() {
        _receiptBytes = bytes;
        _receiptMimeType = file.mimeType ?? 'image/jpeg';
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر اختيار صورة الإشعار: $e', style: GoogleFonts.cairo()),
          backgroundColor: AppColors.statusOffline,
        ),
      );
    }
  }

  void _removeReceiptImage() {
    setState(() {
      _receiptBytes = null;
      _receiptMimeType = null;
    });
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تم نسخ $label بنجاح', style: GoogleFonts.cairo()),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _submitRequest() async {
    final senderName = _senderNameController.text.trim();
    final refNumber = _referenceNumberController.text.trim();

    if (senderName.isEmpty) {
      setState(() => _submitError = 'يرجى إدخال اسم المحول');
      return;
    }
    if (refNumber.isEmpty && _receiptBytes == null) {
      setState(() => _submitError = 'يرجى إدخال رقم العملية المرجعي أو إرفاق صورة إشعار التحويل');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });

    String? receiptBase64;
    if (_receiptBytes != null) {
      final mime = _receiptMimeType ?? 'image/jpeg';
      receiptBase64 = 'data:$mime;base64,${base64Encode(_receiptBytes!)}';
    }

    final res = await ApiClient.requestSubscriptionActivation(
      planId: widget.plan.id,
      paymentMethodId: _selectedMethod?.id,
      senderName: senderName,
      referenceNumber: refNumber.isNotEmpty ? refNumber : null,
      receiptImageBase64: receiptBase64,
      notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (res['success'] == true) {
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            res['message'] as String? ?? 'تم إرسال طلب التفعيل بنجاح وسيتم مراجعته وتأكيده',
            style: GoogleFonts.cairo(fontWeight: FontWeight.w600),
          ),
          backgroundColor: AppColors.statusOnline,
        ),
      );
    } else {
      setState(() {
        _submitError = res['errorMessage'] as String? ?? 'فشل إرسال طلب التفعيل';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
        decoration: const BoxDecoration(
          color: AppColors.pageBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.shadowDark,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'طلب تفعيل اشتراك Jalsah',
                    style: GoogleFonts.cairo(fontWeight: FontWeight.w800, fontSize: 18),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context, false),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Selected Plan Summary
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.heroGradientStart.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.heroGradientStart.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.plan.name,
                          style: GoogleFonts.cairo(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: AppColors.textDark,
                          ),
                        ),
                        Text(
                          'المدة: ${widget.plan.durationDays} يوم • حتى ${widget.plan.maxRoutersLimit} أجهزة راوتر',
                          style: GoogleFonts.cairo(fontSize: 12, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                    Text(
                      '${widget.plan.formattedPrice} ${widget.plan.currency}',
                      style: GoogleFonts.cairo(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: AppColors.heroGradientStart,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Payment Bank Details Card
              if (widget.paymentMethods.isNotEmpty) ...[
                Text(
                  'بيانات الحساب البنكي للتحويل:',
                  style: GoogleFonts.cairo(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 8),

                if (widget.paymentMethods.length > 1) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.shadowDark),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<ManualPaymentMethodModel>(
                        value: _selectedMethod,
                        isExpanded: true,
                        items: widget.paymentMethods.map((m) {
                          return DropdownMenuItem(
                            value: m,
                            child: Text(
                              '${m.providerName} - ${m.accountName}',
                              style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedMethod = val);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],

                if (_selectedMethod != null)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.shadowDark.withValues(alpha: 0.6)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _selectedMethod!.providerName,
                              style: GoogleFonts.cairo(
                                fontWeight: FontWeight.w800,
                                fontSize: 14.5,
                                color: AppColors.heroGradientStart,
                              ),
                            ),
                            Text(
                              _selectedMethod!.currency,
                              style: GoogleFonts.cairo(fontSize: 12, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'اسم الحساب: ${_selectedMethod!.accountName}',
                          style: GoogleFonts.cairo(fontSize: 13, color: AppColors.textDark, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                'رقم الحساب: ${_selectedMethod!.accountNumber}',
                                style: GoogleFonts.cairo(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textDark,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy_rounded, size: 18, color: AppColors.heroGradientStart),
                              tooltip: 'نسخ رقم الحساب',
                              onPressed: () => _copyToClipboard(
                                _selectedMethod!.accountNumber,
                                'رقم الحساب',
                              ),
                            ),
                          ],
                        ),
                        if (_selectedMethod!.beneficiaryName != null) ...[
                          Text(
                            'المستفيد: ${_selectedMethod!.beneficiaryName}',
                            style: GoogleFonts.cairo(fontSize: 12, color: AppColors.textMuted),
                          ),
                        ],
                        if (_selectedMethod!.instructions != null &&
                            _selectedMethod!.instructions!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _selectedMethod!.instructions!,
                              style: GoogleFonts.cairo(fontSize: 11.5, color: const Color(0xFF1E40AF)),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
              ],

              // Sender Name input
              Text(
                'اسم المحول (كما يظهر في الإشعار) *',
                style: GoogleFonts.cairo(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textDark),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _senderNameController,
                style: GoogleFonts.cairo(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'الاسم الرباعي للمحول...',
                  hintStyle: GoogleFonts.cairo(fontSize: 12, color: AppColors.textMuted),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.shadowDark),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Reference Number input
              Text(
                'رقم العملية المرجعي / رقم الإشعار',
                style: GoogleFonts.cairo(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textDark),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _referenceNumberController,
                style: GoogleFonts.cairo(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'مثال: 1234567890 (من تطبيق البنك)',
                  hintStyle: GoogleFonts.cairo(fontSize: 12, color: AppColors.textMuted),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.shadowDark),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Receipt Attachment
              Text(
                'إرفاق صورة إشعار التحويل (مستحسن للتوثيق السريع)',
                style: GoogleFonts.cairo(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textDark),
              ),
              const SizedBox(height: 6),
              if (_receiptBytes != null)
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.shadowDark),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(
                          _receiptBytes!,
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'تم إرفاق صورة الإشعار',
                              style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.statusOnline),
                            ),
                            Text(
                              'الحجم: ${(_receiptBytes!.length / 1024).toStringAsFixed(1)} KB',
                              style: GoogleFonts.cairo(fontSize: 11.5, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: AppColors.statusOffline),
                        tooltip: 'حذف الصورة',
                        onPressed: _removeReceiptImage,
                      ),
                    ],
                  ),
                )
              else
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.heroGradientStart,
                    side: const BorderSide(color: AppColors.heroGradientStart),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _pickReceiptImage,
                  icon: const Icon(Icons.add_photo_alternate_outlined, size: 20),
                  label: Text('اختيار صورة الإشعار من الاستوديو', style: GoogleFonts.cairo(fontWeight: FontWeight.w700, fontSize: 13)),
                ),
              const SizedBox(height: 12),

              // Additional notes
              Text(
                'ملاحظات إضافية (اختياري)',
                style: GoogleFonts.cairo(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textDark),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _notesController,
                maxLines: 2,
                style: GoogleFonts.cairo(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'أي تفاصيل أخرى ترغب في تزويد الإدارة بها...',
                  hintStyle: GoogleFonts.cairo(fontSize: 12, color: AppColors.textMuted),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.shadowDark),
                  ),
                ),
              ),

              if (_submitError != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _submitError!,
                          style: GoogleFonts.cairo(
                            fontSize: 12.5,
                            color: const Color(0xFFB91C1C),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),
              BounceButton(
                onPressed: _isSubmitting ? null : _submitRequest,
                isLoading: _isSubmitting,
                icon: Icons.check_circle_outline_rounded,
                label: 'تأكيد وإرسال طلب الاشتراك',
                height: 50,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
