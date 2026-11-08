import 'package:flutter/material.dart';

import '../../core/layout.dart';
import '../../core/theme/app_theme.dart';
import 'motion.dart';

/// App bar kaca minimalis: gradien lembut, logo garis tipis, dan judul yang
/// bertransisi geser + fade. Tanpa garis pemisah di bawahnya.
///
/// Dipakai di semua platform agar identitas visualnya konsisten. Letakkan di
/// atas konten (mis. `Positioned` dalam `Stack`); konten memakai
/// [AppLayout.screenPadding] agar tidak tertutup.
class GlassAppBar extends StatelessWidget {
  const GlassAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.tabIndex,
  });

  final String title;
  final String? subtitle;

  /// Menggantikan logo (mis. tombol kembali).
  final Widget? leading;
  final Widget? trailing;

  /// Berubah setiap tab ganti agar logo berdenyut sekali; kosongkan di
  /// halaman non-tab.
  final int? tabIndex;

  @override
  Widget build(BuildContext context) {
    final double top = MediaQuery.paddingOf(context).top;

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xB315100C), Color(0x0015100C)],
        ),
      ),
      child: SizedBox(
        height: top + AppLayout.headerHeight,
        child: Padding(
          padding: EdgeInsets.only(top: top, left: 16, right: 16),
          child: Row(
            children: <Widget>[
              leading ?? _BrandMark(pulse: tabIndex ?? 0),
              const SizedBox(width: 12),
              Expanded(
                child: _TitleBlock(title: title, subtitle: subtitle),
              ),
              if (trailing != null) ...<Widget>[
                const SizedBox(width: 8),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark({required this.pulse});

  /// Berubah setiap tab ganti sehingga logo berdenyut sekali.
  final int pulse;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey<int>(pulse),
      tween: Tween<double>(begin: 0.85, end: 1),
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutBack,
      builder: (BuildContext context, double scale, Widget? child) =>
          Transform.scale(scale: scale, child: child),
      child: Container(
        width: 42,
        height: 42,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[Color(0xFFE6B87A), Color(0xFFB9824A)],
          ),
        ),
        child: const Icon(
          Icons.coffee_rounded,
          color: AppColors.onAccent,
          size: 21,
        ),
      ),
    );
  }
}

class _TitleBlock extends StatelessWidget {
  const _TitleBlock({required this.title, required this.subtitle});

  final String title;
  final String? subtitle;

  static Widget _transition(Widget child, Animation<double> animation) {
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.45),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    );
  }

  static Widget _layout(Widget? current, List<Widget> previous) => Stack(
    alignment: Alignment.centerLeft,
    children: <Widget>[...previous, ?current],
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 380),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: _transition,
          layoutBuilder: _layout,
          child: Text(
            title,
            key: ValueKey<String>(title),
            style: const TextStyle(
              fontFamily: appDisplayFontFamily,
              color: AppColors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
              height: 1.1,
            ),
          ),
        ),
        if (subtitle != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 460),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: _transition,
              layoutBuilder: _layout,
              child: Text(
                subtitle!,
                key: ValueKey<String>(subtitle!),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodySecondary.copyWith(
                  fontSize: 13,
                  height: 1.15,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Tombol ikon bulat bergaya kaca untuk app bar.
class GlassIconButton extends StatelessWidget {
  const GlassIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconSize = 18,
  });

  final IconData icon;

  /// Label untuk pembaca layar.
  final String label;
  final VoidCallback onTap;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: PressableScale(
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.glassFill,
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: Icon(icon, size: iconSize, color: AppColors.textPrimary),
        ),
      ),
    );
  }
}

/// Tombol kembali bergaya kaca untuk halaman yang di-push.
class GlassBackButton extends StatelessWidget {
  const GlassBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    return GlassIconButton(
      icon: Icons.arrow_back_ios_new_rounded,
      iconSize: 15,
      label: 'Kembali',
      onTap: () => Navigator.of(context).maybePop(),
    );
  }
}

/// Memotong konten tepat di bawah app bar kaca.
///
/// Kontrol native (segmented control, switch) digambar di lapisan sistem dan
/// tidak bisa tertutup app bar Flutter, sehingga tampil di atas judul saat
/// konten digulir ke atas. Memotong konten di tepi bawah app bar mencegahnya.
class HeaderClip extends StatelessWidget {
  const HeaderClip({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final double top =
        MediaQuery.paddingOf(context).top + AppLayout.headerHeight;
    return ClipRect(clipper: _BelowHeaderClipper(top), child: child);
  }
}

class _BelowHeaderClipper extends CustomClipper<Rect> {
  const _BelowHeaderClipper(this.top);

  final double top;

  @override
  Rect getClip(Size size) => Rect.fromLTRB(0, top, size.width, size.height);

  @override
  bool shouldReclip(_BelowHeaderClipper oldClipper) => oldClipper.top != top;
}
