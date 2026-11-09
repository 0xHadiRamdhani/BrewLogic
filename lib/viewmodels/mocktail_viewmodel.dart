import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../core/utils/formatters.dart';
import '../models/mocktail_model.dart';
import '../services/journal_repository.dart';
import '../services/mocktail_service.dart';

/// ViewModel pembuat mocktail: menyimpan masukan, menghitung takaran, dan
/// mengingat apakah tab Kalkulator sedang di mode Mocktail.
class MocktailViewModel extends ChangeNotifier {
  MocktailViewModel({
    required this._repository,
    this._service = const MocktailService(),
  }) {
    _active = _repository.readInt(_modeKey, fallback: 0) == 1;
    _customBases = _loadCustomBases();
    _customGarnishes = _repository
        .readStringList(_customGarnishesKey)
        .where((String s) => s.trim().isNotEmpty)
        .take(MocktailSpec.maxSavedGarnishes)
        .toList();
    _recalculate();
  }

  static const String _modeKey = 'calcMode';
  static const String _customBasesKey = 'mocktailCustomBases';
  static const String _customGarnishesKey = 'mocktailCustomGarnishes';
  static const int maxSyrupNameLength = 20;

  /// Takaran awal sirup baru saat mode ml sendiri aktif.
  static const double defaultNewSyrupMl = 10;

  /// Resep awal: soda dengan grenadine, jeruk nipis, dan es.
  static const MocktailSpec defaultSpec = MocktailSpec(
    syrups: <MocktailSyrup>[MocktailSyrup('Grenadine')],
    garnishes: <MocktailGarnish>{MocktailGarnish.limeWheel},
  );

  final JournalRepository _repository;
  final MocktailService _service;

  late bool _active;
  late List<MocktailCustomBase> _customBases;
  late List<String> _customGarnishes;
  MocktailSpec _spec = defaultSpec;
  MocktailBlend? _blend;

  /// `true` bila tab Kalkulator menampilkan pembuat mocktail.
  bool get isActive => _active;
  MocktailSpec get spec => _spec;

  /// Hasil hitungan, atau `null` bila belum valid (mis. belum ada sirup).
  MocktailBlend? get blend => _blend;

  /// `true` bila porsi, es, jeruk nipis, atau hiasan berbeda dari bawaan.
  bool get adjusted =>
      _spec.servings != defaultSpec.servings ||
      _spec.useIce != defaultSpec.useIce ||
      _spec.useCitrus != defaultSpec.useCitrus ||
      !setEquals(_spec.garnishes, defaultSpec.garnishes) ||
      _spec.customGarnishes.isNotEmpty;

  /// Pesan petunjuk saat [blend] belum bisa dihitung.
  String? get problem => _service.validate(_spec);

  Future<void> setActive({required bool value}) async {
    if (_active == value) {
      return;
    }
    _active = value;
    notifyListeners();
    await _repository.writeInt(_modeKey, value: value ? 1 : 0);
  }

  void _update(MocktailSpec next) {
    _spec = next;
    _recalculate();
    notifyListeners();
  }

  void _recalculate() => _blend = _service.calculate(_spec);

  void setServings(int value) => _update(
    _spec.copyWith(
      servings: value.clamp(MocktailSpec.minServings, MocktailSpec.maxServings),
    ),
  );

  void setGlassMl(int value) => _update(
    _spec.copyWith(
      glassMl: value.clamp(MocktailSpec.minGlassMl, MocktailSpec.maxGlassMl),
    ),
  );

  /// Memilih bahan dasar preset (menggantikan bahan buatan sendiri).
  void setBase(MocktailBase value) =>
      _update(_spec.copyWith(base: value, clearCustomBase: true));

  // --- Bahan dasar buatan sendiri -----------------------------------------

  /// Bahan dasar buatan sendiri yang tersimpan, urutan penambahan.
  List<MocktailCustomBase> get customBases =>
      List<MocktailCustomBase>.unmodifiable(_customBases);

  bool get canAddCustomBase =>
      _customBases.length < MocktailCustomBase.maxSaved;

  bool isCustomBaseSelected(MocktailCustomBase base) =>
      _spec.customBase?.name.toLowerCase() == base.name.toLowerCase();

  List<MocktailCustomBase> _loadCustomBases() {
    final List<MocktailCustomBase> out = <MocktailCustomBase>[];
    for (final String raw in _repository.readStringList(_customBasesKey)) {
      try {
        final Object? json = jsonDecode(raw);
        if (json is! Map<String, Object?>) {
          continue;
        }
        final Object? name = json['n'];
        if (name is! String || name.trim().isEmpty) {
          continue;
        }
        out.add(
          MocktailCustomBase(
            name.trim(),
            sparkling: json['s'] is bool && json['s']! as bool,
            color: json['c'] is int
                ? json['c']! as int
                : MocktailCustomBase.defaultColor,
          ),
        );
      } catch (_) {
        continue;
      }
    }
    return out;
  }

