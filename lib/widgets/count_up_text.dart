import 'package:flutter/material.dart';

class CountUpText extends StatelessWidget {
  final int targetValue;
  final TextStyle? style;
  final String prefix;
  final String suffix;
  final Curve curve;
  final String Function(int value)? formatter;

  const CountUpText({
    super.key,
    required this.targetValue,
    this.style,
    this.prefix = '',
    this.suffix = '',
    this.curve = Curves.easeOutCubic,
    this.formatter,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: targetValue),
      duration: const Duration(milliseconds: 800),
      curve: curve,
      builder: (context, value, child) {
        final text = formatter != null
            ? formatter!(value)
            : '$prefix$value$suffix';
        return Text(
          text,
          style: style,
        );
      },
    );
  }
}
