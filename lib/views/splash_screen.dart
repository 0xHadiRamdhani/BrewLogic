import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/utils/haptics.dart';
import 'widgets/ambient_background.dart';

/// Splash bergaya barista: kopi dituang ke cangkir, uap naik, lalu wordmark
/// muncul. Ketuk layar untuk melewati. Dengan "reduce motion" aktif, animasi
/// dilewati dan hanya tampil sebentar.
class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
    required this.onFinished,
    this.duration = const Duration(milliseconds: 3600),
  });

  final VoidCallback onFinished;
  final Duration duration;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _main = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  late final AnimationController _steam = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );

  bool _started = false;
  bool _finished = false;
  Timer? _reducedMotionTimer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) {
      return;
    }
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _main.value = 1;
      _reducedMotionTimer = Timer(const Duration(milliseconds: 700), _finish);
      return;
    }
    _main.addStatusListener((AnimationStatus status) {
      if (status == AnimationStatus.completed) {
        _finish();
      }
    });
    _main.forward();
    _steam.repeat();
  }

  void _finish() {
    if (_finished || !mounted) {
      return;
    }
    _finished = true;
    Haptics.light();
    widget.onFinished();
  }

  @override
  void dispose() {
    _reducedMotionTimer?.cancel();
    _main.dispose();
    _steam.dispose();
    super.dispose();
  }

  static double _seg(
    double t,
    double a,
    double b, [
    Curve curve = Curves.linear,
  ]) => curve.transform(((t - a) / (b - a)).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _finish,
      child: Semantics(
        label: 'BrewLogic, sedang memuat. Ketuk untuk melewati.',
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            const AmbientBackground(),
            Center(
              child: AnimatedBuilder(
                animation: Listenable.merge(<Listenable>[_main, _steam]),
                builder: (BuildContext context, Widget? _) {
                  final double t = _main.value;
                  final double word = _seg(t, 0.62, 0.86, Curves.easeOutCubic);
                  final double tag = _seg(t, 0.80, 0.95, Curves.easeOut);
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      SizedBox(
                        width: 280,
                        height: 280,
                        child: CustomPaint(
                          painter: _CupPainter(
                            progress: t,
                            steam: _steam.value,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Opacity(
                        opacity: word,
                        child: Transform.translate(
                          offset: Offset(0, (1 - word) * 16),
                          child: Text.rich(
                            TextSpan(
                              children: <InlineSpan>[
                                TextSpan(
                                  text: 'Brew',
                                  style: _wordStyle(
                                    word,
                                    AppColors.textPrimary,
                                  ),
                                ),
                                TextSpan(
                                  text: 'Logic',
                                  style: _wordStyle(word, AppColors.caramel),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Opacity(
                        opacity: tag,
                        child: Transform.translate(
                          offset: Offset(0, (1 - tag) * 8),
                          child: Text(
                            'SEDUH PRESISI · NIKMATI PELAN',
                            style: AppTextStyles.sectionLabel.copyWith(
                              letterSpacing: 2.2,
                              color: AppColors.sage,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  TextStyle _wordStyle(double reveal, Color color) => TextStyle(
    fontFamily: appDisplayFontFamily,
    color: color,
    fontSize: 40,
    fontWeight: FontWeight.w800,
    letterSpacing: 14 - 12 * reveal,
  );
}

/// Menggambar cangkir, aliran kopi, dan uap di ruang desain 280x280.
class _CupPainter extends CustomPainter {
  const _CupPainter({required this.progress, required this.steam});

  final double progress;
  final double steam;

  static const double _topY = 120;
  static const double _botY = 232;
  static const double _topHalf = 78;
  static const double _botHalf = 56;

  static double _seg(
    double t,
    double a,
    double b, [
    Curve curve = Curves.linear,
  ]) => curve.transform(((t - a) / (b - a)).clamp(0.0, 1.0));

  @override
  void paint(Canvas canvas, Size size) {
    final double s = size.width / 280;
    canvas
      ..save()
      ..scale(s);
    const double cx = 140;
    final double t = progress;

    final double cupAlpha = _seg(t, 0, 0.12, Curves.easeOut);
    final double level = _seg(t, 0.14, 0.62, Curves.easeInOutCubic);
    final double surfaceY = _lerp(_botY - 6, _topY + 6, level);

    _paintGlow(canvas, cx, cupAlpha);
    _paintSaucer(canvas, cx, cupAlpha);

    final Path body = _bodyPath(cx);
    _paintCoffee(canvas, body, cx, surfaceY, level, t);
    _paintGlass(canvas, body, cx, cupAlpha);
    _paintHandle(canvas, cx, cupAlpha);
    _paintStream(canvas, cx, surfaceY, t);
    _paintSteam(canvas, cx, _seg(t, 0.62, 0.80, Curves.easeOut));

    canvas.restore();
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  Path _bodyPath(double cx) {
    return Path()
      ..moveTo(cx - _topHalf, _topY)
      ..lineTo(cx - _botHalf, _botY - 18)
      ..quadraticBezierTo(cx - _botHalf + 2, _botY, cx - _botHalf + 22, _botY)
      ..lineTo(cx + _botHalf - 22, _botY)
      ..quadraticBezierTo(cx + _botHalf - 2, _botY, cx + _botHalf, _botY - 18)
      ..lineTo(cx + _topHalf, _topY)
      ..close();
  }

  void _paintGlow(Canvas canvas, double cx, double alpha) {
    final Paint glow = Paint()
      ..color = AppColors.caramel.withValues(alpha: 0.28 * alpha)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 28);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, _botY + 6), width: 200, height: 40),
      glow,
    );
  }

  void _paintSaucer(Canvas canvas, double cx, double alpha) {
    final Rect rect = Rect.fromCenter(
      center: Offset(cx, _botY + 6),
      width: 224,
      height: 26,
    );
    canvas
      ..drawOval(
        rect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              AppColors.textPrimary.withValues(alpha: 0.22 * alpha),
              AppColors.textPrimary.withValues(alpha: 0.05 * alpha),
            ],
          ).createShader(rect),
      )
      ..drawOval(
        rect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = AppColors.textPrimary.withValues(alpha: 0.35 * alpha),
      );
  }

  void _paintCoffee(
    Canvas canvas,
    Path body,
    double cx,
    double surfaceY,
    double level,
    double t,
  ) {
    if (level <= 0.001) {
      return;
    }
    final double frac = (surfaceY - _topY) / (_botY - _topY);
    final double half = _topHalf + (_botHalf - _topHalf) * frac;
    final Rect fill = Rect.fromLTRB(
      cx - _topHalf,
      surfaceY,
      cx + _topHalf,
      _botY + 4,
    );

    canvas
      ..save()
      ..clipPath(body)
      ..drawRect(
        fill,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFFC77A24), Color(0xFF5A2E0E)],
          ).createShader(fill),
      )
      ..restore();

    final Rect surface = Rect.fromCenter(
      center: Offset(cx, surfaceY),
      width: half * 2,
      height: 14,
    );
    canvas.drawOval(surface, Paint()..color = const Color(0xFFE0A050));

    final bool pouring = t > 0.12 && t < 0.62;
    if (pouring) {
      final double ripple = (t * 9) % 1;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx, surfaceY),
          width: 14 + ripple * 56,
          height: 5 + ripple * 8,
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = AppColors.textPrimary.withValues(alpha: 0.5 * (1 - ripple)),
      );
    }
  }

  void _paintGlass(Canvas canvas, Path body, double cx, double alpha) {
    final Rect bounds = body.getBounds();
    canvas
      ..drawPath(
        body,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              AppColors.textPrimary.withValues(alpha: 0.20 * alpha),
              AppColors.textPrimary.withValues(alpha: 0.03 * alpha),
            ],
          ).createShader(bounds),
      )
      ..drawPath(
        body,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..strokeJoin = StrokeJoin.round
          ..color = AppColors.textPrimary.withValues(alpha: 0.45 * alpha),
      )
      ..drawOval(
        Rect.fromCenter(
          center: Offset(cx, _topY),
          width: _topHalf * 2,
          height: 26,
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = AppColors.textPrimary.withValues(alpha: 0.55 * alpha),
      );
  }

  void _paintHandle(Canvas canvas, double cx, double alpha) {
    final Path handle = Path()
      ..moveTo(cx + _topHalf - 8, _topY + 24)
      ..cubicTo(
        cx + _topHalf + 44,
        _topY + 10,
        cx + _topHalf + 36,
        _topY + 74,
        cx + _botHalf + 8,
        _botY - 34,
      );
    canvas.drawPath(
      handle,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round
        ..color = AppColors.textPrimary.withValues(alpha: 0.30 * alpha),
    );
  }

  void _paintStream(Canvas canvas, double cx, double surfaceY, double t) {
    final double grow = _seg(t, 0.08, 0.18, Curves.easeOut);
    final double retract = _seg(t, 0.58, 0.68, Curves.easeIn);
    const double startY = -24;
    final double y0 = _lerp(startY, surfaceY, retract);
    final double y1 = _lerp(startY, surfaceY, grow);
    if (y1 - y0 < 1) {
      return;
    }

    final Path stream = Path();
    const int steps = 24;
    for (int i = 0; i <= steps; i++) {
      final double y = _lerp(y0, y1, i / steps);
      final double x = cx + math.sin(y * 0.06 + t * 38) * 1.6;
      if (i == 0) {
        stream.moveTo(x, y);
      } else {
        stream.lineTo(x, y);
      }
    }
    final double width = 6.5 * (1 - 0.45 * retract);
    canvas
      ..drawPath(
        stream,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = width + 6
          ..strokeCap = StrokeCap.round
          ..color = AppColors.caramel.withValues(alpha: 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      )
      ..drawPath(
        stream,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round
          ..color = const Color(0xFFD98A2B),
      );
  }

  void _paintSteam(Canvas canvas, double cx, double alpha) {
    if (alpha <= 0.001) {
      return;
    }
    const List<double> offsets = <double>[-34, 0, 34];
    const List<double> lengths = <double>[74, 92, 68];
    const int points = 26;
    for (int w = 0; w < offsets.length; w++) {
      final Path path = Path();
      final double baseY = _topY - 16;
      for (int i = 0; i <= points; i++) {
        final double k = i / points;
        final double y = baseY - k * lengths[w];
        final double x =
            cx +
            offsets[w] +
            math.sin(k * 5.2 + steam * 2 * math.pi + w * 1.7) * (3 + k * 10);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      final Rect bounds = Rect.fromLTRB(
        cx + offsets[w] - 20,
        baseY - lengths[w],
        cx + offsets[w] + 20,
        baseY,
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4.5
          ..strokeCap = StrokeCap.round
          ..shader = LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: <Color>[
              const Color(0xFFFFE3B0).withValues(alpha: 0.55 * alpha),
              const Color(0xFFFFE3B0).withValues(alpha: 0),
            ],
          ).createShader(bounds),
      );
    }
  }

  @override
  bool shouldRepaint(_CupPainter old) =>
      old.progress != progress || old.steam != steam;
}
