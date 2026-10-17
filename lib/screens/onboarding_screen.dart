// ============================================================================
// Platform: Commercial MikroTik Network & HotSpot Card Management System (Jalsah)
// File: lib/screens/onboarding_screen.dart
// Screen: 3-step Onboarding Flow with Neumorphic Styling & Preference Persistence
// Master Reference: Rule 20 (Frontend), Jalsah Branding
// ============================================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_client.dart';
import '../theme/app_colors.dart';
import 'admin/super_admin_dashboard.dart';
import 'dashboard_screen.dart';
import 'temp_login_screen.dart';

class OnboardingPageData {
  final String title;
  final String description;
  final String imagePath;

  const OnboardingPageData({
    required this.title,
    required this.description,
    required this.imagePath,
  });
}

class OnboardingScreen extends StatefulWidget {
  final Widget? nextScreenOverride;
  final VoidCallback? onFinished;

  const OnboardingScreen({
    super.key,
    this.nextScreenOverride,
    this.onFinished,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isCompleting = false;

  final List<OnboardingPageData> _pages = const [
    OnboardingPageData(
      title: 'تحكم كامل في شبكتك',
      description:
          'من مكان واحد، دير كل أجهزة MikroTik وراقب حالتها لحظة بلحظة',
      imagePath: 'assets/onboarding/1.jpg',
    ),
    OnboardingPageData(
      title: 'ولّد وبيع الكروت بسهولة',
      description:
          'أنشئ كروت الإنترنت بضغطة واحدة وتابع مبيعاتك أول بأول',
      imagePath: 'assets/onboarding/2.jpg',
    ),
    OnboardingPageData(
      title: 'راقب شبكتك أينما كنت',
      description:
          'تابع أجهزتك وشبكات Starlink من موبايلك في أي وقت',
      imagePath: 'assets/onboarding/3.jpg',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    if (_isCompleting) return;
    setState(() => _isCompleting = true);

    try {
      final prefs = await SharedPreferences.getInstance().timeout(
        const Duration(seconds: 1),
      );
      await prefs.setBool('has_seen_onboarding', true);
    } catch (e) {
      debugPrint('Failed to save onboarding preference: $e');
    }

    if (!mounted) return;

    if (widget.onFinished != null) {
      widget.onFinished!();
      return;
    }

    if (widget.nextScreenOverride != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => widget.nextScreenOverride!),
      );
      return;
    }

    // Check saved token to determine auth destination
    String? savedToken;
    try {
      savedToken = await ApiClient.loadSavedToken().timeout(
        const Duration(seconds: 1),
        onTimeout: () => null,
      );
    } catch (e) {
      debugPrint('Error loading saved token: $e');
    }

    final bool hasValidToken =
        (savedToken != null && savedToken.isNotEmpty) || ApiClient.isAuthenticated;

    if (!mounted) return;

    final Widget destination;
    if (hasValidToken && ApiClient.isSuperAdmin) {
      destination = const SuperAdminDashboardScreen();
    } else if (hasValidToken) {
      destination = const DashboardScreen();
    } else {
      destination = const TempLoginScreen();
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => destination),
    );
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  Widget _buildTopHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Brand badge
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.pageBg,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    const BoxShadow(
                      color: AppColors.shadowLight,
                      offset: Offset(-2, -2),
                      blurRadius: 6,
                    ),
                    BoxShadow(
                      color: AppColors.shadowDark.withValues(alpha: 0.6),
                      offset: const Offset(2, 2),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.asset(
                    'assets/icon/logo.jpg',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.wifi_tethering_rounded,
                      size: 22,
                      color: AppColors.heroGradientStart,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Jalsah | جلسة',
                style: GoogleFonts.cairo(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.heroGradientStart,
                ),
              ),
            ],
          ),