  Future<void> _saveCustomBases() =>
      _repository.writeStringList(_customBasesKey, <String>[
        for (final MocktailCustomBase b in _customBases)
          jsonEncode(<String, Object>{
            'n': b.name,
            's': b.sparkling,
            'c': b.color,
          }),
      ]);

  /// Pesan error untuk nama bahan dasar baru, atau `null` jika valid.
  String? validateBaseName(String? raw) {
    final String name = (raw ?? '').trim();
    if (name.isEmpty) {
      return 'Nama bahan wajib diisi';
    }
    if (name.length > MocktailCustomBase.maxNameLength) {
      return 'Maksimal ${MocktailCustomBase.maxNameLength} karakter';
    }
    final String lower = name.toLowerCase();
    final bool taken =
        MocktailBase.values.any(
          (MocktailBase b) => b.label.toLowerCase() == lower,
        ) ||
        _customBases.any(
          (MocktailCustomBase b) => b.name.toLowerCase() == lower,
        );
    return taken ? 'Bahan sudah ada' : null;
  }

  /// Menyimpan bahan dasar baru dan langsung memilihnya. Mengembalikan pesan
  /// error, atau `null` jika berhasil.
  Future<String?> addCustomBase(MocktailCustomBase base) async {
    final String? invalid = validateBaseName(base.name);
    if (invalid != null) {
      return invalid;
    }
    if (!canAddCustomBase) {
      return 'Maksimal ${MocktailCustomBase.maxSaved} bahan buatan. '
          'Tahan sebuah bahan untuk menghapusnya.';
    }
    final MocktailCustomBase clean = MocktailCustomBase(
      base.name.trim(),
      sparkling: base.sparkling,
      color: base.color,
    );
    _customBases = <MocktailCustomBase>[..._customBases, clean];
    _update(_spec.copyWith(customBase: clean));
    await _saveCustomBases();
    return null;
  }

  void selectCustomBase(MocktailCustomBase base) =>
      _update(_spec.copyWith(customBase: base));

  /// Menghapus bahan buatan; bila sedang dipilih, kembali ke bahan preset.
  Future<void> removeCustomBase(String name) async {
    final String lower = name.toLowerCase();
    _customBases = <MocktailCustomBase>[
      for (final MocktailCustomBase b in _customBases)
        if (b.name.toLowerCase() != lower) b,
    ];
    if (_spec.customBase?.name.toLowerCase() == lower) {
      _update(_spec.copyWith(clearCustomBase: true));
    } else {
      notifyListeners();
    }
    await _saveCustomBases();
  }

  void setSweetness(MocktailSweetness value) =>
      _update(_spec.copyWith(sweetness: value));

  void setMethod(MocktailMethod value) =>
      _update(_spec.copyWith(method: value));

  void setUseIce({required bool value}) =>
      _update(_spec.copyWith(useIce: value));

  void setUseCitrus({required bool value}) =>
      _update(_spec.copyWith(useCitrus: value));

  bool hasSyrup(String name) => _spec.syrups.any(
    (MocktailSyrup s) => s.name.toLowerCase() == name.toLowerCase(),
  );

  bool get canAddSyrup => _spec.syrups.length < MocktailSpec.maxSyrups;

  /// Menambah sirup bila belum ada, atau melepasnya bila sudah dipilih.
  /// Mengembalikan `false` bila batas jumlah sirup tercapai.
  bool toggleSyrup(String name) {
    final String clean = name.trim();
    if (clean.isEmpty) {
      return false;
    }
    if (hasSyrup(clean)) {
      _update(
        _spec.copyWith(
          syrups: <MocktailSyrup>[
            for (final MocktailSyrup s in _spec.syrups)
              if (s.name.toLowerCase() != clean.toLowerCase()) s,
          ],
        ),
      );
      return true;
    }
    if (!canAddSyrup) {
      return false;
    }
    _update(
      _spec.copyWith(
        syrups: <MocktailSyrup>[
          ..._spec.syrups,
          MocktailSyrup(clean, ml: _spec.customMl ? defaultNewSyrupMl : null),
        ],
      ),
    );
    return true;
  }

  /// Pesan error untuk nama sirup buatan sendiri, atau `null` jika valid.
  String? validateSyrupName(String? raw) {
    final String name = (raw ?? '').trim();
    if (name.isEmpty) {
      return 'Nama sirup wajib diisi';
    }
    if (name.length > maxSyrupNameLength) {
      return 'Maksimal $maxSyrupNameLength karakter';
    }
    return hasSyrup(name) ? 'Sirup sudah dipilih' : null;
  }

