import 'package:flutter/painting.dart';

import '../models/mocktail_model.dart';

/// Rentang frame animasi `assets/animations/mocktail.json` untuk satu jenis
/// langkah. [loop] berarti diputar berulang selama langkah berlangsung.
class MocktailSegment {
  const MocktailSegment(this.from, this.to, {this.loop = false});

  final int from;
  final int to;
  final bool loop;
}

/// Memetakan waktu timer ke frame animasi gelas dan menentukan warnanya.
/// Murni; angka frame harus sama dengan berkas animasi.
abstract final class MocktailScene {
  static const String asset = 'assets/animations/mocktail.json';
  static const int fps = 30;
  static const int totalFrames = 290;

  static const Map<MocktailStepKind, MocktailSegment> segments =
      <MocktailStepKind, MocktailSegment>{
        MocktailStepKind.mixIn: MocktailSegment(0, 30),
        MocktailStepKind.shake: MocktailSegment(30, 60, loop: true),
        MocktailStepKind.strain: MocktailSegment(60, 155),
        MocktailStepKind.ice: MocktailSegment(80, 105),
        MocktailStepKind.syrup: MocktailSegment(105, 135),
        MocktailStepKind.citrus: MocktailSegment(135, 155),
        MocktailStepKind.stir: MocktailSegment(155, 180, loop: true),
        MocktailStepKind.base: MocktailSegment(180, 265),
        MocktailStepKind.garnish: MocktailSegment(265, 290),
      };

  /// Frame (0..[totalFrames]) pada waktu [elapsed] untuk satu gelas.
  static double frameAt(MocktailBlend blend, Duration elapsed) {
    final int totalMs = blend.totalSeconds * 1000;
    if (elapsed.inMilliseconds >= totalMs) {
      return totalFrames.toDouble();
    }
    if (elapsed <= Duration.zero) {
      return segments[blend.stepDetails.first.kind]!.from.toDouble();
    }
    final int index = blend.stepIndexAt(elapsed);
    final MocktailStep step = blend.stepDetails[index];
    final MocktailSegment seg = segments[step.kind]!;
    final int inStepMs =
        elapsed.inMilliseconds - blend.stepStartOf(index).inMilliseconds;
    final int span = seg.to - seg.from;
    if (seg.loop) {
      final double frames = inStepMs * fps / 1000;
      return seg.from + frames % span;
    }
    final double fraction = (inStepMs / (step.durationSeconds * 1000)).clamp(
      0.0,
      1.0,
    );
    return seg.from + span * fraction;
  }

  /// Warna campuran sirup, dirata-ratakan menurut bagian tiap sirup.
  static Color syrupColor(MocktailSpec spec) {
    double r = 0;
    double g = 0;
    double b = 0;
    int parts = 0;
    for (final MocktailSyrup s in spec.syrups) {
      final Color c = Color(SyrupPresets.byName(s.name)?.color ?? 0xFFD9A566);
      r += c.r * s.parts;
      g += c.g * s.parts;
      b += c.b * s.parts;
      parts += s.parts;
    }
    if (parts == 0) {
      return const Color(0xFFD9A566);
    }
    return Color.from(
      alpha: 1,
      red: r / parts,
      green: g / parts,
      blue: b / parts,
    );
  }

  static Color baseColor(MocktailBase base) => switch (base) {
    MocktailBase.soda => const Color(0xFFCDE7F0),
    MocktailBase.tonic => const Color(0xFFE6F3F7),
    MocktailBase.gingerAle => const Color(0xFFF0D58A),
    MocktailBase.water => const Color(0xFFD6EDF5),
    MocktailBase.coconut => const Color(0xFFF2EEE6),
    MocktailBase.iceTea => const Color(0xFFC98A3E),
  };
}
