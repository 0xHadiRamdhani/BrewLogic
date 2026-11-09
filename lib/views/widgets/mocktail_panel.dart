import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/haptics.dart';
import '../../models/mocktail_model.dart';
import '../../viewmodels/mocktail_viewmodel.dart';
import 'brew_icons.dart';
import 'filter_pill.dart';
import 'glass_app_bar.dart';
import 'glass_card.dart';
import 'glass_controls.dart';
import 'grams_chip.dart';
import 'grams_input_field.dart';
import 'motion.dart';
import 'section_label.dart';

/// Kartu input mocktail dengan susunan yang sama seperti kalkulator kopi:
/// ukuran gelas (field + chip cepat), bahan dasar, sirup, lalu tingkat manis
/// dan teknik sebagai segmented control berikon.
class MocktailPanel extends StatefulWidget {
  const MocktailPanel({
    super.key,
    required this.viewModel,
    required this.onAddCustomSyrup,
    required this.onSyrupLimit,
    required this.onAddCustomBase,
    required this.onDeleteCustomBase,
  });

  final MocktailViewModel viewModel;

  /// Dipanggil saat pengguna ingin menambah bahan dasar buatan sendiri.
  final VoidCallback onAddCustomBase;

  /// Dipanggil saat pengguna menahan lama bahan dasar buatan sendiri.
  final ValueChanged<MocktailCustomBase> onDeleteCustomBase;

  /// Dipanggil saat pengguna ingin menambah sirup buatan sendiri.
  final VoidCallback onAddCustomSyrup;

  /// Dipanggil saat batas jumlah sirup tercapai.
  final VoidCallback onSyrupLimit;

  @override
  State<MocktailPanel> createState() => _MocktailPanelState();
}

class _MocktailPanelState extends State<MocktailPanel> {
  static const List<int> _quickGlass = <int>[250, 300, 400];

  late final TextEditingController _glassController;
  late int _lastGlass;

  MocktailViewModel get _vm => widget.viewModel;

  @override
  void initState() {
    super.initState();
    _lastGlass = _vm.spec.glassMl;
    _glassController = TextEditingController(text: '$_lastGlass');
  }

  @override
  void dispose() {
    _glassController.dispose();
    super.dispose();
  }

  void _onGlassTyped(String raw) {
    if (_vm.validateGlassMl(raw) == null) {
      final int value = int.parse(raw.trim());
      _lastGlass = value;
      _vm.setGlassMl(value);
    }
  }

  void _applyQuick(int value) {
    _lastGlass = value;
    _glassController.text = '$value';
    _glassController.selection = TextSelection.collapsed(
      offset: _glassController.text.length,
    );
    _vm.setGlassMl(value);
    FocusManager.instance.primaryFocus?.unfocus();
  }

