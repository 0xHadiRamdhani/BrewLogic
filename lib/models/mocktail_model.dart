import 'package:flutter/foundation.dart';

/// Bahan dasar (cairan pengisi) mocktail.
enum MocktailBase {
  soda('Soda', 'Soda', sparkling: true),
  tonic('Tonic', 'Air tonik', sparkling: true),
  gingerAle('Ginger ale', 'Ginger ale', sparkling: true),
  water('Air putih', 'Air putih dingin', sparkling: false),
  coconut('Air kelapa', 'Air kelapa', sparkling: false),
  iceTea('Teh dingin', 'Teh dingin tanpa gula', sparkling: false);

  const MocktailBase(this.label, this.ingredient, {required this.sparkling});

  final String label;

  /// Nama bahan di daftar takaran.
  final String ingredient;

  /// Berkarbonasi: dituang paling akhir dan perlahan agar gelembung awet.
  final bool sparkling;
}

/// Tingkat manis: porsi sirup terhadap total cairan (di luar es).
enum MocktailSweetness {
  light('Ringan', 0.12),
  normal('Sedang', 0.16),
  sweet('Manis', 0.20);

  const MocktailSweetness(this.label, this.syrupShare);

  final String label;
  final double syrupShare;
}

/// Teknik pembuatan.
enum MocktailMethod {
  build('Langsung', 'Langsung di gelas'),
  shake('Kocok', 'Dikocok di shaker');

  const MocktailMethod(this.label, this.description);

  final String label;
  final String description;
}

/// Hiasan opsional.
enum MocktailGarnish {
  mint('Daun mint'),
  limeWheel('Irisan jeruk nipis'),
  lemonPeel('Kulit lemon'),
  berries('Buah beri'),
  cucumber('Irisan timun');

  const MocktailGarnish(this.label);

  final String label;
}

/// Sirup siap pilih. Warna hanya untuk penanda di antarmuka.
@immutable
class SyrupPreset {
  const SyrupPreset(this.name, this.color);

  final String name;

  /// Warna ARGB penanda.
  final int color;
}

abstract final class SyrupPresets {
  static const List<SyrupPreset> all = <SyrupPreset>[
    SyrupPreset('Simple syrup', 0xFFE9DCC3),
    SyrupPreset('Vanila', 0xFFEBD9A8),
    SyrupPreset('Grenadine', 0xFFD9455B),
    SyrupPreset('Mawar', 0xFFE79AB0),
    SyrupPreset('Markisa', 0xFFF2B23A),
    SyrupPreset('Leci', 0xFFF0C9C0),
    SyrupPreset('Stroberi', 0xFFE5576B),
    SyrupPreset('Blue curaçao', 0xFF4F9BE0),
    SyrupPreset('Mint', 0xFF7FC8A0),
    SyrupPreset('Jahe', 0xFFD9A566),
    SyrupPreset('Karamel', 0xFFC98B4A),
    SyrupPreset('Pandan', 0xFF6DB56D),
  ];

  static SyrupPreset? byName(String name) {
    for (final SyrupPreset p in all) {
      if (p.name.toLowerCase() == name.toLowerCase()) {
        return p;
      }
    }
    return null;
  }
}

/// Satu sirup di resep: [parts] adalah bagian relatif dari total sirup.
@immutable
class MocktailSyrup {
  const MocktailSyrup(this.name, {this.parts = 1});

  final String name;
  final int parts;

  MocktailSyrup copyWith({int? parts}) =>
      MocktailSyrup(name, parts: parts ?? this.parts);

  @override
  bool operator ==(Object other) =>
      other is MocktailSyrup && other.name == name && other.parts == parts;

  @override
  int get hashCode => Object.hash(name, parts);
}

/// Masukan pengguna untuk satu mocktail (per porsi, dikali [servings]).
@immutable
class MocktailSpec {
  const MocktailSpec({
    this.servings = 1,
    this.glassMl = 300,
    this.base = MocktailBase.soda,
    this.sweetness = MocktailSweetness.normal,
    this.method = MocktailMethod.build,
    this.useIce = true,
    this.useCitrus = true,
    this.syrups = const <MocktailSyrup>[],
    this.garnishes = const <MocktailGarnish>{},
  });

  static const int minServings = 1;
  static const int maxServings = 12;
  static const int minGlassMl = 100;
  static const int maxGlassMl = 600;
  static const int maxSyrups = 3;
  static const int minParts = 1;
  static const int maxParts = 4;

  final int servings;

  /// Volume gelas per porsi (ml), termasuk es.
  final int glassMl;
  final MocktailBase base;
  final MocktailSweetness sweetness;
  final MocktailMethod method;
  final bool useIce;

  /// Perasan jeruk nipis/lemon untuk menyeimbangkan manis.
  final bool useCitrus;
  final List<MocktailSyrup> syrups;
  final Set<MocktailGarnish> garnishes;

  MocktailSpec copyWith({
    int? servings,
    int? glassMl,
    MocktailBase? base,
    MocktailSweetness? sweetness,
    MocktailMethod? method,
    bool? useIce,
    bool? useCitrus,
    List<MocktailSyrup>? syrups,
    Set<MocktailGarnish>? garnishes,
  }) => MocktailSpec(
    servings: servings ?? this.servings,
    glassMl: glassMl ?? this.glassMl,
    base: base ?? this.base,
    sweetness: sweetness ?? this.sweetness,
    method: method ?? this.method,
    useIce: useIce ?? this.useIce,
    useCitrus: useCitrus ?? this.useCitrus,
    syrups: syrups ?? this.syrups,
    garnishes: garnishes ?? this.garnishes,
  );
}

/// Satu bahan di hasil hitungan, dengan takaran per porsi.
@immutable
class MocktailIngredient {
  const MocktailIngredient({
    required this.name,
    required this.perServing,
    required this.unit,
    this.color,
  });

  final String name;
  final double perServing;

  /// "ml" atau "g".
  final String unit;
  final int? color;
}

/// Hasil hitungan: bahan per porsi dan langkah pembuatan.
@immutable
class MocktailBlend {
  const MocktailBlend({
    required this.spec,
    required this.ingredients,
    required this.steps,
    required this.liquidMl,
    required this.syrupMl,
  });

  final MocktailSpec spec;
  final List<MocktailIngredient> ingredients;
  final List<String> steps;

  /// Cairan per porsi di luar es.
  final double liquidMl;

  /// Total sirup per porsi.
  final double syrupMl;

  int get servings => spec.servings;

  /// Takaran satu bahan untuk seluruh porsi.
  double totalOf(MocktailIngredient i) => i.perServing * spec.servings;

  /// Ringkasan satu baris, mis. "Soda · 2 sirup · 300 ml".
  String get summary {
    final int n = spec.syrups.length;
    return '${spec.base.label} · $n sirup · ${spec.glassMl} ml';
  }
}

/// Mocktail yang tersimpan di "Resep Saya".
@immutable
class MocktailRecipe {
  const MocktailRecipe({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.spec,
  });

  final String id;
  final String name;
  final DateTime createdAt;
  final MocktailSpec spec;
}