          // Skip button (visible on pages 0 and 1)
          if (_currentPage < _pages.length - 1)
            TextButton(
              onPressed: _completeOnboarding,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textMuted,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'تخطي',
                    style: GoogleFonts.cairo(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 12,
                    color: AppColors.textMuted,
                  ),
                ],
              ),
            )
          else
            const SizedBox(width: 60),
        ],
      ),
    );
  }

  Widget _buildPageItem(OnboardingPageData item) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 8),
          // Large Visual Image Container
          Expanded(
            flex: 6,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.pageBg,
                borderRadius: BorderRadius.circular(26),
                boxShadow: [
                  const BoxShadow(
                    color: AppColors.shadowLight,
                    offset: Offset(-8, -8),
                    blurRadius: 18,
                  ),
                  BoxShadow(
                    color: AppColors.shadowDark.withValues(alpha: 0.75),
                    offset: const Offset(8, 8),
                    blurRadius: 18,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(26),
                child: Image.asset(
                  item.imagePath,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: AppColors.heroGradientStart.withValues(alpha: 0.08),
                    child: Center(
                      child: Icon(
                        Icons.image_outlined,
                        size: 72,
                        color: AppColors.heroGradientStart.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),
          // Text Content Area
          Expanded(
            flex: 3,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cairo(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    item.description,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.cairo(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textMuted,
                      height: 1.6,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDotsIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_pages.length, (index) {
        final bool isActive = _currentPage == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          height: 8,
          width: isActive ? 28 : 8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            gradient: isActive
                ? const LinearGradient(
                    colors: [
                      AppColors.heroGradientStart,
                      AppColors.heroGradientEnd,
                    ],
                  )
                : null,
            color: isActive ? null : AppColors.shadowDark,
          ),
        );
      }),
    );
  }

  Widget _buildBottomControls() {
    final bool isLastPage = _currentPage == _pages.length - 1;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildDotsIndicator(),
          const SizedBox(height: 22),
          if (!isLastPage)
            Row(
              children: [
                // Previous button (if page > 0)
                if (_currentPage > 0)
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: AppColors.pageBg,
                      shape: BoxShape.circle,
                      boxShadow: [
                        const BoxShadow(
                          color: AppColors.shadowLight,
                          offset: Offset(-3, -3),
                          blurRadius: 8,
                        ),
                        BoxShadow(
                          color: AppColors.shadowDark.withValues(alpha: 0.7),
                          offset: const Offset(3, 3),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: IconButton(
                      onPressed: _previousPage,
                      icon: const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 18,
                        color: AppColors.textDark,
                      ),
                    ),
                  )
                else
                  const SizedBox(width: 50),

                const Spacer(),

                // Next Button
                Container(
                  height: 50,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        AppColors.heroGradientStart,
                        AppColors.heroGradientEnd,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.heroGradientStart.withValues(alpha: 0.35),
                        offset: const Offset(0, 4),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _nextPage,
                      borderRadius: BorderRadius.circular(25),
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'التالي',
                              style: GoogleFonts.cairo(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            )
          else
            // Last Page: "ابدأ الآن" Button
            Container(
              width: double.infinity,
              height: 54,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    AppColors.heroGradientStart,
                    AppColors.heroGradientEnd,
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.heroGradientStart.withValues(alpha: 0.4),
                    offset: const Offset(0, 6),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _completeOnboarding,
                  borderRadius: BorderRadius.circular(16),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'ابدأ الآن',
                          style: GoogleFonts.cairo(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Icon(
                          Icons.rocket_launch_rounded,
                          color: AppColors.accentYellow,
                          size: 22,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.pageBg,
        body: SafeArea(
          child: Column(
            children: [
              _buildTopHeader(),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _pages.length,
                  onPageChanged: (index) {
                    setState(() {
                      _currentPage = index;
                    });
                  },
                  itemBuilder: (context, index) {
                    return _buildPageItem(_pages[index]);
                  },
                ),
              ),
              _buildBottomControls(),
            ],
          ),
        ),
      ),
    );
  }
}
