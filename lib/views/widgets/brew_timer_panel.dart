import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/brew_model.dart';
import '../../viewmodels/brew_viewmodel.dart';
import 'app_button.dart';
import 'glass_card.dart';
import 'motion.dart';
import 'pour_animation.dart';

/// Panel timer kaca: cincin progres ganda, hitung mundur fase aktif, dan
/// tombol Play / Pause / Resume / Reset.
class BrewTimerPanel extends StatelessWidget {
  const BrewTimerPanel({super.key, required this.viewModel});

  final BrewViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final BrewCalculation? calc = viewModel.calculation;
    if (calc == null) {
      return const SizedBox.shrink();
    }
    final BrewTimerStatus status = viewModel.timerStatus;

    return GlassCard(
      accent: AppColors.sage,
      child: Column(
        children: <Widget>[
          ValueListenableBuilder<Duration>(
            valueListenable: viewModel.elapsed,
            builder: (BuildContext context, Duration elapsed, _) =>
                _TimerDial(calculation: calc, elapsed: elapsed, status: status),
          ),
          const SizedBox(height: 16),
          _CurrentInstruction(
            step: calc.steps[viewModel.currentStepIndex],
            status: status,
          ),
          const SizedBox(height: 20),
          _TimerControls(viewModel: viewModel, status: status),
        ],
      ),
    );
  }
}

class _TimerDial extends StatelessWidget {
  const _TimerDial({
    required this.calculation,
    required this.elapsed,
    required this.status,
  });

  final BrewCalculation calculation;
  final Duration elapsed;
  final BrewTimerStatus status;

  static const double _dialSize = 290;

