import 'dart:convert';

import '../models/brew_model.dart';
import '../models/mocktail_model.dart';

/// File cadangan tidak valid atau berasal dari versi yang lebih baru.
class BackupException implements Exception {
  const BackupException(this.message);

  final String message;

  @override
  String toString() => 'BackupException: $message';
}

/// Isi cadangan hasil baca. [skipped] = item yang rusak dan dilewati.
class BackupData {
  const BackupData({
    required this.entries,
    required this.recipes,
    required this.beans,
    this.mocktails = const <MocktailRecipe>[],
    this.skipped = 0,
  });

  final List<BrewEntry> entries;
  final List<BrewRecipe> recipes;
  final List<BrewBean> beans;

  /// Resep mocktail; kosong pada cadangan lama yang belum memuatnya.
  final List<MocktailRecipe> mocktails;
  final int skipped;

  int get total =>
      entries.length + recipes.length + beans.length + mocktails.length;
}

/// Mengubah data jurnal, resep, dan biji menjadi JSON/CSV dan sebaliknya.
/// Murni, tanpa Flutter dan tanpa akses berkas. Foto tidak ikut dicadangkan.
class BackupService {
  const BackupService();

  static const String appId = 'BrewLogic';
  static const int formatVersion = 1;

  static const int _maxNotes = 500;
  static const int _maxGrinder = 24;
  static const int _maxName = 40;

  // --- JSON -----------------------------------------------------------------

