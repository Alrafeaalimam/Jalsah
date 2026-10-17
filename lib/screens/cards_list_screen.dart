// ============================================================================
// Platform: Commercial MikroTik Network & HotSpot Card Management System
// File: lib/screens/cards_list_screen.dart
// Screen: Cards List Screen with 4 States, Filters, and Neumorphic Design
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/card_model.dart';
import '../models/package_model.dart';
import '../services/api_client.dart';
import '../services/card_pdf_service.dart';
import '../theme/app_colors.dart';
import '../widgets/card_voucher_widget.dart';
import '../widgets/pressable_neumorphic_card.dart';
import 'generate_cards_screen.dart';

class CardsListScreen extends StatefulWidget {
  final String? initialBatchId;
  final String? initialStatus;

  const CardsListScreen({
    super.key,
    this.initialBatchId,
    this.initialStatus,
  });

  @override
  State<CardsListScreen> createState() => _CardsListScreenState();
}

class _CardsListScreenState extends State<CardsListScreen> {
  List<CardModel> _cards = [];
  bool _isLoading = true;
  String? _errorMessage;
  late String _selectedStatus;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selectedCardIds = {};
  bool _isSubmittingSale = false;
  bool _isExportingPdf = false;
  Map<String, PackageModel> _packagesMap = {};

  static const List<Map<String, String>> _statusFilters = [
    {'key': 'ALL', 'label': 'الكل'},
    {'key': 'GENERATED', 'label': 'تم التوليد'},
    {'key': 'AVAILABLE', 'label': 'متاح للبيع'},
    {'key': 'ACTIVE', 'label': 'نشط'},
    {'key': 'SOLD', 'label': 'تم البيع'},
    {'key': 'EXPIRED', 'label': 'منتهي'},
    {'key': 'CANCELLED', 'label': 'ملغي'},
  ];

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.initialStatus ?? 'ALL';
    _loadCards();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  double get _selectedCardsTotalPrice {
    double sum = 0.0;
    for (final card in _cards) {
      if (_selectedCardIds.contains(card.id)) {
        sum += card.price;
      }
    }
    return sum;
  }

  Future<void> _loadCards() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final String? filterStatus =
        _selectedStatus == 'ALL' ? null : _selectedStatus;
    final result = await ApiClient.getCards(
      status: filterStatus,
      batchId: widget.initialBatchId,
    );

    if (!mounted) return;

