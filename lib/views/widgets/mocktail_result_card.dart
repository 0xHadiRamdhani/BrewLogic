import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/mocktail_model.dart';
import 'glass_card.dart';

/// Hasil mocktail: takaran per porsi (dan total bila lebih dari satu porsi)
/// serta langkah pembuatan.
class MocktailResultCard extends StatelessWidget {
  const MocktailResultCard({super.key, required this.blend});

  final MocktailBlend blend;

  @override
  Widget build(BuildContext context) {
    final bool many = blend.servings > 1;

    return GlassCard(
      accent: AppColors.sage,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text('${blend.spec.glassMl}', style: AppTextStyles.heroNumber),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  'ml / gelas',
                  style: AppTextStyles.bodySecondary.copyWith(
                    color: AppColors.sage,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '${blend.summary} · ${blend.spec.method.description}',
            style: AppTextStyles.bodySecondary,
          ),
          const SizedBox(height: 18),
          Row(
            children: <Widget>[
              const Expanded(
                child: Text('BAHAN', style: AppTextStyles.sectionLabel),
              ),
              Text(
                many ? 'PER PORSI · TOTAL' : 'PER PORSI',
                style: AppTextStyles.sectionLabel,
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final MocktailIngredient item in blend.ingredients)
            _IngredientRow(item: item, servings: blend.servings),
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

class _IngredientRow extends StatelessWidget {
  const _IngredientRow({required this.item, required this.servings});

  final MocktailIngredient item;
  final int servings;

  @override
  Widget build(BuildContext context) {
    final String per = '${formatGrams(item.perServing)} ${item.unit}';
    final String total =
        '${formatGrams(item.perServing * servings)} ${item.unit}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: <Widget>[
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: item.color == null
                  ? AppColors.textSecondary
                  : Color(item.color!),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              item.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.body,
            ),
          ),
          Text(per, style: AppTextStyles.metricValue),
          if (servings > 1) ...<Widget>[
            const SizedBox(width: 8),
            Text(
              '· $total',
              style: AppTextStyles.bodySecondary.copyWith(
                color: AppColors.sage,
              ),
            ),
          ],
        ],
      ),
    );
  }
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
              color: AppColors.sage.withValues(alpha: 0.18),
              border: Border.all(color: AppColors.sage.withValues(alpha: 0.6)),
            ),
            child: Text(
              '$number',
              style: const TextStyle(
                color: AppColors.sage,
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
