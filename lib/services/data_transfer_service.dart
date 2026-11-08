import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/brew_model.dart';
import 'backup_service.dart';
import 'journal_repository.dart';

/// Hasil impor cadangan.
class ImportResult {
  const ImportResult({
    required this.addedEntries,
    required this.addedRecipes,
    required this.addedBeans,
    required this.alreadyPresent,
    required this.invalid,
  });

  final int addedEntries;
  final int addedRecipes;
  final int addedBeans;

  /// Item yang idnya sudah ada sehingga dilewati (tidak menimpa).
  final int alreadyPresent;

  /// Item rusak di dalam berkas.
  final int invalid;

  int get added => addedEntries + addedRecipes + addedBeans;

  String get summary {
    final List<String> parts = <String>[
      if (addedEntries > 0) '$addedEntries catatan',
      if (addedRecipes > 0) '$addedRecipes resep',
      if (addedBeans > 0) '$addedBeans biji',
    ];
    final String head = parts.isEmpty
        ? 'Tidak ada data baru'
        : 'Ditambahkan ${parts.join(', ')}';
    final String tail = <String>[
      if (alreadyPresent > 0) '$alreadyPresent sudah ada',
      if (invalid > 0) '$invalid dilewati',
    ].join(', ');
    return tail.isEmpty ? head : '$head ($tail)';
  }
}

/// Ekspor, impor, dan berbagi berkas. Logika data ada di [BackupService];
/// kelas ini hanya menyentuh penyimpanan, picker, dan share sheet.
class DataTransferService {
  DataTransferService({
    required this._repository,
    this._backup = const BackupService(),
  });

  final JournalRepository _repository;
  final BackupService _backup;

  String buildJsonBackup(DateTime now) => _backup.encodeJson(
    entries: _repository.getAll(),
    recipes: _repository.getRecipes(),
    beans: _repository.getBeans(),
    now: now,
  );

  String buildCsv() => _backup.encodeCsv(_repository.getAll());

  /// Menggabungkan [source] ke data yang ada tanpa menimpa id yang sama.
  /// Melempar [BackupException] bila berkas tidak valid.
  Future<ImportResult> importJson(String source) async {
    final BackupData data = _backup.decodeJson(source);
    final Set<String> entryIds = _repository
        .getAll()
        .map((BrewEntry e) => e.id)
        .toSet();
    final Set<String> recipeIds = _repository
        .getRecipes()
        .map((BrewRecipe r) => r.id)
        .toSet();
    final Set<String> beanIds = _repository
        .getBeans()
        .map((BrewBean b) => b.id)
        .toSet();

    int entries = 0;
    int recipes = 0;
    int beans = 0;
    int present = 0;

    for (final BrewEntry e in data.entries) {
      if (entryIds.add(e.id)) {
        await _repository.save(e);
        entries++;
      } else {
        present++;
      }
    }
    for (final BrewRecipe r in data.recipes) {
      if (recipeIds.add(r.id)) {
        await _repository.saveRecipe(r);
        recipes++;
      } else {
        present++;
      }
    }
    for (final BrewBean b in data.beans) {
      if (beanIds.add(b.id)) {
        await _repository.saveBean(b);
        beans++;
      } else {
        present++;
      }
    }
    return ImportResult(
      addedEntries: entries,
      addedRecipes: recipes,
      addedBeans: beans,
      alreadyPresent: present,
      invalid: data.skipped,
    );
  }

  Future<File> _writeTemp(String name, List<int> bytes) async {
    final Directory dir = await getTemporaryDirectory();
    final File file = File('${dir.path}/$name');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  String _stamp(DateTime now) =>
      '${now.year}${now.month.toString().padLeft(2, '0')}'
      '${now.day.toString().padLeft(2, '0')}';

  /// Byte UTF-8 isi cadangan JSON.
  Uint8List jsonBytes(DateTime now) =>
      Uint8List.fromList(utf8.encode(buildJsonBackup(now)));

  /// Byte UTF-8 CSV dengan BOM agar Excel membaca karakter non-ASCII benar.
  Uint8List csvBytes() =>
      Uint8List.fromList(utf8.encode('\uFEFF${buildCsv()}'));

  Future<void> shareJsonBackup(DateTime now, {Rect? origin}) async {
    final File file = await _writeTemp(
      'brewlogic-cadangan-${_stamp(now)}.json',
      jsonBytes(now),
    );
    await _share(file, 'application/json', origin);
  }

  Future<void> shareCsv(DateTime now, {Rect? origin}) async {
    final File file = await _writeTemp(
      'brewlogic-jurnal-${_stamp(now)}.csv',
      csvBytes(),
    );
    await _share(file, 'text/csv', origin);
  }

  Future<void> sharePng(Uint8List png, String name, {Rect? origin}) async {
    final File file = await _writeTemp(name, png);
    await _share(file, 'image/png', origin);
  }

  Future<void> _share(File file, String mime, Rect? origin) async {
    await SharePlus.instance.share(
      ShareParams(
        files: <XFile>[XFile(file.path, mimeType: mime)],
        sharePositionOrigin: origin,
      ),
    );
  }

  /// Membuka picker berkas JSON lalu mengimpornya. `null` bila dibatalkan.
  Future<ImportResult?> pickAndImport() async {
    final PlatformFile? picked = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: <String>['json'],
    );
    final String? path = picked?.path;
    if (path == null) {
      return null;
    }
    final File file = File(path);
    if (await file.length() > 20 * 1024 * 1024) {
      throw const BackupException('Berkas terlalu besar (maksimal 20 MB).');
    }
    return importJson(await file.readAsString());
  }
}
