import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/brew_model.dart';
import '../../viewmodels/settings_viewmodel.dart';
import 'animated_value_text.dart';
import 'glass_card.dart';

/// Kartu kaca berisi seluruh output kalkulator. Setiap nilai beranimasi
/// fade + scale saat berubah.
class BrewResultCard extends StatelessWidget {
  const BrewResultCard({
    super.key,
    required this.calculation,
    this.inputMode = BrewInputMode.coffee,
  });

  final BrewCalculation calculation;

  /// Menentukan angka utama: total air (mode kopi) atau gramasi kopi yang
  /// dibutuhkan (mode air / kalkulator terbalik).
  final BrewInputMode inputMode;

  @override
  Widget build(BuildContext context) {
    final BrewCalculation c = calculation;
    final bool reverse = inputMode == BrewInputMode.water;
    final double hero = reverse ? c.coffeeGrams : c.totalWaterGrams;
    final String heroLabel = reverse ? 'GRAMASI KOPI' : 'TOTAL AIR';

    return GlassCard(
      accent: AppColors.caramel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(heroLabel, style: AppTextStyles.sectionLabel),
              const Spacer(),
              _RatioPill(label: c.ratioLabel),
            ],
          ),
          const SizedBox(height: 6),
          Semantics(
            label: '$heroLabel ${formatGrams(hero)} gram',
            excludeSemantics: true,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: <Widget>[
                Flexible(
                  child: AnimatedValueText(
                    text: formatGrams(hero),
                    style: AppTextStyles.heroNumber,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  reverse ? 'g' : 'ml',
                  style: TextStyle(
                    color: AppColors.caramel,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const _Divider(),
          if (reverse) ...<Widget>[
            MetricRow(
              icon: Icons.opacity_rounded,
              label: 'Total air',
              value: '${formatGrams(c.totalWaterGrams)} ml',
              caption: 'Rasio ${c.ratioLabel}',
            ),
            const _Divider(),
          ],
          MetricRow(
            icon: Icons.thermostat_rounded,
            label: 'Suhu air ideal',
            value: formatTempRange(
              c.minTempC,
              c.maxTempC,
              fahrenheit: context.watch<SettingsViewModel>().useFahrenheit,
            ),
            caption: 'Roast ${c.roast.label}',
          ),
          const _Divider(),
          MetricRow(
            icon: Icons.grain_rounded,
            label: 'Ukuran gilingan',
            value: c.grindSize,
            caption: c.method.label,
          ),
          const _Divider(),
          MetricRow(
            icon: Icons.water_drop_rounded,
            label: 'Air untuk bloom',
            value: '${formatGrams(c.bloomRecommendedGrams)} ml',
            caption:
                '2x–3x · ${formatGrams(c.bloomMinGrams)}–'
                '${formatGrams(c.bloomMaxGrams)} ml',
          ),
        ],
      ),
    );
  }
}

/// Satu baris metrik: ikon, label, dan nilai beranimasi di kanan.
class MetricRow extends StatelessWidget {
  const MetricRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.caption,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.sage.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.sage, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(label, style: AppTextStyles.bodySecondary),
                if (caption != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      caption!,
                      style: AppTextStyles.bodySecondary.copyWith(
                        fontSize: 12,
                        color: AppColors.textSecondary.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: AnimatedValueText(
              text: value,
              style: AppTextStyles.metricValue,
              alignment: Alignment.centerRight,
            ),
          ),
        ],
      ),
    );
  }
}

class _RatioPill extends StatelessWidget {
  const _RatioPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.caramel.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.caramel.withValues(alpha: 0.5)),
      ),
      child: AnimatedValueText(
        text: 'Rasio $label',
        alignment: Alignment.center,
        style: const TextStyle(
          color: AppColors.caramel,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) =>
      const SizedBox(height: 1, child: ColoredBox(color: Color(0x1FF3E6D6)));
}
