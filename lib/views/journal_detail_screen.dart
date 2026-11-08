import 'dart:async';

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/layout.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';
import '../models/brew_model.dart';
import '../services/data_transfer_service.dart';
import '../services/photo_storage.dart';
import '../viewmodels/brew_viewmodel.dart';
import '../viewmodels/journal_viewmodel.dart';
import '../viewmodels/settings_viewmodel.dart';
import '../viewmodels/shell_navigation.dart';
import 'widgets/app_button.dart';
import 'widgets/app_text_scope.dart';
import 'widgets/glass_dialog.dart';
import 'widgets/ambient_background.dart';
import 'widgets/brew_result_card.dart';
import 'widgets/dial_in_panel.dart';
import 'widgets/entry_extras_card.dart';
import 'widgets/share_card.dart';
import 'widgets/glass_app_bar.dart';
import 'widgets/glass_card.dart';
import 'widgets/motion.dart';
import 'widgets/section_label.dart';
import 'widgets/star_rating_bar.dart';

/// Detail satu catatan seduhan: ringkasan, serta rating dan tasting notes
/// yang bisa diubah.
class JournalDetailScreen extends StatefulWidget {
  const JournalDetailScreen({super.key, required this.entryId});

  final String entryId;

  @override
  State<JournalDetailScreen> createState() => _JournalDetailScreenState();
}

