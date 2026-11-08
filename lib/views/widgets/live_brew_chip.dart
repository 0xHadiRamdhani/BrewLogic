import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/brew_model.dart';
import '../../viewmodels/brew_viewmodel.dart';
import 'motion.dart';

/// Pil "sedang menyeduh" di app bar: titik berdenyut, nama fase, dan sisa
/// waktu. Muncul dan hilang dengan animasi; ketuk untuk membuka tab Timer.
class LiveBrewChip extends StatelessWidget {
  const LiveBrewChip({super.key, required this.onTap, this.visible = true});

  final VoidCallback onTap;

  /// Disembunyikan paksa, mis. saat tab Timer sudah terbuka.
  final bool visible;

  @override
  Widget build(BuildContext context) {
    final BrewViewModel vm = context.watch<BrewViewModel>();
    final BrewCalculation? calc = vm.calculation;
    final bool live =
        visible &&
        calc != null &&
        (vm.timerStatus == BrewTimerStatus.running ||
            vm.timerStatus == BrewTimerStatus.paused);

    return AnimatedSize(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      alignment: Alignment.centerRight,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 320),
        switchInCurve: Curves.easeOutBack,
        transitionBuilder: (Widget child, Animation<double> animation) =>
            FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: animation,
                alignment: Alignment.centerRight,
                child: child,
              ),
            ),
        child: live
            ? _Chip(
                key: const ValueKey<String>('live'),
                calculation: calc,
                viewModel: vm,
                onTap: onTap,
              )
            : const SizedBox.shrink(key: ValueKey<String>('idle')),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    super.key,
    required this.calculation,
    required this.viewModel,
    required this.onTap,
  });

  final BrewCalculation calculation;
  final BrewViewModel viewModel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool running = viewModel.timerStatus == BrewTimerStatus.running;
    final Color color = running ? AppColors.sage : AppColors.caramel;

    return Semantics(
      button: true,
      label: 'Seduhan sedang berlangsung. Buka timer.',
      child: PressableScale(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.55)),
          ),
          child: ValueListenableBuilder<Duration>(
            valueListenable: viewModel.elapsed,
            builder: (BuildContext context, Duration elapsed, Widget? _) {
              final BrewStep step =
                  calculation.steps[calculation.stepIndexAt(elapsed)];
              final int remaining = calculation.stepRemainingSecondsAt(elapsed);
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  PulsingDot(color: color, size: 7, animate: running),
                  const SizedBox(width: 9),
                  Text(
                    '${step.title} · ${formatClock(remaining)}',
                    style: TextStyle(
                      color: color,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      fontFeatures: const <FontFeature>[
                        FontFeature.tabularFigures(),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
