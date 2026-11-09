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
    return null;
  }

  /// Menghitung takaran, atau `null` bila [validate] gagal.
  MocktailBlend? calculate(MocktailSpec spec) {
    if (validate(spec) != null) {
      return null;
    }

    final double liquid = spec.useIce
        ? spec.glassMl * (1 - iceVolumeShare)
        : spec.glassMl * noIceFillShare;
    final double syrupTotal = liquid * spec.sweetness.syrupShare;
    final double citrus = spec.useCitrus ? liquid * citrusShare : 0;

    // Pembulatan ke 0,5 ml; sisa cairan jadi bahan dasar agar jumlah tetap
    // pas dengan volume gelas.
    final int partSum = spec.syrups.fold<int>(
      0,
      (int sum, MocktailSyrup s) => sum + s.parts,
    );
    final List<double> syrupAmounts = <double>[
      for (final MocktailSyrup s in spec.syrups)
        _half(syrupTotal * s.parts / partSum),
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
          name: _syrupLabel(spec.syrups[i].name),
          perServing: syrupAmounts[i],
          unit: 'ml',
          color: SyrupPresets.byName(spec.syrups[i].name)?.color,
        ),
      if (citrusRounded > 0)
        MocktailIngredient(
          name: 'Perasan jeruk nipis',
          perServing: citrusRounded,
          unit: 'ml',
        ),
      MocktailIngredient(
        name: spec.base.ingredient,
        perServing: baseMl,
        unit: 'ml',
      ),
      if (spec.useIce)
        MocktailIngredient(
          name: 'Es batu',
          perServing: _iceGrams(spec.glassMl),
          unit: 'g',
        ),
    ];

    return MocktailBlend(
      spec: spec,
      ingredients: ingredients,
      steps: _steps(spec, syrupAmounts, citrusRounded, baseMl),
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

  List<String> _steps(
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
    final String pour = spec.base.sparkling
        ? 'Tuang ${spec.base.ingredient.toLowerCase()} ${_ml(baseMl)} '
              'perlahan lewat sendok bar agar gelembung tetap awet dan '
              'warnanya bergradasi.'
        : 'Tuang ${spec.base.ingredient.toLowerCase()} ${_ml(baseMl)} '
              'hingga penuh.';

    final List<String> steps = <String>[];
    if (spec.method == MocktailMethod.shake) {
      steps
        ..add(
          'Masukkan $syrupList${citrus > 0 ? ', perasan jeruk nipis '
                    '${_ml(citrus)}' : ''} dan segenggam es ke shaker.',
        )
        ..add('Kocok kuat 10–12 detik sampai shaker terasa dingin.')
        ..add(
          spec.useIce
              ? 'Saring ke gelas berisi $ice.'
              : 'Saring ke gelas yang sudah didinginkan.',
        );
    } else {
      if (spec.useIce) {
        steps.add('Isi gelas dengan $ice.');
      }
      steps.add('Tuang sirup: $syrupList.');
      if (citrus > 0) {
        steps.add('Tambahkan perasan jeruk nipis ${_ml(citrus)}.');
      }
      steps.add('Aduk 5 detik hingga sirup larut.');
    }
    steps.add(pour);
    if (spec.garnishes.isNotEmpty) {
      final String names = spec.garnishes
          .map((MocktailGarnish g) => g.label.toLowerCase())
          .join(', ');
      steps.add('Hias dengan $names, lalu sajikan segera.');
    } else {
      steps.add('Sajikan segera selagi dingin.');
    }
    if (spec.servings > 1) {
      steps.add(
        'Ulangi untuk ${spec.servings} porsi, atau kalikan takaran di '
        'atas bila memakai pitcher.',
      );
    }
    return steps;
  }
}
