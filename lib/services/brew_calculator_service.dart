import '../models/brew_model.dart';

/// Logika murni (tanpa Flutter/UI) untuk validasi input dan perhitungan seduh.
class BrewCalculatorService {
  const BrewCalculatorService();

  static const double minCoffeeGrams = 1;
  static const double maxCoffeeGrams = 200;
  static const double bloomMinMultiplier = 2;
  static const double bloomMaxMultiplier = 3;

  /// Porsi air total yang sudah dituang di akhir fase first pour.
  static const double firstPourShare = 0.6;

  static final RegExp _numberPattern = RegExp(r'^(\d+([.,]\d*)?|[.,]\d+)$');

  /// Mengubah teks input menjadi angka, atau `null` jika tidak valid.
  /// Menerima koma maupun titik desimal. Menolak huruf, `NaN`, `Infinity`,
  /// notasi ilmiah (`1e3`) dan heksadesimal.
  double? parseGrams(String? raw) {
    final String text = (raw ?? '').trim();
    if (!_numberPattern.hasMatch(text)) {
      return null;
    }
    final double? value = double.tryParse(text.replaceAll(',', '.'));
    if (value == null || !value.isFinite) {
      return null;
    }
    return value;
  }

  /// Pesan error untuk field gramasi, atau `null` jika valid.
  String? validateGrams(String? raw) {
    final String text = (raw ?? '').trim();
    if (text.isEmpty) {
      return 'Gramasi wajib diisi';
    }
    final double? value = parseGrams(text);
    if (value == null) {
      return 'Masukkan angka yang valid (tanpa huruf)';
    }
    if (value <= 0) {
      return 'Gramasi harus lebih dari 0 g';
    }
    if (value < minCoffeeGrams) {
      return 'Minimal ${_fmt(minCoffeeGrams)} g';
    }
    if (value > maxCoffeeGrams) {
      return 'Maksimal ${_fmt(maxCoffeeGrams)} g';
    }
    return null;
  }

  /// Gramasi kopi yang dibutuhkan untuk [waterGrams] air pada [method],
  /// dibulatkan 0,1 g (kalkulator terbalik).
  double coffeeForWater(
    double waterGrams,
    BrewMethod method, {
    double? ratio,
  }) => _round1(waterGrams / (ratio ?? method.waterRatio));

  /// Pesan error untuk field target air pada [method], atau `null` jika
  /// valid. Hasil gramasi kopi turunannya juga harus berada di rentang
  /// [minCoffeeGrams]–[maxCoffeeGrams].
  String? validateWater(String? raw, BrewMethod method, {double? ratio}) {
    final String text = (raw ?? '').trim();
    if (text.isEmpty) {
      return 'Target air wajib diisi';
    }
    final double? value = parseGrams(text);
    if (value == null) {
      return 'Masukkan angka yang valid (tanpa huruf)';
    }
    if (value <= 0) {
      return 'Target air harus lebih dari 0 ml';
    }
    final double effectiveRatio = ratio ?? method.waterRatio;
    final double minWater = (minCoffeeGrams * effectiveRatio).ceilToDouble();
    final double maxWater = (maxCoffeeGrams * effectiveRatio).floorToDouble();
    if (coffeeForWater(value, method, ratio: ratio) < minCoffeeGrams) {
      return 'Minimal ${_fmt(minWater)} ml untuk ${method.label}';
    }
    if (coffeeForWater(value, method, ratio: ratio) > maxCoffeeGrams) {
      return 'Maksimal ${_fmt(maxWater)} ml untuk ${method.label}';
    }
    return null;
  }

  /// Menghitung semua output kalkulator. Melempar [ArgumentError] jika
  /// [coffeeGrams] di luar rentang yang valid.
  BrewCalculation calculate({
    required double coffeeGrams,
    required BrewMethod method,
    required RoastLevel roast,
    BrewCustomization customization = const BrewCustomization(),
  }) {
    if (!coffeeGrams.isFinite ||
        coffeeGrams < minCoffeeGrams ||
        coffeeGrams > maxCoffeeGrams) {
      throw ArgumentError.value(
        coffeeGrams,
        'coffeeGrams',
        'harus di antara $minCoffeeGrams dan $maxCoffeeGrams',
      );
    }

    final double ratio = (customization.ratio ?? method.waterRatio).clamp(
      BrewCustomization.minRatio,
      BrewCustomization.maxRatio,
    );
    final int bloomSeconds = (customization.bloomSeconds ?? method.bloomSeconds)
        .clamp(
          BrewCustomization.minBloomSeconds,
          BrewCustomization.maxBloomSeconds,
        );
    final int firstSeconds =
        (customization.firstPourSeconds ?? method.firstPourSeconds).clamp(
          BrewCustomization.minPourSeconds,
          BrewCustomization.maxPourSeconds,
        );
    final int secondSeconds =
        (customization.secondPourSeconds ?? method.secondPourSeconds).clamp(
          BrewCustomization.minPourSeconds,
          BrewCustomization.maxPourSeconds,
        );

    final double totalWater = _round1(coffeeGrams * ratio);
    final double bloomMin = _round1(coffeeGrams * bloomMinMultiplier);
    final double bloomMax = _round1(coffeeGrams * bloomMaxMultiplier);
    final double bloomRecommended = _round1(
      coffeeGrams * roast.bloomMultiplier,
    );

    final double bloomTarget = bloomRecommended.clamp(0, totalWater);
    final double firstTarget = _round1(
      (totalWater * firstPourShare).clamp(bloomTarget, totalWater),
    );

    final List<BrewStep> steps = <BrewStep>[
      BrewStep(
        title: 'Bloom',
        instruction:
            'Tuang ${_fmt(bloomTarget)} ml air hingga seluruh bubuk basah, '
            'lalu biarkan mengembang.',
        durationSeconds: bloomSeconds,
        pourGrams: bloomTarget,
        targetWaterGrams: bloomTarget,
      ),
      BrewStep(
        title: 'First Pour',
        instruction:
            'Tuang perlahan ${_fmt(_round1(firstTarget - bloomTarget))} ml '
            'hingga timbangan menunjukkan ${_fmt(firstTarget)} g.',
        durationSeconds: firstSeconds,
        pourGrams: _round1(firstTarget - bloomTarget),
        targetWaterGrams: firstTarget,
      ),
      BrewStep(
        title: 'Second Pour',
        instruction:
            'Tuang sisa ${_fmt(_round1(totalWater - firstTarget))} ml hingga '
            'total ${_fmt(totalWater)} ml.',
        durationSeconds: secondSeconds,
        pourGrams: _round1(totalWater - firstTarget),
        targetWaterGrams: totalWater,
      ),
    ];

    return BrewCalculation(
      coffeeGrams: coffeeGrams,
      method: method,
      roast: roast,
      totalWaterGrams: totalWater,
      bloomMinGrams: bloomMin,
      bloomMaxGrams: bloomMax,
      bloomRecommendedGrams: bloomTarget,
      steps: List<BrewStep>.unmodifiable(steps),
      ratio: ratio,
      customization: customization,
    );
  }

  static double _round1(double value) => (value * 10).round() / 10;

  static String _fmt(double value) =>
      value % 1 == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
}
