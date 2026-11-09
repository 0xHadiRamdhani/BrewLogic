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

/// Bahan dasar buatan sendiri (mis. jus apel, kombucha). [sparkling] menentukan
/// cara menuang dan gelembung di animasi; [color] (ARGB) mewarnai cairan di
/// animasi gelas.
@immutable
class MocktailCustomBase {
  const MocktailCustomBase(
    this.name, {
    this.sparkling = false,
    this.color = defaultColor,
  });

  static const int maxNameLength = 20;

  /// Jumlah maksimal bahan buatan yang disimpan.
  static const int maxSaved = 8;

  static const int defaultColor = 0xFFEADFC8;

  /// Pilihan warna cairan: bening, kuning, merah muda, hijau, susu, cokelat.
  static const List<int> palette = <int>[
    0xFFD6EDF5,
    0xFFF0D58A,
    0xFFE9A8A0,
    0xFFB9DCA5,
    0xFFF2EEE6,
    0xFFC98A3E,
  ];

  final String name;
  final bool sparkling;
  final int color;

  @override
  bool operator ==(Object other) =>
      other is MocktailCustomBase &&
      other.name == name &&
      other.sparkling == sparkling &&
      other.color == color;

  @override
  int get hashCode => Object.hash(name, sparkling, color);
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

/// Satu sirup di resep. Secara bawaan takarannya otomatis: [parts] adalah
/// bagian relatif dari total sirup menurut tingkat manis. Bila [ml] diisi,
/// itulah takaran tepat (ml per gelas) dan [parts] tidak dipakai.
@immutable
class MocktailSyrup {
  const MocktailSyrup(this.name, {this.parts = 1, this.ml});

  final String name;
  final int parts;
  final double? ml;

  MocktailSyrup copyWith({int? parts, double? ml, bool clearMl = false}) =>
      MocktailSyrup(
        name,
        parts: parts ?? this.parts,
        ml: clearMl ? null : (ml ?? this.ml),
      );

  /// Takaran ml berlaku untuk semua sirup atau tidak sama sekali; campuran
  /// (mis. data lama atau rusak) dikembalikan ke otomatis.
  static List<MocktailSyrup> normalized(List<MocktailSyrup> syrups) =>
      syrups.every((MocktailSyrup s) => s.ml != null)
      ? syrups
      : <MocktailSyrup>[
          for (final MocktailSyrup s in syrups) s.copyWith(clearMl: true),
        ];

  @override
  bool operator ==(Object other) =>
      other is MocktailSyrup &&
      other.name == name &&
      other.parts == parts &&
      other.ml == ml;

  @override
  int get hashCode => Object.hash(name, parts, ml);
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
    this.customGarnishes = const <String>{},
    this.customBase,
  });

  static const int minServings = 1;
  static const int maxServings = 12;
  static const int minGlassMl = 100;
  static const int maxGlassMl = 600;
  static const int maxSyrups = 3;
  static const int minParts = 1;
  static const int maxParts = 4;

  /// Batas takaran sirup yang diisi sendiri (ml per gelas).
  static const double minSyrupMl = 0.5;
  static const double maxSyrupMl = 150;

  /// Sisa minimal bahan dasar (ml) agar minuman tidak hanya sirup.
  static const double minBaseMl = 20;

  /// Batas hiasan buatan sendiri: panjang nama dan jumlah yang tersimpan.
  static const int maxGarnishNameLength = 20;
  static const int maxSavedGarnishes = 10;

  final int servings;

  /// Volume gelas per porsi (ml), termasuk es.
  final int glassMl;
  final MocktailBase base;

  /// Bila diisi, bahan dasar buatan sendiri ini dipakai menggantikan [base].
  final MocktailCustomBase? customBase;
  final MocktailSweetness sweetness;
  final MocktailMethod method;
  final bool useIce;

  /// Perasan jeruk nipis/lemon untuk menyeimbangkan manis.
  final bool useCitrus;
  final List<MocktailSyrup> syrups;
  final Set<MocktailGarnish> garnishes;

  /// Hiasan buatan sendiri yang dipakai (nama), urutan pemilihan.
  final Set<String> customGarnishes;

  /// Semua hiasan yang dipakai: bawaan dulu, lalu buatan sendiri.
  List<String> get garnishNames => <String>[
    for (final MocktailGarnish g in MocktailGarnish.values)
      if (garnishes.contains(g)) g.label,
    ...customGarnishes,
  ];

  /// Nama bahan dasar yang dipilih (preset atau buatan sendiri).
  String get baseLabel => customBase?.name ?? base.label;

  /// Nama bahan dasar di daftar takaran.
  String get baseIngredient => customBase?.name ?? base.ingredient;

  /// Bahan dasar berkarbonasi: dituang perlahan dan bergelembung.
  bool get baseSparkling => customBase?.sparkling ?? base.sparkling;

  /// `true` bila [value] (preset) adalah bahan dasar yang dipilih.
  bool isBase(MocktailBase value) => customBase == null && base == value;

  /// `true` bila semua sirup memakai takaran ml sendiri.
  bool get customMl =>
      syrups.isNotEmpty && syrups.every((MocktailSyrup s) => s.ml != null);

  @override
  bool operator ==(Object other) =>
      other is MocktailSpec &&
      other.servings == servings &&
      other.glassMl == glassMl &&
      other.base == base &&
      other.customBase == customBase &&
      other.sweetness == sweetness &&
      other.method == method &&
      other.useIce == useIce &&
      other.useCitrus == useCitrus &&
      listEquals(other.syrups, syrups) &&
      setEquals(other.garnishes, garnishes) &&
      setEquals(other.customGarnishes, customGarnishes);

  @override
  int get hashCode => Object.hash(
    servings,
    glassMl,
    base,
    customBase,
    sweetness,
    method,
    useIce,
    useCitrus,
    Object.hashAll(syrups),
    Object.hashAllUnordered(garnishes),
    Object.hashAllUnordered(customGarnishes),
  );

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
    Set<String>? customGarnishes,
    MocktailCustomBase? customBase,
    bool clearCustomBase = false,
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
    customGarnishes: customGarnishes ?? this.customGarnishes,
    customBase: clearCustomBase ? null : (customBase ?? this.customBase),
  );
}