  String encodeJson({
    required List<BrewEntry> entries,
    required List<BrewRecipe> recipes,
    required List<BrewBean> beans,
    required DateTime now,
    List<MocktailRecipe> mocktails = const <MocktailRecipe>[],
  }) {
    final Map<String, Object?> root = <String, Object?>{
      'app': appId,
      'version': formatVersion,
      'exportedAt': now.toUtc().toIso8601String(),
      'entries': entries.map(_entryToJson).toList(),
      'recipes': recipes.map(_recipeToJson).toList(),
      'beans': beans.map(_beanToJson).toList(),
      'mocktails': mocktails.map(_mocktailToJson).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(root);
  }

  /// Membaca cadangan. Melempar [BackupException] bila bukan cadangan
  /// BrewLogic yang valid; item individual yang rusak dilewati.
  BackupData decodeJson(String source) {
    final Object? root;
    try {
      root = jsonDecode(source);
    } on FormatException {
      throw const BackupException('Berkas bukan JSON yang valid.');
    }
    if (root is! Map<String, Object?> || root['app'] != appId) {
      throw const BackupException('Berkas ini bukan cadangan BrewLogic.');
    }
    final Object? version = root['version'];
    if (version is! int || version < 1) {
      throw const BackupException('Versi cadangan tidak dikenali.');
    }
    if (version > formatVersion) {
      throw const BackupException(
        'Cadangan dibuat oleh versi BrewLogic yang lebih baru. Perbarui '
        'aplikasi terlebih dahulu.',
      );
    }

    int skipped = 0;
    List<T> parse<T>(Object? raw, T? Function(Map<String, Object?>) read) {
      final List<T> out = <T>[];
      if (raw is! List<Object?>) {
        return out;
      }
      for (final Object? item in raw) {
        T? value;
        try {
          value = item is Map<String, Object?> ? read(item) : null;
        } catch (_) {
          value = null;
        }
        if (value == null) {
          skipped++;
        } else {
          out.add(value);
        }
      }
      return out;
    }

    return BackupData(
      entries: parse<BrewEntry>(root['entries'], _entryFromJson),
      recipes: parse<BrewRecipe>(root['recipes'], _recipeFromJson),
      beans: parse<BrewBean>(root['beans'], _beanFromJson),
      mocktails: parse<MocktailRecipe>(root['mocktails'], _mocktailFromJson),
      skipped: skipped,
    );
  }

  // --- CSV ------------------------------------------------------------------

  String encodeCsv(List<BrewEntry> entries) {
    const List<String> header = <String>[
      'Tanggal',
      'Metode',
      'Roast',
      'Kopi (g)',
      'Air (ml)',
      'Rasio',
      'Durasi (detik)',
      'Rating',
      'Kesan rasa',
      'Tag rasa',
      'Setelan gilingan',
      'Biji',
      'Catatan',
    ];
    final StringBuffer out = StringBuffer(header.map(_csvCell).join(','));
    for (final BrewEntry e in entries) {
      out
        ..write('\n')
        ..write(
          <String>[
            e.createdAt.toIso8601String(),
            e.method.label,
            e.roast.label,
            _num(e.coffeeGrams),
            _num(e.waterGrams),
            '1:${_num((e.ratio * 10).round() / 10)}',
            '${e.brewSeconds}',
            '${e.rating}',
            e.taste?.label ?? '',
            e.flavorTags.map((FlavorTag t) => t.label).join('; '),
            e.grinderSetting,
            e.beanName ?? '',
            e.tastingNotes,
          ].map(_csvCell).join(','),
        );
    }
    return out.toString();
  }

  static String _num(double v) =>
      v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  /// Mengutip sel CSV dan menetralkan sel yang diawali rumus agar tidak
  /// dieksekusi saat dibuka di aplikasi spreadsheet (CSV injection).
  static String _csvCell(String raw) {
    String value = raw;
    if (value.isNotEmpty && '=+-@\t\r'.contains(value[0])) {
      value = "'$value";
    }
    final bool needsQuotes =
        value.contains(',') ||
        value.contains('"') ||
        value.contains('\n') ||
        value.contains('\r');
    return needsQuotes ? '"${value.replaceAll('"', '""')}"' : value;
  }

  // --- Pemetaan item --------------------------------------------------------

  static Map<String, Object?> _entryToJson(BrewEntry e) => <String, Object?>{
    'id': e.id,
    'createdAt': e.createdAt.millisecondsSinceEpoch,
    'coffeeGrams': e.coffeeGrams,
    'waterGrams': e.waterGrams,
    'method': e.method.name,
    'roast': e.roast.name,
    'rating': e.rating,
    'tastingNotes': e.tastingNotes,
    'brewSeconds': e.brewSeconds,
    'taste': e.taste?.name,
    'flavorTags': e.flavorTags.map((FlavorTag t) => t.name).toList(),
    'grinderSetting': e.grinderSetting,
    'beanId': e.beanId,
    'beanName': e.beanName,
  };

  static Map<String, Object?> _recipeToJson(BrewRecipe r) => <String, Object?>{
    'id': r.id,
    'name': r.name,
    'createdAt': r.createdAt.millisecondsSinceEpoch,
    'coffeeGrams': r.coffeeGrams,
    'method': r.method.name,
    'roast': r.roast.name,
    'ratio': r.customization.ratio,
    'bloomSeconds': r.customization.bloomSeconds,
    'firstPourSeconds': r.customization.firstPourSeconds,
    'secondPourSeconds': r.customization.secondPourSeconds,
  };

  static Map<String, Object?> _mocktailToJson(
    MocktailRecipe m,
  ) => <String, Object?>{
    'id': m.id,
    'name': m.name,
    'createdAt': m.createdAt.millisecondsSinceEpoch,
    'servings': m.spec.servings,
    'glassMl': m.spec.glassMl,
    'base': m.spec.base.name,
    if (m.spec.customBase != null)
      'customBase': <String, Object?>{
        'name': m.spec.customBase!.name,
        'sparkling': m.spec.customBase!.sparkling,
        'color': m.spec.customBase!.color,
      },
    'sweetness': m.spec.sweetness.name,
    'method': m.spec.method.name,
    'useIce': m.spec.useIce,
    'useCitrus': m.spec.useCitrus,
    'syrups': <Object?>[
      for (final MocktailSyrup s in m.spec.syrups)
        <String, Object?>{
          'name': s.name,
          'parts': s.parts,
          if (s.ml != null) 'ml': s.ml,
        },
    ],
    'garnishes': m.spec.garnishes.map((MocktailGarnish g) => g.name).toList(),
    if (m.spec.customGarnishes.isNotEmpty)
      'customGarnishes': m.spec.customGarnishes.toList(),
  };

  static Map<String, Object?> _beanToJson(BrewBean b) => <String, Object?>{
    'id': b.id,
    'name': b.name,
    'roaster': b.roaster,
    'origin': b.origin,
    'roastDate': b.roastDate?.millisecondsSinceEpoch,
    'createdAt': b.createdAt.millisecondsSinceEpoch,
  };

  static BrewEntry? _entryFromJson(Map<String, Object?> j) {
    final String? id = _str(j['id']);
    final double? coffee = _positive(j['coffeeGrams']);
    final double? water = _positive(j['waterGrams']);
    final BrewMethod? method = _enum(BrewMethod.values, j['method']);
    final RoastLevel? roast = _enum(RoastLevel.values, j['roast']);
    final int? createdAt = _int(j['createdAt']);
    final int? rating = _int(j['rating']);
    if (id == null ||
        coffee == null ||
        water == null ||
        method == null ||
        roast == null ||
        createdAt == null ||
        rating == null) {
      return null;
    }
    return BrewEntry(
      id: id,
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdAt),
      coffeeGrams: coffee,
      waterGrams: water,
      method: method,
      roast: roast,
      rating: rating.clamp(1, 5),
      tastingNotes: _cut(_str(j['tastingNotes']) ?? '', _maxNotes),
      brewSeconds: (_int(j['brewSeconds']) ?? 0).clamp(0, 86400),
      taste: _enum(TasteFeedback.values, j['taste']),
      flavorTags: <FlavorTag>[
        for (final Object? n
            in (j['flavorTags'] as List<Object?>? ?? <Object?>[]))
          ?_enum(FlavorTag.values, n),
      ],
      grinderSetting: _cut(_str(j['grinderSetting']) ?? '', _maxGrinder),
      beanId: _str(j['beanId']),
      beanName: _str(j['beanName']) == null
          ? null
          : _cut(_str(j['beanName'])!, _maxName),
    );
  }

