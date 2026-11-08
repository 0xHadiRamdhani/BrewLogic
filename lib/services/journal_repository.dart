import 'package:hive_flutter/hive_flutter.dart';

import '../models/brew_adapters.dart';
import '../models/brew_model.dart';

/// Kegagalan akses penyimpanan lokal dengan pesan yang aman ditampilkan.
class StorageException implements Exception {
  const StorageException(this.message);

  final String message;

  @override
  String toString() => 'StorageException: $message';
}

/// Akses Hive untuk Brew Journal dan cache input terakhir pengguna.
class JournalRepository {
  JournalRepository._(
    this._journalBox,
    this._recipeBox,
    this._beanBox,
    this._cacheBox,
  );

  static const String _journalBoxName = 'brew_journal';
  static const String _recipeBoxName = 'brew_recipes';
  static const String _beanBoxName = 'brew_beans';
  static const String _cacheBoxName = 'brew_cache';

  final Box<BrewEntry> _journalBox;
  final Box<BrewRecipe> _recipeBox;
  final Box<BrewBean> _beanBox;
  final Box<dynamic> _cacheBox;

  /// Inisialisasi Hive, daftarkan adapter, dan buka box. Jika file box rusak,
  /// box dibuat ulang agar aplikasi tetap bisa dibuka.
  ///
  /// [path] hanya untuk pengujian; di aplikasi biarkan kosong agar Hive
  /// memakai direktori dokumen aplikasi.
  static Future<JournalRepository> open({String? path}) async {
    if (path == null) {
      await Hive.initFlutter();
    } else {
      Hive.init(path);
    }
    registerBrewAdapters();
    final Box<BrewEntry> journal = await _openSafely<BrewEntry>(
      _journalBoxName,
    );
    final Box<BrewRecipe> recipes = await _openSafely<BrewRecipe>(
      _recipeBoxName,
    );
    final Box<BrewBean> beans = await _openSafely<BrewBean>(_beanBoxName);
    final Box<dynamic> cache = await _openSafely<dynamic>(_cacheBoxName);
    return JournalRepository._(journal, recipes, beans, cache);
  }

  static Future<Box<T>> _openSafely<T>(String name) async {
    try {
      return await Hive.openBox<T>(name);
    } catch (_) {
      await Hive.deleteBoxFromDisk(name);
      return Hive.openBox<T>(name);
    }
  }

  /// Semua catatan, terbaru di atas.
  List<BrewEntry> getAll() {
    final List<BrewEntry> entries = _journalBox.values.toList()
      ..sort((BrewEntry a, BrewEntry b) => b.createdAt.compareTo(a.createdAt));
    return entries;
  }

  Future<void> save(BrewEntry entry) async {
    try {
      await _journalBox.put(entry.id, entry);
    } catch (_) {
      throw const StorageException('Gagal menyimpan catatan seduhan.');
    }
  }

  Future<void> delete(String id) async {
    try {
      await _journalBox.delete(id);
    } catch (_) {
      throw const StorageException('Gagal menghapus catatan seduhan.');
    }
  }

  // --- Resep favorit ----------------------------------------------------------

  /// Semua resep, terbaru di atas.
  List<BrewRecipe> getRecipes() {
    final List<BrewRecipe> recipes = _recipeBox.values.toList()
      ..sort(
        (BrewRecipe a, BrewRecipe b) => b.createdAt.compareTo(a.createdAt),
      );
    return recipes;
  }

  Future<void> saveRecipe(BrewRecipe recipe) async {
    try {
      await _recipeBox.put(recipe.id, recipe);
    } catch (_) {
      throw const StorageException('Gagal menyimpan resep.');
    }
  }

  Future<void> deleteRecipe(String id) async {
    try {
      await _recipeBox.delete(id);
    } catch (_) {
      throw const StorageException('Gagal menghapus resep.');
    }
  }

  // --- Biji kopi --------------------------------------------------------------

  /// Semua biji, terbaru di atas.
  List<BrewBean> getBeans() {
    final List<BrewBean> beans = _beanBox.values.toList()
      ..sort((BrewBean a, BrewBean b) => b.createdAt.compareTo(a.createdAt));
    return beans;
  }

  Future<void> saveBean(BrewBean bean) async {
    try {
      await _beanBox.put(bean.id, bean);
    } catch (_) {
      throw const StorageException('Gagal menyimpan biji.');
    }
  }

  Future<void> deleteBean(String id) async {
    try {
      await _beanBox.delete(id);
    } catch (_) {
      throw const StorageException('Gagal menghapus biji.');
    }
  }

  /// Id biji yang sedang dipilih di kalkulator.
  String? get activeBeanId => _cacheBox.get('activeBean') as String?;

