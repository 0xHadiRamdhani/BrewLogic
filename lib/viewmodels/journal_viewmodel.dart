import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/brew_model.dart';
import '../services/journal_repository.dart';
import '../services/photo_storage.dart';

/// Urutan daftar jurnal.
enum JournalSort {
  newest('Terbaru'),
  oldest('Terlama'),
  ratingHigh('Rating tertinggi'),
  ratingLow('Rating terendah');

  const JournalSort(this.label);

  final String label;
}

/// ViewModel Brew Journal: memuat, menyimpan, mengubah, menghapus, serta
/// mencari, memfilter, dan mengurutkan catatan seduhan.
class JournalViewModel extends ChangeNotifier {
  JournalViewModel({required this._repository, this._photos}) {
    load();
  }

  static const int maxNotesLength = 500;
  static const int maxGrinderLength = 24;

  final JournalRepository _repository;

  /// Untuk menghapus berkas foto saat catatan dihapus atau fotonya diganti.
  final PhotoStorage? _photos;

  /// Pilihan rating minimum yang diputar tiap ketukan: semua → 3★ → 4★ → 5★.
  static const List<int> ratingSteps = <int>[0, 3, 4, 5];

  List<BrewEntry> _entries = const <BrewEntry>[];
  String? _errorMessage;

  String _query = '';
  BrewMethod? _methodFilter;
  int _minRating = 0;
  JournalSort _sort = JournalSort.newest;

  List<BrewEntry> get entries => _entries;

  // --- Cari, filter, urutkan ------------------------------------------------

  String get query => _query;
  BrewMethod? get methodFilter => _methodFilter;
  int get minRating => _minRating;
  JournalSort get sort => _sort;

  bool get hasActiveFilters =>
      _query.trim().isNotEmpty || _methodFilter != null || _minRating > 0;

  /// Catatan yang lolos pencarian dan filter, sudah diurutkan.
  List<BrewEntry> get visibleEntries {
    final String needle = _query.trim().toLowerCase();
    final List<BrewEntry> result = _entries.where((BrewEntry e) {
      if (_methodFilter != null && e.method != _methodFilter) {
        return false;
      }
      if (e.rating < _minRating) {
        return false;
      }
      if (needle.isEmpty) {
        return true;
      }
      return e.tastingNotes.toLowerCase().contains(needle) ||
          e.method.label.toLowerCase().contains(needle) ||
          e.roast.label.toLowerCase().contains(needle) ||
          e.grinderSetting.toLowerCase().contains(needle) ||
          (e.beanName ?? '').toLowerCase().contains(needle) ||
          e.flavorTags.any(
            (FlavorTag t) => t.label.toLowerCase().contains(needle),
          );
    }).toList();

    switch (_sort) {
      case JournalSort.newest:
        result.sort(
          (BrewEntry a, BrewEntry b) => b.createdAt.compareTo(a.createdAt),
        );
      case JournalSort.oldest:
        result.sort(
          (BrewEntry a, BrewEntry b) => a.createdAt.compareTo(b.createdAt),
        );
      case JournalSort.ratingHigh:
        result.sort((BrewEntry a, BrewEntry b) {
          final int byRating = b.rating.compareTo(a.rating);
          return byRating != 0 ? byRating : b.createdAt.compareTo(a.createdAt);
        });
      case JournalSort.ratingLow:
        result.sort((BrewEntry a, BrewEntry b) {
          final int byRating = a.rating.compareTo(b.rating);
          return byRating != 0 ? byRating : b.createdAt.compareTo(a.createdAt);
        });
    }
    return result;
  }

  void setQuery(String value) {
    _query = value;
    notifyListeners();
  }

  void setMethodFilter(BrewMethod? value) {
    _methodFilter = value;
    notifyListeners();
  }

  void cycleMinRating() {
    final int next = (ratingSteps.indexOf(_minRating) + 1) % ratingSteps.length;
    _minRating = ratingSteps[next];
    notifyListeners();
  }

  void cycleSort() {
    _sort = JournalSort.values[(_sort.index + 1) % JournalSort.values.length];
    notifyListeners();
  }

  void resetFilters() {
    _query = '';
    _methodFilter = null;
    _minRating = 0;
    notifyListeners();
  }

  BrewEntry? entryById(String id) {
    for (final BrewEntry entry in _entries) {
      if (entry.id == id) {
        return entry;
      }
    }
    return null;
  }