  static BrewRecipe? _recipeFromJson(Map<String, Object?> j) {
    final String? id = _str(j['id']);
    final String? name = _str(j['name']);
    final double? coffee = _positive(j['coffeeGrams']);
    final BrewMethod? method = _enum(BrewMethod.values, j['method']);
    final RoastLevel? roast = _enum(RoastLevel.values, j['roast']);
    final int? createdAt = _int(j['createdAt']);
    if (id == null ||
        name == null ||
        coffee == null ||
        method == null ||
        roast == null ||
        createdAt == null) {
      return null;
    }
    return BrewRecipe(
      id: id,
      name: _cut(name, _maxName),
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdAt),
      coffeeGrams: coffee,
      method: method,
      roast: roast,
      customization: BrewCustomization(
        ratio: _positive(j['ratio']),
        bloomSeconds: _int(j['bloomSeconds']),
        firstPourSeconds: _int(j['firstPourSeconds']),
        secondPourSeconds: _int(j['secondPourSeconds']),
      ),
    );
  }

  static MocktailCustomBase? _customBaseFromJson(Object? raw) {
    if (raw is! Map<String, Object?>) {
      return null;
    }
    final String? name = _str(raw['name']);
    if (name == null) {
      return null;
    }
    return MocktailCustomBase(
      _cut(name.trim(), MocktailCustomBase.maxNameLength),
      sparkling: raw['sparkling'] is bool && raw['sparkling']! as bool,
      color: _int(raw['color']) ?? MocktailCustomBase.defaultColor,
    );
  }

  static MocktailRecipe? _mocktailFromJson(Map<String, Object?> j) {
    final String? id = _str(j['id']);
    final String? name = _str(j['name']);
    final int? createdAt = _int(j['createdAt']);
    final Object? rawSyrups = j['syrups'];
    if (id == null ||
        name == null ||
        createdAt == null ||
        rawSyrups is! List<Object?>) {
      return null;
    }
    final List<MocktailSyrup> syrups = <MocktailSyrup>[];
    for (final Object? item in rawSyrups) {
      if (item is! Map<String, Object?>) {
        continue;
      }
      final String? syrupName = _str(item['name']);
      if (syrupName == null || syrups.length >= MocktailSpec.maxSyrups) {
        continue;
      }
      syrups.add(
        MocktailSyrup(
          _cut(syrupName, 20),
          parts: (_int(item['parts']) ?? 1).clamp(
            MocktailSpec.minParts,
            MocktailSpec.maxParts,
          ),
          ml: _positive(item['ml'])
              ?.clamp(MocktailSpec.minSyrupMl, MocktailSpec.maxSyrupMl),
        ),
      );
    }
    if (syrups.isEmpty) {
      return null;
    }
    final Object? rawGarnishes = j['garnishes'];
    final Object? rawCustomGarnishes = j['customGarnishes'];
    return MocktailRecipe(
      id: id,
      name: _cut(name, _maxName),
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdAt),
      spec: MocktailSpec(
        servings: (_int(j['servings']) ?? 1).clamp(
          MocktailSpec.minServings,
          MocktailSpec.maxServings,
        ),
        glassMl: (_int(j['glassMl']) ?? 300).clamp(
          MocktailSpec.minGlassMl,
          MocktailSpec.maxGlassMl,
        ),
        base: _enum(MocktailBase.values, j['base']) ?? MocktailBase.soda,
        customBase: _customBaseFromJson(j['customBase']),
        sweetness:
            _enum(MocktailSweetness.values, j['sweetness']) ??
            MocktailSweetness.normal,
        method:
            _enum(MocktailMethod.values, j['method']) ?? MocktailMethod.build,
        useIce: j['useIce'] is bool ? j['useIce']! as bool : true,
        useCitrus: j['useCitrus'] is bool ? j['useCitrus']! as bool : true,
        syrups: MocktailSyrup.normalized(syrups),
        garnishes: <MocktailGarnish>{
          if (rawGarnishes is List<Object?>)
            for (final Object? g in rawGarnishes)
              ?_enum(MocktailGarnish.values, g),
        },
        customGarnishes: <String>{
          if (rawCustomGarnishes is List<Object?>)
            for (final Object? g in rawCustomGarnishes.take(
              MocktailSpec.maxSavedGarnishes,
            ))
              if (_str(g) case final String name)
                _cut(name.trim(), MocktailSpec.maxGarnishNameLength),
        },
      ),
    );
  }

  static BrewBean? _beanFromJson(Map<String, Object?> j) {
    final String? id = _str(j['id']);
    final String? name = _str(j['name']);
    final int? createdAt = _int(j['createdAt']);
    if (id == null || name == null || createdAt == null) {
      return null;
    }
    final int? roast = _int(j['roastDate']);
    return BrewBean(
      id: id,
      name: _cut(name, _maxName),
      roaster: _cut(_str(j['roaster']) ?? '', _maxName),
      origin: _cut(_str(j['origin']) ?? '', _maxName),
      roastDate: roast == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(roast),
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdAt),
    );
  }

  static String? _str(Object? v) =>
      v is String && v.trim().isNotEmpty ? v : null;

  static int? _int(Object? v) => v is num && v.isFinite ? v.toInt() : null;

  static double? _positive(Object? v) =>
      v is num && v.isFinite && v > 0 ? v.toDouble() : null;

  static String _cut(String s, int max) =>
      s.length > max ? s.substring(0, max) : s;

  static T? _enum<T extends Enum>(List<T> values, Object? name) {
    if (name is! String) {
      return null;
    }
    for (final T v in values) {
      if (v.name == name) {
        return v;
      }
    }
    return null;
  }
}
