import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/haptics.dart';
import '../../models/brew_model.dart';
import '../../services/dial_in_service.dart';
import 'filter_pill.dart';
import 'glass_card.dart';
import 'motion.dart';
import 'section_label.dart';

/// Asisten dial-in: pilih kesan rasa lalu dapat saran penyetelan. Memilih
/// kesan yang sama sekali lagi menghapus pilihan.
class DialInPanel extends StatelessWidget {
  const DialInPanel({
    super.key,
    required this.method,
    required this.roast,
    required this.ratio,
    required this.brewSeconds,
    required this.fahrenheit,
    required this.selected,
    required this.onChanged,
    this.onApplyRatio,
  });

  static const DialInService _service = DialInService();

  final BrewMethod method;
  final RoastLevel roast;
  final double ratio;
  final int brewSeconds;
  final bool fahrenheit;
  final TasteFeedback? selected;
  final ValueChanged<TasteFeedback?> onChanged;

  /// Menerapkan rasio saran ke kalkulator; `null` menyembunyikan tombolnya.
  final ValueChanged<double>? onApplyRatio;

  @override
  Widget build(BuildContext context) {
    final TasteFeedback? taste = selected;
    final DialInAdvice? advice = taste == null
        ? null
        : _service.advise(
            taste: taste,
            method: method,
            roast: roast,
            ratio: ratio,
            brewSeconds: brewSeconds,
            fahrenheit: fahrenheit,
          );

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SectionLabel('Asisten dial-in · bagaimana rasanya?'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final TasteFeedback t in TasteFeedback.values)
                FilterPill(
                  label: t.label,
                  selected: t == taste,
                  onTap: () => onChanged(t == taste ? null : t),
                ),
            ],
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              transitionBuilder: (Widget child, Animation<double> a) =>
                  FadeTransition(opacity: a, child: child),
              layoutBuilder: (Widget? current, List<Widget> previous) => Stack(
                alignment: Alignment.topLeft,
                children: <Widget>[...previous, ?current],
              ),
              child: advice == null
                  ? const SizedBox(width: double.infinity)
                  : _AdviceBody(
                      key: ValueKey<TasteFeedback>(advice.taste),
                      advice: advice,
                      onApplyRatio: onApplyRatio,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdviceBody extends StatelessWidget {
  const _AdviceBody({super.key, required this.advice, this.onApplyRatio});

  final DialInAdvice advice;
  final ValueChanged<double>? onApplyRatio;

  @override
  Widget build(BuildContext context) {
    final bool good = advice.taste == TasteFeedback.balanced;
    final Color accent = good ? AppColors.sage : AppColors.caramel;

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              advice.summary,
              style: AppTextStyles.body.copyWith(
                fontWeight: FontWeight.w700,
                color: accent,
              ),
            ),
            const SizedBox(height: 10),
            for (final String tip in advice.tips)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.only(top: 7, right: 10),
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Expanded(child: Text(tip, style: AppTextStyles.body)),
                  ],
                ),
              ),
            if (advice.hasRatioChange && onApplyRatio != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: PressableScale(
                  onTap: () {
                    Haptics.medium();
                    onApplyRatio!(advice.suggestedRatio!);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.caramel.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.caramel.withValues(alpha: 0.55),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Icon(
                          Icons.calculate_outlined,
                          size: 18,
                          color: AppColors.caramel,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Coba ${formatRatio(advice.suggestedRatio!)} di Kalkulator',
                          style: const TextStyle(
                            color: AppColors.caramel,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
