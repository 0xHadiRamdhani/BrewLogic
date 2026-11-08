import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../viewmodels/brew_viewmodel.dart';

/// Animasi Lottie menuang kopi (teko, V60, cangkir) yang mengikuti status timer.
///
/// Berkas `assets/animations/pour.json` berisi dua segmen: frame 0-120 menuang
/// (berulang saat timer berjalan) dan frame 120-150 siaga (hanya uap, dipakai
/// saat siap atau selesai). Saat dijeda, animasi dibekukan di frame terakhir.
class PourAnimation extends StatefulWidget {
  const PourAnimation({super.key, required this.status, this.height = 150});

  static const String asset = 'assets/animations/pour.json';

  final BrewTimerStatus status;
  final double height;

  @override
  State<PourAnimation> createState() => _PourAnimationState();
}

class _PourAnimationState extends State<PourAnimation>
    with SingleTickerProviderStateMixin {
  static const double _totalFrames = 150;
  static const double _pourEnd = 120 / _totalFrames;

  late final AnimationController _controller = AnimationController(vsync: this);
  Duration? _duration;
  bool _reduceMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool reduce = MediaQuery.disableAnimationsOf(context);
    if (reduce != _reduceMotion) {
      _reduceMotion = reduce;
      _sync(null);
    }
  }

  @override
  void didUpdateWidget(PourAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status != widget.status) {
      _sync(oldWidget.status);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _isPouring(BrewTimerStatus status) =>
      status == BrewTimerStatus.running || status == BrewTimerStatus.paused;

  void _sync(BrewTimerStatus? previous) {
    final Duration? duration = _duration;
    if (duration == null) {
      return;
    }
    if (_reduceMotion) {
      _controller
        ..stop()
        ..value = _isPouring(widget.status) ? 0.3 : _pourEnd;
      return;
    }
    switch (widget.status) {
      case BrewTimerStatus.running:
        if (previous != BrewTimerStatus.paused ||
            _controller.value > _pourEnd) {
          _controller.value = 0;
        }
        _controller.repeat(
          min: 0,
          max: _pourEnd,
          period: duration * _pourEnd,
        );
      case BrewTimerStatus.paused:
        _controller.stop();
      case BrewTimerStatus.idle:
      case BrewTimerStatus.finished:
        _controller
          ..value = _pourEnd
          ..repeat(
            min: _pourEnd,
            max: 1,
            period: duration * (1 - _pourEnd),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        height: widget.height,
        child: Lottie.asset(
          PourAnimation.asset,
          controller: _controller,
          frameRate: FrameRate.max,
          fit: BoxFit.contain,
          onLoaded: (LottieComposition composition) {
            _duration = composition.duration;
            _controller.duration = composition.duration;
            _sync(null);
          },
        ),
      ),
    );
  }
}
