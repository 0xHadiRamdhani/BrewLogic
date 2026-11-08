import 'package:flutter/widgets.dart';

import '../../core/theme/app_theme.dart';

/// Menerapkan font pixel dan skala teks aplikasi pada [child].
///
/// `AdaptiveScaffold` membungkus body-nya dengan `DefaultTextStyle` baru tanpa
/// font, dan `AdaptiveApp` mengembalikan skala teks ke bawaan sistem, jadi
/// keduanya harus dipasang ulang di dalam setiap halaman dan dialog.
class AppTextScope extends StatelessWidget {
  const AppTextScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final MediaQueryData media = MediaQuery.of(context);
    return ValueListenableBuilder<double>(
      valueListenable: TextScalePrefs.factor,
      builder: (BuildContext context, double factor, Widget? _) {
        return MediaQuery(
          data: media.copyWith(
            textScaler: TextScaler.linear(media.textScaler.scale(1) * factor),
          ),
          child: DefaultTextStyle.merge(
            style: const TextStyle(fontFamily: appFontFamily),
            child: child,
          ),
        );
      },
    );
  }
}
