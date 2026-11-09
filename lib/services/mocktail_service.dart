import '../core/utils/formatters.dart';
import '../models/mocktail_model.dart';

/// Perhitungan takaran dan langkah mocktail. Murni, tanpa efek samping.
class MocktailService {
  const MocktailService();

  /// Bagian gelas yang diisi es.
  static const double iceVolumeShare = 0.4;

  /// Bila tanpa es, sisakan ruang agar tidak tumpah saat diaduk.
  static const double noIceFillShare = 0.9;

  /// Bobot es batu per ml volume gelas yang terisi.
  static const double _iceGramsPerMl = 0.92;
  static const double citrusShare = 0.08;

  /// Pesan error untuk spesifikasi yang belum bisa dihitung, atau `null`.
  String? validate(MocktailSpec spec) {
    if (spec.syrups.isEmpty) {
      return 'Pilih minimal satu sirup.';
    }
    if (spec.syrups.length > MocktailSpec.maxSyrups) {
      return 'Maksimal ${MocktailSpec.maxSyrups} sirup.';
    }
    if (spec.glassMl < MocktailSpec.minGlassMl ||
        spec.glassMl > MocktailSpec.maxGlassMl) {
      return 'Ukuran gelas ${MocktailSpec.minGlassMl}–'
          '${MocktailSpec.maxGlassMl} ml.';
    }
    if (spec.servings < MocktailSpec.minServings ||
        spec.servings > MocktailSpec.maxServings) {
      return 'Jumlah porsi ${MocktailSpec.minServings}–'
          '${MocktailSpec.maxServings}.';
    }
    if (spec.customMl) {
      for (final MocktailSyrup s in spec.syrups) {
        final double ml = s.ml!;
        if (ml < MocktailSpec.minSyrupMl || ml > MocktailSpec.maxSyrupMl) {
          return 'Takaran sirup ${formatGrams(MocktailSpec.minSyrupMl)}–'
              '${formatGrams(MocktailSpec.maxSyrupMl)} ml.';
        }
      }
      final double syrups = spec.syrups.fold<double>(
        0,
        (double sum, MocktailSyrup s) => sum + _half(s.ml!),
      );
      final double base = _liquid(spec) - syrups - _half(_citrus(spec));
      if (base < MocktailSpec.minBaseMl) {
        return 'Sirup dan jeruk nipis terlalu banyak untuk gelas '
            '${spec.glassMl} ml. Kurangi takaran atau pakai gelas lebih besar.';
      }
    }
    return null;
  }

  double _liquid(MocktailSpec spec) => spec.useIce
      ? spec.glassMl * (1 - iceVolumeShare)
      : spec.glassMl * noIceFillShare;

  double _citrus(MocktailSpec spec) =>
      spec.useCitrus ? _liquid(spec) * citrusShare : 0;

  /// Menghitung takaran, atau `null` bila [validate] gagal.
  MocktailBlend? calculate(MocktailSpec spec) {
    if (validate(spec) != null) {
      return null;
    }

    final double liquid = _liquid(spec);
    final double syrupTotal = liquid * spec.sweetness.syrupShare;
    final double citrus = _citrus(spec);

    // Pembulatan ke 0,5 ml; sisa cairan jadi bahan dasar agar jumlah tetap
    // pas dengan volume gelas. Takaran ml sendiri dipakai apa adanya.
    final int partSum = spec.syrups.fold<int>(
      0,
      (int sum, MocktailSyrup s) => sum + s.parts,
    );
    final List<double> syrupAmounts = <double>[
      for (final MocktailSyrup s in spec.syrups)
        spec.customMl ? _half(s.ml!) : _half(syrupTotal * s.parts / partSum),
    ];
    final double syrupRounded = syrupAmounts.fold<double>(
      0,
      (double a, double b) => a + b,
    );
    final double citrusRounded = _half(citrus);
    final double baseMl = _half(liquid - syrupRounded - citrusRounded);

    final List<MocktailIngredient> ingredients = <MocktailIngredient>[
      for (int i = 0; i < spec.syrups.length; i++)
        MocktailIngredient(
          kind: MocktailIngredientKind.syrup,
          name: _syrupLabel(spec.syrups[i].name),
          perServing: syrupAmounts[i],
          unit: 'ml',
          color: SyrupPresets.byName(spec.syrups[i].name)?.color,
        ),
      if (citrusRounded > 0)
        MocktailIngredient(
          kind: MocktailIngredientKind.citrus,
          name: 'Perasan jeruk nipis',
          perServing: citrusRounded,
          unit: 'ml',
        ),
      MocktailIngredient(
        kind: MocktailIngredientKind.base,
        name: spec.baseIngredient,
        perServing: baseMl,
        unit: 'ml',
      ),
      if (spec.useIce)
        MocktailIngredient(
          kind: MocktailIngredientKind.ice,
          name: 'Es batu',
          perServing: _iceGrams(spec.glassMl),
          unit: 'g',
        ),
    ];

    return MocktailBlend(
      spec: spec,
      ingredients: ingredients,
      stepDetails: _steps(spec, syrupAmounts, citrusRounded, baseMl),
      liquidMl: liquid,
      syrupMl: syrupRounded,
    );
  }

