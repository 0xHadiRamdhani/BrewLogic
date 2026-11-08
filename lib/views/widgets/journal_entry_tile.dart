import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/brew_model.dart';
import 'entry_photo.dart';
import 'glass_card.dart';
import 'motion.dart';
import 'star_rating_bar.dart';

/// Satu catatan seduhan di daftar jurnal.
class JournalEntryTile extends StatelessWidget {
  const JournalEntryTile({
    super.key,
    required this.entry,
    required this.onDelete,
    required this.onTap,
  });

  final BrewEntry entry;
  final VoidCallback onDelete;

  /// Membuka detail catatan.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Widget card = GlassCard(
      padding: const EdgeInsets.fromLTRB(20, 18, 8, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      entry.method.label,
                      style: AppTextStyles.metricValue.copyWith(fontSize: 20),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${formatGrams(entry.coffeeGrams)} g kopi → '
                      '${formatGrams(entry.waterGrams)} ml air',
                      style: AppTextStyles.bodySecondary,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: StarRatingBar(rating: entry.rating, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _Chip(label: 'Roast ${entry.roast.label}'),
              if (entry.taste != null) _Chip(label: entry.taste!.label),
              if (entry.beanName != null) _Chip(label: entry.beanName!),
              if (entry.grinderSetting.isNotEmpty)
                _Chip(label: 'Giling ${entry.grinderSetting}'),
              for (final FlavorTag tag in entry.flavorTags.take(3))
                _Chip(label: tag.label, accent: AppColors.caramel),
              if (entry.flavorTags.length > 3)
                _Chip(
                  label: '+${entry.flavorTags.length - 3}',
                  accent: AppColors.caramel,
                ),
              if (entry.brewSeconds > 0)
                _Chip(label: formatClock(entry.brewSeconds)),
            ],
          ),
          if (entry.photoName != null) ...<Widget>[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: EntryPhoto(
                name: entry.photoName,
                width: double.infinity,
                height: 150,
              ),
            ),
          ],
          if (entry.tastingNotes.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text(
                entry.tastingNotes,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.body,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  formatDateTime(entry.createdAt),
                  style: AppTextStyles.bodySecondary.copyWith(fontSize: 12),
                ),
              ),
              Semantics(
                label: 'Hapus catatan ${entry.method.label}',
                child: AdaptiveButton.icon(
                  icon: Icons.delete_outline_rounded,
                  iconColor: AppColors.danger,
                  style: AdaptiveButtonStyle.plain,
                  size: AdaptiveButtonSize.small,
                  useNative: false,
                  onPressed: onDelete,
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return Semantics(
      button: true,
      label: 'Buka detail seduhan ${entry.method.label}',
      child: PressableScale(pressedScale: 0.98, onTap: onTap, child: card),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, this.accent = AppColors.sage});

  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: accent,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
