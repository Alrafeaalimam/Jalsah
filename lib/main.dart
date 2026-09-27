import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/dashboard_screen.dart';
import 'theme/app_colors.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MikrotikCardsApp());
}

class MikrotikCardsApp extends StatelessWidget {
  const MikrotikCardsApp({super.key});

  @override
  Widget build(BuildContext context) {
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
      home: const DashboardScreen(),
    );
  }
}