  @override
  Widget build(BuildContext context) {
    final int index = calculation.stepIndexAt(elapsed);
    final BrewStep step = calculation.steps[index];
    final int stepMs = step.durationSeconds * 1000;
    final int stepElapsedMs = (elapsed - calculation.stepStartOf(index))
        .inMilliseconds
        .clamp(0, stepMs);
    final int remainingSeconds = ((stepMs - stepElapsedMs) / 1000).ceil();
    final double stepFraction = stepElapsedMs / stepMs;
    final double totalFraction =
        elapsed.inMilliseconds / (calculation.totalSeconds * 1000);

    final bool finished = status == BrewTimerStatus.finished;
    final String caption = switch (status) {
      BrewTimerStatus.idle => 'SIAP',
      BrewTimerStatus.paused => 'DIJEDA · ${step.title.toUpperCase()}',
      BrewTimerStatus.finished => 'SELESAI',
      BrewTimerStatus.running => step.title.toUpperCase(),
    };

    return Semantics(
      label: 'Timer seduh, ${step.title}',
      value: finished
          ? 'Selesai'
          : 'Sisa ${formatClock(remainingSeconds)} pada fase ${step.title}',
      child: SizedBox(
        width: _dialSize,
        height: _dialSize,
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            CustomPaint(
              size: const Size.square(_dialSize),
              painter: _TimerRingPainter(
                stepFraction: stepFraction,
                totalFraction: totalFraction,
                paused: status == BrewTimerStatus.paused,
              ),
            ),
            // Isi cincin dibatasi agar tidak menyentuh cincin dalam, dan
            // mengecil otomatis bila ukuran teks pengguna besar.
            SizedBox(
              width: _dialSize - 100,
              height: _dialSize - 100,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    PourAnimation(status: status, height: 76),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        if (status == BrewTimerStatus.running) ...<Widget>[
                          const PulsingDot(color: AppColors.sage, size: 7),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          caption,
                          style: AppTextStyles.sectionLabel.copyWith(
                            color: status == BrewTimerStatus.paused
                                ? AppColors.caramel
                                : AppColors.sage,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      finished ? '00:00' : formatClock(remainingSeconds),
                      style: AppTextStyles.timerDigits.copyWith(fontSize: 44),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Total ${formatClock(elapsed.inSeconds)} / '
                      '${formatClock(calculation.totalSeconds)}',
                      style: AppTextStyles.bodySecondary.copyWith(fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CurrentInstruction extends StatelessWidget {
  const _CurrentInstruction({required this.step, required this.status});

  final BrewStep step;
  final BrewTimerStatus status;

  @override
  Widget build(BuildContext context) {
    final String text = status == BrewTimerStatus.finished
        ? 'Seduhan selesai. Aduk perlahan, nikmati, lalu catat hasilnya.'
        : step.instruction;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      transitionBuilder: (Widget child, Animation<double> animation) =>
          FadeTransition(opacity: animation, child: child),
      child: Text(
        text,
        key: ValueKey<String>(text),
        textAlign: TextAlign.center,
        style: AppTextStyles.body,
      ),
    );
  }
}

class _TimerControls extends StatelessWidget {
  const _TimerControls({required this.viewModel, required this.status});

  final BrewViewModel viewModel;
  final BrewTimerStatus status;

  @override
  Widget build(BuildContext context) {
    final String primaryLabel = switch (status) {
      BrewTimerStatus.idle => 'Mulai',
      BrewTimerStatus.running => 'Jeda',
      BrewTimerStatus.paused => 'Lanjutkan',
      BrewTimerStatus.finished => 'Ulangi',
    };

    return Row(
      children: <Widget>[
        Expanded(
          flex: 2,
          child: AppButton(
            label: 'Reset',
            color: AppColors.secondaryButton,
            textColor: AppColors.textPrimary,
            enabled: status != BrewTimerStatus.idle,
            onPressed: viewModel.resetTimer,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 3,
          child: AppButton(
            label: primaryLabel,
            color: status == BrewTimerStatus.running
                ? AppColors.sage
                : AppColors.caramel,
            textColor: AppColors.onAccent,
            onPressed: viewModel.toggleTimer,
          ),
        ),
      ],
    );
  }
}

/// Cincin luar = progres total (cyan), cincin dalam = progres fase (amber).
class _TimerRingPainter extends CustomPainter {
  const _TimerRingPainter({
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
  bool shouldRepaint(_TimerRingPainter old) =>
      old.stepFraction != stepFraction ||
      old.totalFraction != totalFraction ||
      old.paused != paused;
}

/// Daftar tiga fase dengan penanda selesai / aktif / menunggu.
class BrewStepList extends StatelessWidget {
  const BrewStepList({
    super.key,
    required this.calculation,
    required this.activeIndex,
    required this.status,
  });

  final BrewCalculation calculation;
  final int activeIndex;
  final BrewTimerStatus status;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        children: <Widget>[
          for (int i = 0; i < calculation.steps.length; i++)
            _StepRow(
              step: calculation.steps[i],
              state: _stateOf(i),
              isLast: i == calculation.steps.length - 1,
            ),
        ],
      ),
    );
  }

  _StepState _stateOf(int index) {
    if (status == BrewTimerStatus.finished) {
      return _StepState.done;
    }
    if (status == BrewTimerStatus.idle) {
      return _StepState.pending;
    }
    if (index < activeIndex) {
      return _StepState.done;
    }
    return index == activeIndex ? _StepState.active : _StepState.pending;
  }
}

enum _StepState { pending, active, done }

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.step,
    required this.state,
    required this.isLast,
  });

  final BrewStep step;
  final _StepState state;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final bool active = state == _StepState.active;
    final bool done = state == _StepState.done;
    final Color accent = done
        ? AppColors.sage
        : active
        ? AppColors.caramel
        : AppColors.textSecondary;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: Color(0x1FF3E6D6))),
      ),
      child: Row(
        children: <Widget>[
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: active || done ? 0.2 : 0.08),
              border: Border.all(color: accent),
            ),
            child: Icon(
              done ? Icons.check_rounded : Icons.circle,
              size: done ? 18 : 8,
              color: accent,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  step.title,
                  style: AppTextStyles.metricValue.copyWith(
                    color: active || done
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                  ),
                ),
                Text(
                  'Tuang ${formatGrams(step.pourGrams)} ml · '
                  'target ${formatGrams(step.targetWaterGrams)} ml',
                  style: AppTextStyles.bodySecondary.copyWith(fontSize: 13),
                ),
              ],
            ),
          ),
          Text(
            formatClock(step.durationSeconds),
            style: AppTextStyles.metricValue.copyWith(color: accent),
          ),
        ],
      ),
    );
  }
}
