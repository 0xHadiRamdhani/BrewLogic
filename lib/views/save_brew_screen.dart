import 'dart:async';

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/layout.dart';
import '../core/navigation.dart';
import 'beans_screen.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';
import '../models/brew_model.dart';
import '../services/photo_storage.dart';
import '../viewmodels/bean_viewmodel.dart';
import '../viewmodels/brew_viewmodel.dart';
import '../viewmodels/journal_viewmodel.dart';
import '../viewmodels/settings_viewmodel.dart';
import '../viewmodels/shell_navigation.dart';
import 'widgets/app_button.dart';
import 'widgets/app_text_scope.dart';
import 'widgets/ambient_background.dart';
import 'widgets/bean_strip.dart';
import 'widgets/entry_extras_card.dart';
import 'widgets/dial_in_panel.dart';
import 'widgets/glass_app_bar.dart';
import 'widgets/glass_card.dart';
import 'widgets/motion.dart';
import 'widgets/section_label.dart';
import 'widgets/star_rating_bar.dart';

/// Halaman penuh untuk memberi rating dan tasting notes sebelum menyimpan
/// hasil seduhan ke jurnal.
class SaveBrewScreen extends StatefulWidget {
  const SaveBrewScreen({super.key});

  /// Membuka halaman ini. Mengembalikan `true` jika catatan berhasil disimpan.
  static Future<bool> open(BuildContext context) async {
    final bool? saved = await pushPlatformPage<bool>(
      context,
      const SaveBrewScreen(),
    );
    return saved ?? false;
  }

  @override
  State<SaveBrewScreen> createState() => _SaveBrewScreenState();
}

