import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/haptics.dart';
import 'brew_icons.dart';

/// Rating 1–5 biji kopi. Bisa interaktif ([onChanged] != null) atau hanya baca.
class StarRatingBar extends StatelessWidget {
  const StarRatingBar({
    super.key,
    required this.rating,
    this.onChanged,
    this.size = 40,
  });

  static const int maxStars = 5;

  final int rating;
  final ValueChanged<int>? onChanged;
  final double size;

  @override
  Widget build(BuildContext context) {
    final bool interactive = onChanged != null;

    return Semantics(
      label: 'Rating',
      value: '$rating dari $maxStars biji kopi',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List<Widget>.generate(maxStars, (int index) {
          final int value = index + 1;
          final bool filled = value <= rating;
          final Widget star = AnimatedScale(
            scale: filled ? 1 : 0.88,
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutBack,
            child: BeanIcon(
              filled: filled,
              size: size,
              color: filled ? AppColors.caramel : AppColors.textSecondary,
            ),
          );

          if (!interactive) {
            return star;
          }
          return Semantics(
            button: true,
            label: '$value biji kopi',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                Haptics.selection();
                onChanged!(value);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: star,
              ),
            ),
          );
        }),
      ),
    );
  }
}
