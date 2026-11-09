import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/field_styles.dart';
import '../../models/mocktail_model.dart';
import 'glass_dialog.dart';

/// Dialog "Hiasan lain": satu nama hiasan. Mengembalikan nama yang dibuat,
/// atau `null` bila dibatalkan. [validator] memeriksa nama (mis. duplikat)
/// dan mengembalikan pesan error.
Future<String?> showMocktailGarnishDialog(
  BuildContext context, {
  required String? Function(String?) validator,
}) {
  return showGlassDialog<String>(
    context,
    (BuildContext _) => _GarnishDialog(validator: validator),
  );
}

class _GarnishDialog extends StatefulWidget {
  const _GarnishDialog({required this.validator});

  final String? Function(String?) validator;

  @override
  State<_GarnishDialog> createState() => _GarnishDialogState();
}

class _GarnishDialogState extends State<_GarnishDialog> {
  final TextEditingController _name = TextEditingController();
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
    Navigator.of(context).pop(_name.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return GlassDialogFrame(
      title: 'Hiasan lain',
      message: 'Tulis hiasan yang kamu punya, mis. "Rosemary" atau "Nanas".',
      confirmLabel: 'Tambah',
      onConfirm: _confirm,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AdaptiveTextFormField(
            controller: _name,
            placeholder: 'Nama hiasan',
            autofocus: true,
            maxLength: MocktailSpec.maxGarnishNameLength,
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
            decoration: FieldStyles.material('Nama hiasan'),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _error!,
                style: const TextStyle(color: AppColors.danger, fontSize: 13),
              ),
            ),
        ],
      ),
    );
  }
}
