// ============================================================================
// Platform: Commercial MikroTik Network & HotSpot Card Management System (Jalsah)
// File: lib/main.dart
// Entrypoint: SplashVideoScreen -> OnboardingScreen -> Auth / Dashboard Routing
// Master Reference: Rule 14 (Security), Rule 19 (Auth), Rule 20 (Branding)
// ============================================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'screens/dashboard_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/splash_video_screen.dart';
import 'screens/temp_login_screen.dart';
import 'services/api_client.dart';
import 'theme/app_colors.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final savedToken = await ApiClient.loadSavedToken();
  runApp(MikrotikCardsApp(initialToken: savedToken));
}

class MikrotikCardsApp extends StatelessWidget {
  final String? initialToken;
  final bool showSplash;
  final bool? hasSeenOnboardingOverride;

  const MikrotikCardsApp({
    super.key,
    this.initialToken,
    this.showSplash = true,
    this.hasSeenOnboardingOverride,
  });

  @override
  Widget build(BuildContext context) {
    Widget homeScreen;
    if (showSplash) {
      homeScreen = const SplashVideoScreen();
    } else {
      final bool hasSeenOnboarding = hasSeenOnboardingOverride ?? true;
      if (!hasSeenOnboarding) {
        homeScreen = const OnboardingScreen();
      } else {
        final bool hasValidToken =
            (initialToken != null && initialToken!.isNotEmpty) ||
                ApiClient.isAuthenticated;
        homeScreen = hasValidToken
            ? const DashboardScreen()
            : const TempLoginScreen();
      }
    }

    return MaterialApp(
      title: 'Jalsah | جلسة',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.pageBg,
        textTheme: GoogleFonts.cairoTextTheme(),
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.heroGradientStart,
          primary: AppColors.heroGradientStart,
          secondary: AppColors.accentYellow,
          surface: AppColors.pageBg,
        ),
      ),
      home: homeScreen,
    );
  }
}
