import 'package:flutter/foundation.dart';

import '../models/brew_model.dart';
import '../services/journal_repository.dart';

/// ViewModel resep favorit: memuat, menyimpan, dan menghapus "Resep Saya".
class RecipeViewModel extends ChangeNotifier {
  RecipeViewModel({required this._repository}) {
    load();
  }

  static const int maxNameLength = 24;

  final JournalRepository _repository;
  List<BrewRecipe> _recipes = const <BrewRecipe>[];

  List<BrewRecipe> get recipes => _recipes;
  bool get isEmpty => _recipes.isEmpty;

  void load() {
    try {
      _recipes = List<BrewRecipe>.unmodifiable(_repository.getRecipes());
    } catch (_) {
      _recipes = const <BrewRecipe>[];
    }
    notifyListeners();
  }

  /// Pesan error untuk nama resep, atau `null` jika valid.
  String? validateName(String? raw) {
    final String name = (raw ?? '').trim();
    if (name.isEmpty) {
      return 'Nama resep wajib diisi';
    }
    if (name.length > maxNameLength) {
      return 'Maksimal $maxNameLength karakter';
    }
    final bool taken = _recipes.any(
      (BrewRecipe r) => r.name.toLowerCase() == name.toLowerCase(),
    );
    return taken ? 'Nama resep sudah dipakai' : null;
  }

  /// Menyimpan seduhan saat ini sebagai resep. Mengembalikan pesan error,
  /// atau `null` jika berhasil.
  Future<String?> saveRecipe({
    required String name,
    required BrewCalculation calculation,
  }) async {
    final String? invalid = validateName(name);
    if (invalid != null) {
      return invalid;
    }
    final DateTime now = DateTime.now();
    final BrewRecipe recipe = BrewRecipe(
      id: now.microsecondsSinceEpoch.toRadixString(36),
      name: name.trim(),
      createdAt: now,
      coffeeGrams: calculation.coffeeGrams,
      method: calculation.method,
      roast: calculation.roast,
      customization: calculation.customization,
    );
    try {
      await _repository.saveRecipe(recipe);
    } on StorageException catch (e) {
      return e.message;
    }
    load();
    return null;
  }

  Future<String?> deleteRecipe(String id) async {
    try {
      await _repository.deleteRecipe(id);
    } on StorageException catch (e) {
      return e.message;
    }
    load();
    return null;
  }
}
