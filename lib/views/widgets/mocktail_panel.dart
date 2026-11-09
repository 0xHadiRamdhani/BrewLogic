import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/haptics.dart';
import '../../models/mocktail_model.dart';
import '../../viewmodels/mocktail_viewmodel.dart';
import 'filter_pill.dart';
import 'glass_card.dart';
import 'glass_controls.dart';
import 'motion.dart';
import 'section_label.dart';

/// Kartu pembuat mocktail: porsi, gelas, bahan dasar, sirup, manis, teknik,
/// es, jeruk nipis, dan hiasan. Semua perubahan langsung masuk ViewModel.
class MocktailPanel extends StatelessWidget {
  const MocktailPanel({
    super.key,
    required this.viewModel,
    required this.onAddCustomSyrup,
    required this.onSyrupLimit,
  });

  final MocktailViewModel viewModel;

  /// Dipanggil saat pengguna ingin menambah sirup buatan sendiri.
  final VoidCallback onAddCustomSyrup;

  /// Dipanggil saat batas jumlah sirup tercapai.
  final VoidCallback onSyrupLimit;

  static const List<int> _glassSizes = <int>[200, 250, 300, 350, 400];

  @override
  Widget build(BuildContext context) {
    final MocktailSpec spec = viewModel.spec;

    return GlassCard(
      accent: AppColors.sage,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SectionLabel('Jumlah porsi'),
          _Stepper(
            value: spec.servings,
            suffix: 'porsi',
            onMinus: spec.servings > MocktailSpec.minServings
                ? () => viewModel.setServings(spec.servings - 1)
                : null,
            onPlus: spec.servings < MocktailSpec.maxServings
                ? () => viewModel.setServings(spec.servings + 1)
                : null,
          ),
          const SizedBox(height: 22),
          const SectionLabel('Ukuran gelas'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final int size in _glassSizes)
                FilterPill(
                  label: '$size ml',
                  selected: spec.glassMl == size,
                  onTap: () => viewModel.setGlassMl(size),
                ),
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
                  selected: spec.base == base,
                  onTap: () => viewModel.setBase(base),
                ),
            ],
          ),
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
                  selected: viewModel.hasSyrup(preset.name),
                  onTap: () {
                    if (!viewModel.toggleSyrup(preset.name)) {
                      onSyrupLimit();
                    }
                  },
                ),
              for (final MocktailSyrup s in spec.syrups)
                if (SyrupPresets.byName(s.name) == null)
                  _SyrupChip(
                    label: s.name,
                    color: AppColors.caramel,
                    selected: true,
                    onTap: () => viewModel.toggleSyrup(s.name),
                  ),
              FilterPill(
                label: 'Sirup lain',
                icon: Icons.add_rounded,
                selected: false,
                onTap: () {
                  if (viewModel.canAddSyrup) {
                    onAddCustomSyrup();
                  } else {
                    onSyrupLimit();
                  }
                },
              ),
            ],
          ),
          if (spec.syrups.isNotEmpty) ...<Widget>[
            const SizedBox(height: 14),
            for (int i = 0; i < spec.syrups.length; i++)
              _SyrupRow(
                syrup: spec.syrups[i],
                showParts: spec.syrups.length > 1,
                onMinus: () => viewModel.changeParts(i, -1),
                onPlus: () => viewModel.changeParts(i, 1),
              ),
          ] else ...<Widget>[
            const SizedBox(height: 12),
            const Text(
              'Pilih minimal satu sirup untuk melihat takaran.',
              style: AppTextStyles.bodySecondary,
            ),
          ],
          const SizedBox(height: 22),
          const SectionLabel('Tingkat manis'),
          GlassSegmentedControl(
            labels: <String>[
              for (final MocktailSweetness s in MocktailSweetness.values)
                s.label,
            ],
            selectedIndex: spec.sweetness.index,
            onChanged: (int i) =>
                viewModel.setSweetness(MocktailSweetness.values[i]),
          ),
          const SizedBox(height: 22),
          const SectionLabel('Teknik'),
          GlassSegmentedControl(
            labels: <String>[
              for (final MocktailMethod m in MocktailMethod.values) m.label,
            ],
            selectedIndex: spec.method.index,
            onChanged: (int i) => viewModel.setMethod(MocktailMethod.values[i]),
          ),
          const SizedBox(height: 22),
          _SwitchRow(
            label: 'Pakai es batu',
            value: spec.useIce,
            onChanged: (bool v) => viewModel.setUseIce(value: v),
          ),
          const SizedBox(height: 12),
          _SwitchRow(
            label: 'Perasan jeruk nipis',
            value: spec.useCitrus,
            onChanged: (bool v) => viewModel.setUseCitrus(value: v),
          ),
          const SizedBox(height: 22),
          const SectionLabel('Hiasan'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final MocktailGarnish g in MocktailGarnish.values)
                FilterPill(
                  label: g.label,
                  selected: spec.garnishes.contains(g),
                  onTap: () => viewModel.toggleGarnish(g),
                ),
            ],
          ),
        ],
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
                ? AppColors.sage.withValues(alpha: 0.18)
                : AppColors.glassFill,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected
                  ? AppColors.sage.withValues(alpha: 0.7)
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
                  color: selected ? AppColors.sage : AppColors.textPrimary,
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
      padding: const EdgeInsets.only(bottom: 8),
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
            _RoundButton(
              icon: Icons.remove_rounded,
              label: 'Kurangi bagian ${syrup.name}',
              onTap: syrup.parts > MocktailSpec.minParts ? onMinus : null,
            ),
            SizedBox(
              width: 58,
              child: Text(
                '${syrup.parts} bagian',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySecondary.copyWith(fontSize: 13),
              ),
            ),
            _RoundButton(
              icon: Icons.add_rounded,
              label: 'Tambah bagian ${syrup.name}',
              onTap: syrup.parts < MocktailSpec.maxParts ? onPlus : null,
            ),
          ],
        ],
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.value,
    required this.suffix,
    required this.onMinus,
    required this.onPlus,
  });

  final int value;
  final String suffix;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        _RoundButton(
          icon: Icons.remove_rounded,
          label: 'Kurangi $suffix',
          onTap: onMinus,
          size: 46,
        ),
        const SizedBox(width: 18),
        Text('$value', style: AppTextStyles.input),
        const SizedBox(width: 8),
        Text(suffix, style: AppTextStyles.bodySecondary),
        const SizedBox(width: 18),
        _RoundButton(
          icon: Icons.add_rounded,
          label: 'Tambah $suffix',
          onTap: onPlus,
          size: 46,
        ),
      ],
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.size = 34,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: PressableScale(
        onTap: () {
          if (onTap != null) {
            Haptics.selection();
            onTap!();
          }
        },
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.sage.withValues(alpha: enabled ? 0.16 : 0.06),
            border: Border.all(
              color: AppColors.sage.withValues(alpha: enabled ? 0.55 : 0.2),
            ),
          ),
          child: Icon(
            icon,
            size: size * 0.5,
            color: enabled ? AppColors.sage : AppColors.textSecondary,
          ),
        ),
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
    return Row(
      children: <Widget>[
        Expanded(child: Text(label, style: AppTextStyles.body)),
        GlassSwitch(value: value, onChanged: onChanged),
      ],
    );
  }
}
