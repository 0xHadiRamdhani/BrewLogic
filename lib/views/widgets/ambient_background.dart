import 'package:flutter/widgets.dart';

import '../../core/theme/app_theme.dart';

/// Cahaya karamel dan sage yang lembut di belakang konten, ditambah cincin
/// tipis seperti bekas dasar cangkir. Tanpa ini, `BackdropFilter` pada latar
/// polos tidak punya apa pun untuk di-blur.
class AmbientBackground extends StatelessWidget {
  const AmbientBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: RepaintBoundary(
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            ColoredBox(color: AppColors.background),
            Positioned(
              top: -140,
              left: -120,
              child: _Glow(color: AppColors.caramel, size: 460, alpha: 0.30),
            ),
            Positioned(
              top: 260,
              right: -180,
              child: _Glow(color: AppColors.sage, size: 420, alpha: 0.10),
            ),
            Positioned(
              bottom: -160,
              left: -80,
              child: _Glow(color: AppColors.caramel, size: 400, alpha: 0.16),
            ),
            CustomPaint(painter: _RingsPainter()),
          ],
        ),
      ),
    );
  }
}

/// Cincin konsentris samar di sudut kanan atas dan kiri bawah.
class _RingsPainter extends CustomPainter {
  const _RingsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    void rings(Offset center, List<double> radii, double alpha) {
      for (int i = 0; i < radii.length; i++) {
        paint.color = AppColors.caramel.withValues(alpha: alpha - i * 0.012);
        canvas.drawCircle(center, radii[i], paint);
      }
    }

    rings(Offset(size.width * 0.92, size.height * 0.14), <double>[
      70,
      108,
      150,
    ], 0.10);
    rings(Offset(size.width * 0.04, size.height * 0.86), <double>[
      90,
      132,
      178,
    ], 0.08);
  }

  @override
  bool shouldRepaint(_RingsPainter oldDelegate) => false;
}

class _Glow extends StatelessWidget {
  const _Glow({required this.color, required this.size, required this.alpha});

  final Color color;
  final double size;
  final double alpha;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: <Color>[
            color.withValues(alpha: alpha),
            color.withValues(alpha: 0),
          ],
        ),
      ),
    );
  }
}
