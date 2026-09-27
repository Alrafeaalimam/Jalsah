import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mikrotik_cards_app/screens/dashboard_screen.dart';
import 'package:mikrotik_cards_app/widgets/count_up_text.dart';
import 'package:mikrotik_cards_app/widgets/pressable_neumorphic_card.dart';
import 'package:mikrotik_cards_app/widgets/pulsing_dot.dart';
import 'package:mikrotik_cards_app/theme/app_colors.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('DashboardScreen renders all elements and supports custom userName',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: DashboardScreen(userName: 'المهندس عثمان البدوي'),
      ),
    );
    await tester.pump();

    // Verify key elements and custom userName
    expect(find.text('مساء الخير 👋'), findsOneWidget);
    expect(find.text('المهندس عثمان البدوي'), findsOneWidget);
    expect(find.text('توليد كروت جديدة'), findsOneWidget);
    expect(find.byType(PressableNeumorphicCard), findsWidgets);
    expect(find.byType(CountUpText), findsWidgets);
    expect(find.byType(PulsingDot), findsWidgets);

    // Advance 900ms
    await tester.pump(const Duration(milliseconds: 900));

    // Tap generate cards button to trigger shake animation and SnackBar
    await tester.tap(find.text('توليد كروت جديدة'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(
      find.text('جاري تجهيز وتوليد كروت المايكروتك الجديدة...'),
      findsOneWidget,
    );

    // Clean unmount
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('CountUpText counts up to targetValue with currency',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CountUpText(
            targetValue: 18400,
            suffix: ' جنيه سوداني',
            formatter: (v) => '$v جنيه سوداني',
          ),
        ),
      ),
    );

    expect(find.text('0 جنيه سوداني'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.text('18400 جنيه سوداني'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('PressableNeumorphicCard handles tap',
      (WidgetTester tester) async {
    bool tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PressableNeumorphicCard(
            onTap: () => tapped = true,
            child: const Text('Tap Me'),
          ),
        ),
      ),
    );

    final gesture =
        await tester.startGesture(tester.getCenter(find.text('Tap Me')));
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 200));

    expect(tapped, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('PulsingDot animates continuously and unmounts cleanly',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PulsingDot(color: AppColors.statusOnline),
        ),
      ),
    );

    expect(find.byType(PulsingDot), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pump(const Duration(milliseconds: 450));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
