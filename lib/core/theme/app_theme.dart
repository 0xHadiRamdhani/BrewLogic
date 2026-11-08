import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Palet kafe: espresso gelap, krim, karamel, dan sage.
abstract final class AppColors {
  /// Espresso: cokelat tua hangat, bukan hitam murni.
  static const Color background = Color(0xFF15100C);

  /// Aksen utama: karamel.
  static const Color caramel = Color(0xFFD9A566);

  /// Aksen kedua: hijau sage lembut ala matcha latte.
  static const Color sage = Color(0xFFA8BFA0);

  /// Teks: krim susu.
  static const Color textPrimary = Color(0xFFF3EADD);
  static const Color textSecondary = Color(0xB3F3EADD);
  static const Color danger = Color(0xFFE06B57);
  static const Color onAccent = Color(0xFF1A110B);

  /// Tombol sekunder: mocha.
  static const Color secondaryButton = Color(0xFF3A2E26);

  /// Lapisan kaca: krim transparan di atas latar espresso.
  static const Color glassFill = Color(0x14F3E6D6);
  static const Color glassBorder = Color(0x33F3E6D6);
}

/// Font teks isi dan angka kecil (DM Sans, lisensi OFL): jernih untuk angka
/// takaran. Menjadi font bawaan seluruh aplikasi.
const String appFontFamily = 'DMSans';

/// Font display (Pixelify Sans, lisensi OFL): hanya untuk judul layar dan
/// angka besar supaya identitas pixel tetap terasa tanpa mengorbankan
/// keterbacaan.
const String appDisplayFontFamily = 'PixelifySans';

/// Faktor ukuran teks pilihan pengguna (Pengaturan → Ukuran teks). Dibaca
/// `AppTextScope` dan diubah `SettingsViewModel`; berupa notifier statis agar
/// widget tanpa Provider (mis. dialog dan tes) tetap bisa memakainya.
abstract final class TextScalePrefs {
  static final ValueNotifier<double> factor = ValueNotifier<double>(1);
}

abstract final class AppTextStyles {
  static const List<FontFeature> _tabular = <FontFeature>[
    FontFeature.tabularFigures(),
  ];

  static const TextStyle screenTitle = TextStyle(
    fontFamily: appDisplayFontFamily,
    color: AppColors.textPrimary,
    fontSize: 28,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
  );

  static const TextStyle sectionLabel = TextStyle(
    color: AppColors.textSecondary,
    fontSize: 13,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.4,
  );

  static const TextStyle body = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 16,
    height: 1.4,
  );

  static const TextStyle bodySecondary = TextStyle(
    color: AppColors.textSecondary,
    fontSize: 15,
    height: 1.4,
  );

  static const TextStyle input = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 24,
    fontWeight: FontWeight.w600,
    fontFeatures: _tabular,
  );

  static const TextStyle heroNumber = TextStyle(
    fontFamily: appDisplayFontFamily,
    color: AppColors.caramel,
    fontSize: 56,
    fontWeight: FontWeight.w800,
    height: 1.05,
    letterSpacing: -1,
    fontFeatures: _tabular,
  );

  static const TextStyle metricValue = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 19,
    fontWeight: FontWeight.w700,
    fontFeatures: _tabular,
  );

  static const TextStyle timerDigits = TextStyle(
    fontFamily: appDisplayFontFamily,
    color: AppColors.textPrimary,
    fontSize: 54,
    fontWeight: FontWeight.w700,
    letterSpacing: -1,
    fontFeatures: _tabular,
  );
}

abstract final class AppTheme {
  static ThemeData get material {
    final ColorScheme scheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.caramel,
          brightness: Brightness.dark,
        ).copyWith(
          primary: AppColors.caramel,
          onPrimary: AppColors.onAccent,
          secondary: AppColors.sage,
          onSecondary: AppColors.onAccent,
          surface: AppColors.background,
          onSurface: AppColors.textPrimary,
          error: AppColors.danger,
        );

    return ThemeData(
      useMaterial3: true,
      fontFamily: appFontFamily,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      canvasColor: AppColors.background,
      splashFactory: NoSplash.splashFactory,
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xCC15100C),
        indicatorColor: AppColors.caramel.withValues(alpha: 0.22),
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  static CupertinoThemeData get cupertino => const CupertinoThemeData(
    brightness: Brightness.dark,
    textTheme: CupertinoTextThemeData(
      textStyle: TextStyle(
        fontFamily: appFontFamily,
        fontSize: 17,
        color: AppColors.textPrimary,
      ),
    ),
    primaryColor: AppColors.caramel,
    primaryContrastingColor: AppColors.onAccent,
    scaffoldBackgroundColor: AppColors.background,
    barBackgroundColor: Color(0xCC15100C),
  );
}
