// ============================================================================
// Platform: Commercial MikroTik Network & HotSpot Card Management System (Jalsah)
// File: test/branding_onboarding_test.dart
// Tests: SplashVideoScreen, OnboardingScreen, and App Launch Sequence
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mikrotik_cards_app/main.dart';
import 'package:mikrotik_cards_app/screens/onboarding_screen.dart';
import 'package:mikrotik_cards_app/screens/splash_video_screen.dart';
import 'package:mikrotik_cards_app/screens/temp_login_screen.dart';
import 'package:mikrotik_cards_app/services/api_client.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ApiClient.resetClient();
  });

  group('OnboardingScreen Widget Tests', () {
    testWidgets('renders first onboarding page with title, description, and controls',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: OnboardingScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Check brand name
      expect(find.text('Jalsah | جلسة'), findsOneWidget);

      // Check first page content
      expect(find.text('تحكم كامل في شبكتك'), findsOneWidget);
      expect(
        find.text('من مكان واحد، دير كل أجهزة MikroTik وراقب حالتها لحظة بلحظة'),
        findsOneWidget,
      );

      // Check buttons
      expect(find.text('تخطي'), findsOneWidget);
      expect(find.text('التالي'), findsOneWidget);
      expect(find.text('ابدأ الآن'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets('navigates through all 3 pages and reaches "ابدأ الآن"',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: OnboardingScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Page 1 -> Next
      await tester.tap(find.text('التالي'));
      await tester.pumpAndSettle();

      // Page 2
      expect(find.text('ولّد وبيع الكروت بسهولة'), findsOneWidget);
      expect(
        find.text('أنشئ كروت الإنترنت بضغطة واحدة وتابع مبيعاتك أول بأول'),
        findsOneWidget,
      );

      // Page 2 -> Next
      await tester.tap(find.text('التالي'));
      await tester.pumpAndSettle();

      // Page 3
      expect(find.text('راقب شبكتك أينما كنت'), findsOneWidget);
      expect(
        find.text('تابع أجهزتك وشبكات Starlink من موبايلك في أي وقت'),
        findsOneWidget,
      );
      expect(find.text('ابدأ الآن'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets('tapping "ابدأ الآن" saves has_seen_onboarding=true in SharedPreferences',
        (WidgetTester tester) async {
      bool onFinishedCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: OnboardingScreen(
            onFinished: () {
              onFinishedCalled = true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Advance to page 3
      await tester.tap(find.text('التالي'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('التالي'));
      await tester.pumpAndSettle();

      // Tap "ابدأ الآن"
      await tester.tap(find.text('ابدأ الآن'));
      await tester.pumpAndSettle();

      expect(onFinishedCalled, isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('has_seen_onboarding'), isTrue);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets('tapping "تخطي" on page 1 saves has_seen_onboarding=true and completes',
        (WidgetTester tester) async {
      bool onFinishedCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: OnboardingScreen(
            onFinished: () {
              onFinishedCalled = true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap "تخطي" on page 1
      await tester.tap(find.text('تخطي'));
      await tester.pumpAndSettle();

      expect(onFinishedCalled, isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('has_seen_onboarding'), isTrue);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  });

  group('SplashVideoScreen Widget Tests', () {
    testWidgets('renders splash UI, shows fallback branding, and displays skip button after delay',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SplashVideoScreen(
            skipButtonDelay: Duration(milliseconds: 500),
          ),
        ),
      );
      await tester.pump();

      // Initially, skip button should not be interactive or opacity 0
      expect(find.text('Jalsah | جلسة'), findsOneWidget);

      // Advance timer past skip delay
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('تخطي'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets('tapping skip on SplashVideoScreen navigates to nextScreenOverride',
        (WidgetTester tester) async {
      const dummyTargetKey = Key('dummy_target_screen');

      await tester.pumpWidget(
        const MaterialApp(
          home: SplashVideoScreen(
            skipButtonDelay: Duration(milliseconds: 100),
            nextScreenOverride: Scaffold(
              key: dummyTargetKey,
              body: Text('Next Screen Target'),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      expect(find.text('تخطي'), findsOneWidget);
      await tester.tap(find.text('تخطي'));
      await tester.pumpAndSettle();

      expect(find.byKey(dummyTargetKey), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  });

  group('MikrotikCardsApp Startup Flow Tests', () {
    testWidgets('when hasSeenOnboardingOverride is false, renders OnboardingScreen directly',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MikrotikCardsApp(
          showSplash: false,
          hasSeenOnboardingOverride: false,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(find.byType(TempLoginScreen), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets('when hasSeenOnboardingOverride is true and no token, renders TempLoginScreen',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MikrotikCardsApp(
          showSplash: false,
          hasSeenOnboardingOverride: true,
          initialToken: null,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TempLoginScreen), findsOneWidget);
      expect(find.byType(OnboardingScreen), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  });
}
