import 'package:flutter/material.dart';

import '../../models/brew_model.dart';
import 'filter_pill.dart';

/// Pilihan banyak tag aroma dan rasa. Mengetuk tag memilih atau melepasnya.
class FlavorTagPicker extends StatelessWidget {
  const FlavorTagPicker({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final List<FlavorTag> selected;
  final ValueChanged<List<FlavorTag>> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        for (final FlavorTag tag in FlavorTag.values)
          FilterPill(
            label: tag.label,
            selected: selected.contains(tag),
            onTap: () {
              final List<FlavorTag> next = selected.contains(tag)
                  ? (List<FlavorTag>.of(selected)..remove(tag))
                  : (List<FlavorTag>.of(selected)..add(tag));
              // Urutan mengikuti daftar enum agar tampilan konsisten.
              next.sort((FlavorTag a, FlavorTag b) => a.index - b.index);
              onChanged(next);
            },
          ),
      ],
    );
  }
}
