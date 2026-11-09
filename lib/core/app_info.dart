import 'package:flutter/material.dart';

/// Satu baris tech stack yang ditampilkan di halaman Tentang.
@immutable
class TechItem {
  const TechItem({
    required this.category,
    required this.name,
    required this.detail,
    required this.icon,
  });

  final String category;
  final String name;

  /// Versi atau keterangan singkat.
  final String detail;
  final IconData icon;
}

/// Satu fitur utama untuk kisi di halaman Tentang.
@immutable
class FeatureItem {
  const FeatureItem(this.icon, this.label);

  final IconData icon;
  final String label;
}

/// Informasi statis aplikasi. Versi paket mengikuti `pubspec.lock`.
abstract final class AppInfo {
  static const String name = 'BrewLogic';
  static const String version = '1.2.0';
  static const String buildNumber = '3';
  static const String releaseYear = '2026';
  static const String platforms = 'iOS & Android';

  static const String developerName = 'Hadi Ramdhani';
  static const String developerRole =
      'Lead Developer & Mobile Expert Developer';
  static const String developerLocation = 'Kota Bandung';
  static const String githubUrl = 'https://github.com/0xHadiRamdhani';
  static const String githubHandle = '0xHadiRamdhani';
  static const String instagramUrl =
      'https://www.instagram.com/hadiramdhani.tsx';
  static const String instagramHandle = '@hadiramdhani.tsx';
  static const String logoAsset = 'assets/images/icons.jpg';
  static const String developerInitials = 'HR';
  static const String developerPhotoAsset = 'assets/images/developer.jpg';

  static const String tagline = 'Seduh presisi, nikmati pelan.';

  static const String description =
      'BrewLogic menemani homebrewer di setiap cangkir: menghitung takaran '
      'dan suhu, memandu seduhan step-by-step dengan timer, lalu menyimpan '
      'resep, biji, rating, dan catatan rasa dalam satu jurnal. Kini juga '
      'untuk meracik mocktail bersirup.';

  static const List<FeatureItem> features = <FeatureItem>[
    FeatureItem(Icons.calculate_rounded, 'Kalkulator seduh'),
    FeatureItem(Icons.swap_horiz_rounded, 'Kalkulator terbalik'),
    FeatureItem(Icons.timer_rounded, 'Timer step-by-step'),
    FeatureItem(Icons.menu_book_rounded, 'Brew journal'),
    FeatureItem(Icons.bookmark_rounded, 'Resep favorit'),
    FeatureItem(Icons.grain_rounded, 'Perpustakaan biji'),
    FeatureItem(Icons.insights_rounded, 'Statistik seduhan'),
    FeatureItem(Icons.ios_share_rounded, 'Ekspor dan bagikan'),
    FeatureItem(Icons.local_bar_rounded, 'Mode mocktail'),
    FeatureItem(Icons.animation_rounded, 'Timer beranimasi'),
  ];

  static const List<TechItem> techStack = <TechItem>[
    TechItem(
      category: 'Framework',
      name: 'Flutter',
      detail: '3.47.7',
      icon: Icons.flutter_dash_rounded,
    ),
    TechItem(
      category: 'Bahasa',
      name: 'Dart',
      detail: '3.13.5',
      icon: Icons.code_rounded,
    ),
    TechItem(
      category: 'UI adaptif',
      name: 'adaptive_platform_ui',
      detail: '1.0.2',
      icon: Icons.devices_rounded,
    ),
    TechItem(
      category: 'State management',
      name: 'provider',
      detail: '6.1.5+1',
      icon: Icons.hub_rounded,
    ),
    TechItem(
      category: 'Penyimpanan lokal',
      name: 'hive + hive_flutter',
      detail: '2.2.3 · 1.1.0',
      icon: Icons.storage_rounded,
    ),
    TechItem(
      category: 'Animasi',
      name: 'lottie',
      detail: '3.8.2',
      icon: Icons.animation_rounded,
    ),
    TechItem(
      category: 'Tipografi',
      name: 'Pixelify Sans',
      detail: 'OFL',
      icon: Icons.text_fields_rounded,
    ),
    TechItem(
      category: 'Arsitektur: models, viewmodels, views, services',
      name: 'MVVM',
      detail: '4 lapisan',
      icon: Icons.account_tree_rounded,
    ),
  ];
}
