import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../services/photo_storage.dart';

/// Menampilkan foto catatan dari penyimpanan aplikasi. Jika berkasnya tidak
/// ada, tampil ikon pengganti.
class EntryPhoto extends StatefulWidget {
  const EntryPhoto({
    super.key,
    required this.name,
    this.width,
    this.height = 160,
    this.borderRadius = 18,
  });

  final String? name;
  final double? width;
  final double height;
  final double borderRadius;

  @override
  State<EntryPhoto> createState() => _EntryPhotoState();
}

class _EntryPhotoState extends State<EntryPhoto> {
  Future<File?>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= context.read<PhotoStorage>().resolve(widget.name);
  }

  @override
  void didUpdateWidget(EntryPhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.name != widget.name) {
      _future = context.read<PhotoStorage>().resolve(widget.name);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: FutureBuilder<File?>(
          future: _future,
          builder: (BuildContext context, AsyncSnapshot<File?> snapshot) {
            final File? file = snapshot.data;
            if (file == null) {
              return const ColoredBox(
                color: AppColors.glassFill,
                child: Center(
                  child: Icon(
                    Icons.image_outlined,
                    color: AppColors.textSecondary,
                    size: 32,
                  ),
                ),
              );
            }
            return Image.file(
              file,
              fit: BoxFit.cover,
              cacheWidth: 900,
              gaplessPlayback: true,
              errorBuilder: (BuildContext c, Object e, StackTrace? s) =>
                  const ColoredBox(color: AppColors.glassFill),
            );
          },
        ),
      ),
    );
  }
}