/// Jenis bahan di hasil hitungan.
enum MocktailIngredientKind { syrup, citrus, base, ice }

/// Satu bahan di hasil hitungan, dengan takaran per porsi.
@immutable
class MocktailIngredient {
  const MocktailIngredient({
    required this.kind,
    required this.name,
    required this.perServing,
    required this.unit,
    this.color,
  });

  final MocktailIngredientKind kind;
  final String name;
  final double perServing;

  /// "ml" atau "g".
  final String unit;
  final int? color;
}

/// Jenis langkah; menentukan bagian animasi gelas yang diputar.
enum MocktailStepKind {
  /// Shaker: bahan dimasukkan.
  mixIn,

  /// Shaker: dikocok.
  shake,

  /// Shaker: disaring ke gelas (es, sirup, dan jeruk nipis masuk gelas).
  strain,
  ice,
  syrup,
  citrus,

  /// Mengaduk dengan sendok bar.
  stir,
  base,
  garnish,
}

/// Satu langkah pembuatan untuk satu gelas. [durationSeconds] adalah takaran
/// waktu yang disarankan; timer pindah otomatis ke langkah berikutnya.
@immutable
class MocktailStep {
  const MocktailStep({
    required this.kind,
    required this.title,
    required this.text,
    required this.durationSeconds,
  });

  final MocktailStepKind kind;
  final String title;
  final String text;
  final int durationSeconds;
}

/// Hasil hitungan: bahan per porsi dan langkah pembuatan.
@immutable
class MocktailBlend {
  const MocktailBlend({
    required this.spec,
    required this.ingredients,
    required this.stepDetails,
    required this.liquidMl,
    required this.syrupMl,
  });

  final MocktailSpec spec;
  final List<MocktailIngredient> ingredients;

  /// Langkah untuk membuat satu gelas.
  final List<MocktailStep> stepDetails;

  /// Total durasi satu gelas (detik).
  int get totalSeconds => stepDetails.fold<int>(
    0,
    (int sum, MocktailStep s) => sum + s.durationSeconds,
  );

  /// Waktu mulai langkah ke-[index] dalam satu gelas.
  Duration stepStartOf(int index) => Duration(
    seconds: stepDetails
        .take(index)
        .fold<int>(0, (int sum, MocktailStep s) => sum + s.durationSeconds),
  );

  /// Indeks langkah pada waktu [elapsed]; langkah terakhir bila sudah lewat.
  int stepIndexAt(Duration elapsed) {
    int start = 0;
    for (int i = 0; i < stepDetails.length; i++) {
      start += stepDetails[i].durationSeconds * 1000;
      if (elapsed.inMilliseconds < start) {
        return i;
      }
    }
    return stepDetails.length - 1;
  }

  /// Teks langkah untuk kartu hasil; ditambah catatan bila lebih dari satu
  /// porsi.
  List<String> get steps => <String>[
    for (final MocktailStep s in stepDetails) s.text,
    if (spec.servings > 1)
      'Ulangi untuk ${spec.servings} porsi, atau kalikan takaran di atas '
          'bila memakai pitcher.',
  ];

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
    return '${spec.baseLabel} · $n sirup · ${spec.glassMl} ml';
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
