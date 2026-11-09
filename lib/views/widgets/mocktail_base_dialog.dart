import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/field_styles.dart';
import '../../core/utils/haptics.dart';
import '../../models/mocktail_model.dart';
import 'glass_controls.dart';
import 'glass_dialog.dart';
import 'motion.dart';

/// Dialog "Bahan dasar lain": nama, bersoda atau tidak, dan warna cairan.
/// Mengembalikan bahan yang dibuat, atau `null` bila dibatalkan. [validator]
/// memeriksa nama (mis. duplikat) dan mengembalikan pesan error.
Future<MocktailCustomBase?> showMocktailBaseDialog(
  BuildContext context, {
  required String? Function(String?) validator,
}) {
  return showGlassDialog<MocktailCustomBase>(
    context,
    (BuildContext _) => _BaseDialog(validator: validator),
  );
}

class _BaseDialog extends StatefulWidget {
  const _BaseDialog({required this.validator});

  final String? Function(String?) validator;

  @override
  State<_BaseDialog> createState() => _BaseDialogState();
}

class _BaseDialogState extends State<_BaseDialog> {
  final TextEditingController _name = TextEditingController();
  bool _sparkling = false;
  int _color = MocktailCustomBase.palette.first;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _confirm() {
    final String? error = widget.validator(_name.text);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.of(context).pop(
      MocktailCustomBase(
        _name.text.trim(),
        sparkling: _sparkling,
        color: _color,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GlassDialogFrame(
      title: 'Bahan dasar lain',
      message:
          'Tulis bahan dasar yang kamu punya, mis. "Jus apel" atau '
          '"Kombucha".',
      confirmLabel: 'Tambah',
      onConfirm: _confirm,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AdaptiveTextFormField(
            controller: _name,
            placeholder: 'Nama bahan',
            autofocus: true,
            maxLength: MocktailCustomBase.maxNameLength,
            textInputAction: TextInputAction.done,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) {
              if (_error != null) {
                setState(() => _error = null);
              }
            },
            onSubmitted: (_) => _confirm(),
            style: AppTextStyles.body,
            cupertinoDecoration: FieldStyles.cupertino,
            decoration: FieldStyles.material('Nama bahan'),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _error!,
                style: const TextStyle(color: AppColors.danger, fontSize: 13),
              ),
            ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              const Expanded(
                child: Text(
                  'Bersoda (berkarbonasi)',
                  style: AppTextStyles.body,
                ),
              ),
              GlassSwitch(
                value: _sparkling,
                onChanged: (bool v) => setState(() => _sparkling = v),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Warna cairan', style: AppTextStyles.bodySecondary),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: <Widget>[
              for (final int color in MocktailCustomBase.palette)
                _Swatch(
                  color: Color(color),
                  selected: color == _color,
                  onTap: () => setState(() => _color = color),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: 'Warna cairan',
      child: PressableScale(
        pressedScale: 0.9,
        onTap: () {
          Haptics.selection();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? AppColors.caramel : AppColors.glassBorder,
              width: selected ? 3 : 1,
            ),
          ),
        ),
      ),
    );
  }
}
