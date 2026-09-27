import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class PressableNeumorphicCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;
  final Color? backgroundColor;
  final double? width;
  final double? height;

  const PressableNeumorphicCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
    this.margin,
    this.borderRadius,
    this.backgroundColor,
    this.width,
    this.height,
  });

  @override
  State<PressableNeumorphicCard> createState() =>
      _PressableNeumorphicCardState();
}

class _PressableNeumorphicCardState extends State<PressableNeumorphicCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final effectiveRadius = widget.borderRadius ?? BorderRadius.circular(18);
    final bgColor = widget.backgroundColor ?? AppColors.pageBg;

    // Normal (بارز - embossed/raised) vs Pressed (غاطس - sunken/debossed)
    final shadows = _isPressed
        ? [
            BoxShadow(
              color: AppColors.shadowDark.withValues(alpha: 0.6),
              offset: const Offset(2, 2),
              blurRadius: 4,
              spreadRadius: 0,
            ),
            BoxShadow(
              color: AppColors.shadowLight.withValues(alpha: 0.8),
              offset: const Offset(-2, -2),
              blurRadius: 4,
              spreadRadius: 0,
            ),
          ]
        : [
            const BoxShadow(
              color: AppColors.shadowLight,
              offset: Offset(-5, -5),
              blurRadius: 10,
              spreadRadius: 1,
            ),
            BoxShadow(
              color: AppColors.shadowDark.withValues(alpha: 0.8),
              offset: const Offset(5, 5),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ];

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap?.call();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        width: widget.width,
        height: widget.height,
        margin: widget.margin,
        padding: widget.padding ?? const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: effectiveRadius,
          boxShadow: shadows,
        ),
        child: widget.child,
      ),
    );
  }
}
