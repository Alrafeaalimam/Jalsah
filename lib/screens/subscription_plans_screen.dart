// ============================================================================
// Platform: Commercial MikroTik Network & HotSpot Card Management System (Jalsah)
// File: lib/screens/subscription_plans_screen.dart
// Screen: Subscription Plans & License Activation Requests (Rule 20, Rule 27)
// Master Reference: Phase 14 Licensing & Subscriptions
// ============================================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/subscription_status_model.dart';
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
  List<Map<String, dynamic>> _plans = [];
  List<Map<String, dynamic>> _myRequests = [];
  String? _selectedPlanId;
  bool _isSubmitting = false;

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
      ]);

      if (!mounted) return;

      final statusRes = results[0];
      final plansRes = results[1];
      final requestsRes = results[2];

      SubscriptionStatusModel? subStatus;
      if (statusRes['success'] == true && statusRes['data'] != null) {
        if (statusRes['data'] is SubscriptionStatusModel) {
          subStatus = statusRes['data'] as SubscriptionStatusModel;
        } else if (statusRes['data'] is Map<String, dynamic>) {
          subStatus = SubscriptionStatusModel.fromJson(statusRes['data'] as Map<String, dynamic>);
        }
      }

      List<Map<String, dynamic>> plansList = [];
      if (plansRes['success'] == true && plansRes['data'] is List) {
        plansList = List<Map<String, dynamic>>.from(plansRes['data']);
      }

      List<Map<String, dynamic>> reqsList = [];
      if (requestsRes['success'] == true && requestsRes['data'] is List) {
        reqsList = List<Map<String, dynamic>>.from(requestsRes['data']);
      }

      setState(() {
        _subscriptionStatus = subStatus;
        _plans = plansList;
        _myRequests = reqsList;
        if (_plans.isNotEmpty && _selectedPlanId == null) {
          _selectedPlanId = _plans.first['id'] as String?;
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

  Future<void> _showActivationRequestDialog() async {
    if (_selectedPlanId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('يرجى اختيار إحدى الباقات أولاً', style: GoogleFonts.cairo()),
          backgroundColor: AppColors.statusOffline,
        ),
      );
      return;
    }

    final selectedPlan = _plans.firstWhere((p) => p['id'] == _selectedPlanId);
    final notesController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AppColors.pageBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'طلب تفعيل اشتراك Jalsah',
            style: GoogleFonts.cairo(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.heroGradientStart.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.heroGradientStart.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'الباقة المختارة: ${selectedPlan['name']}',
                        style: GoogleFonts.cairo(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'السعر: ${selectedPlan['price']} ${selectedPlan['currency']} | المدة: ${selectedPlan['durationDays']} يوم',
                        style: GoogleFonts.cairo(
                          fontSize: 13,
                          color: AppColors.heroGradientStart,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'ملاحظات السداد أو مرجع التحويل (اختياري):',
                  style: GoogleFonts.cairo(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: notesController,
                  maxLines: 2,
                  style: GoogleFonts.cairo(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'رقم إشعار التحويل البنكي أو اسم المحول...',
                    hintStyle: GoogleFonts.cairo(fontSize: 12, color: AppColors.textMuted),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.shadowDark),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'سيتم مراجعة الطلب وتأكيد السداد من قبل إدارة Jalsah قبل تفعيل الحساب.',
                  style: GoogleFonts.cairo(
                    fontSize: 11.5,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text('إلغاء', style: GoogleFonts.cairo(color: AppColors.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.heroGradientStart,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(
                'تأكيد وإرسال الطلب',
                style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      setState(() => _isSubmitting = true);
      final res = await ApiClient.requestSubscriptionActivation(
        planId: _selectedPlanId!,
        notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
      );

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      if (res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              res['message'] as String? ?? 'تم إرسال طلب التفعيل بنجاح وسيتم مراجعته',
              style: GoogleFonts.cairo(fontWeight: FontWeight.w600),
            ),
            backgroundColor: AppColors.statusOnline,
          ),
        );
        _loadAllData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              res['errorMessage'] as String? ?? 'فشل إرسال طلب التفعيل',
              style: GoogleFonts.cairo(fontWeight: FontWeight.w600),
            ),
            backgroundColor: AppColors.statusOffline,
          ),
        );
      }
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

  Widget _buildPlanCard(Map<String, dynamic> plan) {
    final planId = plan['id'] as String;
    final isSelected = _selectedPlanId == planId;
    final name = plan['name'] as String? ?? 'باقة';
    final price = plan['price'];
    final currency = plan['currency'] ?? 'SDG';
    final durationDays = plan['durationDays'] ?? 30;
    final maxRouters = plan['maxRoutersLimit'] ?? 5;
    final description = plan['description'] as String?;

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
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.cairo(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.heroGradientStart.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$price $currency',
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

  Widget _buildRequestsHistory() {
    if (_myRequests.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 20),
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
          final status = (req['status'] as String? ?? 'PENDING').toUpperCase();
          String statusLabel = 'قيد المراجعة';
          Color statusBg = const Color(0xFFFEF3C7);
          Color statusTextColor = const Color(0xFF92400E);

          if (status == 'APPROVED') {
            statusLabel = 'تمت الموافقة';
            statusBg = const Color(0xFFD1FAE5);
            statusTextColor = const Color(0xFF065F46);
          } else if (status == 'REJECTED') {
            statusLabel = 'مرفوض';
            statusBg = const Color(0xFFFEE2E2);
            statusTextColor = const Color(0xFF991B1B);
          }

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.shadowDark.withValues(alpha: 0.5)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      req['planName'] as String? ?? 'باقة',
                      style: GoogleFonts.cairo(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                    Text(
                      '${req['price']} ${req['currency']} • ${req['durationDays']} يوم',
                      style: GoogleFonts.cairo(
                        fontSize: 11.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    statusLabel,
                    style: GoogleFonts.cairo(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: statusTextColor,
                    ),
                  ),
                ),
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
            ? const Center(child: CircularProgressIndicator())
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
                        child: Text(
                          _errorMessage!,
                          style: GoogleFonts.cairo(
                            fontSize: 12.5,
                            color: AppColors.statusOffline,
                            fontWeight: FontWeight.w600,
                          ),
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
                    ..._plans.map(_buildPlanCard),
                    const SizedBox(height: 20),
                    BounceButton(
                      onPressed: _isSubmitting ? null : _showActivationRequestDialog,
                      isLoading: _isSubmitting,
                      icon: Icons.send_rounded,
                      label: 'طلب التفعيل والاشتراك',
                      height: 52,
                    ),
                    _buildRequestsHistory(),
                  ],
                ),
              ),
      ),
    );
  }
}
