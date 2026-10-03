// ============================================================================
// Platform: Commercial MikroTik Network & HotSpot Card Management System
// File: lib/main.dart
// Entrypoint: Loads saved JWT token and routes to Dashboard or TempLoginScreen
// Master Reference: Rule 14 (Security), Rule 19 (Auth)
// ============================================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'screens/dashboard_screen.dart';
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

  const MikrotikCardsApp({
    super.key,
    this.initialToken,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasValidToken =
        (initialToken != null && initialToken!.isNotEmpty) ||
            ApiClient.isAuthenticated;

    return MaterialApp(
      title: 'MikroTik Cards App',
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
      home: hasValidToken ? const DashboardScreen() : const TempLoginScreen(),
    );
  }
}
