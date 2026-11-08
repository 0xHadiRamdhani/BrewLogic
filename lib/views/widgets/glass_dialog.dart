import 'dart:ui' show ImageFilter;

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/field_styles.dart';
import '../../core/utils/haptics.dart';
import 'app_text_scope.dart';
import 'motion.dart';

/// Dialog bergaya kaca untuk seluruh aplikasi.
///
/// Dialog native iOS meredupkan layar di belakangnya sekitar 30–50% dan
/// pengaturannya dikunci oleh sistem, sehingga di aplikasi gelap ini
/// layarnya nyaris tak terlihat. Dialog di sini memakai latar tipis dan
/// kartu kaca gelap yang kontras.

/// Latar tipis di belakang dialog.
const Color _barrier = Color(0x1F000000);

/// Gaya tombol dialog.
enum GlassDialogStyle {
  /// Tombol sekunder abu-abu.
  normal,

  /// Tombol utama amber.
  primary,

  /// Tindakan berbahaya (merah).
  destructive,
}

/// Satu tombol dialog yang mengembalikan [value] saat ditekan.
class GlassDialogAction<T> {
  const GlassDialogAction({
    required this.label,
    this.value,
    this.style = GlassDialogStyle.normal,
  });

  final String label;

  /// Nilai yang dikembalikan; `null` untuk tombol batal.
  final T? value;
  final GlassDialogStyle style;
}

Future<T?> _show<T>(BuildContext context, Widget Function(BuildContext) page) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Tutup',
    barrierColor: _barrier,
    transitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (BuildContext c, Animation<double> a, Animation<double> b) =>
        page(c),
    transitionBuilder:
        (
          BuildContext c,
          Animation<double> animation,
          Animation<double> secondary,
          Widget child,
        ) {
          final Animation<double> curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeIn,
          );
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.92, end: 1).animate(curved),
              child: child,
            ),
          );
        },
  );
}