  /// Bila ukuran gelas berubah dari luar (mis. memuat resep), samakan field.
  void _syncField(int glassMl) {
    if (glassMl == _lastGlass) {
      return;
    }
    _lastGlass = glassMl;
    if (int.tryParse(_glassController.text.trim()) != glassMl) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _glassController.text = '$glassMl';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final MocktailSpec spec = _vm.spec;
    _syncField(spec.glassMl);

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SectionLabel('Ukuran gelas'),
          GramsInputField(
            controller: _glassController,
            validator: _vm.validateGlassMl,
            onChanged: _onGlassTyped,
            placeholder: 'mis. 300',
            semanticLabel: 'Ukuran gelas dalam mililiter',
            unit: 'ml',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final int size in _quickGlass)
                GramsChip(label: '$size ml', onTap: () => _applyQuick(size)),
            ],
          ),
          const SizedBox(height: 22),
          const SectionLabel('Bahan dasar'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final MocktailBase base in MocktailBase.values)
                FilterPill(
                  label: base.label,
                  selected: spec.isBase(base),
                  onTap: () => _vm.setBase(base),
                ),
              for (final MocktailCustomBase base in _vm.customBases)
                _CustomBaseChip(
                  base: base,
                  selected: _vm.isCustomBaseSelected(base),
                  onTap: () => _vm.selectCustomBase(base),
                  onLongPress: () => widget.onDeleteCustomBase(base),
                ),
              FilterPill(
                label: 'Bahan lain',
                icon: Icons.add_rounded,
                selected: false,
                onTap: widget.onAddCustomBase,
              ),
            ],
          ),
          if (_vm.customBases.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              'Tahan bahan buatan sendiri untuk menghapus.',
              style: AppTextStyles.bodySecondary.copyWith(fontSize: 12),
            ),
          ],
          const SizedBox(height: 22),
          SectionLabel('Sirup (maks ${MocktailSpec.maxSyrups})'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final SyrupPreset preset in SyrupPresets.all)
                _SyrupChip(
                  label: preset.name,
                  color: Color(preset.color),
                  selected: _vm.hasSyrup(preset.name),
                  onTap: () {
                    if (!_vm.toggleSyrup(preset.name)) {
                      widget.onSyrupLimit();
                    }
                  },
                ),
              for (final MocktailSyrup s in spec.syrups)
                if (SyrupPresets.byName(s.name) == null)
                  _SyrupChip(
                    label: s.name,
                    color: AppColors.caramel,
                    selected: true,
                    onTap: () => _vm.toggleSyrup(s.name),
                  ),
              FilterPill(
                label: 'Sirup lain',
                icon: Icons.add_rounded,
                selected: false,
                onTap: () {
                  if (_vm.canAddSyrup) {
                    widget.onAddCustomSyrup();
                  } else {
                    widget.onSyrupLimit();
                  }
                },
              ),
            ],
          ),
          if (spec.syrups.isNotEmpty) ...<Widget>[
            const SizedBox(height: 22),
            const SectionLabel('Takaran sirup'),
            GlassSegmentedControl(
              labels: const <String>['Otomatis', 'Sendiri (ml)'],
              selectedIndex: spec.customMl ? 1 : 0,
              onChanged: (int i) => _vm.setSyrupMode(custom: i == 1),
            ),
            const SizedBox(height: 10),
            for (int i = 0; i < spec.syrups.length; i++)
              if (spec.customMl)
                SyrupMlRow(
                  syrup: spec.syrups[i],
                  onMinus: () => _vm.changeSyrupMl(i, -1),
                  onPlus: () => _vm.changeSyrupMl(i, 1),
                  validator: _vm.validateSyrupMl,
                  onValid: (double v) => _vm.setSyrupMl(i, v),
                )
              else
                _SyrupRow(
                  syrup: spec.syrups[i],
                  showParts: spec.syrups.length > 1,
                  onMinus: () => _vm.changeParts(i, -1),
                  onPlus: () => _vm.changeParts(i, 1),
                ),
            if (spec.customMl) _CustomInfo(vm: _vm),
          ] else ...<Widget>[
            const SizedBox(height: 12),
            const Text(
              'Pilih minimal satu sirup untuk melihat takaran.',
              style: AppTextStyles.bodySecondary,
            ),
          ],
          if (!spec.customMl) ...<Widget>[
            const SizedBox(height: 22),
            const SectionLabel('Tingkat manis'),
            GlassSegmentedControl(
              labels: <String>[
                for (final MocktailSweetness s in MocktailSweetness.values)
                  s.label,
              ],
              iconBuilders: <Widget Function(Color, double)>[
                for (final MocktailSweetness s in MocktailSweetness.values)
                  (Color c, double size) =>
                      SweetnessIcon(sweetness: s, color: c, size: size),
              ],
              selectedIndex: spec.sweetness.index,
              onChanged: (int i) =>
                  _vm.setSweetness(MocktailSweetness.values[i]),
            ),
          ],
          const SizedBox(height: 22),
          const SectionLabel('Teknik'),
          GlassSegmentedControl(
            labels: <String>[
              for (final MocktailMethod m in MocktailMethod.values) m.label,
            ],
            iconBuilders: <Widget Function(Color, double)>[
              for (final MocktailMethod m in MocktailMethod.values)
                (Color c, double size) =>
                    MocktailMethodIcon(method: m, color: c, size: size),
            ],
            selectedIndex: spec.method.index,
            onChanged: (int i) => _vm.setMethod(MocktailMethod.values[i]),
          ),
        ],
      ),
    );
  }
}

