import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Grafik garis rating (skala 1–5) yang tergambar dengan animasi.
class RatingLineChart extends StatelessWidget {
  const RatingLineChart({super.key, required this.values, this.height = 150});

  /// Rating dari yang terlama ke terbaru.
  final List<int> values;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Grafik rating terakhir',
      value: values.join(', '),
      child: TweenAnimationBuilder<double>(
        key: ValueKey<String>(values.join(',')),
        tween: Tween<double>(begin: 0, end: 1),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (BuildContext context, double progress, Widget? _) =>
            CustomPaint(
              size: Size(double.infinity, height),
              painter: _RatingPainter(values: values, progress: progress),
            ),
      ),
    );
  }
}

class _RatingPainter extends CustomPainter {
  const _RatingPainter({required this.values, required this.progress});

  final List<int> values;
  final double progress;

  static const double _left = 22;
  static const double _pad = 10;

  @override
  void paint(Canvas canvas, Size size) {
    final double top = _pad;
    final double bottom = size.height - _pad;
    double yFor(num rating) => bottom - (rating - 1) / 4 * (bottom - top);

    final Paint grid = Paint()
      ..color = const Color(0x1AF3E6D6)
      ..strokeWidth = 1;
    for (int r = 1; r <= 5; r++) {
      final double y = yFor(r);
      canvas.drawLine(Offset(_left, y), Offset(size.width, y), grid);
      final TextPainter label = TextPainter(
        text: TextSpan(
          text: '$r',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(canvas, Offset(0, y - label.height / 2));
    }
    if (values.isEmpty) {
      return;
    }

    final double width = size.width - _left - 6;
    Offset pointAt(int i) {
      final double x = values.length == 1
          ? _left + width / 2
          : _left + width * i / (values.length - 1);
      return Offset(x, yFor(values[i]));
    }

    final Path line = Path()..moveTo(pointAt(0).dx, pointAt(0).dy);
    for (int i = 1; i < values.length; i++) {
      final Offset prev = pointAt(i - 1);
      final Offset cur = pointAt(i);
      final double mid = (prev.dx + cur.dx) / 2;
      line.cubicTo(mid, prev.dy, mid, cur.dy, cur.dx, cur.dy);
    }

    final double revealX = _left + width * progress;
    canvas
      ..save()
      ..clipRect(Rect.fromLTRB(0, 0, revealX + 6, size.height));
    if (values.length > 1) {
      canvas
        ..drawPath(
          line,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 7
            ..strokeCap = StrokeCap.round
            ..color = AppColors.caramel.withValues(alpha: 0.35)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
        )
        ..drawPath(
          line,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..strokeCap = StrokeCap.round
            ..color = AppColors.caramel,
        );
    }
    for (int i = 0; i < values.length; i++) {
      final Offset p = pointAt(i);
      canvas
        ..drawCircle(p, 5, Paint()..color = AppColors.background)
        ..drawCircle(
          p,
          5,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.2
            ..color = AppColors.sage,
        );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_RatingPainter old) =>
      old.progress != progress || old.values != values;
}
