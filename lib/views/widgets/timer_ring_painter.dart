import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Cincin luar = progres total (sage), cincin dalam = progres langkah
/// (karamel). Dipakai timer kopi dan timer mocktail.
class TimerRingPainter extends CustomPainter {
  const TimerRingPainter({
    required this.stepFraction,
    required this.totalFraction,
    required this.paused,
  });

  final double stepFraction;
  final double totalFraction;
  final bool paused;

  static const double _start = -math.pi / 2;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    final double outerRadius = size.shortestSide / 2 - 8;
    final double innerRadius = outerRadius - 22;

    _ring(canvas, center, outerRadius, totalFraction, AppColors.sage, 6);
    _ring(
      canvas,
      center,
      innerRadius,
      stepFraction,
      paused ? AppColors.caramel.withValues(alpha: 0.6) : AppColors.caramel,
      12,
    );
  }

  void _ring(
    Canvas canvas,
    Offset center,
    double radius,
    double fraction,
    Color color,
    double stroke,
  ) {
    final Rect rect = Rect.fromCircle(center: center, radius: radius);
    final Paint track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = const Color(0x1AF3E6D6);
    canvas.drawCircle(center, radius, track);

    final double sweep = 2 * math.pi * fraction.clamp(0, 1);
    if (sweep <= 0) {
      return;
    }
    final Paint glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke + 4
      ..strokeCap = StrokeCap.round
      ..color = color.withValues(alpha: 0.55)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    final Paint arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas
      ..drawArc(rect, _start, sweep, false, glow)
      ..drawArc(rect, _start, sweep, false, arc);
  }

  @override
  bool shouldRepaint(TimerRingPainter old) =>
      old.stepFraction != stepFraction ||
      old.totalFraction != totalFraction ||
      old.paused != paused;
}