    if (result['success'] == true) {
      setState(() {
        _cards = (result['data'] as List<dynamic>).cast<CardModel>();
        _selectedCardIds.removeWhere(
          (id) => !_cards.any(
            (c) => c.id == id && c.status.toUpperCase() == 'AVAILABLE',
          ),
        );
        _isLoading = false;
        _errorMessage = null;
      });

      // Lazily load packages map for rich voucher previews if empty
      if (_packagesMap.isEmpty) {
        ApiClient.getPackages().then((pkgRes) {
          if (mounted && pkgRes['success'] == true) {
            final pkgs = (pkgRes['data'] as List<dynamic>).cast<PackageModel>();
            setState(() {
              _packagesMap = {for (final p in pkgs) p.id: p};
            });
          }
        });
      }
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage =
            result['errorMessage'] ?? 'تعذر الاتصال بالخادم لجلب قائمة الكروت';
      });
    }
  }

  void _showCardVoucherModal(CardModel card) {
    final pkg = _packagesMap[card.packageId];
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
                package: pkg,
              ),
              const SizedBox(height: 20),
              PressableNeumorphicCard(
                onTap: () {
                  Navigator.of(ctx).pop();
                  CardPdfService.shareSingleCardPdf(
                    card: card,
                    package: pkg,
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


  void _onStatusFilterSelected(String statusKey) {
    if (_selectedStatus == statusKey) return;
    setState(() {
      _selectedStatus = statusKey;
    });
    _loadCards();
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

  List<CardModel> get _filteredCards {
    if (_searchQuery.trim().isEmpty) return _cards;
    final q = _searchQuery.trim().toLowerCase();
    return _cards.where((c) {
      return c.username.toLowerCase().contains(q) ||
          c.password.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final int generatedCount =
        _cards.where((c) => c.status.toUpperCase() == 'GENERATED').length;
    final int availableCount =
        _cards.where((c) => c.status.toUpperCase() == 'AVAILABLE').length;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.pageBg,
        body: Column(
          children: [
            // Top Hero Banner
            _buildTopBanner(
              totalCount: _cards.length,
              generatedCount: generatedCount,
              availableCount: availableCount,
            ),

            // Search Bar & Filter Chips
            _buildFiltersSection(),

            // Main Content Area (4 States)
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadCards,
                color: AppColors.heroGradientStart,
                backgroundColor: AppColors.pageBg,
                child: _buildContent(),
              ),
            ),
          ],
        ),
        bottomNavigationBar: _selectedCardIds.isNotEmpty
            ? _buildFloatingBottomBar()
            : null,
      ),
    );
  }


  Widget _buildTopBanner({
    required int totalCount,
    required int generatedCount,
    required int availableCount,
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
              // Navigation & Title Row
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
                              Row(
                                children: [
                                  Text(
                                    'كروت الهوتسبوت',
                                    style: GoogleFonts.cairo(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                  if (widget.initialBatchId != null) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.accentYellow,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        'دفعة محددة',
                                        style: GoogleFonts.cairo(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.textDark,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              Text(
                                'إدارة ومتابعة كروت شبكة المايكروتك',
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

                  // Actions: Export PDF & Generate Cards
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildExportPdfButton(),
                      const SizedBox(width: 6),
                      _buildGenerateCardsButton(),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Stat Cards Row
              Row(
                children: [
                  // Total Cards Stat
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
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
                          Text(
                            'إجمالي الكروت',
                            style: GoogleFonts.cairo(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$totalCount كرت',
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

                  // Generated Stat
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
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
                          Text(
                            'جديدة / مولدة',
                            style: GoogleFonts.cairo(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$generatedCount كرت',
                            style: GoogleFonts.cairo(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.accentYellow,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Available Stat
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
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
                          Text(
                            'متاحة للبيع',
                            style: GoogleFonts.cairo(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$availableCount كرت',
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

  void _showEmptyExportPdfMessage() {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.heroGradientStart,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(
          children: [
            const Icon(
              Icons.info_outline_rounded,
              color: AppColors.accentYellow,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'لا توجد كروت متاحة للتصدير في هذه القائمة',
                style: GoogleFonts.cairo(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportCurrentCardsPdf() async {
    final cardsToExport = _filteredCards;
    if (cardsToExport.isEmpty) {
      _showEmptyExportPdfMessage();
      return;
    }

    setState(() {
      _isExportingPdf = true;
    });

    try {
      if (_packagesMap.isEmpty) {
        try {
          final pkgRes = await ApiClient.getPackages();
          if (mounted && pkgRes['success'] == true) {
            final pkgs = (pkgRes['data'] as List<dynamic>).cast<PackageModel>();
            _packagesMap = {for (final p in pkgs) p.id: p};
          }
        } catch (_) {}
      }

      final activeBatchName = widget.initialBatchId != null
          ? 'batch-${widget.initialBatchId}'
          : 'status-$_selectedStatus';

      await CardPdfService.shareBatchCardsPdf(
        cards: cardsToExport,
        packagesMap: _packagesMap,
        batchNumber: activeBatchName,
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
              style: GoogleFonts.cairo(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
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

  Widget _buildExportPdfButton() {
    final bool isEmpty = _filteredCards.isEmpty;
    final bool isDisabled = isEmpty || _isExportingPdf;

    return Tooltip(
      message: isEmpty
          ? 'القائمة فارغة، لا توجد كروت للتصدير'
          : 'تصدير كل الكروت المعروضة كملف PDF',
      child: InkWell(
        key: const Key('export_pdf_button'),
        onTap: isDisabled
            ? () {
                if (isEmpty) {
                  _showEmptyExportPdfMessage();
                }
              }
            : _exportCurrentCardsPdf,
        borderRadius: BorderRadius.circular(14),
        child: Opacity(
          opacity: isDisabled ? 0.45 : 1.0,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 7,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.25),
                width: 1.2,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isExportingPdf)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                else
                  const Icon(
                    Icons.picture_as_pdf_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                const SizedBox(width: 4),
                Text(
                  _isExportingPdf ? 'جارٍ التصدير...' : 'تصدير PDF',
                  style: GoogleFonts.cairo(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGenerateCardsButton() {
    return InkWell(
      key: const Key('generate_cards_button'),
      onTap: () async {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const GenerateCardsScreen(),
          ),
        );
        _loadCards();
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 7,
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
              Icons.add_rounded,
              size: 16,
              color: AppColors.textDark,
            ),
            const SizedBox(width: 4),
            Text(
              'توليد كروت',
              style: GoogleFonts.cairo(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFiltersSection() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        children: [
          // Search input box
          Container(
            height: 44,
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
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                });
              },
              style: GoogleFonts.cairo(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
              decoration: InputDecoration(
                hintText: 'البحث باسم المستخدم أو كلمة المرور...',
                hintStyle: GoogleFonts.cairo(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textMuted,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  size: 20,
                  color: AppColors.textMuted,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.clear_rounded,
                          size: 18,
                          color: AppColors.textMuted,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Horizontal Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _statusFilters.map((filter) {
                final isSelected = _selectedStatus == filter['key'];
                return Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: InkWell(
                    onTap: () => _onStatusFilterSelected(filter['key']!),
                    borderRadius: BorderRadius.circular(12),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.heroGradientStart
                            : AppColors.pageBg,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: AppColors.heroGradientStart
                                      .withValues(alpha: 0.35),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : [
                                BoxShadow(
                                  color: AppColors.shadowDark
                                      .withValues(alpha: 0.5),
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
                        filter['label']!,
                        style: GoogleFonts.cairo(
                          fontSize: 12,
                          fontWeight: isSelected
                              ? FontWeight.w800
                              : FontWeight.w600,
                          color: isSelected ? Colors.white : AppColors.textDark,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
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
                  'جارٍ تحميل كروت الهوتسبوت...',
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
                  'تعذر جلب بيانات الكروت',
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
                  onTap: _loadCards,
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
          ),
        ],
      );
    }

    final displayCards = _filteredCards;

    // 3. Empty State
    if (displayCards.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: AppColors.pageBg,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                const BoxShadow(
                  color: AppColors.shadowLight,
                  offset: Offset(-3, -3),
                  blurRadius: 6,
                ),
                BoxShadow(
                  color: AppColors.shadowDark.withValues(alpha: 0.6),
                  offset: const Offset(3, 3),
                  blurRadius: 6,
                ),
              ],
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.credit_card_off_rounded,
                  size: 52,
                  color: AppColors.textMuted,
                ),
                const SizedBox(height: 14),
                Text(
                  _searchQuery.isNotEmpty
                      ? 'لا توجد نتائج مطابقة لبحثك'
                      : 'لا توجد كروت في هذه القائمة',
                  style: GoogleFonts.cairo(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _searchQuery.isNotEmpty
                      ? 'جرب البحث بكلمة مختلفة أو قم بإلغاء الفلتر الحالي'
                      : 'ابدأ الآن بتوليد دفعة جديدة من كروت الهوتسبوت للشبكة.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cairo(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 20),
                PressableNeumorphicCard(
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const GenerateCardsScreen(),
                      ),
                    );
                    _loadCards();
                  },
                  backgroundColor: AppColors.accentYellow,
                  borderRadius: BorderRadius.circular(14),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 11,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.bolt_rounded,
                        size: 20,
                        color: AppColors.textDark,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'توليد كروت جديدة',
                        style: GoogleFonts.cairo(
                          fontSize: 13.5,
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
      );
    }

    // 4. Data State
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: displayCards.length,
      itemBuilder: (context, index) {
        final card = displayCards[index];
        return _buildCardItem(card);
      },
    );
  }

  Widget _buildCardItem(CardModel card) {
    final bool isAvailable = card.status.toUpperCase() == 'AVAILABLE';
    final bool isSelected = _selectedCardIds.contains(card.id);

    return InkWell(
      onTap: isAvailable
          ? () {
              setState(() {
                if (isSelected) {
                  _selectedCardIds.remove(card.id);
                } else {
                  _selectedCardIds.add(card.id);
                }
              });
            }
          : null,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.heroGradientStart.withValues(alpha: 0.05)
              : AppColors.pageBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? AppColors.heroGradientStart
                : Colors.transparent,
            width: 1.5,
          ),
          boxShadow: [
            const BoxShadow(
              color: AppColors.shadowLight,
              offset: Offset(-3, -3),
              blurRadius: 6,
            ),
            BoxShadow(
              color: AppColors.shadowDark.withValues(alpha: 0.65),
              offset: const Offset(3, 3),
              blurRadius: 6,
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Checkbox (if AVAILABLE), Status badge and Price
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    if (isAvailable) ...[
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: Checkbox(
                          value: isSelected,
                          activeColor: AppColors.heroGradientStart,
                          checkColor: AppColors.accentYellow,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(5),
                          ),
                          side: BorderSide(
                            color: isSelected
                                ? AppColors.heroGradientStart
                                : AppColors.textMuted.withValues(alpha: 0.6),
                            width: 1.5,
                          ),
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                _selectedCardIds.add(card.id);
                              } else {
                                _selectedCardIds.remove(card.id);
                              }
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],

                    // Status Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: card.statusColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: card.statusColor.withValues(alpha: 0.35),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: card.statusColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            card.statusTextArabic,
                            style: GoogleFonts.cairo(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: card.statusColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Creation Info / Price & QR Voucher Action
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (card.price > 0) ...[
                      Text(
                        '${card.formattedPrice} SDG',
                        style: GoogleFonts.cairo(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.heroGradientStart,
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    IconButton(
                      icon: const Icon(
                        Icons.qr_code_2_rounded,
                        size: 20,
                        color: AppColors.heroGradientStart,
                      ),
                      tooltip: 'معاينة وطباعة بطاقة الكرت',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => _showCardVoucherModal(card),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Username Row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.heroGradientStart.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    size: 18,
                    color: AppColors.heroGradientStart,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'اسم المستخدم (User)',
                        style: GoogleFonts.cairo(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted,
                        ),
                      ),
                      SelectableText(
                        card.username,
                        style: GoogleFonts.cairo(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.copy_rounded,
                    size: 18,
                    color: AppColors.heroGradientStart,
                  ),
                  tooltip: 'نسخ اسم المستخدم',
                  onPressed: () => _copyToClipboard(card.username, 'اسم المستخدم'),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Password Row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.accentYellow.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.lock_outline_rounded,
                    size: 18,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'كلمة المرور (PIN)',
                        style: GoogleFonts.cairo(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted,
                        ),
                      ),
                      SelectableText(
                        card.password,
                        style: GoogleFonts.cairo(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.copy_rounded,
                    size: 18,
                    color: AppColors.textDark,
                  ),
                  tooltip: 'نسخ كلمة المرور',
                  onPressed: () => _copyToClipboard(card.password, 'كلمة المرور'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingBottomBar() {
    final count = _selectedCardIds.length;
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: PressableNeumorphicCard(
          onTap: _showSaleBottomSheet,
          backgroundColor: AppColors.accentYellow,
          borderRadius: BorderRadius.circular(16),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.textDark.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.point_of_sale_rounded,
                  size: 20,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'بيع ($count) ${count == 1 ? 'كرت' : 'كروت'}',
                style: GoogleFonts.cairo(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
              ),
              const Spacer(),
              if (_selectedCardsTotalPrice > 0) ...[
                Text(
                  '${_selectedCardsTotalPrice.toStringAsFixed(0)} SDG',
                  style: GoogleFonts.cairo(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              const Icon(
                Icons.arrow_back_ios_rounded,
                size: 14,
                color: AppColors.textDark,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSaleBottomSheet() {
    String selectedPaymentMethod = 'CASH';

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: Container(
                padding: EdgeInsets.fromLTRB(
                  20,
                  20,
                  20,
                  MediaQuery.of(context).viewInsets.bottom + 24,
                ),
                decoration: const BoxDecoration(
                  color: AppColors.pageBg,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 20,
                      offset: Offset(0, -5),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle bar
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.textMuted.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Title
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'إتمام عملية البيع',
                          style: GoogleFonts.cairo(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textDark,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          color: AppColors.textMuted,
                          onPressed: () => Navigator.of(sheetContext).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Summary Card
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.heroGradientStart.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.heroGradientStart.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'عدد الكروت المحددة: ${_selectedCardIds.length}',
                            style: GoogleFonts.cairo(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.heroGradientStart,
                            ),
                          ),
                          Text(
                            'الإجمالي: ${_selectedCardsTotalPrice.toStringAsFixed(0)} SDG',
                            style: GoogleFonts.cairo(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppColors.heroGradientStart,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    Text(
                      'طريقة الدفع',
                      style: GoogleFonts.cairo(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Payment options
                    _buildPaymentOption(
                      label: 'نقداً (كاش)',
                      value: 'CASH',
                      icon: Icons.payments_rounded,
                      groupValue: selectedPaymentMethod,
                      onChanged: (val) {
                        setSheetState(() {
                          selectedPaymentMethod = val!;
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    _buildPaymentOption(
                      label: 'تحويل بنكي (بنكك / فوري)',
                      value: 'BANK_TRANSFER',
                      icon: Icons.account_balance_rounded,
                      groupValue: selectedPaymentMethod,
                      onChanged: (val) {
                        setSheetState(() {
                          selectedPaymentMethod = val!;
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    _buildPaymentOption(
                      label: 'محفظة إلكترونية',
                      value: 'MOBILE_MONEY',
                      icon: Icons.phone_android_rounded,
                      groupValue: selectedPaymentMethod,
                      onChanged: (val) {
                        setSheetState(() {
                          selectedPaymentMethod = val!;
                        });
                      },
                    ),
                    const SizedBox(height: 22),

                    // Confirm Button
                    SizedBox(
                      width: double.infinity,
                      child: PressableNeumorphicCard(
                        onTap: _isSubmittingSale
                            ? null
                            : () async {
                                Navigator.of(sheetContext).pop();
                                await _performSale(selectedPaymentMethod);
                              },
                        backgroundColor: AppColors.accentYellow,
                        borderRadius: BorderRadius.circular(14),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Center(
                          child: Text(
                            'تأكيد البيع',
                            style: GoogleFonts.cairo(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textDark,
                            ),
                          ),
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

  Widget _buildPaymentOption({
    required String label,
    required String value,
    required IconData icon,
    required String groupValue,
    required ValueChanged<String?> onChanged,
  }) {
    final isSelected = value == groupValue;
    return InkWell(
      onTap: () => onChanged(value),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.accentYellow.withValues(alpha: 0.15)
              : AppColors.pageBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? AppColors.accentYellow
                : AppColors.textMuted.withValues(alpha: 0.2),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? AppColors.textDark : AppColors.textMuted,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.cairo(
                  fontSize: 13.5,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
            ),
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? AppColors.heroGradientStart
                      : AppColors.textMuted.withValues(alpha: 0.5),
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.heroGradientStart,
                        ),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }


  Future<void> _performSale(String paymentMethod) async {
    setState(() {
      _isSubmittingSale = true;
    });

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.heroGradientStart,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
            const SizedBox(width: 10),
            Text(
              'جارٍ إتمام عملية البيع...',
              style: GoogleFonts.cairo(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );

    final cardIdsToSell = _selectedCardIds.toList();
    final count = cardIdsToSell.length;

    final result = await ApiClient.createSale(
      cardIds: cardIdsToSell,
      paymentMethod: paymentMethod,
    );

    if (!mounted) return;

    setState(() {
      _isSubmittingSale = false;
    });

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    if (result['success'] == true) {
      setState(() {
        _selectedCardIds.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.statusOnline,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'تم بيع $count ${count == 1 ? 'كرت' : 'كروت'} بنجاح!',
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

      _loadCards();
    } else {
      final err = result['errorMessage'] ?? 'فشل إتمام عملية البيع';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.statusOffline,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
}

