import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/brew_model.dart';
import 'brew_icons.dart';

/// Kartu seduhan yang dirender menjadi gambar untuk dibagikan. Ukuran logis
/// tetap [width] x [height]; pada pixelRatio 3 hasilnya 1080 x 1350.
class BrewShareCard extends StatelessWidget {
  const BrewShareCard({super.key, required this.entry});

  static const double width = 360;
  static const double height = 450;

  final BrewEntry entry;

  @override
  Widget build(BuildContext context) {
    final BrewEntry e = entry;
    final String ratio = formatRatio((e.ratio * 10).round() / 10);

    return Directionality(
      textDirection: TextDirection.ltr,
      child: SizedBox(
        width: width,
        height: height,
        child: DecoratedBox(
          decoration: const BoxDecoration(color: AppColors.background),
          child: Stack(
            children: <Widget>[
              const _Glow(
                alignment: Alignment.topLeft,
                color: AppColors.caramel,
                alpha: 0.42,
              ),
              const _Glow(
                alignment: Alignment.bottomRight,
                color: AppColors.sage,
                alpha: 0.28,
              ),
              Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Row(
                      children: <Widget>[
                        Icon(
                          Icons.coffee_outlined,
                          color: AppColors.caramel,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        _Plain(
                          'BrewLogic',
                          size: 15,
                          weight: FontWeight.w700,
                          color: AppColors.caramel,
                          letterSpacing: 0.6,
                        ),
                      ],
                    ),
                    const Spacer(),
                    _Plain(
                      e.method.label,
                      size: 44,
                      weight: FontWeight.w800,
                      letterSpacing: -1,
                    ),
                    const SizedBox(height: 6),
                    _Plain(
                      'Roast ${e.roast.label} · $ratio',
                      size: 15,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(height: 22),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        Expanded(
                          child: _Amount(
                            value: formatGrams(e.coffeeGrams),
                            label: 'g kopi',
                            color: AppColors.caramel,
                          ),
                        ),
                        const _Plain(
                          '→',
                          size: 24,
                          color: AppColors.textSecondary,
                        ),
                        Expanded(
                          child: _Amount(
                            value: formatGrams(e.waterGrams),
                            label: 'ml air',
                            color: AppColors.sage,
                            alignEnd: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: <Widget>[
                        for (int i = 1; i <= 5; i++)
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: BeanIcon(
                              filled: i <= e.rating,
                              size: 26,
                              color: i <= e.rating
                                  ? AppColors.caramel
                                  : AppColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                    if (e.flavorTags.isNotEmpty ||
                        e.beanName != null) ...<Widget>[
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: <Widget>[
                          if (e.beanName != null)
                            _Chip(e.beanName!, AppColors.sage),
                          for (final FlavorTag t in e.flavorTags.take(4))
                            _Chip(t.label, AppColors.caramel),
                        ],
                      ),
                    ],
                    if (e.tastingNotes.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 16),
                      Text(
                        '“${e.tastingNotes}”',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontStyle: FontStyle.italic,
                          height: 1.4,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ],
                    const Spacer(),
                    _Plain(
                      '${formatDate(e.createdAt)} · seduh presisi, nikmati pelan',
                      size: 12,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Amount extends StatelessWidget {
  const _Amount({
    required this.value,
    required this.label,
    required this.color,
    this.alignEnd = false,
  });

  final String value;
  final String label;
  final Color color;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: <Widget>[
        FittedBox(
          fit: BoxFit.scaleDown,
          child: _Plain(value, size: 44, weight: FontWeight.w800, color: color),
        ),
        _Plain(label, size: 14, color: AppColors.textSecondary),
      ],
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({
    required this.alignment,
    required this.color,
    required this.alpha,
  });

  final Alignment alignment;
  final Color color;
  final double alpha;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Container(
        width: 360,
        height: 360,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: <Color>[
              color.withValues(alpha: alpha),
              color.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}

class _Plain extends StatelessWidget {
  const _Plain(
    this.text, {
    required this.size,
    this.weight = FontWeight.w500,
    this.color = AppColors.textPrimary,
    this.letterSpacing,
  });

  final String text;
  final double size;
  final FontWeight weight;
  final Color color;
  final double? letterSpacing;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      color: color,
      fontSize: size,
      fontWeight: weight,
      letterSpacing: letterSpacing,
      decoration: TextDecoration.none,
    ),
  );
}

class _Chip extends StatelessWidget {
  const _Chip(this.label, this.color);

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: _Plain(label, size: 12.5, weight: FontWeight.w600, color: color),
    );
  }
}

/// Merender [BrewShareCard] di luar layar menjadi PNG 1080 x 1350.
Future<Uint8List> captureShareCard(
  BuildContext context,
  BrewEntry entry,
) async {
  final OverlayState overlay = Overlay.of(context, rootOverlay: true);
  final GlobalKey boundaryKey = GlobalKey();
  final OverlayEntry host = OverlayEntry(
    builder: (BuildContext _) => Positioned(
      left: -BrewShareCard.width * 3,
      top: 0,
      child: IgnorePointer(
        child: ExcludeSemantics(
          child: RepaintBoundary(
            key: boundaryKey,
            child: BrewShareCard(entry: entry),
          ),
        ),
      ),
    ),
  );
  overlay.insert(host);
  try {
    // Beri waktu satu-dua frame agar kartu selesai di-layout dan digambar.
    await WidgetsBinding.instance.endOfFrame;
    await WidgetsBinding.instance.endOfFrame;
    final RenderRepaintBoundary boundary =
        boundaryKey.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
    final ui.Image image = await boundary.toImage(pixelRatio: 3);
    final ByteData? data = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    image.dispose();
    if (data == null) {
      throw StateError('Gagal membuat gambar kartu.');
    }
    return data.buffer.asUint8List();
  } finally {
    host.remove();
  }
}