  /// Beralih antara takaran otomatis (bagian + tingkat manis) dan takaran ml
  /// sendiri. Saat beralih ke ml sendiri, takaran awal diambil dari hitungan
  /// otomatis saat ini agar tidak melompat.
  void setSyrupMode({required bool custom}) {
    if (_spec.syrups.isEmpty || _spec.customMl == custom) {
      return;
    }
    if (!custom) {
      _update(
        _spec.copyWith(
          syrups: <MocktailSyrup>[
            for (final MocktailSyrup s in _spec.syrups)
              s.copyWith(clearMl: true),
          ],
        ),
      );
      return;
    }
    final List<double> auto = <double>[
      for (final MocktailIngredient i
          in _blend?.ingredients ?? const <MocktailIngredient>[])
        if (i.kind == MocktailIngredientKind.syrup) i.perServing,
    ];
    _update(
      _spec.copyWith(
        syrups: <MocktailSyrup>[
          for (int i = 0; i < _spec.syrups.length; i++)
            _spec.syrups[i].copyWith(
              ml: i < auto.length && auto.length == _spec.syrups.length
                  ? auto[i]
                  : defaultNewSyrupMl,
            ),
        ],
      ),
    );
  }

  /// Pesan error untuk takaran sirup (ml) yang diketik, atau `null`.
  String? validateSyrupMl(String? raw) {
    final String text = (raw ?? '').trim().replaceAll(',', '.');
    if (text.isEmpty) {
      return 'Isi takaran';
    }
    final double? value = double.tryParse(text);
    if (value == null) {
      return 'Masukkan angka';
    }
    if (value < MocktailSpec.minSyrupMl || value > MocktailSpec.maxSyrupMl) {
      return '${formatGrams(MocktailSpec.minSyrupMl)}–'
          '${formatGrams(MocktailSpec.maxSyrupMl)} ml';
    }
    return null;
  }

  /// Mengatur takaran ml sirup ke-[index] (hanya di mode ml sendiri).
  void setSyrupMl(int index, double ml) {
    if (!_spec.customMl || index < 0 || index >= _spec.syrups.length) {
      return;
    }
    final List<MocktailSyrup> syrups = List<MocktailSyrup>.of(_spec.syrups);
    syrups[index] = syrups[index].copyWith(ml: ml);
    _update(_spec.copyWith(syrups: syrups));
  }

  /// Menambah atau mengurangi takaran ml sirup ke-[index] sebesar [delta],
  /// dijepit ke batas takaran sirup.
  void changeSyrupMl(int index, double delta) {
    if (!_spec.customMl || index < 0 || index >= _spec.syrups.length) {
      return;
    }
    final double current = _spec.syrups[index].ml!;
    final double next = (current + delta).clamp(
      MocktailSpec.minSyrupMl,
      MocktailSpec.maxSyrupMl,
    );
    if (next != current) {
      setSyrupMl(index, next);
    }
  }

  /// Mengubah bagian relatif sirup ke-[index] sebesar [delta].
  void changeParts(int index, int delta) {
    if (index < 0 || index >= _spec.syrups.length) {
      return;
    }
    final MocktailSyrup current = _spec.syrups[index];
    final int next = (current.parts + delta).clamp(
      MocktailSpec.minParts,
      MocktailSpec.maxParts,
    );
    if (next == current.parts) {
      return;
    }
    final List<MocktailSyrup> syrups = List<MocktailSyrup>.of(_spec.syrups);
    syrups[index] = current.copyWith(parts: next);
    _update(_spec.copyWith(syrups: syrups));
  }

  /// Pesan error untuk ukuran gelas (ml), atau `null` jika valid.
  String? validateGlassMl(String? raw) {
    final String text = (raw ?? '').trim();
    if (text.isEmpty) {
      return 'Ukuran gelas wajib diisi';
    }
    final int? value = int.tryParse(text);
    if (value == null) {
      return 'Masukkan angka bulat';
    }
    if (value < MocktailSpec.minGlassMl || value > MocktailSpec.maxGlassMl) {
      return 'Ukuran gelas ${MocktailSpec.minGlassMl}–'
          '${MocktailSpec.maxGlassMl} ml';
    }
    return null;
  }

  /// Mengembalikan porsi, es, jeruk nipis, dan hiasan ke bawaan; bahan dasar
  /// dan sirup tetap.
  void resetAdjustments() => _update(
    _spec.copyWith(
      servings: defaultSpec.servings,
      useIce: defaultSpec.useIce,
      useCitrus: defaultSpec.useCitrus,
      garnishes: defaultSpec.garnishes,
      customGarnishes: const <String>{},
    ),
  );

