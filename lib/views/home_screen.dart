import 'dart:async';

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/layout.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';
import '../models/brew_model.dart';
import '../models/mocktail_model.dart';
import '../viewmodels/bean_viewmodel.dart';
import '../viewmodels/brew_viewmodel.dart';
import '../viewmodels/mocktail_viewmodel.dart';
import '../viewmodels/recipe_viewmodel.dart';
import 'beans_screen.dart';
import 'save_brew_screen.dart';
import 'widgets/app_button.dart';
import 'widgets/bean_strip.dart';
import 'widgets/brew_result_card.dart';
import 'widgets/customization_panel.dart';
import 'widgets/brew_icons.dart';
import 'widgets/glass_card.dart';
import 'widgets/glass_controls.dart';
import 'widgets/grams_chip.dart';
import 'widgets/grams_input_field.dart';
import 'widgets/mocktail_panel.dart';
import 'widgets/mocktail_result_card.dart';
import 'widgets/glass_dialog.dart';
import 'widgets/recipe_strip.dart';
import 'widgets/section_label.dart';
import 'widgets/motion.dart';

/// Tab Kalkulator: input gramasi, metode, dan roasting dengan hasil real-time.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.onOpenTimer,
    required this.onOpenJournal,
  });

  final VoidCallback onOpenTimer;
  final VoidCallback onOpenJournal;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const List<int> _quickGrams = <int>[15, 18, 20, 30];
  static const List<int> _quickWater = <int>[250, 350, 500, 700];
  static const List<String> _modeLabels = <String>['Dari kopi', 'Dari air'];
  static const List<String> _calculatorModes = <String>['Kopi', 'Mocktail'];

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _gramsController;
  late final TextEditingController _waterController;

  @override
  void initState() {
    super.initState();
    final BrewViewModel vm = context.read<BrewViewModel>();
    _gramsController = TextEditingController(text: vm.gramsText);
    _waterController = TextEditingController(text: vm.waterText);
  }

  @override
  void dispose() {
    _gramsController.dispose();
    _waterController.dispose();
    super.dispose();
  }

  void _applyQuick(int value, {required BrewInputMode mode}) {
    final BrewViewModel vm = context.read<BrewViewModel>();
    final TextEditingController controller = mode == BrewInputMode.coffee
        ? _gramsController
        : _waterController;
    controller.text = '$value';
    controller.selection = TextSelection.collapsed(
      offset: controller.text.length,
    );
    if (mode == BrewInputMode.coffee) {
      vm.updateGrams(controller.text);
    } else {
      vm.updateWater(controller.text);
    }
    _formKey.currentState?.validate();
    FocusManager.instance.primaryFocus?.unfocus();
  }

  Widget _inputBlock(BrewViewModel vm) {
    final bool coffee = vm.inputMode == BrewInputMode.coffee;
    return Column(
      key: ValueKey<BrewInputMode>(vm.inputMode),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SectionLabel(coffee ? 'Gramasi kopi' : 'Target air'),
        GramsInputField(
          controller: coffee ? _gramsController : _waterController,
          validator: coffee ? vm.validateGrams : vm.validateWater,
          onChanged: coffee ? vm.updateGrams : vm.updateWater,
          placeholder: coffee ? 'mis. 18' : 'mis. 250',
          semanticLabel: coffee
              ? 'Gramasi kopi dalam gram'
              : 'Target air dalam mililiter',
          unit: coffee ? 'g' : 'ml',
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            for (final int value in coffee ? _quickGrams : _quickWater)
              GramsChip(
                label: coffee ? '$value g' : '$value ml',
                onTap: () => _applyQuick(value, mode: vm.inputMode),
              ),
          ],
        ),
      ],
    );
  }

  void _applyRecipe(BrewRecipe recipe) {
    final BrewViewModel vm = context.read<BrewViewModel>();
    unawaited(context.read<MocktailViewModel>().setActive(value: false));
    vm.applyRecipe(recipe);
    _gramsController.text = vm.gramsText;
    FocusManager.instance.primaryFocus?.unfocus();
    AdaptiveSnackBar.show(
      context,
      message: 'Resep "${recipe.name}" dimuat',
      type: AdaptiveSnackBarType.success,
      duration: const Duration(seconds: 2),
    );
  }

  Future<void> _saveRecipe() async {
    final BrewCalculation? calc = context.read<BrewViewModel>().calculation;
    if (calc == null) {
      return;
    }
    final RecipeViewModel recipes = context.read<RecipeViewModel>();
    final String? name = await showPromptDialog(
      context,
      title: 'Simpan resep',
      message:
          '${calc.method.label} · ${formatGrams(calc.coffeeGrams)} g · '
          '${calc.ratioLabel} · Roast ${calc.roast.label}',
      placeholder: 'Nama resep',
      initialValue: '${calc.method.label} ${formatGrams(calc.coffeeGrams)} g',
      maxLength: RecipeViewModel.maxNameLength,
    );
    if (name == null || !mounted) {
      return;
    }
    final String? error = await recipes.saveRecipe(
      name: name,
      calculation: calc,
    );
    if (!mounted) {
      return;
    }
    AdaptiveSnackBar.show(
      context,
      message: error ?? 'Resep "${name.trim()}" disimpan',
      type: error == null
          ? AdaptiveSnackBarType.success
          : AdaptiveSnackBarType.error,
      duration: const Duration(seconds: 2),
    );
  }

  Future<void> _confirmDeleteRecipe(BrewRecipe recipe) async {
    final RecipeViewModel recipes = context.read<RecipeViewModel>();
    final bool confirmed = await showGlassConfirm(
      context,
      title: 'Hapus resep?',
      message: 'Resep "${recipe.name}" akan dihapus permanen.',
      confirmLabel: 'Hapus',
      destructive: true,
    );
    if (confirmed) {
      await recipes.deleteRecipe(recipe.id);
    }
  }

  void _applyMocktail(MocktailRecipe recipe) {
    final MocktailViewModel mocktail = context.read<MocktailViewModel>();
    mocktail.applyRecipe(recipe);
    unawaited(mocktail.setActive(value: true));
    AdaptiveSnackBar.show(
      context,
      message: 'Resep "${recipe.name}" dimuat',
      type: AdaptiveSnackBarType.success,
      duration: const Duration(seconds: 2),
    );
  }

  Future<void> _saveMocktail() async {
    final MocktailViewModel mocktail = context.read<MocktailViewModel>();
    final MocktailBlend? blend = mocktail.blend;
    if (blend == null) {
      return;
    }
    final RecipeViewModel recipes = context.read<RecipeViewModel>();
    final String suggestion =
        '${blend.spec.syrups.first.name} '
        '${blend.spec.base.label}';
    final String? name = await showPromptDialog(
      context,
      title: 'Simpan resep mocktail',
      message: '${blend.summary} · ${blend.spec.sweetness.label}',
      placeholder: 'Nama mocktail',
      initialValue: suggestion.length > RecipeViewModel.maxNameLength
          ? suggestion.substring(0, RecipeViewModel.maxNameLength)
          : suggestion,
      maxLength: RecipeViewModel.maxNameLength,
    );
    if (name == null || !mounted) {
      return;
    }
    final String? error = await recipes.saveMocktail(
      name: name,
      spec: blend.spec,
    );
    if (!mounted) {
      return;
    }
    AdaptiveSnackBar.show(
      context,
      message: error ?? 'Resep "${name.trim()}" disimpan',
      type: error == null
          ? AdaptiveSnackBarType.success
          : AdaptiveSnackBarType.error,
      duration: const Duration(seconds: 2),
    );
  }

  Future<void> _confirmDeleteMocktail(MocktailRecipe recipe) async {
    final RecipeViewModel recipes = context.read<RecipeViewModel>();
    final bool confirmed = await showGlassConfirm(
      context,
      title: 'Hapus resep?',
      message: 'Resep "${recipe.name}" akan dihapus permanen.',
      confirmLabel: 'Hapus',
      destructive: true,
    );
    if (confirmed) {
      await recipes.deleteMocktail(recipe.id);
    }
  }

  Future<void> _addCustomSyrup() async {
    final MocktailViewModel mocktail = context.read<MocktailViewModel>();
    final String? name = await showPromptDialog(
      context,
      title: 'Sirup lain',
      message:
          'Tulis nama sirup yang kamu punya, mis. "Kokum" atau "Lavender".',
      placeholder: 'Nama sirup',
      maxLength: MocktailViewModel.maxSyrupNameLength,
      confirmLabel: 'Tambah',
    );
    if (name == null || !mounted) {
      return;
    }
    final String? error = mocktail.validateSyrupName(name);
    if (error != null) {
      AdaptiveSnackBar.show(
        context,
        message: error,
        type: AdaptiveSnackBarType.error,
        duration: const Duration(seconds: 2),
      );
      return;
    }
    mocktail.toggleSyrup(name);
  }

  void _syrupLimitReached() {
    AdaptiveSnackBar.show(
      context,
      message: 'Maksimal ${MocktailSpec.maxSyrups} sirup per mocktail',
      type: AdaptiveSnackBarType.info,
      duration: const Duration(seconds: 2),
    );
  }

  Future<void> _saveToJournal() async {
    final bool saved = await SaveBrewScreen.open(context);
    if (saved && mounted) {
      widget.onOpenJournal();
    }
  }

  @override
  Widget build(BuildContext context) {
    final BrewViewModel vm = context.watch<BrewViewModel>();
    final RecipeViewModel recipeVm = context.watch<RecipeViewModel>();
    final BeanViewModel beanVm = context.watch<BeanViewModel>();
    final MocktailViewModel mocktailVm = context.watch<MocktailViewModel>();
    final BrewCalculation? calc = vm.calculation;
    final bool cocktail = mocktailVm.isActive;
    final bool showRecipes =
        !recipeVm.isEmpty ||
        (cocktail ? mocktailVm.blend != null : calc != null);

    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: AppLayout.screenPadding(context),
      children: <Widget>[
        StaggerIn(
          child: GlassSegmentedControl(
            labels: _calculatorModes,
            selectedIndex: cocktail ? 1 : 0,
            onChanged: (int i) =>
                unawaited(mocktailVm.setActive(value: i == 1)),
          ),
        ),
        const SizedBox(height: 16),
        if (showRecipes) ...<Widget>[
          StaggerIn(
            child: RecipeStrip(
              recipes: recipeVm.recipes,
              mocktails: recipeVm.mocktails,
              canSave: cocktail ? mocktailVm.blend != null : calc != null,
              onApply: _applyRecipe,
              onDelete: _confirmDeleteRecipe,
              onApplyMocktail: _applyMocktail,
              onDeleteMocktail: _confirmDeleteMocktail,
              onSave: cocktail ? _saveMocktail : _saveRecipe,
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (cocktail)
          ..._mocktailSection(mocktailVm)
        else
          ..._coffeeSection(vm, beanVm, calc),
      ],
    );
  }

  List<Widget> _mocktailSection(MocktailViewModel mocktailVm) {
    final MocktailBlend? blend = mocktailVm.blend;
    return <Widget>[
      StaggerIn(
        index: 1,
        child: MocktailPanel(
          viewModel: mocktailVm,
          onAddCustomSyrup: () => unawaited(_addCustomSyrup()),
          onSyrupLimit: _syrupLimitReached,
        ),
      ),
      const SizedBox(height: 16),
      StaggerIn(
        index: 2,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (Widget child, Animation<double> animation) =>
              FadeTransition(opacity: animation, child: child),
          child: blend == null
              ? GlassCard(
                  key: const ValueKey<String>('mocktail-empty'),
                  child: Row(
                    children: <Widget>[
                      const Icon(
                        Icons.local_bar_rounded,
                        color: AppColors.sage,
                        size: 32,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          mocktailVm.problem ??
                              'Atur bahan untuk melihat takaran.',
                          style: AppTextStyles.bodySecondary,
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  key: const ValueKey<String>('mocktail-result'),
                  children: <Widget>[
                    MocktailResultCard(blend: blend),
                    const SizedBox(height: 16),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: AppButton(
                            label: 'Reset',
                            color: AppColors.secondaryButton,
                            textColor: AppColors.textPrimary,
                            onPressed: mocktailVm.reset,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: AppButton(
                            label: 'Simpan ke Resep Saya',
                            color: AppColors.sage,
                            textColor: AppColors.onAccent,
                            onPressed: () => unawaited(_saveMocktail()),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
        ),
      ),
    ];
  }

  List<Widget> _coffeeSection(
    BrewViewModel vm,
    BeanViewModel beanVm,
    BrewCalculation? calc,
  ) {
    return <Widget>[
      StaggerIn(
        index: 1,
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
        index: 1,
        child: GlassCard(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                GlassSegmentedControl(
                  labels: _modeLabels,
                  selectedIndex: vm.inputMode.index,
                  onChanged: (int i) =>
                      vm.selectInputMode(BrewInputMode.values[i]),
                ),
                const SizedBox(height: 20),
                AnimatedSize(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 260),
                    transitionBuilder: (
                      Widget child,
                      Animation<double> animation,
                    ) => FadeTransition(opacity: animation, child: child),
                    layoutBuilder: (Widget? current, List<Widget> previous) =>
                        Stack(
                          alignment: Alignment.topCenter,
                          children: <Widget>[...previous, ?current],
                        ),
                    child: _inputBlock(vm),
                  ),
                ),
                const SizedBox(height: 22),
                const SectionLabel('Metode seduh'),
                GlassSegmentedControl(
                  labels: <String>[
                    for (final BrewMethod m in BrewMethod.values) m.shortLabel,
                  ],
                  iconBuilders: <Widget Function(Color, double)>[
                    for (final BrewMethod m in BrewMethod.values)
                      (Color c, double s) =>
                          BrewMethodIcon(method: m, color: c, size: s),
                  ],
                  selectedIndex: vm.method.index,
                  onChanged: (int i) {
                    vm.selectMethod(BrewMethod.values[i]);
                    if (vm.inputMode == BrewInputMode.water) {
                      _formKey.currentState?.validate();
                    }
                  },
                ),
                const SizedBox(height: 22),
                const SectionLabel('Tingkat roasting'),
                GlassSegmentedControl(
                  labels: <String>[
                    for (final RoastLevel r in RoastLevel.values) r.label,
                  ],
                  iconBuilders: <Widget Function(Color, double)>[
                    for (final RoastLevel r in RoastLevel.values)
                      (Color c, double s) => RoastBeanIcon(level: r, size: s),
                  ],
                  selectedIndex: vm.roast.index,
                  onChanged: (int i) => vm.selectRoast(RoastLevel.values[i]),
                ),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(height: 16),
      StaggerIn(index: 2, child: CustomizationPanel(viewModel: vm)),
      const SizedBox(height: 16),
      StaggerIn(
        index: 3,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (Widget child, Animation<double> animation) =>
              FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.96, end: 1).animate(animation),
                  child: child,
                ),
              ),
          child: calc == null
              ? _EmptyResult(
                  key: const ValueKey<String>('empty'),
                  inputMode: vm.inputMode,
                )
              : Column(
                  key: const ValueKey<String>('result'),
                  children: <Widget>[
                    BrewResultCard(calculation: calc, inputMode: vm.inputMode),
                    const SizedBox(height: 16),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: AppButton(
                            label: 'Simpan',
                            color: AppColors.secondaryButton,
                            textColor: AppColors.textPrimary,
                            onPressed: _saveToJournal,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: AppButton(
                            label: 'Mulai Timer',
                            color: AppColors.caramel,
                            textColor: AppColors.onAccent,
                            onPressed: widget.onOpenTimer,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
        ),
      ),
    ];
  }
}

class _EmptyResult extends StatelessWidget {
  const _EmptyResult({super.key, required this.inputMode});

  final BrewInputMode inputMode;

  @override
  Widget build(BuildContext context) {
    final String text = inputMode == BrewInputMode.coffee
        ? 'Masukkan gramasi kopi (1–200 g) untuk melihat takaran air, '
              'suhu, gilingan, dan air bloom.'
        : 'Masukkan target air (ml) untuk mengetahui berapa gram kopi yang '
              'dibutuhkan, lengkap dengan suhu, gilingan, dan air bloom.';
    return GlassCard(
      child: Row(
        children: <Widget>[
          const Icon(Icons.coffee_rounded, color: AppColors.caramel, size: 32),
          const SizedBox(width: 16),
          Expanded(child: Text(text, style: AppTextStyles.bodySecondary)),
        ],
      ),
    );
  }
}
