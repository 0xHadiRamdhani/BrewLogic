import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/layout.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';
import '../services/stats_service.dart';
import '../viewmodels/journal_viewmodel.dart';
import 'widgets/empty_state.dart';
import 'widgets/app_text_scope.dart';
import 'widgets/ambient_background.dart';
import 'widgets/glass_app_bar.dart';
import 'widgets/glass_card.dart';
import 'widgets/motion.dart';
import 'widgets/rating_chart.dart';
import 'widgets/section_label.dart';

/// Statistik dan insight dari seluruh catatan jurnal.
class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key, this.clock = DateTime.now});

  /// Sumber waktu "sekarang"; bisa diganti di tes.
  final DateTime Function() clock;

  static const List<String> _weekdays = <String>[
    'Sen',
    'Sel',
    'Rab',
    'Kam',
    'Jum',
    'Sab',
    'Min',
  ];

  @override
  Widget build(BuildContext context) {
    final JournalViewModel journal = context.watch<JournalViewModel>();
    final JournalStats stats = const StatsService().compute(
      journal.entries,
      clock(),
    );

    return AdaptiveScaffold(
      backgroundColor: AppColors.background,
      body: AppTextScope(
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            const AmbientBackground(),
            HeaderClip(
              child: ListView(
                padding: AppLayout.screenPadding(context, hasBottomBar: false),
                children: <Widget>[
                  if (stats.isEmpty)
                    const StaggerIn(
                      child: EmptyState(
                        icon: Icons.insights_rounded,
                        title: 'Belum ada statistik',
                        message:
                            'Statistik muncul setelah kamu menyimpan seduhan '
                            'pertama.',
                      ),
                    )
                  else ...<Widget>[
                    StaggerIn(child: _Highlights(stats: stats)),
                    const SizedBox(height: 16),
                    StaggerIn(
                      index: 1,
                      child: _Section(
                        label: 'Rating terakhir',
                        child: RatingLineChart(values: stats.recentRatings),
                      ),
                    ),
                    const SizedBox(height: 16),
                    StaggerIn(
                      index: 2,
                      child: _Section(
                        label: '7 hari terakhir',
                        child: _WeekBars(days: stats.last7Days),
                      ),
                    ),
                    const SizedBox(height: 16),
                    StaggerIn(
                      index: 3,
                      child: _Section(
                        label: 'Metode favorit',
                        child: _MethodBars(stats: stats.perMethod),
                      ),
                    ),
                    if (stats.bestCombo != null) ...<Widget>[
                      const SizedBox(height: 16),
                      StaggerIn(
                        index: 4,
                        child: _BestCombo(combo: stats.bestCombo!),
                      ),
                    ],
                    if (stats.topTags.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 16),
                      StaggerIn(
                        index: 5,
                        child: _Section(
                          label: 'Rasa favorit',
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: <Widget>[
                              for (final TagCount t in stats.topTags)
                                _CountChip(label: t.tag.label, count: t.count),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: GlassAppBar(
                title: 'Statistik',
                subtitle: 'Insight dari seluruh seduhanmu',
                leading: GlassBackButton(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String weekday(DateTime d) => _weekdays[d.weekday - 1];
}

class _Section extends StatelessWidget {
  const _Section({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[SectionLabel(label), child],
        ),
      ),
    );
  }
}

class _Highlights extends StatelessWidget {
  const _Highlights({required this.stats});

  final JournalStats stats;

  @override
  Widget build(BuildContext context) {
    final int? seconds = stats.averageBrewSeconds;
    return GlassCard(
      accent: AppColors.caramel,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 18),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              _Tile(label: 'SEDUHAN', value: '${stats.totalBrews}'),
              _Tile(
                label: 'RATA-RATA',
                value: '${stats.averageRating.toStringAsFixed(1)}/5',
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: <Widget>[
              _Tile(
                label: 'STREAK',
                value: '${stats.currentStreak} hari',
                caption: 'Terpanjang ${stats.longestStreak}',
              ),
              _Tile(
                label: 'RATA-RATA DURASI',
                value: seconds == null ? '–' : formatClock(seconds),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.label, required this.value, this.caption});

  final String label;
  final String value;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: <Widget>[
          Text(
            value,
            maxLines: 1,
            style: AppTextStyles.heroNumber.copyWith(fontSize: 28),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTextStyles.sectionLabel.copyWith(fontSize: 10.5),
          ),
          if (caption != null)
            Text(
              caption!,
              style: AppTextStyles.bodySecondary.copyWith(fontSize: 11.5),
            ),
        ],
      ),
    );
  }
}

class _WeekBars extends StatelessWidget {
  const _WeekBars({required this.days});

  final List<DayCount> days;

  @override
  Widget build(BuildContext context) {
    final int max = days.fold<int>(
      1,
      (int m, DayCount d) => d.count > m ? d.count : m,
    );
    return SizedBox(
      height: 130,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          for (final (int i, DayCount day) in days.indexed)
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  Text(
                    day.count == 0 ? '' : '${day.count}',
                    style: AppTextStyles.bodySecondary.copyWith(fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: day.count / max),
                    duration: Duration(milliseconds: 500 + i * 70),
                    curve: Curves.easeOutCubic,
                    builder: (BuildContext c, double v, Widget? _) => Container(
                      width: 16,
                      height: 6 + 74 * v,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: <Color>[
                            day.count == 0
                                ? const Color(0x22F3E6D6)
                                : AppColors.caramel,
                            day.count == 0
                                ? const Color(0x11F3E6D6)
                                : AppColors.sage,
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    StatsScreen.weekday(day.date),
                    style: AppTextStyles.bodySecondary.copyWith(fontSize: 11.5),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _MethodBars extends StatelessWidget {
  const _MethodBars({required this.stats});

  final List<MethodStat> stats;

  @override
  Widget build(BuildContext context) {
    final int max = stats.fold<int>(
      1,
      (int m, MethodStat s) => s.count > m ? s.count : m,
    );
    return Column(
      children: <Widget>[
        for (final (int i, MethodStat s) in stats.indexed)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(
              children: <Widget>[
                SizedBox(
                  width: 78,
                  child: Text(s.method.shortLabel, style: AppTextStyles.body),
                ),
                Expanded(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: s.count / max),
                    duration: Duration(milliseconds: 600 + i * 90),
                    curve: Curves.easeOutCubic,
                    builder: (BuildContext c, double v, Widget? _) => Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: v.clamp(0.04, 1),
                        child: Container(
                          height: 14,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            gradient: const LinearGradient(
                              colors: <Color>[
                                AppColors.caramel,
                                AppColors.sage,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${s.count} · ${s.averageRating.toStringAsFixed(1)}/5',
                  style: AppTextStyles.bodySecondary.copyWith(fontSize: 13),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _BestCombo extends StatelessWidget {
  const _BestCombo({required this.combo});

  final ComboStat combo;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      accent: AppColors.sage,
      child: Row(
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.caramel.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.emoji_events_outlined,
              color: AppColors.caramel,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'KOMBINASI TERBAIK',
                  style: AppTextStyles.sectionLabel,
                ),
                const SizedBox(height: 4),
                Text(
                  '${combo.method.label} · Roast ${combo.roast.label}',
                  style: AppTextStyles.metricValue,
                ),
                Text(
                  '${combo.averageRating.toStringAsFixed(1)}/5 dari '
                  '${combo.count} seduhan',
                  style: AppTextStyles.bodySecondary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.caramel.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.caramel.withValues(alpha: 0.4)),
      ),
      child: Text(
        '$label · $count',
        style: const TextStyle(
          color: AppColors.caramel,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
