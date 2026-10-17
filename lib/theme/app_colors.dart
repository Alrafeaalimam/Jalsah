import 'package:flutter/material.dart';

class AppColors {
  // Brand Identity Gradients & Backgrounds
  static const heroGradientStart = Color(0xFF3B2FA0);
  static const heroGradientMiddle = Color(0xFF5544C8);
  static const heroGradientEnd = Color(0xFF7B6FF0);
  static const pageBg = Color(0xFFEAEBF2);

  // Signature Accent Colors
  static const accentYellow = Color(0xFFF5C94B);
  static const accentYellowDark = Color(0xFFE0B432);
  static const accentYellowLight = Color(0xFFFFF8E1);

  // Typography Colors
  static const textDark = Color(0xFF2B2A4C);
  static const textMuted = Color(0xFF8A8FA3);
  static const textLight = Color(0xFFFFFFFF);

  // Neumorphic & Surface Shadows
  static const shadowLight = Color(0xFFFFFFFF);
  static const shadowDark = Color(0xFFC9CBD6);
  static const cardSurface = Color(0xFFECEEF5);
  static const cardSurfaceLight = Color(0xFFF5F6FA);
  static const cardBorder = Color(0x33FFFFFF);
  static const divider = Color(0xFFDCDFEA);

  // Glassmorphic Highlights
  static const glassSurface = Color(0x26FFFFFF);
  static const glassSurfaceStrong = Color(0x3DFFFFFF);
  static const glassBorder = Color(0x38FFFFFF);

  // Status & Semantic Colors
  static const statusOnline = Color(0xFF22C08A);
  static const statusOnlineBg = Color(0x1A22C08A);
  static const statusOffline = Color(0xFFE0574F);
  static const statusOfflineBg = Color(0x1AE0574F);
  static const statusWarning = Color(0xFFF59E0B);
  static const statusWarningBg = Color(0x1AF59E0B);
  static const statusInfo = Color(0xFF3B82F6);
  static const statusInfoBg = Color(0x1A3B82F6);
  static const badgePurpleBg = Color(0x1F3B2FA0);

  // Brand Linear Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [heroGradientStart, heroGradientMiddle, heroGradientEnd],
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [accentYellow, accentYellowDark],
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
  );
}
