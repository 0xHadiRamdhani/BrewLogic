import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/haptics.dart';

/// Segmented control bergaya kaca yang digambar Flutter.
///
/// Versi native iOS 26 memakai lapisan sistem yang tidak ikut terpotong saat
/// digulir di bawah app bar dan meninggalkan sisa gambar di status bar, jadi
/// kontrol ini sengaja dibuat dari widget Flutter biasa.
class GlassSegmentedControl extends StatelessWidget {
  const GlassSegmentedControl({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onChanged,
    this.iconBuilders,
  }) : assert(labels.length > 0, 'labels tidak boleh kosong'),
       assert(
         iconBuilders == null || iconBuilders.length == labels.length,
         'iconBuilders harus sama panjang dengan labels',
       );

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  /// Ikon opsional di atas tiap label; menerima warna dan ukuran.
  final List<Widget Function(Color color, double size)>? iconBuilders;

  static const double _height = 44;
  static const double _heightWithIcons = 66;
  static const double _inset = 3;

  @override
  Widget build(BuildContext context) {
    final int count = labels.length;
    final int selected = selectedIndex.clamp(0, count - 1);
    final bool withIcons = iconBuilders != null;
    final double height = withIcons ? _heightWithIcons : _height;

    return Container(
      height: height,
      padding: const EdgeInsets.all(_inset),
      decoration: BoxDecoration(
        color: const Color(0x14F3E6D6),
        borderRadius: BorderRadius.circular(withIcons ? 24 : height / 2),
        border: Border.all(color: const Color(0x14F3E6D6)),
      ),
      child: Stack(
        children: <Widget>[
          AnimatedAlign(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            alignment: count == 1
                ? Alignment.center
                : Alignment(-1 + 2 * selected / (count - 1), 0),
            child: FractionallySizedBox(
              widthFactor: 1 / count,
              heightFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0x66D9A566),
                  borderRadius: BorderRadius.circular(
                    withIcons ? 21 : height / 2,
                  ),
                ),
              ),
            ),
          ),
          Row(
            children: <Widget>[
              for (int i = 0; i < count; i++)
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: i == selected,
                    label: labels[i],
                    excludeSemantics: true,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        if (i == selected) {
                          return;
                        }
                        Haptics.selection();
                        onChanged(i);
                      },
                      child: Center(child: _label(i, i == selected)),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

extension on GlassSegmentedControl {
  Widget _label(int i, bool isSelected) {
    final Text text = Text(
      labels[i],
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: AppColors.textPrimary,
        fontSize: iconBuilders == null ? 14 : 12.5,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
      ),
    );
    final builders = iconBuilders;
    if (builders == null) {
      return text;
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        builders[i](
          isSelected ? AppColors.textPrimary : AppColors.textSecondary,
          24,
        ),
        const SizedBox(height: 4),
        text,
      ],
    );
  }
}

/// Saklar yang digambar Flutter (Cupertino di iOS, Material di platform lain).
class GlassSwitch extends StatelessWidget {
  const GlassSwitch({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    if (PlatformInfo.isIOS) {
      return CupertinoSwitch(
        value: value,
        activeTrackColor: AppColors.caramel,
        onChanged: onChanged,
      );
    }
    return Switch(
      value: value,
      activeThumbColor: AppColors.onAccent,
      activeTrackColor: AppColors.caramel,
      onChanged: onChanged,
    );
  }
}
