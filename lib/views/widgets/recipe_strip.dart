import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/haptics.dart';
import '../../models/brew_model.dart';
import 'filter_pill.dart';
import 'motion.dart';

/// Baris "Resep Saya": chip resep yang bisa dimuat dengan satu ketukan
/// (tahan lama untuk menghapus) dan tombol untuk menyimpan seduhan saat ini.
class RecipeStrip extends StatelessWidget {
  const RecipeStrip({
    super.key,
    required this.recipes,
    required this.canSave,
    required this.onApply,
    required this.onDelete,
    required this.onSave,
  });

  final List<BrewRecipe> recipes;

  /// Tombol simpan aktif jika kalkulator punya hasil yang valid.
  final bool canSave;
  final ValueChanged<BrewRecipe> onApply;
  final ValueChanged<BrewRecipe> onDelete;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 0, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 18),
            child: Row(
              children: <Widget>[
                const Icon(
                  Icons.bookmark_outline_rounded,
                  size: 18,
                  color: AppColors.caramel,
                ),
                const SizedBox(width: 8),
                const Text('RESEP SAYA', style: AppTextStyles.sectionLabel),
                const Spacer(),
                if (recipes.isNotEmpty)
                  Text(
                    'Tahan untuk hapus',
                    style: AppTextStyles.bodySecondary.copyWith(fontSize: 11.5),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: recipes.isEmpty ? 44 : 62,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(right: 18),
              children: <Widget>[
                for (final BrewRecipe recipe in recipes) ...<Widget>[
                  _RecipeChip(
                    recipe: recipe,
                    onTap: () => onApply(recipe),
                    onLongPress: () => onDelete(recipe),
                  ),
                  const SizedBox(width: 10),
                ],
                if (canSave)
                  Center(
                    child: FilterPill(
                      label: 'Simpan resep',
                      icon: Icons.add_rounded,
                      selected: true,
                      onTap: onSave,
                    ),
                  )
                else if (recipes.isEmpty)
                  const Center(
                    child: Text(
                      'Isi kalkulator lalu simpan sebagai resep.',
                      style: AppTextStyles.bodySecondary,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecipeChip extends StatelessWidget {
  const _RecipeChip({
    required this.recipe,
    required this.onTap,
    required this.onLongPress,
  });

  final BrewRecipe recipe;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final double ratio = recipe.customization.ratio ?? recipe.method.waterRatio;
    return Semantics(
      button: true,
      label: 'Resep ${recipe.name}',
      hint: 'Ketuk untuk memuat, tahan untuk menghapus',
      child: PressableScale(
        pressedScale: 0.95,
        onTap: () {
          Haptics.selection();
          onTap();
        },
        onLongPress: () {
          Haptics.medium();
          onLongPress();
        },
        child: Container(
          constraints: const BoxConstraints(minWidth: 120, maxWidth: 190),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.caramel.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: AppColors.caramel.withValues(alpha: 0.45),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                recipe.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${recipe.method.shortLabel} · ${formatGrams(recipe.coffeeGrams)} g '
                '· ${formatRatio(ratio)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodySecondary.copyWith(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