/// Konfirmasi dua pilihan. `true` bila dikonfirmasi, `false` bila dibatalkan
/// atau ditutup.
Future<bool> showGlassConfirm(
  BuildContext context, {
  required String title,
  String? message,
  required String confirmLabel,
  String cancelLabel = 'Batal',
  bool destructive = false,
}) async {
  final bool? result = await _show<bool>(
    context,
    (BuildContext _) => _Frame(
      title: title,
      message: message,
      actions: <Widget>[
        _ActionRow(
          children: <Widget>[
            _Button<bool>(
              action: GlassDialogAction<bool>(label: cancelLabel, value: false),
            ),
            _Button<bool>(
              action: GlassDialogAction<bool>(
                label: confirmLabel,
                value: true,
                style: destructive
                    ? GlassDialogStyle.destructive
                    : GlassDialogStyle.primary,
              ),
            ),
          ],
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Beberapa pilihan bertumpuk; `null` bila ditutup tanpa memilih.
Future<T?> showGlassChoice<T>(
  BuildContext context, {
  required String title,
  String? message,
  required List<GlassDialogAction<T>> choices,
  String cancelLabel = 'Batal',
}) {
  return _show<T>(
    context,
    (BuildContext _) => _Frame(
      title: title,
      message: message,
      actions: <Widget>[
        for (final GlassDialogAction<T> choice in choices) ...<Widget>[
          _Button<T>(action: choice, expand: true),
          const SizedBox(height: 10),
        ],
        _Button<T>(
          action: GlassDialogAction<T>(label: cancelLabel),
          expand: true,
          dismissOnly: true,
        ),
      ],
    ),
  );
}

/// Isian teks satu baris. Mengembalikan teks, atau `null` bila dibatalkan.
Future<String?> showPromptDialog(
  BuildContext context, {
  required String title,
  String? message,
  required String placeholder,
  String initialValue = '',
  int? maxLength,
  String confirmLabel = 'Simpan',
  String cancelLabel = 'Batal',
}) {
  return _show<String>(
    context,
    (BuildContext _) => _PromptBody(
      title: title,
      message: message,
      placeholder: placeholder,
      initialValue: initialValue,
      maxLength: maxLength,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
    ),
  );
}

class _PromptBody extends StatefulWidget {
  const _PromptBody({
    required this.title,
    required this.message,
    required this.placeholder,
    required this.initialValue,
    required this.maxLength,
    required this.confirmLabel,
    required this.cancelLabel,
  });

  final String title;
  final String? message;
  final String placeholder;
  final String initialValue;
  final int? maxLength;
  final String confirmLabel;
  final String cancelLabel;

  @override
  State<_PromptBody> createState() => _PromptBodyState();
}

class _PromptBodyState extends State<_PromptBody> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  );

  @override
  void initState() {
    super.initState();
    // Seluruh teks awal terpilih agar mudah diganti.
    _controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: widget.initialValue.length,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _confirm() => Navigator.of(context).pop(_controller.text);

  @override
  Widget build(BuildContext context) {
    return _Frame(
      title: widget.title,
      message: widget.message,
      body: AdaptiveTextFormField(
        controller: _controller,
        placeholder: widget.placeholder,
        autofocus: true,
        maxLength: widget.maxLength,
        textInputAction: TextInputAction.done,
        textCapitalization: TextCapitalization.sentences,
        onSubmitted: (_) => _confirm(),
        style: AppTextStyles.body,
        cupertinoDecoration: FieldStyles.cupertino,
        decoration: FieldStyles.material(widget.placeholder),
      ),
      actions: <Widget>[
        _ActionRow(
          children: <Widget>[
            _Button<String>(
              action: GlassDialogAction<String>(label: widget.cancelLabel),
              dismissOnly: true,
            ),
            _Button<String>(
              action: GlassDialogAction<String>(
                label: widget.confirmLabel,
                style: GlassDialogStyle.primary,
              ),
              onPressedOverride: _confirm,
            ),
          ],
        ),
      ],
    );
  }
}

/// Kerangka kartu dialog: judul, pesan, isi opsional, dan tombol. Naik
/// mengikuti keyboard.
class _Frame extends StatelessWidget {
  const _Frame({
    required this.title,
    required this.actions,
    this.message,
    this.body,
  });

  final String title;
  final String? message;
  final Widget? body;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final EdgeInsets insets = MediaQuery.viewInsetsOf(context);

    return AppTextScope(
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: EdgeInsets.fromLTRB(28, 24, 28, 24 + insets.bottom),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340),
            child: Semantics(
              scopesRoute: true,
              namesRoute: true,
              explicitChildNodes: true,
              label: title,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: AppColors.glassBorder),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: <Color>[Color(0xFF2D241E), Color(0xFF1D1612)],
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                      child: Material(
                        type: MaterialType.transparency,
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              Text(
                                title,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 19,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (message != null) ...<Widget>[
                                const SizedBox(height: 6),
                                Text(
                                  message!,
                                  textAlign: TextAlign.center,
                                  style: AppTextStyles.bodySecondary,
                                ),
                              ],
                              if (body != null) ...<Widget>[
                                const SizedBox(height: 18),
                                body!,
                              ],
                              const SizedBox(height: 20),
                              ...actions,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        for (int i = 0; i < children.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(width: 12),
          Expanded(child: children[i]),
        ],
      ],
    );
  }
}

class _Button<T> extends StatelessWidget {
  const _Button({
    required this.action,
    this.expand = false,
    this.dismissOnly = false,
    this.onPressedOverride,
  });

  final GlassDialogAction<T> action;

  /// Tombol selebar kartu (untuk susunan vertikal).
  final bool expand;

  /// Menutup dialog tanpa nilai (tombol batal).
  final bool dismissOnly;

  /// Menggantikan perilaku bawaan (mis. mengirim teks isian).
  final VoidCallback? onPressedOverride;

  @override
  Widget build(BuildContext context) {
    final bool primary = action.style == GlassDialogStyle.primary;
    final bool destructive = action.style == GlassDialogStyle.destructive;
    final Color fill = primary
        ? AppColors.caramel
        : destructive
        ? AppColors.danger
        : AppColors.secondaryButton;
    final Color textColor = primary
        ? AppColors.onAccent
        : destructive
        ? Colors.white
        : AppColors.textPrimary;

    return Semantics(
      button: true,
      label: action.label,
      child: PressableScale(
        pressedScale: 0.96,
        onTap: () {
          Haptics.selection();
          if (onPressedOverride != null) {
            onPressedOverride!();
          } else if (dismissOnly) {
            Navigator.of(context).pop();
          } else {
            Navigator.of(context).pop(action.value);
          }
        },
        child: Container(
          height: 48,
          width: expand ? double.infinity : null,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            action.label,
            style: TextStyle(
              color: textColor,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