class _JournalDetailScreenState extends State<JournalDetailScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _notesController;
  late int _rating;
  late final int _initialRating;
  late final TasteFeedback? _initialTaste;
  TasteFeedback? _taste;
  late final String _initialNotes;
  late final TextEditingController _grinderController;
  late final String _initialGrinder;
  late final List<FlavorTag> _initialTags;
  late final String? _initialPhoto;
  late final PhotoStorage _photos;
  List<FlavorTag> _tags = const <FlavorTag>[];
  String? _photoName;
  bool _saving = false;
  bool _saved = false;
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    final BrewEntry? entry = context.read<JournalViewModel>().entryById(
      widget.entryId,
    );
    _initialRating = entry?.rating ?? 1;
    _initialNotes = entry?.tastingNotes ?? '';
    _photos = context.read<PhotoStorage>();
    _initialTaste = entry?.taste;
    _taste = _initialTaste;
    _initialGrinder = entry?.grinderSetting ?? '';
    _initialTags = entry?.flavorTags ?? const <FlavorTag>[];
    _initialPhoto = entry?.photoName;
    _tags = _initialTags;
    _photoName = _initialPhoto;
    _grinderController = TextEditingController(text: _initialGrinder);
    _grinderController.addListener(() => setState(() {}));
    _rating = _initialRating;
    _notesController = TextEditingController(text: _initialNotes);
    _notesController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _notesController.dispose();
    _grinderController.dispose();
    // Foto baru yang tidak jadi disimpan dibuang.
    if (!_saved && _photoName != null && _photoName != _initialPhoto) {
      unawaited(_photos.delete(_photoName));
    }
    super.dispose();
  }

  void _setPhoto(String? name) {
    // Hanya foto baru (belum tersimpan) yang boleh dibuang di sini; foto
    // asli baru dihapus saat perubahan disimpan.
    if (_photoName != null &&
        _photoName != name &&
        _photoName != _initialPhoto) {
      unawaited(_photos.delete(_photoName));
    }
    setState(() => _photoName = name);
  }

  bool get _dirty =>
      _rating != _initialRating ||
      _taste != _initialTaste ||
      _photoName != _initialPhoto ||
      !listEquals(_tags, _initialTags) ||
      _grinderController.text.trim() != _initialGrinder ||
      _notesController.text.trim() != _initialNotes;

  Future<void> _save() async {
    if (_saving || !(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final JournalViewModel vm = context.read<JournalViewModel>();
    setState(() => _saving = true);
    final String? error = await vm.updateEntry(
      id: widget.entryId,
      rating: _rating,
      tastingNotes: _notesController.text,
      taste: _taste,
      flavorTags: _tags,
      grinderSetting: _grinderController.text,
      photoName: _photoName,
      clearPhoto: _photoName == null && _initialPhoto != null,
    );
    if (!mounted) {
      return;
    }
    setState(() => _saving = false);
    _saved = error == null;
    AdaptiveSnackBar.show(
      context,
      message: error ?? 'Perubahan tersimpan',
      type: error == null
          ? AdaptiveSnackBarType.success
          : AdaptiveSnackBarType.error,
    );
    if (error == null) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _shareCard(BrewEntry entry) async {
    final DataTransferService transfer = context.read<DataTransferService>();
    final Size size = MediaQuery.sizeOf(context);
    setState(() => _sharing = true);
    try {
      final Uint8List png = await captureShareCard(context, entry);
      await transfer.sharePng(
        png,
        'brewlogic-${entry.id}.png',
        origin: Rect.fromLTWH(size.width / 2, size.height / 2, 1, 1),
      );
    } catch (_) {
      if (mounted) {
        AdaptiveSnackBar.show(
          context,
          message: 'Kartu tidak dapat dibagikan',
          type: AdaptiveSnackBarType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _sharing = false);
      }
    }
  }

  /// Menerapkan rasio saran ke kalkulator lalu kembali ke tab Kalkulator.
  void _applyRatio(BrewEntry entry, double ratio) {
    context.read<BrewViewModel>().applyAdjustment(
      method: entry.method,
      roast: entry.roast,
      coffeeGrams: entry.coffeeGrams,
      ratio: ratio,
    );
    final ShellNavigation nav = context.read<ShellNavigation>();
    Navigator.of(context).pop();
    nav.goTo(ShellNavigation.calculator);
  }

  Future<void> _confirmDelete(BrewEntry entry) async {
    final JournalViewModel vm = context.read<JournalViewModel>();
    final NavigatorState navigator = Navigator.of(context);
    final bool confirmed = await showGlassConfirm(
      context,
      title: 'Hapus catatan?',
      message: 'Catatan ${entry.method.label} ini akan dihapus permanen.',
      confirmLabel: 'Hapus',
      destructive: true,
    );
    if (!confirmed) {
      return;
    }
    final String? error = await vm.deleteEntry(entry.id);
    if (error == null) {
      navigator.pop();
    } else if (mounted) {
      AdaptiveSnackBar.show(
        context,
        message: error,
        type: AdaptiveSnackBarType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final JournalViewModel vm = context.watch<JournalViewModel>();
    final BrewEntry? entry = vm.entryById(widget.entryId);

    return AdaptiveScaffold(
      backgroundColor: AppColors.background,
      body: AppTextScope(
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            const AmbientBackground(),
            if (entry == null)
              HeaderClip(
                child: ListView(
                  padding: AppLayout.screenPadding(
                    context,
                    hasBottomBar: false,
                  ),
                  children: const <Widget>[
                    GlassCard(
                      child: Text(
                        'Catatan ini sudah tidak tersedia.',
                        style: AppTextStyles.bodySecondary,
                      ),
                    ),
                  ],
                ),
              )
            else
              HeaderClip(
                child: ListView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: AppLayout.screenPadding(
                    context,
                    hasBottomBar: false,
                  ),
                  children: <Widget>[
                    StaggerIn(child: _Summary(entry: entry)),
                    const SizedBox(height: 16),
                    StaggerIn(
                      index: 1,
                      child: GlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const SectionLabel('Rating'),
                            StarRatingBar(
                              rating: _rating,
                              onChanged: (int value) =>
                                  setState(() => _rating = value),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    StaggerIn(
                      index: 2,
                      child: GlassCard(
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              const SectionLabel('Tasting notes'),
                              AdaptiveTextFormField(
                                controller: _notesController,
                                placeholder: 'Tambahkan catatan rasa',
                                maxLines: 6,
                                minLines: 3,
                                maxLength: JournalViewModel.maxNotesLength,
                                textCapitalization:
                                    TextCapitalization.sentences,
                                autovalidateMode:
                                    AutovalidateMode.onUserInteraction,
                                validator: (String? _) =>
                                    vm.validateNotes(_notesController.text),
                                onTapOutside: (_) => FocusManager
                                    .instance
                                    .primaryFocus
                                    ?.unfocus(),
                                style: AppTextStyles.body,
                                cupertinoDecoration: BoxDecoration(
                                  color: AppColors.glassFill,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: AppColors.glassBorder,
                                  ),
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Tambahkan catatan rasa',
                                  filled: true,
                                  fillColor: AppColors.glassFill,
                                  border: _border(AppColors.glassBorder),
                                  enabledBorder: _border(AppColors.glassBorder),
                                  focusedBorder: _border(
                                    AppColors.caramel,
                                    1.6,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    StaggerIn(
                      index: 3,
                      child: EntryExtrasCard(
                        grinderController: _grinderController,
                        tags: _tags,
                        onTagsChanged: (List<FlavorTag> tags) =>
                            setState(() => _tags = tags),
                        photoName: _photoName,
                        onPhotoChanged: _setPhoto,
                      ),
                    ),
                    const SizedBox(height: 16),
                    StaggerIn(
                      index: 3,
                      child: DialInPanel(
                        method: entry.method,
                        roast: entry.roast,
                        ratio: entry.ratio,
                        brewSeconds: entry.brewSeconds,
                        fahrenheit: context
                            .watch<SettingsViewModel>()
                            .useFahrenheit,
                        selected: _taste,
                        onChanged: (TasteFeedback? value) =>
                            setState(() => _taste = value),
                        onApplyRatio: (double ratio) =>
                            _applyRatio(entry, ratio),
                      ),
                    ),
                    const SizedBox(height: 20),
                    StaggerIn(
                      index: 4,
                      child: AppButton(
                        label: _saving ? 'Menyimpan…' : 'Simpan perubahan',
                        color: AppColors.caramel,
                        textColor: AppColors.onAccent,
                        enabled: _dirty && !_saving,
                        onPressed: _save,
                      ),
                    ),
                    const SizedBox(height: 12),
                    StaggerIn(
                      index: 5,
                      child: AppButton(
                        label: _sharing ? 'Menyiapkan kartu…' : 'Bagikan kartu',
                        color: AppColors.secondaryButton,
                        textColor: AppColors.textPrimary,
                        enabled: !_sharing,
                        onPressed: () => _shareCard(entry),
                      ),
                    ),
                    const SizedBox(height: 12),
                    StaggerIn(
                      index: 6,
                      child: AppButton(
                        label: 'Hapus catatan',
                        color: AppColors.secondaryButton,
                        textColor: AppColors.danger,
                        onPressed: () => _confirmDelete(entry),
                      ),
                    ),
                  ],
                ),
              ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: GlassAppBar(
                title: 'Detail Seduhan',
                subtitle: entry == null
                    ? 'Tidak tersedia'
                    : formatDateTime(entry.createdAt),
                leading: const GlassBackButton(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static OutlineInputBorder _border(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: color, width: width),
      );
}

class _Summary extends StatelessWidget {
  const _Summary({required this.entry});

  final BrewEntry entry;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      accent: AppColors.caramel,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Column(
        children: <Widget>[
          MetricRow(
            icon: Icons.coffee_outlined,
            label: 'Metode',
            value: entry.method.label,
            caption: 'Roast ${entry.roast.label}',
          ),
          const _Divider(),
          MetricRow(
            icon: Icons.scale_rounded,
            label: 'Takaran',
            value:
                '${formatGrams(entry.coffeeGrams)} g → '
                '${formatGrams(entry.waterGrams)} ml',
            caption: 'Rasio 1:${formatGrams((entry.ratio * 10).round() / 10)}',
          ),
          if (entry.beanName != null) ...<Widget>[
            const _Divider(),
            MetricRow(
              icon: Icons.grain_rounded,
              label: 'Biji',
              value: entry.beanName!,
            ),
          ],
          if (entry.brewSeconds > 0) ...<Widget>[
            const _Divider(),
            MetricRow(
              icon: Icons.timer_outlined,
              label: 'Durasi seduh',
              value: formatClock(entry.brewSeconds),
            ),
          ],
        ],
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
