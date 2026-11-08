import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';

/// Field gramasi kopi: hanya menerima angka, memvalidasi saat pengguna
/// mengetik, dan menampilkan pesan error dengan gaya platform masing-masing.
class GramsInputField extends StatelessWidget {
  const GramsInputField({
    super.key,
    required this.controller,
    required this.validator,
    required this.onChanged,
    this.placeholder = 'mis. 18',
    this.semanticLabel = 'Gramasi kopi dalam gram',
    this.unit = 'g',
  });

  final String placeholder;
  final String semanticLabel;

  /// Satuan di ujung kanan field: `g` untuk kopi, `ml` untuk air.
  final String unit;

  final TextEditingController controller;
  final String? Function(String? value) validator;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    const BorderRadius radius = BorderRadius.all(Radius.circular(18));

    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: color, width: width),
        );

    return Semantics(
      label: semanticLabel,
      textField: true,
      child: AdaptiveTextFormField(
        controller: controller,
        placeholder: placeholder,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textInputAction: TextInputAction.done,
        inputFormatters: <TextInputFormatter>[DecimalTextInputFormatter()],
        autovalidateMode: AutovalidateMode.onUserInteraction,
        // Teks dibaca dari controller, bukan argumen validator, karena
        // chip cepat mengubah controller tanpa memicu onChanged.
        validator: (String? _) => validator(controller.text),
        onChanged: onChanged,
        onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
        style: AppTextStyles.input,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        suffix: Padding(
          padding: const EdgeInsets.only(right: 18),
          child: Text(
            unit,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        cupertinoDecoration: BoxDecoration(
          color: AppColors.glassFill,
          borderRadius: radius,
          border: Border.all(color: AppColors.glassBorder),
        ),
        decoration: InputDecoration(
          hintText: placeholder,
          suffixText: unit,
          suffixStyle: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 18,
          ),
          filled: true,
          fillColor: AppColors.glassFill,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 16,
          ),
          border: border(AppColors.glassBorder),
          enabledBorder: border(AppColors.glassBorder),
          focusedBorder: border(AppColors.caramel, 1.6),
          errorBorder: border(AppColors.danger),
          focusedErrorBorder: border(AppColors.danger, 1.6),
          errorStyle: const TextStyle(color: AppColors.danger),
        ),
      ),
    );
  }
}
