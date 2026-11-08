import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/layout.dart';
import '../core/navigation.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';
import '../models/brew_model.dart';
import '../viewmodels/journal_viewmodel.dart';
import 'journal_detail_screen.dart';
import 'stats_screen.dart';
import 'widgets/empty_state.dart';
import 'widgets/glass_dialog.dart';
import 'widgets/animated_value_text.dart';
import 'widgets/glass_card.dart';
import 'widgets/filter_pill.dart';
import 'widgets/journal_entry_tile.dart';
import 'widgets/motion.dart';
import 'widgets/section_label.dart';

/// Tab Jurnal: daftar seduhan tersimpan beserta ringkasan statistik.
class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _resetFilters(JournalViewModel vm) {
    _searchController.clear();
    vm.resetFilters();
  }

  void _openDetail(BuildContext context, BrewEntry entry) {
    pushPlatformPage<void>(context, JournalDetailScreen(entryId: entry.id));
  }

  /// Id catatan yang baru digeser hapus; disembunyikan seketika karena
  /// `Dismissible` mensyaratkan item hilang dari pohon widget di frame yang sama.
  final Set<String> _hiddenIds = <String>{};

  Future<bool> _confirm(BuildContext context, BrewEntry entry) {
    return showGlassConfirm(
      context,
      title: 'Hapus catatan?',
      message: 'Catatan ${entry.method.label} ini akan dihapus permanen.',
      confirmLabel: 'Hapus',
      destructive: true,
    );
  }

  Future<void> _delete(BuildContext context, BrewEntry entry) async {
    final JournalViewModel vm = context.read<JournalViewModel>();
    final String? error = await vm.deleteEntry(entry.id);
    if (error != null) {
      if (mounted) {
        setState(() => _hiddenIds.remove(entry.id));
      }
      if (context.mounted) {
        AdaptiveSnackBar.show(
          context,
          message: error,
          type: AdaptiveSnackBarType.error,
        );
      }
    }
  }

  Future<void> _confirmDelete(BuildContext context, BrewEntry entry) async {
    if (await _confirm(context, entry) && context.mounted) {
      await _delete(context, entry);
    }
  }

  @override
  Widget build(BuildContext context) {
    final JournalViewModel vm = context.watch<JournalViewModel>();
    final List<BrewEntry> visible = vm.visibleEntries
        .where((BrewEntry e) => !_hiddenIds.contains(e.id))
        .toList();
    final bool groupByDay =
        vm.sort == JournalSort.newest || vm.sort == JournalSort.oldest;

    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: AppLayout.screenPadding(context),
      children: <Widget>[
        if (vm.errorMessage != null)
          _Notice(
            icon: Icons.error_outline_rounded,
            color: AppColors.danger,
            text: vm.errorMessage!,
          )
        else if (vm.isEmpty)
          const StaggerIn(
            child: EmptyState(
              icon: Icons.menu_book_rounded,
              title: 'Jurnal masih kosong',
              message:
                  'Hitung takaran, seduh dengan timer, lalu simpan rating '
                  'dan tasting notes-mu di sini.',
            ),
          )
        else ...<Widget>[
          StaggerIn(
            child: _StatsCard(
              count: vm.entries.length,
              averageRating: vm.averageRating,
            ),
          ),
          const SizedBox(height: 12),
          StaggerIn(
            index: 1,
            child: Align(
              alignment: Alignment.centerLeft,
              child: FilterPill(
                label: 'Lihat statistik',
                icon: Icons.insights_rounded,
                selected: true,
                onTap: () =>
                    pushPlatformPage<void>(context, const StatsScreen()),
              ),
            ),
          ),
          const SizedBox(height: 12),
          StaggerIn(
            index: 1,
            child: _FilterBar(
              viewModel: vm,
              searchController: _searchController,
            ),
          ),
          if (visible.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: StaggerIn(
                index: 2,
                child: GlassCard(
                  child: Column(
                    children: <Widget>[
                      const _Notice(
                        icon: Icons.search_off_rounded,
                        color: AppColors.sage,
                        text:
                            'Tidak ada catatan yang cocok dengan pencarian '
                            'atau filter ini.',
                      ),
                      const SizedBox(height: 14),
                      FilterPill(
                        label: 'Reset filter',
                        selected: true,
                        icon: Icons.restart_alt_rounded,
                        onTap: () => _resetFilters(vm),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          for (final (int i, BrewEntry entry) in visible.indexed) ...<Widget>[
            if (groupByDay &&
                (i == 0 ||
                    !isSameDay(
                      visible[i - 1].createdAt,
                      entry.createdAt,
                    ))) ...<Widget>[
              SizedBox(height: i == 0 ? 20 : 12),
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: SectionLabel(dayLabel(entry.createdAt)),
              ),
            ] else
              const SizedBox(height: 12),
            StaggerIn(
              key: ValueKey<String>(entry.id),
              index: i + 2,
              child: Dismissible(
                key: ValueKey<String>('dismiss-${entry.id}'),
                direction: DismissDirection.endToStart,
                confirmDismiss: (_) => _confirm(context, entry),
                onDismissed: (_) {
                  setState(() => _hiddenIds.add(entry.id));
                  _delete(context, entry);
                },
                background: const _SwipeDeleteBackground(),
                child: JournalEntryTile(
                  entry: entry,
                  onTap: () => _openDetail(context, entry),
                  onDelete: () => _confirmDelete(context, entry),
                ),
              ),
            ),
          ],
        ],
      ],
    );
  }
}

/// Kolom pencarian, chip metode, serta pil pengurutan dan rating minimum.
class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.viewModel, required this.searchController});

  final JournalViewModel viewModel;
  final TextEditingController searchController;

  @override
  Widget build(BuildContext context) {
    final JournalViewModel vm = viewModel;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        AdaptiveTextFormField(
          controller: searchController,
          placeholder: 'Cari catatan, metode, atau roast',
          textInputAction: TextInputAction.search,
          onChanged: vm.setQuery,
          onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
          style: AppTextStyles.body,
          prefixIcon: const Padding(
            padding: EdgeInsets.only(left: 4),
            child: Icon(
              Icons.search_rounded,
              size: 20,
              color: AppColors.textSecondary,
            ),
          ),
          cupertinoDecoration: BoxDecoration(
            color: AppColors.glassFill,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.glassBorder),
          ),
          decoration: InputDecoration(
            hintText: 'Cari catatan, metode, atau roast',
            prefixIcon: const Icon(Icons.search_rounded, size: 20),
            filled: true,
            fillColor: AppColors.glassFill,
            isDense: true,
            border: _border(AppColors.glassBorder),
            enabledBorder: _border(AppColors.glassBorder),
            focusedBorder: _border(AppColors.caramel, 1.6),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            children: <Widget>[
              FilterPill(
                label: 'Semua',
                selected: vm.methodFilter == null,
                onTap: () => vm.setMethodFilter(null),
              ),
              for (final BrewMethod m in BrewMethod.values) ...<Widget>[
                const SizedBox(width: 8),
                FilterPill(
                  label: m.shortLabel,
                  selected: vm.methodFilter == m,
                  onTap: () => vm.setMethodFilter(m),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            FilterPill(
              label: vm.sort.label,
              icon: Icons.swap_vert_rounded,
              selected: vm.sort != JournalSort.newest,
              onTap: vm.cycleSort,
            ),
            FilterPill(
              label: vm.minRating == 0
                  ? 'Semua rating'
                  : '${vm.minRating}/5 ke atas',
              icon: Icons.grain_rounded,
              selected: vm.minRating > 0,
              onTap: vm.cycleMinRating,
            ),
          ],
        ),
      ],
    );
  }

  static OutlineInputBorder _border(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: color, width: width),
      );
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.count, required this.averageRating});

  final int count;
  final double averageRating;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      accent: AppColors.caramel,
      child: Row(
        children: <Widget>[
          Expanded(
            child: _Stat(label: 'SEDUHAN', value: '$count'),
          ),
          const SizedBox(
            height: 40,
            width: 1,
            child: ColoredBox(color: Color(0x33F3E6D6)),
          ),
          Expanded(
            child: _Stat(
              label: 'RATA-RATA',
              value: '${averageRating.toStringAsFixed(1)}/5',
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        AnimatedValueText(
          text: value,
          alignment: Alignment.center,
          style: AppTextStyles.heroNumber.copyWith(fontSize: 34),
        ),
        const SizedBox(height: 4),
        Text(label, style: AppTextStyles.sectionLabel),
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Row(
        children: <Widget>[
          Icon(icon, color: color, size: 32),
          const SizedBox(width: 16),
          Expanded(child: Text(text, style: AppTextStyles.bodySecondary)),
        ],
      ),
    );
  }
}

/// Latar merah lembut yang tampak saat catatan digeser ke kiri.
class _SwipeDeleteBackground extends StatelessWidget {
  const _SwipeDeleteBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 28),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(26),
      ),
      child: const Icon(
        Icons.delete_outline_rounded,
        color: AppColors.danger,
        size: 28,
      ),
    );
  }
}
