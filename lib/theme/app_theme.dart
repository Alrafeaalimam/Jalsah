import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Spacing system tokens for consistent padding and margins
class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
  static const double xxxl = 32.0;
}

/// Border radius tokens for modern, rounded aesthetics
class AppRadius {
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
  static const double full = 999.0;

  static BorderRadius get radiusSm => BorderRadius.circular(sm);
  static BorderRadius get radiusMd => BorderRadius.circular(md);
  static BorderRadius get radiusLg => BorderRadius.circular(lg);
  static BorderRadius get radiusXl => BorderRadius.circular(xl);
  static BorderRadius get radiusXxl => BorderRadius.circular(xxl);
  static BorderRadius get radiusFull => BorderRadius.circular(full);
}

/// Soft UI & Neumorphic box shadows
class AppShadows {
  /// Standard raised neumorphic shadow
  static List<BoxShadow> get cardRaised => [
        const BoxShadow(
          color: AppColors.shadowLight,
          offset: Offset(-4, -4),
          blurRadius: 10,
          spreadRadius: 1,
        ),
        BoxShadow(
          color: AppColors.shadowDark.withValues(alpha: 0.75),
          offset: const Offset(4, 4),
          blurRadius: 10,
          spreadRadius: 1,
        ),
      ];

  /// Subtle soft shadow for clean modern cards
  static List<BoxShadow> get cardSubtle => [
        BoxShadow(
          color: AppColors.shadowLight.withValues(alpha: 0.9),
          offset: const Offset(-2, -2),
          blurRadius: 6,
        ),
        BoxShadow(
          color: AppColors.shadowDark.withValues(alpha: 0.5),
          offset: const Offset(2, 4),
          blurRadius: 8,
        ),
      ];

  /// Debossed / recessed / pressed shadow
  static List<BoxShadow> get pressed => [
        BoxShadow(
          color: AppColors.shadowDark.withValues(alpha: 0.6),
          offset: const Offset(2, 2),
          blurRadius: 4,
        ),
        BoxShadow(
          color: AppColors.shadowLight.withValues(alpha: 0.8),
          offset: const Offset(-2, -2),
          blurRadius: 4,
        ),
      ];

  /// Floating hero element shadow
  static List<BoxShadow> get heroFloating => [
        const BoxShadow(
          color: Color(0x333B2FA0),
          offset: Offset(0, 8),
          blurRadius: 20,
        ),
      ];

  /// Golden accent button glow
  static List<BoxShadow> get accentGlow => [
        BoxShadow(
          color: AppColors.accentYellow.withValues(alpha: 0.4),
          offset: const Offset(0, 4),
          blurRadius: 12,
        ),
      ];
}

/// Comprehensive ThemeData configuration for Jalsah
class AppTheme {
  static ThemeData get lightTheme {
    final baseTextTheme = GoogleFonts.cairoTextTheme();

    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Cairo',
      scaffoldBackgroundColor: AppColors.pageBg,
      primaryColor: AppColors.heroGradientStart,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.heroGradientStart,
        primary: AppColors.heroGradientStart,
        secondary: AppColors.accentYellow,
        surface: AppColors.pageBg,
        error: AppColors.statusOffline,
      ),
      textTheme: baseTextTheme.copyWith(
        displayLarge: GoogleFonts.cairo(
          fontSize: 26,
          fontWeight: FontWeight.w800,
          color: AppColors.textDark,
        ),
        headlineLarge: GoogleFonts.cairo(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: AppColors.textDark,
        ),
        headlineMedium: GoogleFonts.cairo(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.textDark,
        ),
        titleLarge: GoogleFonts.cairo(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: AppColors.textDark,
        ),
        titleMedium: GoogleFonts.cairo(
          fontSize: 14.5,
          fontWeight: FontWeight.w600,
          color: AppColors.textDark,
        ),
        bodyLarge: GoogleFonts.cairo(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textDark,
        ),
        bodyMedium: GoogleFonts.cairo(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppColors.textMuted,
        ),
        bodySmall: GoogleFonts.cairo(
          fontSize: 11.5,
          fontWeight: FontWeight.w500,
          color: AppColors.textMuted,
        ),
        labelLarge: GoogleFonts.cairo(
          fontSize: 13.5,
          fontWeight: FontWeight.w700,
          color: AppColors.textDark,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.pageBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: AppColors.textDark),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.pageBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xxl),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.pageBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
    );
  }
}
