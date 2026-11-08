import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/layout.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/field_styles.dart';
import '../core/utils/formatters.dart';
import '../models/brew_model.dart';
import '../viewmodels/bean_viewmodel.dart';
import 'widgets/app_button.dart';
import 'widgets/app_text_scope.dart';
import 'widgets/glass_dialog.dart';
import 'widgets/ambient_background.dart';
import 'widgets/filter_pill.dart';
import 'widgets/glass_app_bar.dart';
import 'widgets/glass_card.dart';
import 'widgets/motion.dart';
import 'widgets/section_label.dart';

/// Form tambah atau ubah satu biji kopi.
class BeanEditorScreen extends StatefulWidget {
  const BeanEditorScreen({super.key, this.bean});

  /// `null` berarti biji baru.
  final BrewBean? bean;

  @override
  State<BeanEditorScreen> createState() => _BeanEditorScreenState();
}

class _BeanEditorScreenState extends State<BeanEditorScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _roaster;
  late final TextEditingController _origin;
  DateTime? _roastDate;
  bool _saving = false;

  bool get _editing => widget.bean != null;

  @override
  void initState() {
    super.initState();
    final BrewBean? bean = widget.bean;
    _name = TextEditingController(text: bean?.name ?? '');
    _roaster = TextEditingController(text: bean?.roaster ?? '');
    _origin = TextEditingController(text: bean?.origin ?? '');
    _roastDate = bean?.roastDate;
  }

  @override
  void dispose() {
    _name.dispose();
    _roaster.dispose();
    _origin.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await AdaptiveDatePicker.show(
      context: context,
      initialDate: _roastDate ?? now,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
    );
    if (picked != null && mounted) {
      setState(() => _roastDate = picked);
    }
  }

  Future<void> _save() async {
    if (_saving) {
      return;
    }
    final BeanViewModel vm = context.read<BeanViewModel>();
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() => _saving = true);
    final String? error = await vm.saveBean(
      id: widget.bean?.id,
      name: _name.text,
      roaster: _roaster.text,
      origin: _origin.text,
      roastDate: _roastDate,
    );
    if (!mounted) {
      return;
    }
    setState(() => _saving = false);
    if (error != null) {
      AdaptiveSnackBar.show(
        context,
        message: error,
        type: AdaptiveSnackBarType.error,
      );
      return;
    }
    Navigator.of(context).pop(true);
  }

  Future<void> _confirmDelete() async {
    final BeanViewModel vm = context.read<BeanViewModel>();
    final NavigatorState navigator = Navigator.of(context);
    final BrewBean bean = widget.bean!;
    final bool confirmed = await showGlassConfirm(
      context,
      title: 'Hapus biji?',
      message:
          'Biji "${bean.name}" dihapus dari perpustakaan. Catatan seduhan '
          'yang memakainya tetap tersimpan.',
      confirmLabel: 'Hapus',
      destructive: true,
    );
    if (!confirmed) {
      return;
    }
    final String? error = await vm.deleteBean(bean.id);
    if (error == null) {
      navigator.pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final BeanViewModel vm = context.watch<BeanViewModel>();

    Widget field(
      TextEditingController controller,
      String label,
      String hint, {
      String? Function(String?)? validator,
      TextCapitalization capitalization = TextCapitalization.words,
    }) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SectionLabel(label),
          AdaptiveTextFormField(
            controller: controller,
            placeholder: hint,
            maxLength: BeanViewModel.maxNameLength,
            textCapitalization: capitalization,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: validator,
            onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
            style: AppTextStyles.body,
            cupertinoDecoration: FieldStyles.cupertino,
            decoration: FieldStyles.material(hint),
          ),
        ],
      );
    }

    return AdaptiveScaffold(
      backgroundColor: AppColors.background,
      body: AppTextScope(
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            const AmbientBackground(),
            HeaderClip(
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: AppLayout.screenPadding(context, hasBottomBar: false),
                children: <Widget>[
                  StaggerIn(
                    child: GlassCard(
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            field(
                              _name,
                              'Nama biji',
                              'mis. Gayo Natural',
                              validator: (String? _) => vm.validateName(
                                _name.text,
                                excludeId: widget.bean?.id,
                              ),
                            ),
                            const SizedBox(height: 18),
                            field(
                              _roaster,
                              'Roaster (opsional)',
                              'mis. Kopi Kenangan',
                              validator: (String? _) =>
                                  vm.validateOptional(_roaster.text),
                            ),
                            const SizedBox(height: 18),
                            field(
                              _origin,
                              'Asal (opsional)',
                              'mis. Aceh, Indonesia',
                              validator: (String? _) =>
                                  vm.validateOptional(_origin.text),
                            ),
                            const SizedBox(height: 18),
                            const SectionLabel('Tanggal roasting'),
                            Row(
                              children: <Widget>[
                                FilterPill(
                                  label: _roastDate == null
                                      ? 'Pilih tanggal'
                                      : formatDate(_roastDate!),
                                  icon: Icons.event_rounded,
                                  selected: _roastDate != null,
                                  onTap: _pickDate,
                                ),
                                if (_roastDate != null) ...<Widget>[
                                  const SizedBox(width: 8),
                                  FilterPill(
                                    label: 'Hapus',
                                    selected: false,
                                    onTap: () =>
                                        setState(() => _roastDate = null),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  StaggerIn(
                    index: 1,
                    child: AppButton(
                      label: _saving ? 'Menyimpan…' : 'Simpan biji',
                      color: AppColors.caramel,
                      textColor: AppColors.onAccent,
                      enabled: !_saving,
                      onPressed: _save,
                    ),
                  ),
                  if (_editing) ...<Widget>[
                    const SizedBox(height: 12),
                    StaggerIn(
                      index: 2,
                      child: AppButton(
                        label: 'Hapus biji',
                        color: AppColors.secondaryButton,
                        textColor: AppColors.danger,
                        onPressed: _confirmDelete,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: GlassAppBar(
                title: _editing ? 'Ubah Biji' : 'Biji Baru',
                subtitle: 'Perpustakaan biji kopi',
                leading: const GlassBackButton(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
