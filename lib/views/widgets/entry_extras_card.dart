import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/field_styles.dart';
import '../../models/brew_model.dart';
import '../../viewmodels/journal_viewmodel.dart';
import 'flavor_tag_picker.dart';
import 'glass_card.dart';
import 'photo_picker_field.dart';
import 'section_label.dart';

/// Kartu detail tambahan catatan: setelan gilingan, tag rasa, dan foto.
/// Dipakai di layar Simpan dan Detail.
class EntryExtrasCard extends StatelessWidget {
  const EntryExtrasCard({
    super.key,
    required this.grinderController,
    required this.tags,
    required this.onTagsChanged,
    required this.photoName,
    required this.onPhotoChanged,
  });

  final TextEditingController grinderController;
  final List<FlavorTag> tags;
  final ValueChanged<List<FlavorTag>> onTagsChanged;
  final String? photoName;
  final ValueChanged<String?> onPhotoChanged;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SectionLabel('Tag rasa'),
          FlavorTagPicker(selected: tags, onChanged: onTagsChanged),
          const SizedBox(height: 20),
          const SectionLabel('Setelan gilingan'),
          AdaptiveTextFormField(
            controller: grinderController,
            placeholder: 'mis. 21 klik',
            maxLength: JournalViewModel.maxGrinderLength,
            onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
            style: AppTextStyles.body,
            cupertinoDecoration: FieldStyles.cupertino,
            decoration: FieldStyles.material('mis. 21 klik'),
          ),
          const SizedBox(height: 16),
          const SectionLabel('Foto'),
          PhotoPickerField(photoName: photoName, onChanged: onPhotoChanged),
        ],
      ),
    );
  }
}
