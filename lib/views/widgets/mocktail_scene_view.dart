import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:lottie/lottie.dart';

import '../../models/mocktail_model.dart';
import '../../services/mocktail_scene.dart';

/// Gelas mocktail beranimasi yang terisi mengikuti timer: es, sirup, jeruk
/// nipis, aduk atau kocok, bahan dasar, lalu hiasan. Warna sirup dan bahan
/// dasar serta bagian yang tampil mengikuti resep.
class MocktailSceneView extends StatefulWidget {
  const MocktailSceneView({
    super.key,
    required this.blend,
    required this.elapsed,
    this.height = 100,
  });

  final MocktailBlend blend;

  /// Waktu berjalan untuk satu gelas.
  final ValueListenable<Duration> elapsed;
  final double height;

  @override
  State<MocktailSceneView> createState() => _MocktailSceneViewState();
}

class _MocktailSceneViewState extends State<MocktailSceneView> {
  static Future<LottieComposition>? _loading;

  LottieComposition? _composition;
  late LottieDelegates _delegates = _buildDelegates(widget.blend.spec);

  @override
  void initState() {
    super.initState();
    _loading ??= AssetLottie(MocktailScene.asset).load();
    _loading!.then((LottieComposition composition) {
      if (mounted) {
        setState(() => _composition = composition);
      }
    });
  }

  @override
  void didUpdateWidget(MocktailSceneView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.blend.spec != widget.blend.spec) {
      _delegates = _buildDelegates(widget.blend.spec);
    }
  }

  static LottieDelegates _buildDelegates(MocktailSpec spec) {
    final Color syrup = MocktailScene.syrupColor(spec);
    ValueDelegate<int> hide(String layer) =>
        ValueDelegate.opacity(<String>[layer, '**'], value: 0);

    return LottieDelegates(
      values: <ValueDelegate<Object?>>[
        ValueDelegate.color(<String>[
          'syrup',
          '**',
          'liquidFill',
        ], value: syrup),
        ValueDelegate.color(<String>['shaker', '**', 'bandFill'], value: syrup),
        ValueDelegate.color(<String>[
          'base',
          '**',
          'baseFill',
        ], value: MocktailScene.baseColor(spec.base)),
        if (!spec.useIce) hide('ice'),
        if (!spec.useCitrus) hide('citrus'),
        if (!spec.base.sparkling) hide('bubbles'),
        if (spec.method == MocktailMethod.shake) hide('spoon'),
        if (spec.method == MocktailMethod.build) hide('shaker'),
        if (!spec.garnishes.contains(MocktailGarnish.limeWheel))
          hide('garnish-lime'),
        if (!spec.garnishes.contains(MocktailGarnish.mint))
          hide('garnish-mint'),
        if (!spec.garnishes.contains(MocktailGarnish.lemonPeel))
          hide('garnish-lemon'),
        if (!spec.garnishes.contains(MocktailGarnish.berries))
          hide('garnish-berries'),
        if (!spec.garnishes.contains(MocktailGarnish.cucumber))
          hide('garnish-cucumber'),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final LottieComposition? composition = _composition;
    return ExcludeSemantics(
      child: SizedBox(
        height: widget.height,
        child: composition == null
            ? null
            : ValueListenableBuilder<Duration>(
                valueListenable: widget.elapsed,
                builder: (BuildContext context, Duration elapsed, _) {
                  final double frame = MocktailScene.frameAt(
                    widget.blend,
                    elapsed,
                  );
                  return RawLottie(
                    composition: composition,
                    delegates: _delegates,
                    progress: frame / MocktailScene.totalFrames,
                    frameRate: FrameRate.max,
                    height: widget.height,
                    fit: BoxFit.contain,
                  );
                },
              ),
      ),
    );
  }
}
