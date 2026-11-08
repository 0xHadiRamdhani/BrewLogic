import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_info.dart';
import '../core/layout.dart';
import '../core/navigation.dart';
import '../core/theme/app_theme.dart';
import '../services/backup_service.dart';
import '../services/data_transfer_service.dart';
import '../viewmodels/bean_viewmodel.dart';
import '../viewmodels/journal_viewmodel.dart';
import '../viewmodels/recipe_viewmodel.dart';
import '../viewmodels/settings_viewmodel.dart';
import 'about_screen.dart';
import 'beans_screen.dart';
import 'widgets/glass_dialog.dart';
import 'widgets/glass_card.dart';
import 'widgets/glass_controls.dart';
import 'widgets/motion.dart';
import 'widgets/section_label.dart';
import 'widgets/settings_row.dart';

/// Tab Pengaturan: preferensi, data, dan tentang aplikasi.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Rect _origin(BuildContext context) {
    final Size size = MediaQuery.sizeOf(context);
    return Rect.fromLTWH(size.width / 2, size.height / 2, 1, 1);
  }

  void _toast(BuildContext context, String message, {bool error = false}) {
    AdaptiveSnackBar.show(
      context,
      message: message,
      type: error ? AdaptiveSnackBarType.error : AdaptiveSnackBarType.success,
      duration: const Duration(seconds: 3),
    );
  }

  Future<void> _export(BuildContext context, {required bool csv}) async {
    final DataTransferService transfer = context.read<DataTransferService>();
    final Rect origin = _origin(context);
    try {
      if (csv) {
        await transfer.shareCsv(DateTime.now(), origin: origin);
      } else {
        await transfer.shareJsonBackup(DateTime.now(), origin: origin);
      }
    } catch (_) {
      if (context.mounted) {
        _toast(context, 'Gagal menyiapkan berkas ekspor', error: true);
      }
    }
  }

  Future<void> _import(BuildContext context) async {
    final DataTransferService transfer = context.read<DataTransferService>();
    final JournalViewModel journal = context.read<JournalViewModel>();
    final RecipeViewModel recipes = context.read<RecipeViewModel>();
    final BeanViewModel beans = context.read<BeanViewModel>();
    try {
      final ImportResult? result = await transfer.pickAndImport();
      if (result == null) {
        return;
      }
      journal.load();
      recipes.load();
      beans.load();
      if (context.mounted) {
        _toast(context, result.summary);
      }
    } on BackupException catch (e) {
      if (context.mounted) {
        _toast(context, e.message, error: true);
      }
    } catch (_) {
      if (context.mounted) {
        _toast(context, 'Berkas tidak dapat dibaca', error: true);
      }
    }
  }

  Future<void> _confirmClear(BuildContext context) async {
    final JournalViewModel journal = context.read<JournalViewModel>();
    final bool confirmed = await showGlassConfirm(
      context,
      title: 'Hapus semua catatan?',
      message:
          '${journal.entries.length} catatan seduhan akan dihapus permanen '
          'dan tidak dapat dikembalikan.',
      confirmLabel: 'Hapus semua',
      destructive: true,
    );
    if (!confirmed) {
      return;
    }
    final String? error = await journal.clearAll();
    if (context.mounted) {
      _toast(context, error ?? 'Semua catatan dihapus', error: error != null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final SettingsViewModel settings = context.watch<SettingsViewModel>();
    final JournalViewModel journal = context.watch<JournalViewModel>();
    final BeanViewModel beans = context.watch<BeanViewModel>();

    return ListView(
      padding: AppLayout.screenPadding(context),
      children: <Widget>[
        StaggerIn(
          child: _Section(
            label: 'Umum',
            children: <Widget>[
              SettingsRow(
                icon: Icons.vibration_rounded,
                title: 'Getaran haptic',
                subtitle: 'Umpan sentuhan saat timer dan input',
                trailing: GlassSwitch(
                  value: settings.hapticsEnabled,
                  onChanged: (bool value) => settings.setHaptics(value: value),
                ),
              ),
              Column(
                children: <Widget>[
                  const SettingsRow(
                    icon: Icons.text_fields_rounded,
                    title: 'Ukuran teks',
                    subtitle: 'Atur agar nyaman dibaca',
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: GlassSegmentedControl(
                      labels: <String>[
                        for (final TextSizeOption o in TextSizeOption.values)
                          o.label,
                      ],
                      selectedIndex: settings.textSize.index,
                      onChanged: (int i) =>
                          settings.setTextSize(TextSizeOption.values[i]),
                    ),
                  ),
                ],
              ),
              SettingsRow(
                icon: Icons.device_thermostat_rounded,
                title: 'Suhu dalam °F',
                subtitle: 'Tampilkan suhu air dalam Fahrenheit',
                trailing: GlassSwitch(
                  value: settings.useFahrenheit,
                  onChanged: (bool value) =>
                      settings.setFahrenheit(value: value),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        StaggerIn(
          index: 1,
          child: _Section(
            label: 'Timer seduh',
            children: <Widget>[
              SettingsRow(
                icon: Icons.volume_up_rounded,
                title: 'Suara pengingat',
                subtitle: 'Nada saat ganti fase dan seduhan selesai',
                trailing: GlassSwitch(
                  value: settings.soundEnabled,
                  onChanged: (bool value) => settings.setSound(value: value),
                ),
              ),
              SettingsRow(
                icon: Icons.light_mode_outlined,
                title: 'Layar tetap menyala',
                subtitle: 'Cegah layar mati saat timer berjalan',
                trailing: GlassSwitch(
                  value: settings.keepAwakeEnabled,
                  onChanged: (bool value) =>
                      settings.setKeepAwake(value: value),
                ),
              ),
              SettingsRow(
                icon: Icons.notifications_active_outlined,
                title: 'Notifikasi selesai',
                subtitle: 'Ingatkan saat aplikasi di latar belakang',
                trailing: GlassSwitch(
                  value: settings.notifyEnabled,
                  onChanged: (bool value) => settings.setNotify(value: value),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        StaggerIn(
          index: 2,
          child: _Section(
            label: 'Data',
            children: <Widget>[
              SettingsRow(
                icon: Icons.grain_rounded,
                title: 'Biji kopi',
                subtitle: beans.isEmpty
                    ? 'Belum ada biji tersimpan'
                    : '${beans.beans.length} biji di perpustakaan',
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textSecondary,
                ),
                onTap: () =>
                    pushPlatformPage<void>(context, const BeansScreen()),
              ),
              SettingsRow(
                icon: Icons.ios_share_rounded,
                title: 'Ekspor cadangan',
                subtitle: 'Jurnal, resep, dan biji dalam berkas JSON',
                onTap: () => _export(context, csv: false),
              ),
              SettingsRow(
                icon: Icons.table_chart_outlined,
                title: 'Ekspor CSV',
                subtitle: 'Jurnal untuk dibuka di spreadsheet',
                onTap: () => _export(context, csv: true),
              ),
              SettingsRow(
                icon: Icons.file_download_outlined,
                title: 'Impor cadangan',
                subtitle: 'Gabungkan dari berkas JSON tanpa menimpa data',
                onTap: () => _import(context),
              ),
              SettingsRow(
                icon: Icons.delete_sweep_outlined,
                title: 'Hapus semua catatan',
                subtitle: journal.isEmpty
                    ? 'Jurnal masih kosong'
                    : '${journal.entries.length} catatan tersimpan',
                destructive: true,
                onTap: journal.isEmpty ? null : () => _confirmClear(context),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        StaggerIn(
          index: 3,
          child: _Section(
            label: 'Tentang',
            children: <Widget>[
              SettingsRow(
                icon: Icons.info_outline_rounded,
                title: 'Tentang ${AppInfo.name}',
                subtitle: 'Versi ${AppInfo.version} · ${AppInfo.developerName}',
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textSecondary,
                ),
                onTap: () =>
                    pushPlatformPage<void>(context, const AboutScreen()),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.label, required this.children});

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(left: 6),
          child: SectionLabel(label),
        ),
        GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
          child: Column(
            children: <Widget>[
              for (int i = 0; i < children.length; i++) ...<Widget>[
                if (i > 0)
                  const SizedBox(
                    height: 1,
                    child: ColoredBox(color: Color(0x1FF3E6D6)),
                  ),
                children[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}
