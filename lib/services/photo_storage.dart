import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Menyimpan foto catatan di folder dokumen aplikasi.
///
/// Yang disimpan di jurnal hanyalah nama berkas; path penuh dihitung saat
/// dipakai karena lokasi folder dokumen di iOS bisa berubah antar pembaruan.
class PhotoStorage {
  PhotoStorage({Future<Directory> Function()? documentsDirectory})
    : _documents = documentsDirectory ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _documents;

  Future<Directory> _photosDirectory() async {
    final Directory dir = Directory('${(await _documents()).path}/photos');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Menyalin [sourcePath] ke penyimpanan aplikasi dan mengembalikan nama
  /// berkas barunya.
  Future<String> importFile(String sourcePath) async {
    final Directory dir = await _photosDirectory();
    final String name =
        '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}'
        '.${_extensionOf(sourcePath)}';
    await File(sourcePath).copy('${dir.path}/$name');
    return name;
  }

  /// Berkas foto bernama [name], atau `null` bila tidak ada.
  Future<File?> resolve(String? name) async {
    if (name == null || name.isEmpty || name.contains('/')) {
      return null;
    }
    final File file = File('${(await _photosDirectory()).path}/$name');
    return await file.exists() ? file : null;
  }

  Future<void> delete(String? name) async {
    try {
      final File? file = await resolve(name);
      await file?.delete();
    } catch (_) {
      return;
    }
  }

  Future<void> deleteAll(Iterable<String?> names) async {
    for (final String? name in names) {
      await delete(name);
    }
  }

  static String _extensionOf(String path) {
    final int dot = path.lastIndexOf('.');
    if (dot < 0 || dot == path.length - 1) {
      return 'jpg';
    }
    final String ext = path
        .substring(dot + 1)
        .toLowerCase()
        .replaceAll(RegExp('[^a-z0-9]'), '');
    return ext.isEmpty || ext.length > 5 ? 'jpg' : ext;
  }
}