  /// Mengubah rating dan tasting notes sebuah catatan. Mengembalikan pesan
  /// error, atau `null` jika berhasil.
  Future<String?> updateEntry({
    required String id,
    required int rating,
    required String tastingNotes,
    TasteFeedback? taste,
    List<FlavorTag>? flavorTags,
    String? grinderSetting,
    String? photoName,
    bool clearPhoto = false,
  }) async {
    final String? invalid =
        validateRating(rating) ??
        validateNotes(tastingNotes) ??
        validateGrinder(grinderSetting);
    if (invalid != null) {
      return invalid;
    }
    final BrewEntry? existing = entryById(id);
    if (existing == null) {
      return 'Catatan tidak ditemukan.';
    }
    try {
      await _repository.save(
        existing.copyWith(
          rating: rating,
          tastingNotes: tastingNotes.trim(),
          taste: taste,
          clearTaste: taste == null,
          flavorTags: flavorTags,
          grinderSetting: grinderSetting?.trim(),
          photoName: photoName,
          clearPhoto: clearPhoto,
        ),
      );
    } on StorageException catch (e) {
      return e.message;
    }
    // Foto lama dibuang bila diganti atau dihapus.
    final String? oldPhoto = existing.photoName;
    if (oldPhoto != null &&
        (clearPhoto || (photoName != null && photoName != oldPhoto))) {
      unawaited(_photos?.delete(oldPhoto) ?? Future<void>.value());
    }
    load();
    return null;
  }

  String? get errorMessage => _errorMessage;
  bool get isEmpty => _entries.isEmpty;

  double get averageRating {
    if (_entries.isEmpty) {
      return 0;
    }
    final int sum = _entries.fold<int>(
      0,
      (int total, BrewEntry e) => total + e.rating,
    );
    return sum / _entries.length;
  }

  void load() {
    try {
      _entries = List<BrewEntry>.unmodifiable(_repository.getAll());
      _errorMessage = null;
    } catch (_) {
      _entries = const <BrewEntry>[];
      _errorMessage = 'Jurnal tidak dapat dimuat.';
    }
    notifyListeners();
  }

  String? validateRating(int rating) =>
      rating < 1 || rating > 5 ? 'Pilih rating 1–5 bintang' : null;

  String? validateNotes(String? notes) =>
      (notes ?? '').trim().length > maxNotesLength
      ? 'Maksimal $maxNotesLength karakter'
      : null;

  String? validateGrinder(String? raw) =>
      (raw ?? '').trim().length > maxGrinderLength
      ? 'Maksimal $maxGrinderLength karakter'
      : null;

  /// Menyimpan hasil seduhan. Mengembalikan `null` jika berhasil, atau pesan
  /// error yang siap ditampilkan.
  Future<String?> saveBrew({
    required BrewCalculation calculation,
    required int rating,
    required String tastingNotes,
    required int brewSeconds,
    TasteFeedback? taste,
    List<FlavorTag> flavorTags = const <FlavorTag>[],
    String grinderSetting = '',
    String? photoName,
    BrewBean? bean,
  }) async {
    final String? invalid =
        validateRating(rating) ??
        validateNotes(tastingNotes) ??
        validateGrinder(grinderSetting);
    if (invalid != null) {
      return invalid;
    }

    final DateTime now = DateTime.now();
    final BrewEntry entry = BrewEntry(
      id: now.microsecondsSinceEpoch.toRadixString(36),
      createdAt: now,
      coffeeGrams: calculation.coffeeGrams,
      waterGrams: calculation.totalWaterGrams,
      method: calculation.method,
      roast: calculation.roast,
      rating: rating,
      tastingNotes: tastingNotes.trim(),
      brewSeconds: brewSeconds < 0 ? 0 : brewSeconds,
      taste: taste,
      flavorTags: List<FlavorTag>.unmodifiable(flavorTags),
      grinderSetting: grinderSetting.trim(),
      photoName: photoName,
      beanId: bean?.id,
      beanName: bean?.name,
    );

    try {
      await _repository.save(entry);
    } on StorageException catch (e) {
      return e.message;
    }
    load();
    return null;
  }

  /// Menghapus semua catatan. Mengembalikan pesan error, atau `null`.
  Future<String?> clearAll() async {
    final List<String?> photos = _entries
        .map((BrewEntry e) => e.photoName)
        .toList();
    try {
      await _repository.clearJournal();
    } on StorageException catch (e) {
      return e.message;
    }
    unawaited(_photos?.deleteAll(photos) ?? Future<void>.value());
    load();
    return null;
  }

  /// Mengembalikan pesan error, atau `null` jika berhasil.
  Future<String?> deleteEntry(String id) async {
    final String? photo = entryById(id)?.photoName;
    try {
      await _repository.delete(id);
    } on StorageException catch (e) {
      return e.message;
    }
    unawaited(_photos?.delete(photo) ?? Future<void>.value());
    load();
    return null;
  }
}
