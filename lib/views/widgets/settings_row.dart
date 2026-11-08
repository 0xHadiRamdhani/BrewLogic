import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'motion.dart';

/// Satu baris pengaturan: ikon, judul, subjudul, dan elemen di kanan.
/// Bila [onTap] diisi, baris bisa ditekan dengan efek mengecil.
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final Color accent = destructive ? AppColors.danger : AppColors.sage;
    final bool disabled = destructive && onTap == null;

    final Widget row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: <Widget>[
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: disabled ? 0.06 : 0.14),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              icon,
              size: 20,
              color: accent.withValues(alpha: disabled ? 0.4 : 1),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: destructive
                        ? AppColors.danger.withValues(
                            alpha: disabled ? 0.45 : 1,
                          )
                        : AppColors.textPrimary,
                  ),
                ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      subtitle!,
                      style: AppTextStyles.bodySecondary.copyWith(
                        fontSize: 12.5,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (trailing != null) ...<Widget>[
            const SizedBox(width: 12),
            trailing!,
          ],
        ],
      ),
    );

    if (onTap == null) {
      return row;
    }
    return Semantics(
      button: true,
      label: title,
      child: PressableScale(pressedScale: 0.98, onTap: onTap!, child: row),
    );
  }
}
