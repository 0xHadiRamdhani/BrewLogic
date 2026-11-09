import 'package:flutter/foundation.dart';

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
    _recalculate();
  }

  static const String _modeKey = 'calcMode';
  static const int maxSyrupNameLength = 20;

  /// Resep awal: soda dengan grenadine, jeruk nipis, dan es.
  static const MocktailSpec defaultSpec = MocktailSpec(
    syrups: <MocktailSyrup>[MocktailSyrup('Grenadine')],
    garnishes: <MocktailGarnish>{MocktailGarnish.limeWheel},
  );

  final JournalRepository _repository;
  final MocktailService _service;

  late bool _active;
  MocktailSpec _spec = defaultSpec;
  MocktailBlend? _blend;

  /// `true` bila tab Kalkulator menampilkan pembuat mocktail.
  bool get isActive => _active;
  MocktailSpec get spec => _spec;

  /// Hasil hitungan, atau `null` bila belum valid (mis. belum ada sirup).
  MocktailBlend? get blend => _blend;

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

  void setBase(MocktailBase value) => _update(_spec.copyWith(base: value));

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
        syrups: <MocktailSyrup>[..._spec.syrups, MocktailSyrup(clean)],
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

  void toggleGarnish(MocktailGarnish garnish) {
    final Set<MocktailGarnish> next = Set<MocktailGarnish>.of(_spec.garnishes);
    if (!next.add(garnish)) {
      next.remove(garnish);
    }
    _update(_spec.copyWith(garnishes: next));
  }

  /// Memuat resep tersimpan ke pembuat mocktail.
  void applyRecipe(MocktailRecipe recipe) => _update(recipe.spec);

  void reset() => _update(defaultSpec);
}