  void toggleGarnish(MocktailGarnish garnish) {
    final Set<MocktailGarnish> next = Set<MocktailGarnish>.of(_spec.garnishes);
    if (!next.add(garnish)) {
      next.remove(garnish);
    }
    _update(_spec.copyWith(garnishes: next));
  }

  // --- Hiasan buatan sendiri ---------------------------------------------

  /// Hiasan buatan sendiri yang tersimpan, urutan penambahan.
  List<String> get customGarnishes =>
      List<String>.unmodifiable(_customGarnishes);

  bool get canAddCustomGarnish =>
      _customGarnishes.length < MocktailSpec.maxSavedGarnishes;

  bool isCustomGarnishSelected(String name) =>
      _spec.customGarnishes.contains(name);

  bool _hasCustomGarnish(String name) {
    final String lower = name.toLowerCase();
    return _customGarnishes.any((String g) => g.toLowerCase() == lower);
  }

  Future<void> _saveCustomGarnishes() =>
      _repository.writeStringList(_customGarnishesKey, _customGarnishes);

  /// Pesan error untuk nama hiasan baru, atau `null` jika valid.
  String? validateGarnishName(String? raw) {
    final String name = (raw ?? '').trim();
    if (name.isEmpty) {
      return 'Nama hiasan wajib diisi';
    }
    if (name.length > MocktailSpec.maxGarnishNameLength) {
      return 'Maksimal ${MocktailSpec.maxGarnishNameLength} karakter';
    }
    final String lower = name.toLowerCase();
    final bool taken =
        MocktailGarnish.values.any(
          (MocktailGarnish g) => g.label.toLowerCase() == lower,
        ) ||
        _hasCustomGarnish(name);
    return taken ? 'Hiasan sudah ada' : null;
  }

  /// Menyimpan hiasan baru dan langsung memakainya. Mengembalikan pesan
  /// error, atau `null` jika berhasil.
  Future<String?> addCustomGarnish(String raw) async {
    final String? invalid = validateGarnishName(raw);
    if (invalid != null) {
      return invalid;
    }
    if (!canAddCustomGarnish) {
      return 'Maksimal ${MocktailSpec.maxSavedGarnishes} hiasan buatan. '
          'Tahan sebuah hiasan untuk menghapusnya.';
    }
    final String name = raw.trim();
    _customGarnishes = <String>[..._customGarnishes, name];
    _update(
      _spec.copyWith(customGarnishes: <String>{..._spec.customGarnishes, name}),
    );
    await _saveCustomGarnishes();
    return null;
  }

  void toggleCustomGarnish(String name) {
    final Set<String> next = Set<String>.of(_spec.customGarnishes);
    if (!next.add(name)) {
      next.remove(name);
    }
    _update(_spec.copyWith(customGarnishes: next));
  }

  /// Menghapus hiasan buatan dari daftar; juga dilepas dari resep aktif.
  Future<void> removeCustomGarnish(String name) async {
    _customGarnishes = <String>[
      for (final String g in _customGarnishes)
        if (g != name) g,
    ];
    if (_spec.customGarnishes.contains(name)) {
      _update(
        _spec.copyWith(
          customGarnishes: <String>{
            for (final String g in _spec.customGarnishes)
              if (g != name) g,
          },
        ),
      );
    } else {
      notifyListeners();
    }
    await _saveCustomGarnishes();
  }

  /// Memuat resep tersimpan ke pembuat mocktail.
  void applyRecipe(MocktailRecipe recipe) {
    // Hiasan buatan dari resep ikut tersimpan agar tetap bisa dipilih.
    final List<String> missing = <String>[
      for (final String g in recipe.spec.customGarnishes)
        if (!_hasCustomGarnish(g)) g,
    ];
    final int room = MocktailSpec.maxSavedGarnishes - _customGarnishes.length;
    if (missing.isNotEmpty && room > 0) {
      _customGarnishes = <String>[..._customGarnishes, ...missing.take(room)];
      unawaited(_saveCustomGarnishes());
    }
    final MocktailCustomBase? base = recipe.spec.customBase;
    // Bahan buatan dari resep ikut tersimpan agar tetap bisa dipilih.
    if (base != null &&
        canAddCustomBase &&
        !_customBases.any(
          (MocktailCustomBase b) =>
              b.name.toLowerCase() == base.name.toLowerCase(),
        )) {
      _customBases = <MocktailCustomBase>[..._customBases, base];
      unawaited(_saveCustomBases());
    }
    _update(recipe.spec);
  }

  void reset() => _update(defaultSpec);
}
