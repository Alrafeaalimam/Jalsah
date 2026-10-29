// ============================================================================
// Platform: Commercial MikroTik Network & HotSpot Card Management System
// File: lib/screens/generate_cards_screen.dart
// Screen: Hotspot Card Batch Generator adhering to Backend Clean Architecture
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/card_batch_model.dart';
import '../models/card_model.dart';
import '../models/package_model.dart';
import '../models/router_model.dart';
import '../models/subscription_status_model.dart';
import '../services/api_client.dart';
import '../services/card_pdf_service.dart';
import '../services/local_card_sync_service.dart';
import '../services/mikrotik_discovery_service.dart';
import '../theme/app_colors.dart';
import '../widgets/bounce_button.dart';
import '../widgets/card_voucher_widget.dart';
import '../widgets/neumorphic_text_field.dart';
import '../widgets/pressable_neumorphic_card.dart';
import 'cards_list_screen.dart';
import 'packages_screen.dart';
import 'subscription_plans_screen.dart';

class GenerateCardsScreen extends StatefulWidget {
  const GenerateCardsScreen({super.key});

  @override
  State<GenerateCardsScreen> createState() => _GenerateCardsScreenState();
}

class _GenerateCardsScreenState extends State<GenerateCardsScreen> {
  List<PackageModel> _packages = [];
  PackageModel? _selectedPackage;
  bool _isLoadingPackages = true;
  String? _packagesError;

  List<RouterModel> _routers = [];
  RouterModel? _selectedRouter;
  bool _isLoadingRouters = false;

  final TextEditingController _quantityController =
      TextEditingController(text: '10');
  final TextEditingController _prefixController = TextEditingController();
  final TextEditingController _userLengthController =
      TextEditingController(text: '6');
  final TextEditingController _passwordLengthController =
      TextEditingController(text: '4');

  bool _showAdvancedSettings = false;
  bool _isGenerating = false;
  String? _generationError;
  String _generationMode = 'USERNAME_AND_PASSWORD';
  SubscriptionStatusModel? _subscriptionStatus;

  CardBatchModel? _generatedBatch;
  List<CardModel>? _generatedCards;
  BatchSyncResult? _syncResult;
  bool _isResyncing = false;
  String? _syncStatusMessage;
  int _syncProgressCurrent = 0;
  int _syncProgressTotal = 0;

  @override
  void initState() {
    super.initState();
    _loadPackages();
    _loadRouters();
    _loadSubscriptionStatus();
  }

  Future<void> _loadSubscriptionStatus() async {
    try {
      final res = await ApiClient.getSubscriptionStatus();
      if (res['success'] == true && res['data'] != null && mounted) {
        setState(() {
          _subscriptionStatus = SubscriptionStatusModel.fromJson(res['data']);
        });
      }
    } catch (_) {}
  }

