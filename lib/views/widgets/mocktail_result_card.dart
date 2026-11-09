import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/mocktail_model.dart';
import 'animated_value_text.dart';
import 'brew_result_card.dart' show MetricRow;
import 'glass_card.dart';

/// Hasil mocktail dengan tata letak yang sama seperti kartu hasil kopi: angka
/// utama (ukuran gelas), lencana tingkat manis, lalu satu `MetricRow` per
/// bahan. Takaran per porsi, plus total bila lebih dari satu porsi, dan
/// langkah pembuatan di bawahnya.
class MocktailResultCard extends StatelessWidget {
  const MocktailResultCard({super.key, required this.blend});

  final MocktailBlend blend;

  static IconData _iconOf(MocktailIngredient i, MocktailSpec spec) =>
      switch (i.kind) {
        MocktailIngredientKind.syrup => Icons.water_drop_rounded,
        MocktailIngredientKind.citrus => Icons.eco_rounded,
        MocktailIngredientKind.base =>
          spec.baseSparkling
              ? Icons.bubble_chart_rounded
              : Icons.opacity_rounded,
        MocktailIngredientKind.ice => Icons.ac_unit_rounded,
      };

  String _captionOf(MocktailIngredient i, int index) {
    final MocktailSpec spec = blend.spec;
    final String base = switch (i.kind) {
      MocktailIngredientKind.syrup =>
        spec.customMl
            ? 'Takaran sendiri'
            : spec.syrups.length > 1
            ? '${spec.syrups[index].parts} bagian'
            : 'Manis ${spec.sweetness.label.toLowerCase()}',
      MocktailIngredientKind.citrus => 'Penyeimbang manis',
      MocktailIngredientKind.base =>
        spec.baseSparkling ? 'Berkarbonasi' : 'Tuang terakhir',
      MocktailIngredientKind.ice => 'Isi sekitar 40% gelas',
    };
    if (blend.servings > 1) {
      return '$base · Total ${formatGrams(i.perServing * blend.servings)} '
          '${i.unit}';
    }
    return base;
  }

  @override
  Widget build(BuildContext context) {
    final MocktailSpec spec = blend.spec;

    return GlassCard(
      accent: AppColors.caramel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Expanded(
                child: Text(
                  'UKURAN GELAS',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.sectionLabel,
                ),
              ),
              const SizedBox(width: 8),
              _Pill(
                label: blend.servings > 1
                    ? '${spec.customMl ? 'Sendiri' : spec.sweetness.label} '
                          '· ${blend.servings} porsi'
                    : spec.customMl
                    ? 'Takaran sendiri'
                    : 'Manis ${spec.sweetness.label}',
              ),
            ],
          ),
          const SizedBox(height: 6),
          Semantics(
            label: 'Ukuran gelas ${spec.glassMl} mililiter',
            excludeSemantics: true,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: <Widget>[
                Flexible(
                  child: AnimatedValueText(
                    text: '${spec.glassMl}',
                    style: AppTextStyles.heroNumber,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'ml',
                  style: TextStyle(
                    color: AppColors.caramel,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${spec.baseLabel} · ${spec.method.description}',
            style: AppTextStyles.bodySecondary,
          ),
          const SizedBox(height: 16),
          const _Divider(),
          for (int i = 0; i < blend.ingredients.length; i++) ...<Widget>[
            MetricRow(
              icon: _iconOf(blend.ingredients[i], spec),
              label: blend.ingredients[i].name,
              value:
                  '${formatGrams(blend.ingredients[i].perServing)} '
                  '${blend.ingredients[i].unit}',
              caption: _captionOf(blend.ingredients[i], i),
            ),
            const _Divider(),
          ],
          const SizedBox(height: 18),
          const Text('LANGKAH', style: AppTextStyles.sectionLabel),
          const SizedBox(height: 12),
          for (int i = 0; i < blend.steps.length; i++)
            _StepRow(number: i + 1, text: blend.steps[i]),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 190),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.caramel.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.caramel.withValues(alpha: 0.5)),
      ),
      child: AnimatedValueText(
        text: label,
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

class _StepRow extends StatelessWidget {
  const _StepRow({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.caramel.withValues(alpha: 0.16),
              border: Border.all(
                color: AppColors.caramel.withValues(alpha: 0.6),
              ),
            ),
            child: Text(
              '$number',
              style: const TextStyle(
                color: AppColors.caramel,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: AppTextStyles.body)),
        ],
      ),
    );
  }
}
