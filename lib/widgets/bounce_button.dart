// ============================================================================
// Platform: Commercial MikroTik Network & HotSpot Card Management System (Jalsah)
// File: lib/widgets/bounce_button.dart
// Widget: Tactile Micro-interactive Bounce Button with States & Double-Tap Guard
// Master Reference: Rule 20 (Design System), Phase 14 UI/UX
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';

enum BounceButtonStyle {
  primary,
  secondary,
  outline,
  danger,
}

class BounceButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final String? label;
  final Widget? child;
  final IconData? icon;
  final bool isLoading;
  final bool isSuccess;
  final BounceButtonStyle style;
  final double? width;
  final double height;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;
  final Color? textColor;
  final Gradient? gradient;

  const BounceButton({
    super.key,
    required this.onPressed,
    this.label,
    this.child,
    this.icon,
    this.isLoading = false,
    this.isSuccess = false,
    this.style = BounceButtonStyle.primary,
    this.width,
    this.height = 50,
    this.borderRadius,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    this.backgroundColor,
    this.textColor,
    this.gradient,
  }) : assert(label != null || child != null, 'Either label or child must be provided');

  @override
  State<BounceButton> createState() => _BounceButtonState();
}

class _BounceButtonState extends State<BounceButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _scaleAnimation;
  bool _isProcessingTap = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 110),
      reverseDuration: const Duration(milliseconds: 150),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeOutBack,
      ),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    if (widget.onPressed == null || widget.isLoading) return;
    _animController.forward();
    HapticFeedback.lightImpact();
  }

  void _onTapUp(TapUpDetails _) {
    _animController.reverse();
  }

  void _onTapCancel() {
    _animController.reverse();
  }

  void _triggerAction() {
    if (widget.onPressed == null || widget.isLoading || _isProcessingTap) return;
    _isProcessingTap = true;
    try {
      widget.onPressed?.call();
    } finally {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _isProcessingTap = false;
        }
      });
    }
  }

  BoxDecoration _resolveDecoration() {
    final radius = widget.borderRadius ?? BorderRadius.circular(16);
    final disabled = widget.onPressed == null;

    if (disabled) {
      return BoxDecoration(
        color: AppColors.shadowDark.withValues(alpha: 0.3),
        borderRadius: radius,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
      );
    }

    if (widget.isSuccess) {
      return BoxDecoration(
        color: AppColors.statusOnline,
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: AppColors.statusOnline.withValues(alpha: 0.35),
            offset: const Offset(0, 4),
            blurRadius: 10,
          ),
        ],
      );
    }

    switch (widget.style) {
      case BounceButtonStyle.primary:
        return BoxDecoration(
          gradient: widget.gradient ??
              const LinearGradient(
                colors: [
                  AppColors.heroGradientStart,
                  AppColors.heroGradientMiddle,
                ],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: AppColors.heroGradientStart.withValues(alpha: 0.38),
              offset: const Offset(0, 5),
              blurRadius: 12,
            ),
            const BoxShadow(
              color: AppColors.shadowLight,
              offset: Offset(-2, -2),
              blurRadius: 6,
            ),
          ],
        );

      case BounceButtonStyle.secondary:
        return BoxDecoration(
          color: widget.backgroundColor ?? AppColors.pageBg,
          borderRadius: radius,
          boxShadow: [
            const BoxShadow(
              color: AppColors.shadowLight,
              offset: Offset(-3, -3),
              blurRadius: 6,
            ),
            BoxShadow(
              color: AppColors.shadowDark.withValues(alpha: 0.35),
              offset: const Offset(3, 3),
              blurRadius: 6,
            ),
          ],
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.4),
            width: 1,
          ),
        );

      case BounceButtonStyle.outline:
        return BoxDecoration(
          color: Colors.transparent,
          borderRadius: radius,
          border: Border.all(
            color: widget.textColor ?? AppColors.heroGradientStart,
            width: 1.5,
          ),
        );

      case BounceButtonStyle.danger:
        return BoxDecoration(
          color: AppColors.statusOffline,
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: AppColors.statusOffline.withValues(alpha: 0.35),
              offset: const Offset(0, 4),
              blurRadius: 10,
            ),
          ],
        );
    }
  }

  Color _resolveTextColor() {
    if (widget.textColor != null) return widget.textColor!;
    if (widget.onPressed == null) return AppColors.textMuted;
    if (widget.isSuccess) return Colors.white;

    switch (widget.style) {
      case BounceButtonStyle.primary:
      case BounceButtonStyle.danger:
        return Colors.white;
      case BounceButtonStyle.secondary:
        return AppColors.textDark;
      case BounceButtonStyle.outline:
        return AppColors.heroGradientStart;
    }
  }

  Widget _buildContent(Color textColor) {
    if (widget.isLoading) {
      return SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2.2,
          valueColor: AlwaysStoppedAnimation<Color>(textColor),
        ),
      );
    }

    if (widget.isSuccess) {
      return Row(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              widget.label ?? 'تم بنجاح',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.cairo(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      );
    }

    if (widget.child != null) {
      return widget.child!;
    }

    return Row(
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.icon != null) ...[
          Icon(widget.icon, size: 20, color: textColor),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(
            widget.label!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final decoration = _resolveDecoration();
    final textColor = _resolveTextColor();

    Widget buttonBody = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeInOut,
      width: widget.width,
      height: widget.height,
      decoration: decoration,
      alignment: Alignment.center,
      padding: widget.padding,
      child: _buildContent(textColor),
    );

    if (disableAnimations) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _triggerAction,
        child: buttonBody,
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: _triggerAction,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          );
        },
        child: buttonBody,
      ),
    );
  }
}
