import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/haptics.dart';
import '../../models/brew_model.dart';
import '../../models/mocktail_model.dart';
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
    this.mocktails = const <MocktailRecipe>[],
    this.onApplyMocktail,
    this.onDeleteMocktail,
  });

  final List<BrewRecipe> recipes;

  /// Resep mocktail, tampil bersama resep kopi (terbaru di depan).
  final List<MocktailRecipe> mocktails;
  final ValueChanged<MocktailRecipe>? onApplyMocktail;
  final ValueChanged<MocktailRecipe>? onDeleteMocktail;

  /// Tombol simpan aktif jika kalkulator punya hasil yang valid.
  final bool canSave;
  final ValueChanged<BrewRecipe> onApply;
  final ValueChanged<BrewRecipe> onDelete;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final List<_StripItem> items = <_StripItem>[
      for (final BrewRecipe r in recipes) _StripItem.coffee(r),
      for (final MocktailRecipe m in mocktails) _StripItem.mocktail(m),
    ]..sort((_StripItem a, _StripItem b) => b.createdAt.compareTo(a.createdAt));
    final bool isEmpty = items.isEmpty;

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
                if (!isEmpty)
                  Text(
                    'Tahan untuk hapus',
                    style: AppTextStyles.bodySecondary.copyWith(fontSize: 11.5),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: isEmpty ? 44 : 62,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(right: 18),
              children: <Widget>[
                for (final _StripItem item in items) ...<Widget>[
                  _RecipeChip(
                    title: item.title,
                    subtitle: item.subtitle,
                    icon: item.icon,
                    accent: item.accent,
                    semanticLabel: item.semanticLabel,
                    onTap: () {
                      if (item.coffee != null) {
                        onApply(item.coffee!);
                      } else {
                        onApplyMocktail?.call(item.mocktail!);
                      }
                    },
                    onLongPress: () {
                      if (item.coffee != null) {
                        onDelete(item.coffee!);
                      } else {
                        onDeleteMocktail?.call(item.mocktail!);
                      }
                    },
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
                else if (isEmpty)
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

/// Satu entri strip: resep kopi atau mocktail.
class _StripItem {
  _StripItem.coffee(BrewRecipe this.coffee) : mocktail = null;
  _StripItem.mocktail(MocktailRecipe this.mocktail) : coffee = null;

  final BrewRecipe? coffee;
  final MocktailRecipe? mocktail;

  DateTime get createdAt => coffee?.createdAt ?? mocktail!.createdAt;
  String get title => coffee?.name ?? mocktail!.name;

  String get subtitle {
    final BrewRecipe? c = coffee;
    if (c != null) {
      final double ratio = c.customization.ratio ?? c.method.waterRatio;
      return '${c.method.shortLabel} · ${formatGrams(c.coffeeGrams)} g '
          '· ${formatRatio(ratio)}';
    }
    final MocktailSpec s = mocktail!.spec;
    return 'Mocktail · ${s.syrups.length} sirup · ${s.glassMl} ml';
  }

  IconData get icon =>
      coffee != null ? Icons.coffee_rounded : Icons.local_bar_rounded;
  Color get accent => coffee != null ? AppColors.caramel : AppColors.sage;
  String get semanticLabel =>
      coffee != null ? 'Resep $title' : 'Resep mocktail $title';
}

class _RecipeChip extends StatelessWidget {
  const _RecipeChip({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.semanticLabel,
    required this.onTap,
    required this.onLongPress,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final String semanticLabel;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
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
          constraints: const BoxConstraints(minWidth: 120, maxWidth: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: accent.withValues(alpha: 0.45)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 18, color: accent),
              const SizedBox(width: 10),
              Flexible(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
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
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySecondary.copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
