import 'dart:async';

import 'package:flutter/material.dart';

/// Memberi tahu widget turunan apakah tab-nya sedang aktif, supaya animasi
/// masuk bisa diputar ulang setiap tab dibuka.
class TabActivity extends InheritedWidget {
  const TabActivity({super.key, required this.active, required super.child});

  final bool active;

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TabActivity>()?.active ?? true;

  @override
  bool updateShouldNotify(TabActivity oldWidget) => active != oldWidget.active;
}

/// Animasi masuk berurutan: fade + naik sedikit, tertunda sesuai [index].
/// Diputar saat widget pertama tampil dan setiap [TabActivity] menjadi aktif.
class StaggerIn extends StatefulWidget {
  const StaggerIn({
    super.key,
    required this.child,
    this.index = 0,
    this.step = const Duration(milliseconds: 80),
    this.offsetY = 26,
  });

  final Widget child;
  final int index;
  final Duration step;
  final double offsetY;

  @override
  State<StaggerIn> createState() => _StaggerInState();
}

class _StaggerInState extends State<StaggerIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 560),
  );
  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );

  Timer? _delay;
  bool _wasActive = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool active = TabActivity.of(context);
    if (active && !_wasActive) {
      _play();
    } else if (!active && _wasActive) {
      _delay?.cancel();
      _controller.value = 0;
    }
    _wasActive = active;
  }

  void _play() {
    _delay?.cancel();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
      return;
    }
    _controller.value = 0;
    final int slot = widget.index.clamp(0, 8);
    _delay = Timer(widget.step * slot, () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _delay?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _curve,
      child: widget.child,
      builder: (BuildContext context, Widget? child) {
        final double v = _curve.value;
        return Opacity(
          opacity: v,
          child: Transform.translate(
            offset: Offset(0, (1 - v) * widget.offsetY),
            child: child,
          ),
        );
      },
    );
  }
}

/// Mengecil sedikit saat ditekan, kembali dengan pantulan halus.
class PressableScale extends StatefulWidget {
  const PressableScale({
    super.key,
    required this.child,
    required this.onTap,
    this.onLongPress,
    this.pressedScale = 0.92,
  });

  final Widget child;
  final VoidCallback onTap;

  /// Tahan lama, mis. untuk menghapus.
  final VoidCallback? onLongPress;
  final double pressedScale;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _pressed = false;

  void _set(bool value) {
    if (_pressed != value) {
      setState(() => _pressed = value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapCancel: () => _set(false),
      onTapUp: (_) => _set(false),
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: AnimatedScale(
        scale: _pressed ? widget.pressedScale : 1,
        duration: Duration(milliseconds: _pressed ? 90 : 260),
        curve: _pressed ? Curves.easeOut : Curves.easeOutBack,
        child: widget.child,
      ),
    );
  }
}

/// Titik berdenyut dengan cahaya, penanda aktivitas "live".
class PulsingDot extends StatefulWidget {
  const PulsingDot({
    super.key,
    required this.color,
    this.size = 8,
    this.animate = true,
  });

  final Color color;
  final double size;
  final bool animate;

  @override
  State<PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(PulsingDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    if (widget.animate) {
      if (!_controller.isAnimating) {
        _controller.repeat(reverse: true);
      }
    } else {
      _controller
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? _) {
        final double v = Curves.easeInOut.transform(_controller.value);
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color,
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: widget.color.withValues(alpha: 0.65),
                blurRadius: 3 + 8 * v,
                spreadRadius: 3 * v,
              ),
            ],
          ),
        );
      },
    );
  }
}
