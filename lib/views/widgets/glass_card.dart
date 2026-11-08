import 'dart:ui' show ImageFilter;

import 'package:flutter/widgets.dart';

import '../../core/theme/app_theme.dart';

/// Panel bergaya iOS Liquid Glass: blur tinggi, isian putih transparan, dan
/// tepi bercahaya yang lebih terang di sisi atas-kiri.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.borderRadius = 26,
    this.blurSigma = 28,
    this.accent,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final double blurSigma;

  /// Warna tepi opsional untuk menonjolkan kartu (mis. hasil kalkulasi).
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius = BorderRadius.circular(borderRadius);
    final Color edge = accent?.withValues(alpha: 0.45) ?? AppColors.glassBorder;
    final Color tint = accent ?? const Color(0xFFF3E6D6);

    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: edge),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                tint.withValues(alpha: accent == null ? 0.13 : 0.24),
                tint.withValues(alpha: accent == null ? 0.03 : 0.05),
              ],
            ),
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
