import 'glass_dialog.dart';

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../services/photo_storage.dart';
import 'entry_photo.dart';
import 'glass_app_bar.dart';
import 'motion.dart';

/// Kolom foto: ketuk untuk memotret atau memilih dari galeri. Foto langsung
/// disalin ke penyimpanan aplikasi dan namanya dikirim lewat [onChanged].
class PhotoPickerField extends StatefulWidget {
  const PhotoPickerField({
    super.key,
    required this.photoName,
    required this.onChanged,
  });

  final String? photoName;
  final ValueChanged<String?> onChanged;

  @override
  State<PhotoPickerField> createState() => _PhotoPickerFieldState();
}

class _PhotoPickerFieldState extends State<PhotoPickerField> {
  bool _busy = false;

  Future<void> _choose() async {
    final ImageSource? source = await showGlassChoice<ImageSource>(
      context,
      title: 'Tambah foto',
      message: 'Foto cangkir atau kemasan kopi.',
      choices: const <GlassDialogAction<ImageSource>>[
        GlassDialogAction<ImageSource>(
          label: 'Kamera',
          value: ImageSource.camera,
          style: GlassDialogStyle.primary,
        ),
        GlassDialogAction<ImageSource>(
          label: 'Galeri',
          value: ImageSource.gallery,
        ),
      ],
    );
    if (source != null) {
      await _pick(source);
    }
  }

  Future<void> _pick(ImageSource source) async {
    final PhotoStorage storage = context.read<PhotoStorage>();
    setState(() => _busy = true);
    try {
      final XFile? file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (file == null) {
        return;
      }
      final String name = await storage.importFile(file.path);
      if (mounted) {
        widget.onChanged(name);
      }
    } catch (_) {
      if (mounted) {
        AdaptiveSnackBar.show(
          context,
          message: source == ImageSource.camera
              ? 'Kamera tidak tersedia atau izin ditolak'
              : 'Foto tidak dapat dibuka',
          type: AdaptiveSnackBarType.error,
          duration: const Duration(seconds: 3),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String? name = widget.photoName;
    return AnimatedSize(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: name == null
          ? Semantics(
              button: true,
              label: 'Tambah foto',
              child: PressableScale(
                pressedScale: 0.98,
                onTap: _busy ? () {} : _choose,
                child: Container(
                  height: 84,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.glassFill,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.glassBorder),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Icon(
                        _busy
                            ? Icons.hourglass_top_rounded
                            : Icons.add_a_photo_outlined,
                        color: AppColors.caramel,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _busy ? 'Memproses…' : 'Tambah foto',
                        style: const TextStyle(
                          color: AppColors.caramel,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          : Stack(
              children: <Widget>[
                PressableScale(
                  pressedScale: 0.98,
                  onTap: _busy ? () {} : _choose,
                  child: EntryPhoto(
                    name: name,
                    width: double.infinity,
                    height: 190,
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: GlassIconButton(
                    icon: Icons.close_rounded,
                    label: 'Hapus foto',
                    iconSize: 18,
                    onTap: () => widget.onChanged(null),
                  ),
                ),
              ],
            ),
    );
  }
}