  void _showTrialLockDialog() {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AppColors.pageBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.lock_outline_rounded, color: Color(0xFFD97706), size: 24),
              const SizedBox(width: 8),
              Text(
                'توليد الكروت مقفل في النسخة التجريبية',
                style: GoogleFonts.cairo(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ],
          ),
          content: Text(
            'يمكنك استخدام وظائف Jalsah خلال الفترة التجريبية. لتوليد كروت الإنترنت، يرجى الاشتراك في إحدى الباقات أو طلب تفعيل حسابك من الإدارة.',
            style: GoogleFonts.cairo(fontSize: 13.5, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('إلغاء', style: GoogleFonts.cairo(color: AppColors.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.heroGradientStart,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const SubscriptionPlansScreen(openDirectlyForTrialLock: true),
                  ),
                );
              },
              child: Text(
                'عرض الباقات وطلب التفعيل',
                style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _prefixController.dispose();
    _userLengthController.dispose();
    _passwordLengthController.dispose();
    super.dispose();
  }

  Future<void> _loadPackages() async {
    setState(() {
      _isLoadingPackages = true;
      _packagesError = null;
    });

    final result = await ApiClient.getPackages();

    if (!mounted) return;

    if (result['success'] == true) {
      final pkgs = (result['data'] as List<dynamic>).cast<PackageModel>();
      setState(() {
        _packages = pkgs;
        _isLoadingPackages = false;
        _packagesError = null;

        if (_packages.isNotEmpty) {
          // Default to first active package, or first package
          _selectedPackage = _packages.firstWhere(
            (p) => p.isActive,
            orElse: () => _packages.first,
          );
        } else {
          _selectedPackage = null;
        }
      });
    } else {
      setState(() {
        _isLoadingPackages = false;
        _packagesError = result['errorMessage'] ??
            'تعذر تحميل قائمة باقات الإنترنت من الخادم';
      });
    }
  }

  Future<void> _loadRouters() async {
    setState(() {
      _isLoadingRouters = true;
    });

    final result = await ApiClient.getRouters();
    if (!mounted) return;

    if (result['success'] == true) {
      final list = (result['data'] as List<dynamic>).cast<RouterModel>();
      setState(() {
        _routers = list;
        _isLoadingRouters = false;
        if (_routers.isNotEmpty && _selectedRouter == null) {
          final online = _routers.where((r) => r.isOnline);
          if (online.isNotEmpty) {
            _selectedRouter = online.first;
          }
        }
      });
    } else {
      setState(() {
        _isLoadingRouters = false;
      });
    }
  }

  Future<void> _generateBatch() async {
    if (_isGenerating) return;

    // Phase 14: Enforce Trial Period Card Generation Lock on client
    if (_subscriptionStatus?.isTrial == true) {
      _showTrialLockDialog();
      return;
    }

    if (_selectedPackage == null) {
      setState(() {
        _generationError = 'يرجى اختيار باقة إنترنت أولاً.';
      });
      return;
    }

    final int? quantity = int.tryParse(_quantityController.text.trim());
    if (quantity == null || quantity < 1 || quantity > 1000) {
      setState(() {
        _generationError = 'يرجى إدخال عدد صحيح للكمية بين 1 و 1000 كرت.';
      });
      return;
    }

    final bool isNumbersOnly = _generationMode == 'NUMBERS_ONLY';
    int? userLen = int.tryParse(_userLengthController.text.trim());
    if (userLen != null && (userLen < 4 || userLen > 16)) {
      setState(() {
        _generationError = isNumbersOnly
            ? 'طول رقم الكرت يجب أن يكون بين 4 و 16 رقماً.'
            : 'طول اسم المستخدم يجب أن يكون بين 4 و 16 محرفاً.';
      });
      return;
    }

    int? passLen = isNumbersOnly ? 0 : int.tryParse(_passwordLengthController.text.trim());
    if (!isNumbersOnly && passLen != null && (passLen < 4 || passLen > 16)) {
      setState(() {
        _generationError = 'طول كلمة المرور يجب أن يكون بين 4 و 16 رقماً.';
      });
      return;
    }

    final isLocalRouter = _selectedRouter != null &&
        MikrotikDiscoveryService.isLocalPrivateIp(_selectedRouter!.host);

    setState(() {
      _isGenerating = true;
      _generationError = null;
      _syncResult = null;
      _syncStatusMessage = isLocalRouter
          ? 'جاري فحص الاتصال وتجربة إضافة مستخدم تجريبي في الراوتر...'
          : 'جارٍ توليد وتشفير الكروت بأمان...';
    });

    // 1. If local router: Execute Pre-Flight Probe directly on device
    if (isLocalRouter) {
      final probeResult = await LocalCardSyncService.probeRouter(
        router: _selectedRouter!,
        profile: _selectedPackage!.hotspotProfileName,
      );

      if (probeResult['success'] != true) {
        if (!mounted) return;
        setState(() {
          _isGenerating = false;
          _generationError = probeResult['errorMessage'] ??
              'تعذر الاتصال بالراوتر المحلي للتحقق من الجاهزية قبل التوليد.';
          _syncStatusMessage = null;
        });
        return;
      }

      if (mounted) {
        setState(() {
          _syncStatusMessage = 'نجح فحص الراوتر! جارٍ حفظ الكروت في السيرفر...';
        });
      }
    }

    // 2. Call backend to generate batch
    // For local routers, pass routerId: null so cloud backend saves cards without attempting direct router connection
    final result = await ApiClient.generateCardBatch(
      packageId: _selectedPackage!.id,
      quantity: quantity,
      routerId: isLocalRouter ? null : _selectedRouter?.id,
      prefix: _prefixController.text.trim().isEmpty
          ? null
          : _prefixController.text.trim(),
      userLength: userLen,
      passwordLength: passLen,
      generationMode: _generationMode,
    );

    if (!mounted) return;

    if (result['success'] == true) {
      final batch = result['data']['batch'] as CardBatchModel;
      final cards = result['data']['cards'] as List<CardModel>;

      // 3. If local router, sync cards directly from device to router
      BatchSyncResult? syncResult;
      if (isLocalRouter && cards.isNotEmpty) {
        setState(() {
          _syncProgressCurrent = 0;
          _syncProgressTotal = cards.length;
          _syncStatusMessage = 'جاري رفع الكروت إلى الراوتر (0/${cards.length})...';
        });

        syncResult = await LocalCardSyncService.syncCardsToRouter(
          router: _selectedRouter!,
          cards: cards,
          profile: _selectedPackage!.hotspotProfileName,
          comment: 'Jalsah:${batch.batchNumber}',
          timeLimit: _selectedPackage!.durationMinutes > 0
              ? '${_selectedPackage!.durationMinutes}m'
              : null,
          onProgress: (current, total, username) {
            if (mounted) {
              setState(() {
                _syncProgressCurrent = current;
                _syncProgressTotal = total;
                _syncStatusMessage = 'جاري رفع الكروت إلى الراوتر ($current/$total)...';
              });
            }
          },
        );
      }

      if (!mounted) return;

      setState(() {
        _isGenerating = false;
        _generatedBatch = batch;
        _generatedCards = cards;
        _syncResult = syncResult;
        _generationError = null;
        _syncStatusMessage = null;
      });
    } else {
      if (result['errorCode'] == 'TRIAL_CARD_GENERATION_LOCKED') {
        setState(() {
          _isGenerating = false;
          _syncStatusMessage = null;
        });
        _showTrialLockDialog();
        return;
      }
      setState(() {
        _isGenerating = false;
        _syncStatusMessage = null;
        _generationError = result['errorMessage'] ??
            'فشل توليد دفعة الكروت، يرجى المحاولة مرة أخرى.';
      });
    }
  }

  Future<void> _resyncPendingCards() async {
    if (_isResyncing || _selectedRouter == null || _generatedCards == null) return;
    setState(() {
      _isResyncing = true;
      _syncStatusMessage = 'جاري قراءة المستخدمين من الراوتر ومقارنة الكروت...';
    });

    try {
      final res = await LocalCardSyncService.resyncPendingCards(
        router: _selectedRouter!,
        cards: _generatedCards!,
        profile: _selectedPackage?.hotspotProfileName,
        comment: _generatedBatch != null ? 'Jalsah:${_generatedBatch!.batchNumber}' : 'Jalsah:Card',
        timeLimit: (_selectedPackage?.durationMinutes ?? 0) > 0
            ? '${_selectedPackage!.durationMinutes}m'
            : null,
        onProgress: (current, total, username) {
          if (mounted) {
            setState(() {
              _syncStatusMessage = 'جاري التحقق وإعادة الرفع ($current/$total)...';
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _syncResult = res;
          _isResyncing = false;
          _syncStatusMessage = null;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              res.success
                  ? 'تمت مزامنة جميع الكروت في الراوتر بنجاح!'
                  : 'اكتملت العملية: تم مزامنة ${res.syncedCount} كرت، وتوجد ${res.failedCount} كروت متبقية.',
              style: GoogleFonts.cairo(fontWeight: FontWeight.w700),
            ),
            backgroundColor: res.success ? AppColors.statusOnline : const Color(0xFFD97706),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isResyncing = false;
          _syncStatusMessage = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشلت إعادة المزامنة: $e', style: GoogleFonts.cairo()),
            backgroundColor: AppColors.statusOffline,
          ),
        );
      }
    }
  }

  void _resetForNewBatch() {
    setState(() {
      _generatedBatch = null;
      _generatedCards = null;
      _syncResult = null;
      _isResyncing = false;
      _syncStatusMessage = null;
      _generationError = null;
      _quantityController.text = '10';
      _prefixController.clear();
    });
  }

  bool _isExportingPdf = false;

  Future<void> _exportBatchPdf() async {
    if (_generatedCards == null || _generatedCards!.isEmpty) return;

    setState(() {
      _isExportingPdf = true;
    });

    try {
      await CardPdfService.shareBatchCardsPdf(
        cards: _generatedCards!,
        package: _selectedPackage,
        batchNumber: _generatedBatch?.batchNumber,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.statusOffline,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Text(
              'تعذر تصدير ملف PDF: $e',
              style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExportingPdf = false;
        });
      }
    }
  }

  void _showVoucherPreview(CardModel card) {
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
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textMuted.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              CardVoucherWidget(
                card: card,
                package: _selectedPackage,
              ),
              const SizedBox(height: 20),
              PressableNeumorphicCard(
                onTap: () {
                  Navigator.of(ctx).pop();
                  CardPdfService.shareSingleCardPdf(
                    card: card,
                    package: _selectedPackage,
                  );
                },
                backgroundColor: AppColors.accentYellow,
                borderRadius: BorderRadius.circular(14),
                padding: const EdgeInsets.symmetric(vertical: 13),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.picture_as_pdf_rounded,
                      color: AppColors.textDark,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'مشاركة / طباعة هذا الكرت (PDF)',
                      style: GoogleFonts.cairo(
                        fontSize: 14,
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
      ),
    );
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.heroGradientStart,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(
          children: [
            const Icon(Icons.check_rounded, color: AppColors.accentYellow, size: 18),
            const SizedBox(width: 8),
            Text(
              'تم نسخ $label: $text',
              style: GoogleFonts.cairo(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
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
            // Top Hero Banner
            _buildTopBanner(),

            // Form Body or Results Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                child: _buildMainBody(),
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
            AppColors.heroGradientMiddle,
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
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 22),
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
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'توليد كروت جديدة',
                    style: GoogleFonts.cairo(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.2,
                    ),
                  ),
                  Text(
                    'إنشاء دفعة كروت هوتسبوت مايكروتك آمنة',
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
      ),
    );
  }

  Widget _buildMainBody() {
    // 1. Loading Packages
    if (_isLoadingPackages) {
      return Container(
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
              'جارٍ جلب باقات الإنترنت المتاحة...',
              style: GoogleFonts.cairo(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      );
    }

    // 2. Error Loading Packages
    if (_packagesError != null) {
      return Container(
        padding: const EdgeInsets.all(24),
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
              color: AppColors.shadowDark.withValues(alpha: 0.7),
              offset: const Offset(4, 4),
              blurRadius: 8,
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
              'فشل تحميل الباقات',
              style: GoogleFonts.cairo(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _packagesError!,
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 18),
            PressableNeumorphicCard(
              onTap: _loadPackages,
              borderRadius: BorderRadius.circular(14),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.heroGradientStart,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // 3. Empty Packages: User must add a package first
    if (_packages.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(26),
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
              color: AppColors.shadowDark.withValues(alpha: 0.7),
              offset: const Offset(4, 4),
              blurRadius: 8,
            ),
          ],
        ),
        child: Column(
          children: [
            const Icon(
              Icons.inventory_2_outlined,
              size: 54,
              color: AppColors.accentYellow,
            ),
            const SizedBox(height: 14),
            Text(
              'لا توجد باقات إنترنت معرّفة',
              style: GoogleFonts.cairo(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'لتتمكن من توليد كروت هوتسبوت جديدة، يجب أولاً إضافة باقة إنترنت واحدة على الأقل لتحديد السرعة والسعر ومدة الصلاحية.',
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textMuted,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            PressableNeumorphicCard(
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const PackagesScreen(),
                  ),
                );
                _loadPackages();
              },
              backgroundColor: AppColors.heroGradientStart,
              borderRadius: BorderRadius.circular(14),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.add_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'الذهاب لإضافة باقة إنترنت',
                    style: GoogleFonts.cairo(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // 4. Batch Generation Success Section
    if (_generatedBatch != null && _generatedCards != null) {
      return _buildSuccessSection();
    }

    // 5. Generation Form
    return _buildGenerationForm();
  }

  Widget _buildGenerationForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Title: Package Selection
        Padding(
          padding: const EdgeInsets.only(right: 4, bottom: 8),
          child: Text(
            'اختر باقة الإنترنت *',
            style: GoogleFonts.cairo(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
        ),

        // Neumorphic Dropdown Container
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.pageBg,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadowDark.withValues(alpha: 0.7),
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
            child: DropdownButton<PackageModel>(
              value: _selectedPackage,
              isExpanded: true,
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: AppColors.heroGradientStart,
              ),
              items: _packages.map((pkg) {
                return DropdownMenuItem<PackageModel>(
                  value: pkg,
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: pkg.isActive
                              ? AppColors.statusOnline
                              : AppColors.statusOffline,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${pkg.name} (${pkg.formattedSpeed})',
                          style: GoogleFonts.cairo(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                          ),
                        ),
                      ),
                      Text(
                        pkg.formattedPrice,
                        style: GoogleFonts.cairo(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppColors.heroGradientStart,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: _isGenerating
                  ? null
                  : (val) {
                      setState(() {
                        _selectedPackage = val;
                      });
                    },
            ),
          ),
        ),
        const SizedBox(height: 18),

        // Section Title: Router Selection
        Padding(
          padding: const EdgeInsets.only(right: 4, bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ربط بالراوتر (اختياري)',
                style: GoogleFonts.cairo(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              if (_isLoadingRouters)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.heroGradientStart,
                  ),
                ),
            ],
          ),
        ),

        // Neumorphic Router Dropdown Container
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.pageBg,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadowDark.withValues(alpha: 0.7),
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
            child: DropdownButton<String?>(
              value: _selectedRouter?.id,
              isExpanded: true,
              hint: Text(
                'بدون راوتر محدد (كروت عامة)',
                style: GoogleFonts.cairo(
                  fontSize: 13,
                  color: AppColors.textMuted,
                ),
              ),
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: AppColors.heroGradientStart,
              ),
              items: [
                DropdownMenuItem<String?>(
                  value: null,
                  child: Text(
                    'بدون راوتر محدد (كروت عامة)',
                    style: GoogleFonts.cairo(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
                ..._routers.map((router) {
                  return DropdownMenuItem<String?>(
                    value: router.id,
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: router.isOnline
                                ? AppColors.statusOnline
                                : AppColors.statusOffline,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '${router.name} (${router.host})',
                            style: GoogleFonts.cairo(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDark,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
              onChanged: _isGenerating
                  ? null
                  : (val) {
                      setState(() {
                        if (val == null) {
                          _selectedRouter = null;
                        } else {
                          _selectedRouter = _routers.firstWhere(
                            (r) => r.id == val,
                            orElse: () => _routers.first,
                          );
                        }
                      });
                    },
            ),
          ),
        ),
        const SizedBox(height: 18),

        // Generation Mode Selector (Phase 14)
        Text(
          'طريقة توليد الكروت *',
          style: GoogleFonts.cairo(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.shadowDark.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _isGenerating
                      ? null
                      : () => setState(() => _generationMode = 'USERNAME_AND_PASSWORD'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _generationMode == 'USERNAME_AND_PASSWORD'
                          ? Colors.white
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: _generationMode == 'USERNAME_AND_PASSWORD'
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'اسم مستخدم وكلمة مرور',
                      style: GoogleFonts.cairo(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: _generationMode == 'USERNAME_AND_PASSWORD'
                            ? AppColors.heroGradientStart
                            : AppColors.textMuted,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: _isGenerating
                      ? null
                      : () => setState(() {
                            _generationMode = 'NUMBERS_ONLY';
                            if (_userLengthController.text == '6') {
                              _userLengthController.text = '8';
                            }
                          }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _generationMode == 'NUMBERS_ONLY'
                          ? Colors.white
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: _generationMode == 'NUMBERS_ONLY'
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'أرقام فقط (بدون كلمة سر)',
                      style: GoogleFonts.cairo(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: _generationMode == 'NUMBERS_ONLY'
                            ? AppColors.heroGradientStart
                            : AppColors.textMuted,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Quantity Field
        NeumorphicTextField(
          label: 'عدد الكروت المطلوب توليدها (الكمية) *',
          hintText: 'أدخل رقماً بين 1 و 1000 كرت',
          controller: _quantityController,
          keyboardType: TextInputType.number,
          enabled: !_isGenerating,
          textDirection: TextDirection.ltr,
          prefixIcon: const Icon(
            Icons.format_list_numbered_rounded,
            color: AppColors.heroGradientStart,
            size: 20,
          ),
        ),
        const SizedBox(height: 8),

        // Quick Preset Chips for Quantity
        Row(
          children: [10, 25, 50, 100, 200].map((qty) {
            return Padding(
              padding: const EdgeInsets.only(left: 6),
              child: InkWell(
                onTap: _isGenerating
                    ? null
                    : () {
                        setState(() {
                          _quantityController.text = qty.toString();
                        });
                      },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.pageBg,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.shadowDark.withValues(alpha: 0.4),
                        offset: const Offset(1, 1),
                        blurRadius: 2,
                      ),
                      const BoxShadow(
                        color: AppColors.shadowLight,
                        offset: Offset(-1, -1),
                        blurRadius: 2,
                      ),
                    ],
                  ),
                  child: Text(
                    '+$qty',
                    style: GoogleFonts.cairo(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.heroGradientStart,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 18),

        // Prefix Field
        NeumorphicTextField(
          label: 'بادئة اسم المستخدم (اختياري)',
          hintText: 'مثال: VIP أو HOT أو NET',
          controller: _prefixController,
          enabled: !_isGenerating,
          textDirection: TextDirection.ltr,
          prefixIcon: const Icon(
            Icons.title_rounded,
            color: AppColors.heroGradientStart,
            size: 20,
          ),
        ),
        const SizedBox(height: 14),

        // Advanced Settings Toggle
        InkWell(
          onTap: () {
            setState(() {
              _showAdvancedSettings = !_showAdvancedSettings;
            });
          },
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
            child: Row(
              children: [
                Icon(
                  _showAdvancedSettings
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: AppColors.heroGradientStart,
                  size: 20,
                ),
                const SizedBox(width: 6),
                Text(
                  'إعدادات متقدمة لأطوال الحسابات وكلمات المرور',
                  style: GoogleFonts.cairo(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.heroGradientStart,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Advanced Options Form
        if (_showAdvancedSettings) ...[
          const SizedBox(height: 12),
          if (_generationMode == 'NUMBERS_ONLY') ...[
            NeumorphicTextField(
              label: 'طول رقم الكرت (عدد الأرقام)',
              hintText: 'افتراضي: 8 أرقام',
              controller: _userLengthController,
              keyboardType: TextInputType.number,
              enabled: !_isGenerating,
              textDirection: TextDirection.ltr,
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: NeumorphicTextField(
                    label: 'طول اسم المستخدم',
                    hintText: 'افتراضي: 6',
                    controller: _userLengthController,
                    keyboardType: TextInputType.number,
                    enabled: !_isGenerating,
                    textDirection: TextDirection.ltr,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: NeumorphicTextField(
                    label: 'طول كلمة السر (PIN)',
                    hintText: 'افتراضي: 4',
                    controller: _passwordLengthController,
                    keyboardType: TextInputType.number,
                    enabled: !_isGenerating,
                    textDirection: TextDirection.ltr,
                  ),
                ),
              ],
            ),
          ],
        ],

        // Error message if generation failed
        if (_generationError != null) ...[
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.statusOffline.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.statusOffline.withValues(alpha: 0.35),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: AppColors.statusOffline,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _generationError!,
                    style: GoogleFonts.cairo(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.statusOffline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        // Sync / Generation Progress Indicator
        if (_isGenerating && _syncStatusMessage != null) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.heroGradientStart.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.heroGradientStart.withValues(alpha: 0.25),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.heroGradientStart,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _syncStatusMessage!,
                        style: GoogleFonts.cairo(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.heroGradientStart,
                        ),
                      ),
                    ),
                  ],
                ),
                if (_syncProgressTotal > 0) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: _syncProgressCurrent / _syncProgressTotal,
                      backgroundColor: AppColors.heroGradientStart.withValues(alpha: 0.15),
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.heroGradientStart),
                      minHeight: 6,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
        const SizedBox(height: 26),

        // Generate Action Button
        BounceButton(
          onPressed: _isGenerating ? null : _generateBatch,
          isLoading: _isGenerating,
          height: 54,
          backgroundColor: AppColors.accentYellow,
          textColor: AppColors.textDark,
          gradient: const LinearGradient(
            colors: [Color(0xFFF5C94B), Color(0xFFE5B535)],
          ),
          icon: Icons.bolt_rounded,
          label: _isGenerating
              ? (_syncStatusMessage ?? 'جارٍ توليد وتشفير الكروت بأمان...')
              : 'بدء توليد دفعة الكروت الآن',
        ),
      ],
    );
  }

  Widget _buildRouterSyncCard() {
    final sync = _syncResult;
    if (sync == null) return const SizedBox.shrink();

    final isAllSynced = sync.success;
    final color = isAllSynced ? AppColors.statusOnline : const Color(0xFFD97706);

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: 0.35),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isAllSynced ? Icons.check_circle_rounded : Icons.sync_problem_rounded,
                color: color,
                size: 24,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isAllSynced
                      ? 'تمت مزامنة جميع الكروت (${sync.syncedCount}/${sync.totalCount}) بالراوتر بنجاح!'
                      : 'مزامنة جزئية بالراوتر: تم رفع ${sync.syncedCount} كرت، وتوجد ${sync.failedCount} كروت معلقة.',
                  style: GoogleFonts.cairo(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
              ),
            ],
          ),
          if (sync.errorMessage != null && !isAllSynced) ...[
            const SizedBox(height: 8),
            Text(
              sync.errorMessage!,
              style: GoogleFonts.cairo(
                fontSize: 12,
                color: AppColors.textMuted,
              ),
            ),
          ],
          if (!isAllSynced && _selectedRouter != null) ...[
            const SizedBox(height: 12),
            PressableNeumorphicCard(
              onTap: _isResyncing ? null : _resyncPendingCards,
              backgroundColor: AppColors.pageBg,
              borderRadius: BorderRadius.circular(12),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_isResyncing) ...[
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.heroGradientStart,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _syncStatusMessage ?? 'جارٍ فحص الراوتر وإعادة المزامنة...',
                      style: GoogleFonts.cairo(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.heroGradientStart,
                      ),
                    ),
                  ] else ...[
                    const Icon(
                      Icons.sync_rounded,
                      color: AppColors.heroGradientStart,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'إعادة مزامنة الكروت المعلّقة بالراوتر',
                      style: GoogleFonts.cairo(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.heroGradientStart,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSuccessSection() {
    final batch = _generatedBatch!;
    final cards = _generatedCards!;
    final previewCards = cards.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Success Header Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.statusOnline.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.statusOnline.withValues(alpha: 0.35),
              width: 1.2,
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.statusOnline.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.statusOnline,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'تم توليد الكروت بنجاح! 🎉',
                          style: GoogleFonts.cairo(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textDark,
                          ),
                        ),
                        Text(
                          'تم إنشاء وحفظ ${cards.length} كرت جديد بالحالة الابتدائية (GENERATED)',
                          style: GoogleFonts.cairo(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(height: 1, thickness: 0.8),
              const SizedBox(height: 14),

              // Batch Summary Details
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildSummaryItem(
                    label: 'رقم الدفعة',
                    value: batch.batchNumber,
                    icon: Icons.tag_rounded,
                  ),
                  _buildSummaryItem(
                    label: 'الكمية الفعلية',
                    value: '${cards.length} كرت',
                    icon: Icons.credit_card_rounded,
                  ),
                  if (batch.totalPrice > 0)
                    _buildSummaryItem(
                      label: 'إجمالي القيمة',
                      value: '${batch.formattedTotalPrice} SDG',
                      icon: Icons.payments_rounded,
                    ),
                ],
              ),
            ],
          ),
        ),
        _buildRouterSyncCard(),
        const SizedBox(height: 22),

        // Section Title: Preview
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'معاينة أول ${previewCards.length} كروت مولّدة:',
              style: GoogleFonts.cairo(
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
              ),
            ),
            Text(
              'قابلة للنسخ المباشر',
              style: GoogleFonts.cairo(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Preview Cards List
        ...previewCards.asMap().entries.map((entry) {
          final int index = entry.key + 1;
          final CardModel card = entry.value;

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.pageBg,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                const BoxShadow(
                  color: AppColors.shadowLight,
                  offset: Offset(-2, -2),
                  blurRadius: 4,
                ),
                BoxShadow(
                  color: AppColors.shadowDark.withValues(alpha: 0.6),
                  offset: const Offset(2, 2),
                  blurRadius: 4,
                ),
              ],
            ),
            child: Row(
              children: [
                // Index Circle
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.heroGradientStart.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$index',
                    style: GoogleFonts.cairo(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.heroGradientStart,
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Username & Password
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'المستخدم: ',
                            style: GoogleFonts.cairo(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textMuted,
                            ),
                          ),
                          SelectableText(
                            card.username,
                            style: GoogleFonts.cairo(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textDark,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.copy_rounded,
                              size: 15,
                              color: AppColors.heroGradientStart,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            tooltip: 'نسخ اسم المستخدم',
                            onPressed: () => _copyToClipboard(
                              card.username,
                              'اسم المستخدم',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      if (card.password.isNotEmpty) ...[
                        Row(
                          children: [
                            Text(
                              'المرور: ',
                              style: GoogleFonts.cairo(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textMuted,
                              ),
                            ),
                            SelectableText(
                              card.password,
                              style: GoogleFonts.cairo(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textDark,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.copy_rounded,
                                size: 15,
                                color: AppColors.accentYellow,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              tooltip: 'نسخ كلمة المرور',
                              onPressed: () => _copyToClipboard(
                                card.password,
                                'كلمة المرور',
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.heroGradientStart.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'أرقام فقط (بدون كلمة سر)',
                                style: GoogleFonts.cairo(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.heroGradientStart,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                // Status Badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: card.statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    card.statusTextArabic,
                    style: GoogleFonts.cairo(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: card.statusColor,
                    ),
                  ),
                ),

                // Router Sync Badge
                if (_syncResult != null) ...[
                  Builder(
                    builder: (context) {
                      final isCardSynced = _syncResult!.items.any(
                        (it) => (it.cardId == card.id || it.username == card.username) && it.isSynced,
                      );
                      return Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        decoration: BoxDecoration(
                          color: isCardSynced
                              ? AppColors.statusOnline.withValues(alpha: 0.15)
                              : const Color(0xFFD97706).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isCardSynced ? 'بالراوتر ✓' : 'معلّق ⏳',
                          style: GoogleFonts.cairo(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: isCardSynced ? AppColors.statusOnline : const Color(0xFFD97706),
                          ),
                        ),
                      );
                    },
                  ),
                ],
                const SizedBox(width: 6),

                // Voucher Preview Button
                IconButton(
                  icon: const Icon(
                    Icons.qr_code_2_rounded,
                    size: 20,
                    color: AppColors.heroGradientStart,
                  ),
                  tooltip: 'معاينة بطاقة الكرت',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => _showVoucherPreview(card),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 18),

        // PDF Export / Share Full Batch Button
        PressableNeumorphicCard(
          onTap: _isExportingPdf ? null : _exportBatchPdf,
          backgroundColor: AppColors.accentYellow,
          borderRadius: BorderRadius.circular(16),
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isExportingPdf) ...[
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'جارٍ تجهيز ملف PDF للدفعة...',
                  style: GoogleFonts.cairo(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
              ] else ...[
                const Icon(
                  Icons.picture_as_pdf_rounded,
                  color: AppColors.textDark,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'تحميل / مشاركة PDF لكل الدفعة (${cards.length} كرت)',
                  style: GoogleFonts.cairo(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Action Buttons Row
        Row(
          children: [
            // View All Cards Button
            Expanded(
              flex: 3,
              child: PressableNeumorphicCard(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => CardsListScreen(
                        initialBatchId: batch.id,
                      ),
                    ),
                  );
                },
                backgroundColor: AppColors.heroGradientStart,
                borderRadius: BorderRadius.circular(16),
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.format_list_bulleted_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'عرض كل الكروت',
                      style: GoogleFonts.cairo(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),

            // Generate Another Batch Button
            Expanded(
              flex: 2,
              child: PressableNeumorphicCard(
                onTap: _resetForNewBatch,
                backgroundColor: AppColors.pageBg,
                borderRadius: BorderRadius.circular(16),
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.add_rounded,
                      color: AppColors.textDark,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'دفعة أخرى',
                      style: GoogleFonts.cairo(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryItem({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Column(
      children: [
        Icon(icon, size: 18, color: AppColors.heroGradientStart),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.cairo(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textMuted,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.cairo(
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            color: AppColors.textDark,
          ),
        ),
      ],
    );
  }
}
