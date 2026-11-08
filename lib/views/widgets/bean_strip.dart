import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/haptics.dart';
import '../../models/brew_model.dart';
import '../../services/bean_freshness.dart';
import 'filter_pill.dart';
import 'glass_card.dart';
import 'motion.dart';

/// Warna penanda tahap kesegaran.
Color freshnessColor(FreshnessStage stage) => switch (stage) {
  FreshnessStage.resting => AppColors.sage,
  FreshnessStage.peak => const Color(0xFF9DBB8A),
  FreshnessStage.good => AppColors.caramel,
  FreshnessStage.fading => const Color(0xFFC9794F),
};

/// Baris "Biji Kopi": pilih biji aktif, lihat kesegarannya, atau tambah biji.
class BeanStrip extends StatelessWidget {
  const BeanStrip({
    super.key,
    required this.beans,
    required this.activeId,
    required this.freshnessOf,
    required this.onSelect,
    required this.onAdd,
  });

  final List<BrewBean> beans;
  final String? activeId;
  final BeanFreshness? Function(BrewBean bean) freshnessOf;
  final ValueChanged<String> onSelect;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    BrewBean? active;
    for (final BrewBean b in beans) {
      if (b.id == activeId) {
        active = b;
      }
    }
    final BeanFreshness? freshness = active == null
        ? null
        : freshnessOf(active);

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 0, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Row(
            children: <Widget>[
              Icon(Icons.grain_rounded, size: 18, color: AppColors.caramel),
              SizedBox(width: 8),
              Text('BIJI KOPI', style: AppTextStyles.sectionLabel),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(right: 18),
              children: <Widget>[
                for (final BrewBean bean in beans) ...<Widget>[
                  FilterPill(
                    label: bean.name,
                    selected: bean.id == activeId,
                    onTap: () => onSelect(bean.id),
                  ),
                  const SizedBox(width: 8),
                ],
                FilterPill(
                  label: beans.isEmpty ? 'Tambah biji' : 'Baru',
                  icon: Icons.add_rounded,
                  selected: beans.isEmpty,
                  onTap: onAdd,
                ),
              ],
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: freshness == null
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: 14, right: 18),
                    child: _FreshnessLine(freshness: freshness),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Satu baris kesegaran: titik warna, ringkasan, dan saran.
class _FreshnessLine extends StatelessWidget {
  const _FreshnessLine({required this.freshness});

  final BeanFreshness freshness;

  @override
  Widget build(BuildContext context) {
    final Color color = freshnessColor(freshness.stage);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(top: 6, right: 10),
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                freshness.summary,
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                freshness.tip,
                style: AppTextStyles.bodySecondary.copyWith(fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Kartu satu biji untuk layar Biji Kopi.
class BeanCard extends StatelessWidget {
  const BeanCard({
    super.key,
    required this.bean,
    required this.freshness,
    required this.onTap,
  });

  final BrewBean bean;
  final BeanFreshness? freshness;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final List<String> meta = <String>[
      if (bean.roaster.isNotEmpty) bean.roaster,
      if (bean.origin.isNotEmpty) bean.origin,
    ];
    return Semantics(
      button: true,
      label: 'Ubah biji ${bean.name}',
      child: PressableScale(
        pressedScale: 0.98,
        onTap: () {
          Haptics.selection();
          onTap();
        },
        child: GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      bean.name,
                      style: AppTextStyles.metricValue.copyWith(fontSize: 19),
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
              if (meta.isNotEmpty) ...<Widget>[
                const SizedBox(height: 2),
                Text(meta.join(' · '), style: AppTextStyles.bodySecondary),
              ],
              const SizedBox(height: 12),
              if (freshness != null)
                _FreshnessLine(freshness: freshness!)
              else
                Text(
                  'Tanggal roasting belum diisi',
                  style: AppTextStyles.bodySecondary.copyWith(fontSize: 13),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
