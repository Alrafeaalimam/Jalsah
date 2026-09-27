import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';
import '../widgets/count_up_text.dart';
import '../widgets/pressable_neumorphic_card.dart';
import '../widgets/pulsing_dot.dart';

class RouterItemData {
  final String name;
  final String model;
  final String ip;
  final int usersCount;
  final bool isOnline;

  const RouterItemData({
    required this.name,
    required this.model,
    required this.ip,
    required this.usersCount,
    required this.isOnline,
  });
}

class DashboardScreen extends StatefulWidget {
  final String userName;

  const DashboardScreen({
    super.key,
    this.userName = 'المهندس أحمد ممدوح',
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final List<RouterItemData> _routers = const [
    RouterItemData(
      name: 'راوتر الصالة الرئيسية',
      model: 'MikroTik RB4011iGS+',
      ip: '192.168.10.1',
      usersCount: 68,
      isOnline: true,
    ),
    RouterItemData(
      name: 'راوتر برج التوزيع الغربي',
      model: 'MikroTik CCR1009-7G',
      ip: '192.168.20.1',
      usersCount: 145,
      isOnline: true,
    ),
    RouterItemData(
      name: 'راوتر كافيه ومطعم الواحة',
      model: 'MikroTik hEX S',
      ip: '192.168.30.1',
      usersCount: 52,
      isOnline: true,
    ),
    RouterItemData(
      name: 'راوتر سكن الطلاب والشباب',
      model: 'MikroTik RB3011UiAS',
      ip: '192.168.40.1',
      usersCount: 94,
      isOnline: true,
    ),
    RouterItemData(
      name: 'راوتر الحديقة والمسبح',
      model: 'MikroTik Metal 52 ac',
      ip: '192.168.50.1',
      usersCount: 0,
      isOnline: false,
    ),
  ];

  int _buttonShakeCounter = 0;

  void _onGenerateCardsPressed() {
    setState(() {
      _buttonShakeCounter++;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.heroGradientStart,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Row(
          children: [
            const Icon(Icons.bolt_rounded, color: AppColors.accentYellow),
            const SizedBox(width: 10),
            Text(
              'جاري تجهيز وتوليد كروت المايكروتك الجديدة...',
              style: GoogleFonts.cairo(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onRouterCardTapped(RouterItemData router) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.textDark,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Text(
          'تم اختيار: ${router.name} (${router.isOnline ? "متصل" : "غير متصل"})',
          style: GoogleFonts.cairo(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
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
            _buildTopBanner(context),

            // Router List Header & List
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12, right: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'أجهزة الراوتر والشبكات',
                            style: GoogleFonts.cairo(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDark,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.shadowDark.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '5 راوترات مسجلة',
                            style: GoogleFonts.cairo(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Routers List Items
                  ...List.generate(_routers.length, (index) {
                    final router = _routers[index];
                    return _buildRouterCard(router, index);
                  }),
                ],
              ),
            ),

            // Bottom Action Area: "توليد كروت جديدة"
            _buildBottomActionBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBanner(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.heroGradientStart,
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
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User Greeting Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'مساء الخير 👋',
                        style: GoogleFonts.cairo(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.userName,
                        style: GoogleFonts.cairo(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.25),
                        width: 1.5,
                      ),
                    ),
                    child: const Icon(
                      Icons.notifications_none_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Two Stats Cards (Online 4/5, مبيعات اليوم 18400)
              Row(
                children: [
                  // Stat Card 1: Online 4/5
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.22),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: AppColors.statusOnline,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'حالة الأجهزة',
                                  style: GoogleFonts.cairo(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white.withValues(alpha: 0.9),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  'Online ',
                                  style: GoogleFonts.cairo(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.accentYellow,
                                  ),
                                ),
                                CountUpText(
                                  targetValue: 4,
                                  suffix: '/5',
                                  style: GoogleFonts.cairo(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Stat Card 2: مبيعات اليوم 18400
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.22),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Row(
                              children: [
                                Icon(
                                  Icons.payments_outlined,
                                  size: 14,
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'مبيعات اليوم',
                                  style: GoogleFonts.cairo(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white.withValues(alpha: 0.9),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: CountUpText(
                              targetValue: 18400,
                              suffix: ' جنيه سوداني',
                              formatter: (val) {
                                // Format with commas for readability: 18,400 جنيه سوداني
                                final formatted = val.toString().replaceAllMapped(
                                  RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                                  (Match m) => '${m[1]},',
                                );
                                return '$formatted جنيه سوداني';
                              },
                              style: GoogleFonts.cairo(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: AppColors.accentYellow,
                              ),
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

  Widget _buildRouterCard(RouterItemData router, int index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: PressableNeumorphicCard(
        onTap: () => _onRouterCardTapped(router),
        borderRadius: BorderRadius.circular(20),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            // Status Pulsing Dot
            PulsingDot(
              color: router.isOnline
                  ? AppColors.statusOnline
                  : AppColors.statusOffline,
              size: 13,
            ),
            const SizedBox(width: 14),

            // Router Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    router.name,
                    style: GoogleFonts.cairo(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(
                        router.model,
                        style: GoogleFonts.cairo(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 3,
                        height: 3,
                        decoration: const BoxDecoration(
                          color: AppColors.textMuted,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        router.ip,
                        style: GoogleFonts.cairo(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // User Count & Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: router.isOnline
                    ? AppColors.statusOnline.withValues(alpha: 0.12)
                    : AppColors.statusOffline.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    router.isOnline
                        ? Icons.group_rounded
                        : Icons.wifi_off_rounded,
                    size: 14,
                    color: router.isOnline
                        ? AppColors.statusOnline
                        : AppColors.statusOffline,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    router.isOnline
                        ? '${router.usersCount} مستخدم'
                        : 'غير متصل',
                    style: GoogleFonts.cairo(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: router.isOnline
                          ? AppColors.statusOnline
                          : AppColors.statusOffline,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(delay: (index * 100).ms)
        .slideY(begin: 0.15, duration: 300.ms);
  }

  Widget _buildBottomActionBar() {
    Widget button = PressableNeumorphicCard(
      onTap: _onGenerateCardsPressed,
      backgroundColor: AppColors.accentYellow,
      borderRadius: BorderRadius.circular(18),
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.add_card_rounded,
            color: AppColors.textDark,
            size: 22,
          ),
          const SizedBox(width: 10),
          Text(
            'توليد كروت جديدة',
            style: GoogleFonts.cairo(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );

    if (_buttonShakeCounter > 0) {
      button = button
          .animate(key: ValueKey(_buttonShakeCounter))
          .shake(duration: 200.ms);
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
      decoration: BoxDecoration(
        color: AppColors.pageBg,
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowDark.withValues(alpha: 0.3),
            offset: const Offset(0, -6),
            blurRadius: 10,
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: button,
      ),
    );
  }
}
