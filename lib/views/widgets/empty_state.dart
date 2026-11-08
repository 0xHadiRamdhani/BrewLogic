import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Tampilan kosong yang hangat: ikon dalam lingkaran bercincin, judul, dan
/// satu kalimat penjelasan.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 48, 12, 24),
      child: Column(
        children: <Widget>[
          SizedBox(
            width: 148,
            height: 148,
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                for (final (double size, double alpha) in <(double, double)>[
                  (148, 0.10),
                  (116, 0.16),
                ])
                  Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.caramel.withValues(alpha: alpha),
                      ),
                    ),
                  ),
                Container(
                  width: 84,
                  height: 84,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: <Color>[Color(0xFFE6B87A), Color(0xFFB9824A)],
                    ),
                  ),
                  child: Icon(icon, color: AppColors.onAccent, size: 38),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: appDisplayFontFamily,
              color: AppColors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySecondary,
          ),
        ],
      ),
    );
  }
}
