import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/brew_model.dart';
import '../../models/mocktail_model.dart';

/// Ikon garis alat seduh (V60, Aeropress, French press, Chemex) yang
/// digambar `CustomPaint` pada kotak 24 × 24.
class BrewMethodIcon extends StatelessWidget {
  const BrewMethodIcon({
    super.key,
    required this.method,
    required this.color,
    this.size = 24,
  });

  final BrewMethod method;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _MethodPainter(method, color),
    );
  }
}

class _MethodPainter extends CustomPainter {
  const _MethodPainter(this.method, this.color);

  final BrewMethod method;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24);
    final Paint line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    switch (method) {
      case BrewMethod.v60:
        canvas
          ..drawPath(
            Path()
              ..moveTo(4, 6)
              ..lineTo(20, 6)
              ..lineTo(14, 17)
              ..lineTo(10, 17)
              ..close(),
            line,
          )
          ..drawLine(const Offset(8, 20.5), const Offset(16, 20.5), line);
      case BrewMethod.aeropress:
        canvas
          ..drawRRect(
            RRect.fromRectAndRadius(
              const Rect.fromLTWH(8.5, 4, 7, 13),
              const Radius.circular(1.5),
            ),
            line,
          )
          ..drawLine(const Offset(6.5, 4), const Offset(17.5, 4), line)
          ..drawPath(
            Path()
              ..moveTo(7, 17)
              ..lineTo(17, 17)
              ..lineTo(15.8, 21.5)
              ..lineTo(8.2, 21.5)
              ..close(),
            line,
          );
      case BrewMethod.frenchPress:
        canvas
          ..drawRRect(
            RRect.fromRectAndRadius(
              const Rect.fromLTWH(6, 8, 12, 12),
              const Radius.circular(2),
            ),
            line,
          )
          ..drawLine(const Offset(5, 7), const Offset(19, 7), line)
          ..drawLine(const Offset(12, 3.6), const Offset(12, 7), line)
          ..drawCircle(const Offset(12, 2.6), 1.3, line)
          ..drawPath(
            Path()
              ..moveTo(18, 10)
              ..cubicTo(22.5, 10, 22.5, 17, 18, 17),
            line,
          );
      case BrewMethod.chemex:
        canvas
          ..drawPath(
            Path()
              ..moveTo(6, 3)
              ..lineTo(18, 3)
              ..lineTo(13.2, 12)
              ..lineTo(18, 21)
              ..lineTo(6, 21)
              ..lineTo(10.8, 12)
              ..close(),
            line,
          )
          ..drawLine(const Offset(9.2, 12), const Offset(14.8, 12), line);
    }
  }

  @override
  bool shouldRepaint(_MethodPainter old) =>
      old.method != method || old.color != color;
}

/// Biji kopi dengan warna sesuai tingkat roasting (terang, sedang, gelap).
class RoastBeanIcon extends StatelessWidget {
  const RoastBeanIcon({super.key, required this.level, this.size = 24});

  final RoastLevel level;
  final double size;

  static Color colorOf(RoastLevel level) => switch (level) {
    RoastLevel.light => const Color(0xFFD9B88A),
    RoastLevel.medium => const Color(0xFFA06F3F),
    RoastLevel.dark => const Color(0xFF5A3720),
  };

  @override
  Widget build(BuildContext context) =>
      BeanIcon(filled: true, color: colorOf(level), size: size);
}

/// Satu biji kopi: terisi (rating/roast) atau hanya garis tepi.
class BeanIcon extends StatelessWidget {
  const BeanIcon({
    super.key,
    required this.filled,
    required this.color,
    this.size = 24,
  });

  final bool filled;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _BeanPainter(filled: filled, color: color),
    );
  }
}

class _BeanPainter extends CustomPainter {
  const _BeanPainter({required this.filled, required this.color});

  final bool filled;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..scale(size.width / 24)
      ..translate(12, 12)
      ..rotate(35 * math.pi / 180)
      ..translate(-12, -12);

    final Rect bean = Rect.fromCenter(
      center: const Offset(12, 12),
      width: 14,
      height: 20,
    );
    final Path slit = Path()
      ..moveTo(12, 3.2)
      ..cubicTo(8.6, 8, 15.4, 16, 12, 20.8);