  /// Nama bahan sirup; "Simple syrup" sudah memuat kata sirup.
  String _syrupLabel(String name) {
    final String lower = name.toLowerCase();
    return lower.contains('syrup') || lower.contains('sirup')
        ? name
        : 'Sirup $name';
  }

  double _half(double value) => (value * 2).roundToDouble() / 2;

  double _iceGrams(int glassMl) {
    final double raw = glassMl * iceVolumeShare * _iceGramsPerMl;
    return (raw / 5).roundToDouble() * 5;
  }

  String _ml(double value) => '${formatGrams(value)} ml';

  List<MocktailStep> _steps(
    MocktailSpec spec,
    List<double> syrupAmounts,
    double citrus,
    double baseMl,
  ) {
    final String syrupList = <String>[
      for (int i = 0; i < spec.syrups.length; i++)
        '${spec.syrups[i].name} ${_ml(syrupAmounts[i])}',
    ].join(', ');
    final String ice = 'es batu (± ${formatGrams(_iceGrams(spec.glassMl))} g)';
    final String baseName = spec.baseIngredient.toLowerCase();
    final String citrusText = citrus > 0
        ? 'perasan jeruk nipis ${_ml(citrus)}'
        : '';

    final List<MocktailStep> steps = <MocktailStep>[];
    if (spec.method == MocktailMethod.shake) {
      steps
        ..add(
          MocktailStep(
            kind: MocktailStepKind.mixIn,
            title: 'Masukkan bahan',
            text:
                'Masukkan $syrupList${citrus > 0 ? ', $citrusText' : ''} dan '
                'segenggam es ke shaker.',
            durationSeconds: 15,
          ),
        )
        ..add(
          const MocktailStep(
            kind: MocktailStepKind.shake,
            title: 'Kocok',
            text: 'Kocok kuat 10–12 detik sampai shaker terasa dingin.',
            durationSeconds: 12,
          ),
        )
        ..add(
          MocktailStep(
            kind: MocktailStepKind.strain,
            title: 'Saring',
            text: spec.useIce
                ? 'Saring ke gelas berisi $ice.'
                : 'Saring ke gelas yang sudah didinginkan.',
            durationSeconds: 8,
          ),
        );
    } else {
      if (spec.useIce) {
        steps.add(
          MocktailStep(
            kind: MocktailStepKind.ice,
            title: 'Isi es',
            text: 'Isi gelas dengan $ice.',
            durationSeconds: 8,
          ),
        );
      }
      steps.add(
        MocktailStep(
          kind: MocktailStepKind.syrup,
          title: 'Tuang sirup',
          text: 'Tuang sirup: $syrupList.',
          durationSeconds: 8,
        ),
      );
      if (citrus > 0) {
        steps.add(
          MocktailStep(
            kind: MocktailStepKind.citrus,
            title: 'Tambah jeruk nipis',
            text: 'Tambahkan perasan jeruk nipis ${_ml(citrus)}.',
            durationSeconds: 6,
          ),
        );
      }
      steps.add(
        const MocktailStep(
          kind: MocktailStepKind.stir,
          title: 'Aduk',
          text: 'Aduk 5 detik hingga sirup larut.',
          durationSeconds: 5,
        ),
      );
    }
    steps.add(
      MocktailStep(
        kind: MocktailStepKind.base,
        title: 'Tuang ${spec.baseLabel.toLowerCase()}',
        text: spec.baseSparkling
            ? 'Tuang $baseName ${_ml(baseMl)} perlahan lewat sendok bar agar '
                  'gelembung tetap awet dan warnanya bergradasi.'
            : 'Tuang $baseName ${_ml(baseMl)} hingga penuh.',
        durationSeconds: spec.baseSparkling ? 15 : 10,
      ),
    );
    if (spec.garnishNames.isNotEmpty) {
      final String names = spec.garnishNames
          .map((String g) => g.toLowerCase())
          .join(', ');
      steps.add(
        MocktailStep(
          kind: MocktailStepKind.garnish,
          title: 'Hias & sajikan',
          text: 'Hias dengan $names, lalu sajikan segera.',
          durationSeconds: 8,
        ),
      );
    } else {
      steps.add(
        const MocktailStep(
          kind: MocktailStepKind.garnish,
          title: 'Sajikan',
          text: 'Sajikan segera selagi dingin.',
          durationSeconds: 5,
        ),
      );
    }
    return steps;
  }
}
