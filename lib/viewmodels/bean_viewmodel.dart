import 'package:flutter/foundation.dart';

import '../models/brew_model.dart';
import '../services/bean_freshness.dart';
import '../services/journal_repository.dart';

/// ViewModel perpustakaan biji: daftar, simpan, hapus, kesegaran, dan biji
/// aktif yang dipakai kalkulator dan dicatat ke jurnal.
class BeanViewModel extends ChangeNotifier {
  BeanViewModel({
    required this._repository,
    DateTime Function()? clock,
    this._freshness = const BeanFreshnessService(),
  }) : _clock = clock ?? DateTime.now {
    _activeId = _repository.activeBeanId;
    load();
  }

  static const int maxNameLength = 40;
  static const int maxFieldLength = 40;

  final JournalRepository _repository;
  final DateTime Function() _clock;
  final BeanFreshnessService _freshness;

  List<BrewBean> _beans = const <BrewBean>[];
  String? _activeId;

  List<BrewBean> get beans => _beans;
  bool get isEmpty => _beans.isEmpty;

  /// Biji aktif, atau `null` bila tidak ada atau sudah dihapus.
  BrewBean? get active {
    for (final BrewBean bean in _beans) {
      if (bean.id == _activeId) {
        return bean;
      }
    }
    return null;
  }

  BeanFreshness? freshnessOf(BrewBean bean) =>
      _freshness.evaluate(bean.roastDate, _clock());

  void load() {
    try {
      _beans = List<BrewBean>.unmodifiable(_repository.getBeans());
    } catch (_) {
      _beans = const <BrewBean>[];
    }
    notifyListeners();
  }

  /// Memilih biji aktif; `null` atau id yang sama sekali lagi melepas pilihan.
  void selectActive(String? id) {
    _activeId = id == _activeId ? null : id;
    _repository.setActiveBeanId(_activeId);
    notifyListeners();
  }

  String? validateName(String? raw, {String? excludeId}) {
    final String name = (raw ?? '').trim();
    if (name.isEmpty) {
      return 'Nama biji wajib diisi';
    }
    if (name.length > maxNameLength) {
      return 'Maksimal $maxNameLength karakter';
    }
    final bool taken = _beans.any(
      (BrewBean b) =>
          b.id != excludeId && b.name.toLowerCase() == name.toLowerCase(),
    );
    return taken ? 'Nama biji sudah dipakai' : null;
  }

  String? validateOptional(String? raw) =>
      (raw ?? '').trim().length > maxFieldLength
      ? 'Maksimal $maxFieldLength karakter'
      : null;

  /// Tanggal roasting tidak boleh di masa depan.
  String? validateRoastDate(DateTime? date) {
    if (date == null) {
      return null;
    }
    final DateTime now = _clock();
    final DateTime today = DateTime(now.year, now.month, now.day);
    return DateTime(date.year, date.month, date.day).isAfter(today)
        ? 'Tanggal roasting tidak boleh di masa depan'
        : null;
  }

  /// Menyimpan biji baru, atau memperbarui bila [id] diisi. Mengembalikan
  /// pesan error, atau `null` jika berhasil.
  Future<String?> saveBean({
    String? id,
    required String name,
    String roaster = '',
    String origin = '',
    DateTime? roastDate,
  }) async {
    final String? invalid =
        validateName(name, excludeId: id) ??
        validateOptional(roaster) ??
        validateOptional(origin) ??
        validateRoastDate(roastDate);
    if (invalid != null) {
      return invalid;
    }
    final DateTime now = _clock();
    final BrewBean? existing = id == null
        ? null
        : _beans.where((BrewBean b) => b.id == id).firstOrNull;
    final BrewBean bean = BrewBean(
      id: existing?.id ?? now.microsecondsSinceEpoch.toRadixString(36),
      createdAt: existing?.createdAt ?? now,
      name: name.trim(),
      roaster: roaster.trim(),
      origin: origin.trim(),
      roastDate: roastDate,
    );
    try {
      await _repository.saveBean(bean);
    } on StorageException catch (e) {
      return e.message;
    }
    load();
    return null;
  }

  Future<String?> deleteBean(String id) async {
    try {
      await _repository.deleteBean(id);
    } on StorageException catch (e) {
      return e.message;
    }
    if (_activeId == id) {
      _activeId = null;
      await _repository.setActiveBeanId(null);
    }
    load();
    return null;
  }
}
