import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/brew_model.dart';
import '../../viewmodels/brew_viewmodel.dart';
import 'glass_app_bar.dart';
import 'glass_card.dart';
import 'motion.dart';

/// Panel "Sesuaikan resep": rasio dan durasi tiap fase. Tertutup secara
/// bawaan; lencana "Disesuaikan" muncul bila ada nilai yang diubah.
class CustomizationPanel extends StatefulWidget {
  const CustomizationPanel({super.key, required this.viewModel});

  final BrewViewModel viewModel;

  @override
  State<CustomizationPanel> createState() => _CustomizationPanelState();
}

class _CustomizationPanelState extends State<CustomizationPanel> {
  static const int _step = 5;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final BrewViewModel vm = widget.viewModel;
    final BrewCustomization custom = vm.customization;
    final BrewMethod method = vm.method;
    final double ratio = custom.ratio ?? method.waterRatio;
    final int bloom = custom.bloomSeconds ?? method.bloomSeconds;
    final int first = custom.firstPourSeconds ?? method.firstPourSeconds;
    final int second = custom.secondPourSeconds ?? method.secondPourSeconds;

    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Semantics(
            button: true,
            expanded: _expanded,
            label: 'Sesuaikan resep',
            child: PressableScale(
              pressedScale: 0.98,
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Row(
                  children: <Widget>[
                    const Icon(
                      Icons.tune_rounded,
                      color: AppColors.sage,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Sesuaikan resep',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (!custom.isDefault) const _Badge(label: 'Disesuaikan'),
                    const SizedBox(width: 8),
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOutCubic,
                      child: const Icon(
                        Icons.expand_more_rounded,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _expanded
                ? Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        _RatioRow(
                          ratio: ratio,
                          isCustom: custom.ratio != null,
                          onChanged: vm.setRatio,
                        ),
                        const SizedBox(height: 8),
                        _DurationRow(
                          label: 'Bloom',
                          seconds: bloom,
                          isCustom: custom.bloomSeconds != null,
                          onChanged: (int v) => vm.setBloomSeconds(v),
                          step: _step,
                          min: BrewCustomization.minBloomSeconds,
                          max: BrewCustomization.maxBloomSeconds,
                        ),
                        _DurationRow(
                          label: 'First Pour',
                          seconds: first,
                          isCustom: custom.firstPourSeconds != null,
                          onChanged: (int v) => vm.setFirstPourSeconds(v),
                          step: _step,
                          min: BrewCustomization.minPourSeconds,
                          max: BrewCustomization.maxPourSeconds,
                        ),
                        _DurationRow(
                          label: 'Second Pour',
                          seconds: second,
                          isCustom: custom.secondPourSeconds != null,
                          onChanged: (int v) => vm.setSecondPourSeconds(v),
                          step: _step,
                          min: BrewCustomization.minPourSeconds,
                          max: BrewCustomization.maxPourSeconds,
                        ),
                        if (!custom.isDefault) ...<Widget>[
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: PressableScale(
                              onTap: vm.resetCustomization,
                              child: const Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 8,
                                ),
                                child: Text(
                                  'Kembalikan ke bawaan',
                                  style: TextStyle(
                                    color: AppColors.caramel,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class _RatioRow extends StatelessWidget {
  const _RatioRow({
    required this.ratio,
    required this.isCustom,
    required this.onChanged,
  });

  final double ratio;
  final bool isCustom;
  final ValueChanged<double?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            const Text('Rasio air:kopi', style: AppTextStyles.bodySecondary),
            const Spacer(),
            Text(
              formatRatio(ratio),
              style: AppTextStyles.metricValue.copyWith(
                color: isCustom ? AppColors.caramel : AppColors.textPrimary,
              ),
            ),
          ],
        ),
        Semantics(
          label: 'Rasio air banding kopi',
          value: formatRatio(ratio),
          // Slider selalu menuntut leluhur Material (assert di mode debug),
          // juga di iOS yang memakai CupertinoSlider.
          child: Material(
            type: MaterialType.transparency,
            child: Slider.adaptive(
              value: ratio.clamp(
                BrewCustomization.minRatio,
                BrewCustomization.maxRatio,
              ),
              min: BrewCustomization.minRatio,
              max: BrewCustomization.maxRatio,
              divisions: 20,
              activeColor: AppColors.caramel,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}

class _DurationRow extends StatelessWidget {
  const _DurationRow({
    required this.label,
    required this.seconds,
    required this.isCustom,
    required this.onChanged,
    required this.step,
    required this.min,
    required this.max,
  });

  final String label;
  final int seconds;
  final bool isCustom;
  final ValueChanged<int> onChanged;
  final int step;
  final int min;
  final int max;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(label, style: AppTextStyles.body)),
          GlassIconButton(
            icon: Icons.remove_rounded,
            label: 'Kurangi durasi $label',
            onTap: seconds <= min ? () {} : () => onChanged(seconds - step),
          ),
          SizedBox(
            width: 68,
            child: Text(
              formatClock(seconds),
              textAlign: TextAlign.center,
              style: AppTextStyles.metricValue.copyWith(
                color: isCustom ? AppColors.caramel : AppColors.textPrimary,
              ),
            ),
          ),
          GlassIconButton(
            icon: Icons.add_rounded,
            label: 'Tambah durasi $label',
            onTap: seconds >= max ? () {} : () => onChanged(seconds + step),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.caramel.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.caramel.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.caramel,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