/// Panel "Sesuaikan mocktail": porsi, es, jeruk nipis, dan hiasan. Tertutup
/// secara bawaan, dengan lencana "Disesuaikan" bila ada yang diubah (sama
/// seperti "Sesuaikan resep" di kalkulator kopi).
class MocktailAdjustPanel extends StatefulWidget {
  const MocktailAdjustPanel({
    super.key,
    required this.viewModel,
    required this.onAddCustomGarnish,
    required this.onDeleteCustomGarnish,
  });

  final MocktailViewModel viewModel;

  /// Dipanggil saat pengguna ingin menambah hiasan buatan sendiri.
  final VoidCallback onAddCustomGarnish;

  /// Dipanggil saat pengguna menahan lama hiasan buatan sendiri.
  final ValueChanged<String> onDeleteCustomGarnish;

  @override
  State<MocktailAdjustPanel> createState() => _MocktailAdjustPanelState();
}

class _MocktailAdjustPanelState extends State<MocktailAdjustPanel> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final MocktailViewModel vm = widget.viewModel;
    final MocktailSpec spec = vm.spec;

    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Semantics(
            button: true,
            expanded: _expanded,
            label: 'Sesuaikan mocktail',
            child: PressableScale(
              pressedScale: 0.98,
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Row(
                  children: <Widget>[
                    const Icon(
                      Icons.tune_rounded,
                      color: AppColors.sage,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Sesuaikan mocktail',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (vm.adjusted) const _Badge(label: 'Disesuaikan'),
                    const SizedBox(width: 8),
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOutCubic,
                      child: const Icon(
                        Icons.expand_more_rounded,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _expanded
                ? Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        _StepperRow(
                          label: 'Jumlah porsi',
                          value: '${spec.servings} porsi',
                          highlighted: spec.servings != 1,
                          minusLabel: 'Kurangi porsi',
                          plusLabel: 'Tambah porsi',
                          onMinus: spec.servings > MocktailSpec.minServings
                              ? () => vm.setServings(spec.servings - 1)
                              : null,
                          onPlus: spec.servings < MocktailSpec.maxServings
                              ? () => vm.setServings(spec.servings + 1)
                              : null,
                        ),
                        _SwitchRow(
                          label: 'Pakai es batu',
                          value: spec.useIce,
                          onChanged: (bool v) => vm.setUseIce(value: v),
                        ),
                        _SwitchRow(
                          label: 'Perasan jeruk nipis',
                          value: spec.useCitrus,
                          onChanged: (bool v) => vm.setUseCitrus(value: v),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Hiasan',
                          style: AppTextStyles.bodySecondary,
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: <Widget>[
                            for (final MocktailGarnish g
                                in MocktailGarnish.values)
                              FilterPill(
                                label: g.label,
                                selected: spec.garnishes.contains(g),
                                onTap: () => vm.toggleGarnish(g),
                              ),
                            for (final String name in vm.customGarnishes)
                              _CustomGarnishChip(
                                name: name,
                                selected: vm.isCustomGarnishSelected(name),
                                onTap: () => vm.toggleCustomGarnish(name),
                                onLongPress: () =>
                                    widget.onDeleteCustomGarnish(name),
                              ),
                            FilterPill(
                              label: 'Hiasan lain',
                              icon: Icons.add_rounded,
                              selected: false,
                              onTap: widget.onAddCustomGarnish,
                            ),
                          ],
                        ),
                        if (vm.customGarnishes.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 8),
                          Text(
                            'Tahan hiasan buatan sendiri untuk menghapus.',
                            style: AppTextStyles.bodySecondary.copyWith(
                              fontSize: 12,
                            ),
                          ),
                        ],
                        if (vm.adjusted) ...<Widget>[
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: PressableScale(
                              onTap: vm.resetAdjustments,
                              child: const Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 8,
                                ),
                                child: Text(
                                  'Kembalikan ke bawaan',
                                  style: TextStyle(
                                    color: AppColors.caramel,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.caramel.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.caramel.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.caramel,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Bahan dasar buatan sendiri: titik warna cairan, nama, dan ikon gelembung
/// bila bersoda. Ketuk untuk memilih, tahan untuk menghapus.
class _CustomBaseChip extends StatelessWidget {
  const _CustomBaseChip({
    required this.base,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
  });

  final MocktailCustomBase base;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: 'Bahan dasar ${base.name}',
      hint: 'Ketuk untuk memilih, tahan untuk menghapus',
      child: PressableScale(
        pressedScale: 0.94,
        onTap: () {
          Haptics.selection();
          onTap();
        },
        onLongPress: () {
          Haptics.medium();
          onLongPress();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.caramel.withValues(alpha: 0.16)
                : AppColors.glassFill,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected
                  ? AppColors.caramel.withValues(alpha: 0.6)
                  : AppColors.glassBorder,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: Color(base.color),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                base.name,
                style: TextStyle(
                  color: selected ? AppColors.caramel : AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (base.sparkling) ...<Widget>[
                const SizedBox(width: 6),
                Icon(
                  Icons.bubble_chart_rounded,
                  size: 15,
                  color: selected ? AppColors.caramel : AppColors.textSecondary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Hiasan buatan sendiri: ketuk untuk memakai, tahan untuk menghapus.
class _CustomGarnishChip extends StatelessWidget {
  const _CustomGarnishChip({
    required this.name,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
  });

  final String name;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: 'Hiasan $name',
      hint: 'Ketuk untuk memilih, tahan untuk menghapus',
      child: PressableScale(
        pressedScale: 0.94,
        onTap: () {
          Haptics.selection();
          onTap();
        },
        onLongPress: () {
          Haptics.medium();
          onLongPress();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.caramel.withValues(alpha: 0.16)
                : AppColors.glassFill,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected
                  ? AppColors.caramel.withValues(alpha: 0.6)
                  : AppColors.glassBorder,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.local_florist_rounded,
                size: 15,
                color: selected ? AppColors.caramel : AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                name,
                style: TextStyle(
                  color: selected ? AppColors.caramel : AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SyrupChip extends StatelessWidget {
  const _SyrupChip({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: 'Sirup $label',
      child: PressableScale(
        pressedScale: 0.94,
        onTap: () {
          Haptics.selection();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.caramel.withValues(alpha: 0.16)
                : AppColors.glassFill,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected
                  ? AppColors.caramel.withValues(alpha: 0.6)
                  : AppColors.glassBorder,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: selected ? AppColors.caramel : AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SyrupRow extends StatelessWidget {
  const _SyrupRow({
    required this.syrup,
    required this.showParts,
    required this.onMinus,
    required this.onPlus,
  });

  final MocktailSyrup syrup;
  final bool showParts;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    final Color dot = Color(
      SyrupPresets.byName(syrup.name)?.color ?? AppColors.caramel.toARGB32(),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: <Widget>[
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              syrup.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.body,
            ),
          ),
          if (showParts) ...<Widget>[
            GlassIconButton(
              icon: Icons.remove_rounded,
              label: 'Kurangi bagian ${syrup.name}',
              onTap: syrup.parts > MocktailSpec.minParts ? onMinus : () {},
            ),
            SizedBox(
              width: 76,
              child: Text(
                '${syrup.parts} bagian',
                textAlign: TextAlign.center,
                style: AppTextStyles.metricValue.copyWith(fontSize: 15),
              ),
            ),
            GlassIconButton(
              icon: Icons.add_rounded,
              label: 'Tambah bagian ${syrup.name}',
              onTap: syrup.parts < MocktailSpec.maxParts ? onPlus : () {},
            ),
          ],
        ],
      ),
    );
  }
}

class _StepperRow extends StatelessWidget {
  const _StepperRow({
    required this.label,
    required this.value,
    required this.highlighted,
    required this.minusLabel,
    required this.plusLabel,
    required this.onMinus,
    required this.onPlus,
  });

  final String label;
  final String value;
  final bool highlighted;
  final String minusLabel;
  final String plusLabel;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(label, style: AppTextStyles.body)),
          GlassIconButton(
            icon: Icons.remove_rounded,
            label: minusLabel,
            onTap: onMinus ?? () {},
          ),
          SizedBox(
            width: 84,
            child: Text(
              value,
              textAlign: TextAlign.center,
              style: AppTextStyles.metricValue.copyWith(
                color: highlighted ? AppColors.caramel : AppColors.textPrimary,
              ),
            ),
          ),
          GlassIconButton(
            icon: Icons.add_rounded,
            label: plusLabel,
            onTap: onPlus ?? () {},
          ),
        ],
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(label, style: AppTextStyles.body)),
          GlassSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

/// Info mode ml sendiri: total sirup, atau pesan bila takarannya tidak muat.
class _CustomInfo extends StatelessWidget {
  const _CustomInfo({required this.vm});

  final MocktailViewModel vm;

  @override
  Widget build(BuildContext context) {
    final String? problem = vm.problem;
    final MocktailBlend? blend = vm.blend;
    final String text =
        problem ??
        'Total sirup ${formatGrams(blend!.syrupMl)} ml per gelas. '
            'Tingkat manis tidak dipakai di mode ini.';
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        text,
        style: AppTextStyles.bodySecondary.copyWith(
          fontSize: 13,
          color: problem == null ? null : AppColors.danger,
        ),
      ),
    );
  }
}

/// Satu baris sirup di mode ml sendiri: tombol +/- dan field angka.
class SyrupMlRow extends StatelessWidget {
  const SyrupMlRow({
    super.key,
    required this.syrup,
    required this.onMinus,
    required this.onPlus,
    required this.validator,
    required this.onValid,
  });

  final MocktailSyrup syrup;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final String? Function(String?) validator;
  final ValueChanged<double> onValid;

  @override
  Widget build(BuildContext context) {
    final Color dot = Color(
      SyrupPresets.byName(syrup.name)?.color ?? AppColors.caramel.toARGB32(),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: <Widget>[
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              syrup.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.body,
            ),
          ),
          GlassIconButton(
            icon: Icons.remove_rounded,
            label: 'Kurangi takaran ${syrup.name}',
            onTap: onMinus,
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 96,
            child: _MlField(
              key: ValueKey<String>('ml-${syrup.name}'),
              label: 'Takaran sirup ${syrup.name} dalam mililiter',
              value: syrup.ml!,
              validator: validator,
              onValid: onValid,
            ),
          ),
          const SizedBox(width: 8),
          GlassIconButton(
            icon: Icons.add_rounded,
            label: 'Tambah takaran ${syrup.name}',
            onTap: onPlus,
          ),
        ],
      ),
    );
  }
}

/// Field ml kecil: hanya angka, batas merah bila tidak valid, dan ikut
/// berubah saat nilainya diubah dari luar (tombol +/- atau ganti mode).
class _MlField extends StatefulWidget {
  const _MlField({
    super.key,
    required this.label,
    required this.value,
    required this.validator,
    required this.onValid,
  });

  final String label;
  final double value;
  final String? Function(String?) validator;
  final ValueChanged<double> onValid;

  @override
  State<_MlField> createState() => _MlFieldState();
}

class _MlFieldState extends State<_MlField> {
  late final TextEditingController _controller = TextEditingController(
    text: formatGrams(widget.value),
  );
  final FocusNode _focus = FocusNode();
  String? _error;

  @override
  void didUpdateWidget(_MlField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final double? typed = double.tryParse(
      _controller.text.trim().replaceAll(',', '.'),
    );
    if (typed != widget.value && !_focus.hasFocus) {
      _controller.text = formatGrams(widget.value);
      _error = null;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String raw) {
    final String? error = widget.validator(raw);
    setState(() => _error = error);
    if (error == null) {
      widget.onValid(double.parse(raw.trim().replaceAll(',', '.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    const BorderRadius radius = BorderRadius.all(Radius.circular(14));
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: c, width: w),
    );
    final bool invalid = _error != null;

    // Di iOS aplikasi berbasis Cupertino, jadi TextField Material butuh
    // induk Material (transparan) agar bisa digambar.
    return Semantics(
      label: widget.label,
      textField: true,
      child: Material(
        type: MaterialType.transparency,
        child: TextField(
          controller: _controller,
          focusNode: _focus,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textInputAction: TextInputAction.done,
          inputFormatters: <TextInputFormatter>[DecimalTextInputFormatter()],
          textAlign: TextAlign.center,
          onChanged: _onChanged,
          onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
          style: AppTextStyles.metricValue.copyWith(
            fontSize: 16,
            color: invalid ? AppColors.danger : AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: AppColors.glassFill,
            suffixText: 'ml',
            suffixStyle: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 10,
            ),
            border: border(AppColors.glassBorder),
            enabledBorder: border(
              invalid ? AppColors.danger : AppColors.glassBorder,
            ),
            focusedBorder: border(
              invalid ? AppColors.danger : AppColors.caramel,
              1.6,
            ),
          ),
        ),
      ),
    );
  }
}
