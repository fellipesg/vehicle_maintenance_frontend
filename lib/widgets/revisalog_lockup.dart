import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Horizontal RevisaLog mark: odometer icon + wordmark (no baked PNG frame).
class RevisalogLockupHorizontal extends StatelessWidget {
  const RevisalogLockupHorizontal({super.key, this.height = 32});

  final double height;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fontSize = height * 0.72;
    final revisaColor = dark ? Colors.white : AppColors.navy;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        CustomPaint(
          size: Size.square(height),
          painter: OdometerMarkPainter(
            arcColor: AppColors.teal,
            markColor: dark ? Colors.white : AppColors.navy,
          ),
        ),
        SizedBox(width: height * 0.28),
        RichText(
          text: TextSpan(
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.3,
              height: 1,
            ),
            children: [
              TextSpan(
                text: 'Revisa',
                style: TextStyle(color: revisaColor),
              ),
              const TextSpan(
                text: 'Log',
                style: TextStyle(color: AppColors.teal),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Speedometer mark without the navy plate baked into the app icon.
class OdometerMarkPainter extends CustomPainter {
  const OdometerMarkPainter({
    required this.arcColor,
    required this.markColor,
  });

  final Color arcColor;
  final Color markColor;

  static const double _start = 5 * math.pi / 6;
  static const double _sweep = 4 * math.pi / 3;

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    final center = Offset(side / 2, side * 0.44);
    final radius = side * 0.34;

    final arcPaint = Paint()
      ..color = arcColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = side * 0.07
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      _start,
      _sweep,
      false,
      arcPaint,
    );

    final tickPaint = Paint()
      ..color = markColor
      ..strokeWidth = side * 0.02
      ..strokeCap = StrokeCap.round;

    const tickCount = 9;
    for (var i = 0; i < tickCount; i++) {
      final angle = _start + (i / (tickCount - 1)) * _sweep;
      final direction = Offset(math.cos(angle), math.sin(angle));
      canvas.drawLine(
        center + direction * (radius - side * 0.105),
        center + direction * (radius - side * 0.055),
        tickPaint,
      );
    }

    final needlePaint = Paint()
      ..color = markColor
      ..strokeWidth = side * 0.065
      ..strokeCap = StrokeCap.round;
    const needleAngle = -math.pi / 3.4;
    final needleDirection = Offset(
      math.cos(needleAngle),
      math.sin(needleAngle),
    );
    canvas.drawLine(
      center,
      center + needleDirection * (radius * 0.78),
      needlePaint,
    );
    canvas.drawCircle(center, side * 0.032, needlePaint);

    final dotPaint = Paint()..color = arcColor;
    final dotRadius = side * 0.03;
    final dotGap = side * 0.095;
    final dotCenterY = center.dy + radius * 0.72;
    for (final dx in [-dotGap, 0.0, dotGap]) {
      canvas.drawCircle(
          Offset(center.dx + dx, dotCenterY), dotRadius, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant OdometerMarkPainter oldDelegate) {
    return oldDelegate.arcColor != arcColor ||
        oldDelegate.markColor != markColor;
  }
}
