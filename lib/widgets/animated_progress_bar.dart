import 'package:flutter/material.dart';

class AnimatedProgressBar extends StatelessWidget {
  final double value;
  final double minHeight;
  final Color backgroundColor;
  final Color valueColor;
  final BorderRadius borderRadius;
  final Duration duration;

  const AnimatedProgressBar({
    super.key,
    required this.value,
    required this.backgroundColor,
    required this.valueColor,
    this.minHeight = 4,
    this.borderRadius = const BorderRadius.all(Radius.circular(2)),
    this.duration = const Duration(milliseconds: 420),
  });

  @override
  Widget build(BuildContext context) {
    final clamped = value.clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: borderRadius,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(end: clamped),
        duration: duration,
        curve: Curves.easeOutCubic,
        builder: (context, animatedValue, _) {
          return LinearProgressIndicator(
            value: animatedValue,
            backgroundColor: backgroundColor,
            valueColor: AlwaysStoppedAnimation<Color>(valueColor),
            minHeight: minHeight,
          );
        },
      ),
    );
  }
}