class _SaveBrewScreenState extends State<SaveBrewScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _notesController = TextEditingController();

  final TextEditingController _grinderController = TextEditingController();
  late final PhotoStorage _photos;

  int _rating = 0;
  TasteFeedback? _taste;
  List<FlavorTag> _tags = const <FlavorTag>[];
  String? _photoName;
  String? _ratingError;
  bool _saving = false;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _photos = context.read<PhotoStorage>();
  }

  @override
  void dispose() {
    _notesController.dispose();
    _grinderController.dispose();
    // Foto yang sudah dipilih tetapi tidak jadi disimpan dibuang.
    if (!_saved) {
      unawaited(_photos.delete(_photoName));
    }
    super.dispose();
  }

  void _setPhoto(String? name) {
    if (_photoName != null && _photoName != name) {
      unawaited(_photos.delete(_photoName));
    }
    setState(() => _photoName = name);
  }

  Future<void> _save() async {
    if (_saving) {
      return;
    }
    final BrewViewModel brew = context.read<BrewViewModel>();
    final JournalViewModel journal = context.read<JournalViewModel>();
    final BrewCalculation? calc = brew.calculation;

    final String? ratingError = journal.validateRating(_rating);
    setState(() => _ratingError = ratingError);
    final bool notesValid = _formKey.currentState?.validate() ?? false;
    if (calc == null || ratingError != null || !notesValid) {
      return;
    }

    setState(() => _saving = true);
    final String? error = await journal.saveBrew(
      calculation: calc,
      rating: _rating,
      tastingNotes: _notesController.text,
      brewSeconds: brew.brewedSeconds,
      taste: _taste,
      flavorTags: _tags,
      grinderSetting: _grinderController.text,
      photoName: _photoName,
      bean: context.read<BeanViewModel>().active,
    );
    if (!mounted) {
      return;
    }
    setState(() => _saving = false);

    if (error != null) {
      AdaptiveSnackBar.show(
        context,
        message: error,
        type: AdaptiveSnackBarType.error,
      );
      return;
    }
    _saved = true;
    AdaptiveSnackBar.show(
      context,
      message: 'Seduhan tersimpan di jurnal',
      type: AdaptiveSnackBarType.success,
    );
    Navigator.of(context).pop(true);
  }

  /// Menerapkan rasio saran ke kalkulator lalu kembali ke tab Kalkulator.
  void _applyRatio(BrewCalculation calc, double ratio) {
    context.read<BrewViewModel>().applyAdjustment(
      method: calc.method,
      roast: calc.roast,
      coffeeGrams: calc.coffeeGrams,
      ratio: ratio,
    );
    final ShellNavigation nav = context.read<ShellNavigation>();
    Navigator.of(context).pop(false);
    nav.goTo(ShellNavigation.calculator);
  }

  @override
  Widget build(BuildContext context) {
    final BrewViewModel brew = context.watch<BrewViewModel>();
    final BeanViewModel beanVm = context.watch<BeanViewModel>();
    final JournalViewModel journal = context.read<JournalViewModel>();
    final BrewCalculation? calc = brew.calculation;

    return AdaptiveScaffold(
      backgroundColor: AppColors.background,
      body: AppTextScope(
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            const Positioned.fill(child: AmbientBackground()),
            HeaderClip(
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: AppLayout.screenPadding(context, hasBottomBar: false),
                children: <Widget>[
                  if (calc != null)
                    StaggerIn(
                      child: _Summary(calculation: calc, brew: brew),
                    ),
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
                            onChanged: (int value) => setState(() {
                              _rating = value;
                              _ratingError = null;
                            }),
                          ),
                          if (_ratingError != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                _ratingError!,
                                style: const TextStyle(
                                  color: AppColors.danger,
                                  fontSize: 13,
                                ),
                              ),
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
                              placeholder: 'mis. floral, jeruk, manis karamel',
                              maxLines: 5,
                              minLines: 3,
                              maxLength: JournalViewModel.maxNotesLength,
                              textCapitalization: TextCapitalization.sentences,
                              autovalidateMode:
                                  AutovalidateMode.onUserInteraction,
                              validator: (String? _) =>
                                  journal.validateNotes(_notesController.text),
                              onTapOutside: (_) =>
                                  FocusManager.instance.primaryFocus?.unfocus(),
                              style: AppTextStyles.body,
                              cupertinoDecoration: BoxDecoration(
                                color: AppColors.glassFill,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: AppColors.glassBorder,
                                ),
                              ),
                              decoration: InputDecoration(
                                hintText: 'mis. floral, jeruk, manis karamel',
                                filled: true,
                                fillColor: AppColors.glassFill,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(
                                    color: AppColors.glassBorder,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(
                                    color: AppColors.glassBorder,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(
                                    color: AppColors.caramel,
                                    width: 1.6,
                                  ),
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
                    child: BeanStrip(
                      beans: beanVm.beans,
                      activeId: beanVm.active?.id,
                      freshnessOf: beanVm.freshnessOf,
                      onSelect: beanVm.selectActive,
                      onAdd: () => BeansScreen.openEditor(context),
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
                  if (calc != null)
                    StaggerIn(
                      index: 3,
                      child: DialInPanel(
                        method: calc.method,
                        roast: calc.roast,
                        ratio: calc.ratio,
                        brewSeconds: brew.brewedSeconds,
                        fahrenheit: context
                            .watch<SettingsViewModel>()
                            .useFahrenheit,
                        selected: _taste,
                        onChanged: (TasteFeedback? value) =>
                            setState(() => _taste = value),
                        onApplyRatio: (double ratio) =>
                            _applyRatio(calc, ratio),
                      ),
                    ),
                  const SizedBox(height: 20),
                  StaggerIn(
                    index: 4,
                    child: AppButton(
                      label: _saving ? 'Menyimpan…' : 'Simpan ke Jurnal',
                      color: AppColors.caramel,
                      textColor: AppColors.onAccent,
                      enabled: !_saving && calc != null,
                      onPressed: _save,
                    ),
                  ),
                ],
              ),
            ),
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: GlassAppBar(
                title: 'Simpan Seduhan',
                subtitle: 'Beri rating dan catat rasanya',
                leading: GlassBackButton(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.calculation, required this.brew});

  final BrewCalculation calculation;
  final BrewViewModel brew;

  @override
  Widget build(BuildContext context) {
    final BrewCalculation c = calculation;
    final int seconds = brew.brewedSeconds;
    return GlassCard(
      accent: AppColors.caramel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(c.method.label, style: AppTextStyles.metricValue),
          const SizedBox(height: 4),
          Text(
            '${formatGrams(c.coffeeGrams)} g kopi → '
            '${formatGrams(c.totalWaterGrams)} ml air · Roast ${c.roast.label}'
            '${seconds > 0 ? ' · ${formatClock(seconds)}' : ''}',
            style: AppTextStyles.bodySecondary,
          ),
        ],
      ),
    );
  }
}