    if (filled) {
      canvas
        ..drawOval(bean, Paint()..color = color)
        ..drawPath(
          slit,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6
            ..strokeCap = StrokeCap.round
            ..color = const Color(0x59000000),
        );
    } else {
      final Paint stroke = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round
        ..color = color;
      canvas
        ..drawOval(bean.deflate(0.75), stroke)
        ..drawPath(slit, stroke);
    }
  }

  @override
  bool shouldRepaint(_BeanPainter old) =>
      old.filled != filled || old.color != color;
}

/// Ikon garis teknik mocktail: gelas dengan sendok bar (langsung) atau
/// shaker (kocok), pada kotak 24 × 24.
class MocktailMethodIcon extends StatelessWidget {
  const MocktailMethodIcon({
    super.key,
    required this.method,
    required this.color,
    this.size = 24,
  });

  final MocktailMethod method;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(size),
    painter: _MocktailMethodPainter(method, color),
  );
}

class _MocktailMethodPainter extends CustomPainter {
  const _MocktailMethodPainter(this.method, this.color);

  final MocktailMethod method;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24);
    final Paint line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    switch (method) {
      case MocktailMethod.build:
        canvas
          ..drawPath(
            Path()
              ..moveTo(6, 7)
              ..lineTo(18, 7)
              ..lineTo(16.4, 21)
              ..lineTo(7.6, 21)
              ..close(),
            line,
          )
          ..drawLine(const Offset(14.5, 2.5), const Offset(11, 15), line)
          ..drawLine(const Offset(7.2, 12), const Offset(16.8, 12), line);
      case MocktailMethod.shake:
        canvas
          ..drawPath(
            Path()
              ..moveTo(7.5, 9)
              ..lineTo(16.5, 9)
              ..lineTo(15.4, 21.5)
              ..lineTo(8.6, 21.5)
              ..close(),
            line,
          )
          ..drawRRect(
            RRect.fromRectAndRadius(
              const Rect.fromLTWH(8.5, 5, 7, 4),
              const Radius.circular(1.2),
            ),
            line,
          )
          ..drawCircle(const Offset(12, 3.3), 1.3, line)
          ..drawLine(const Offset(9.2, 14), const Offset(14.8, 14), line);
    }
  }

  @override
  bool shouldRepaint(_MocktailMethodPainter old) =>
      old.method != method || old.color != color;
}

/// Tingkat manis sebagai satu sampai tiga tetes.
class SweetnessIcon extends StatelessWidget {
  const SweetnessIcon({
    super.key,
    required this.sweetness,
    required this.color,
    this.size = 24,
  });

  final MocktailSweetness sweetness;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(size),
    painter: _SweetnessPainter(sweetness.index + 1, color),
  );
}

class _SweetnessPainter extends CustomPainter {
  const _SweetnessPainter(this.drops, this.color);

  final int drops;
  final Color color;

  Path _drop(double cx, double cy, double s) => Path()
    ..moveTo(cx, cy - 5.2 * s)
    ..cubicTo(
      cx + 2 * s,
      cy - 2.2 * s,
      cx + 3.6 * s,
      cy - 0.4 * s,
      cx + 3.6 * s,
      cy + 1.6 * s,
    )
    ..cubicTo(
      cx + 3.6 * s,
      cy + 3.8 * s,
      cx + 2 * s,
      cy + 5 * s,
      cx,
      cy + 5 * s,
    )
    ..cubicTo(
      cx - 2 * s,
      cy + 5 * s,
      cx - 3.6 * s,
      cy + 3.8 * s,
      cx - 3.6 * s,
      cy + 1.6 * s,
    )
    ..cubicTo(
      cx - 3.6 * s,
      cy - 0.4 * s,
      cx - 2 * s,
      cy - 2.2 * s,
      cx,
      cy - 5.2 * s,
    )
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24);
    final Paint line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    switch (drops) {
      case 1:
        canvas.drawPath(_drop(12, 12.5, 1.55), line);
      case 2:
        canvas
          ..drawPath(_drop(7.6, 13, 1.25), line)
          ..drawPath(_drop(16.4, 11, 1.25), line);
      default:
        canvas
          ..drawPath(_drop(12, 7, 1.0), line)
          ..drawPath(_drop(6.6, 16.5, 1.0), line)
          ..drawPath(_drop(17.4, 16.5, 1.0), line);
    }
  }

  @override
  bool shouldRepaint(_SweetnessPainter old) =>
      old.drops != drops || old.color != color;
}
