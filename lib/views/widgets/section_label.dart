import 'package:flutter/widgets.dart';

import '../../core/theme/app_theme.dart';

/// Judul kecil kapital di atas sebuah grup input, diawali garis karamel
/// pendek sebagai penanda.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: <Widget>[
          Container(
            width: 14,
            height: 2,
            decoration: BoxDecoration(
              color: AppColors.caramel,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(text.toUpperCase(), style: AppTextStyles.sectionLabel),
          ),
        ],
      ),
    );
  }
}
