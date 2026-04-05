import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class DoseRing extends StatelessWidget {
  final int remaining;
  final int total;
  final double size;
  final double strokeWidth;
  final bool showLabel;

  const DoseRing({
    super.key,
    required this.remaining,
    required this.total,
    this.size = 70,
    this.strokeWidth = 5,
    this.showLabel = true,
  });

  @override
  Widget build(BuildContext context) {
    final color = doseColor(remaining, total);
    final progress = total > 0 ? remaining / total : 0.0;

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _DoseRingPainter(
          progress: progress,
          trackColor: AppColors.border,
          arcColor: color,
          strokeWidth: strokeWidth,
        ),
        child: showLabel
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$remaining',
                      style: TextStyle(
                        fontFamily: 'Courier New',
                        fontSize: size < 80 ? 13 : 22,
                        fontWeight: FontWeight.w600,
                        color: color,
                        height: 1.1,
                      ),
                    ),
                    Text(
                      'left',
                      style: TextStyle(
                        fontSize: size < 80 ? 9 : 11,
                        color: AppColors.textTertiary,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              )
            : null,
      ),
    );
  }
}

class _DoseRingPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color arcColor;
  final double strokeWidth;

  const _DoseRingPainter({
    required this.progress,
    required this.trackColor,
    required this.arcColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - strokeWidth) / 2;

    final trackPaint = Paint()
      ..color = trackColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final arcPaint = Paint()
      ..color = arcColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        arcPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_DoseRingPainter old) =>
      progress != old.progress || arcColor != old.arcColor;
}