  Future<void> setActiveBeanId(String? id) async {
    try {
      if (id == null) {
        await _cacheBox.delete('activeBean');
      } else {
        await _cacheBox.put('activeBean', id);
      }
    } catch (_) {
      return;
    }
  }

  /// Menghapus seluruh catatan jurnal.
  Future<void> clearJournal() async {
    try {
      await _journalBox.clear();
    } catch (_) {
      throw const StorageException('Gagal menghapus seluruh catatan.');
    }
  }

  // --- Pengaturan -----------------------------------------------------------

  bool get hapticsEnabled => (_cacheBox.get('haptics') as bool?) ?? true;

  Future<void> setHapticsEnabled({required bool value}) async {
    try {
      await _cacheBox.put('haptics', value);
    } catch (_) {
      return;
    }
  }

  // --- Cache input terakhir -------------------------------------------------

  String? get cachedGrams => _cacheBox.get('grams') as String?;

  BrewMethod? get cachedMethod {
    final Object? index = _cacheBox.get('method');
    return index is int && index >= 0 && index < BrewMethod.values.length
        ? BrewMethod.values[index]
        : null;
  }

  RoastLevel? get cachedRoast {
    final Object? index = _cacheBox.get('roast');
    return index is int && index >= 0 && index < RoastLevel.values.length
        ? RoastLevel.values[index]
        : null;
  }

  String? get cachedWater => _cacheBox.get('water') as String?;

  BrewInputMode? get cachedInputMode {
    final Object? index = _cacheBox.get('inputMode');
    return index is int && index >= 0 && index < BrewInputMode.values.length
        ? BrewInputMode.values[index]
        : null;
  }

  /// Penyesuaian terakhir (rasio dan durasi fase); kosong = bawaan metode.
  BrewCustomization get cachedCustomization {
    final Object? ratio = _cacheBox.get('cRatio');
    final Object? bloom = _cacheBox.get('cBloom');
    final Object? first = _cacheBox.get('cFirst');
    final Object? second = _cacheBox.get('cSecond');
    return BrewCustomization(
      ratio: ratio is num ? ratio.toDouble() : null,
      bloomSeconds: bloom is int ? bloom : null,
      firstPourSeconds: first is int ? first : null,
      secondPourSeconds: second is int ? second : null,
    );
  }

  Future<void> _pendingCache = Future<void>.value();

  /// Menunggu semua penulisan cache yang sedang antre selesai.
  Future<void> flushCache() => _pendingCache;

  /// Menyimpan input terakhir. Penulisan diantre berurutan agar perubahan
  /// beruntun (mis. menggeser slider) tidak saling menimpa. Gagal menyimpan
  /// cache tidak boleh mengganggu pengguna, jadi diabaikan.
  Future<void> cacheInputs({
    required String grams,
    required String water,
    required BrewInputMode inputMode,
    required BrewMethod method,
    required RoastLevel roast,
    BrewCustomization customization = const BrewCustomization(),
  }) {
    final Map<String, Object> values = <String, Object>{
      'grams': grams,
      'water': water,
      'inputMode': inputMode.index,
      'method': method.index,
      'roast': roast.index,
      'cRatio': ?customization.ratio,
      'cBloom': ?customization.bloomSeconds,
      'cFirst': ?customization.firstPourSeconds,
      'cSecond': ?customization.secondPourSeconds,
    };
    final List<String> cleared = <String>[
      if (customization.ratio == null) 'cRatio',
      if (customization.bloomSeconds == null) 'cBloom',
      if (customization.firstPourSeconds == null) 'cFirst',
      if (customization.secondPourSeconds == null) 'cSecond',
    ];

    _pendingCache = _pendingCache.then((_) async {
      try {
        await _cacheBox.putAll(values);
        await _cacheBox.deleteAll(cleared);
      } catch (_) {
        return;
      }
    });
    return _pendingCache;
  }

  // --- Preferensi boolean generik --------------------------------------------

  bool readFlag(String key, {required bool fallback}) =>
      (_cacheBox.get(key) as bool?) ?? fallback;

  /// Bilangan bulat tersimpan, atau [fallback] bila belum ada.
  int readInt(String key, {required int fallback}) {
    final Object? value = _cacheBox.get(key);
    return value is int ? value : fallback;
  }

  Future<void> writeInt(String key, {required int value}) async {
    try {
      await _cacheBox.put(key, value);
    } catch (_) {
      return;
    }
  }

  Future<void> writeFlag(String key, {required bool value}) async {
    try {
      await _cacheBox.put(key, value);
    } catch (_) {
      return;
    }
  }
}
