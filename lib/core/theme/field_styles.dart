import 'package:flutter/material.dart';

import 'app_theme.dart';

/// Gaya field teks kaca yang dipakai bersama oleh form baru.
abstract final class FieldStyles {
  static const BorderRadius radius = BorderRadius.all(Radius.circular(16));

  static OutlineInputBorder _border(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: color, width: width),
      );

  /// Dekorasi untuk iOS (`AdaptiveTextFormField.cupertinoDecoration`).
  static BoxDecoration get cupertino => BoxDecoration(
    color: AppColors.glassFill,
    borderRadius: radius,
    border: Border.all(color: AppColors.glassBorder),
  );

  /// Dekorasi untuk Android (`AdaptiveTextFormField.decoration`).
  static InputDecoration material(String hint) => InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: AppColors.glassFill,
    isDense: true,
    border: _border(AppColors.glassBorder),
    enabledBorder: _border(AppColors.glassBorder),
    focusedBorder: _border(AppColors.caramel, 1.6),
    errorBorder: _border(AppColors.danger),
    focusedErrorBorder: _border(AppColors.danger, 1.6),
    errorStyle: const TextStyle(color: AppColors.danger),
  );
}
