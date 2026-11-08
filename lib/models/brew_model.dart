import 'package:flutter/foundation.dart';

/// Cara kalkulator menerima input utama.
enum BrewInputMode {
  /// Pengguna memasukkan gramasi kopi; air dihitung dari rasio.
  coffee,

  /// Pengguna memasukkan target air; gramasi kopi dihitung balik.
  water,
}

/// Metode seduh yang didukung beserta parameter default-nya.
enum BrewMethod {
  v60(
    label: 'V60',
    shortLabel: 'V60',
    waterRatio: 15,
    grindSize: 'Medium-Fine',
    bloomSeconds: 40,
    firstPourSeconds: 50,
    secondPourSeconds: 60,
  ),
  aeropress(
    label: 'Aeropress',
    shortLabel: 'Aeropress',
    waterRatio: 13,
    grindSize: 'Medium-Fine',
    bloomSeconds: 30,
    firstPourSeconds: 45,
    secondPourSeconds: 45,
  ),
  frenchPress(
    label: 'French Press',
    shortLabel: 'French',
    waterRatio: 12,
    grindSize: 'Coarse',
    bloomSeconds: 30,
    firstPourSeconds: 90,
    secondPourSeconds: 120,
  ),
  chemex(
    label: 'Chemex',
    shortLabel: 'Chemex',
    waterRatio: 16,
    grindSize: 'Medium-Coarse',
    bloomSeconds: 45,
    firstPourSeconds: 60,
    secondPourSeconds: 75,
  );

  const BrewMethod({
    required this.label,
    required this.shortLabel,
    required this.waterRatio,
    required this.grindSize,
    required this.bloomSeconds,
    required this.firstPourSeconds,
    required this.secondPourSeconds,
  });

  /// Nama lengkap untuk ditampilkan.
  final String label;

  /// Nama singkat untuk segmented control.
  final String shortLabel;

  /// Gram air untuk setiap 1 gram kopi (V60 = 15 berarti 1:15).
  final double waterRatio;

  /// Rekomendasi ukuran gilingan.
  final String grindSize;

  /// Durasi fase bloom (30–45 detik).
  final int bloomSeconds;

  /// Durasi fase tuang pertama.
  final int firstPourSeconds;

  /// Durasi fase tuang kedua.
  final int secondPourSeconds;

  /// Rasio dalam format "1:15".
  String get ratioLabel {
    final String ratio = waterRatio % 1 == 0
        ? waterRatio.toStringAsFixed(0)
        : waterRatio.toStringAsFixed(1);
    return '1:$ratio';
  }
}

/// Tingkat roasting beserta suhu air dan pengali bloom yang disarankan.
enum RoastLevel {
  light(label: 'Light', minTempC: 93, maxTempC: 95, bloomMultiplier: 3),
  medium(label: 'Medium', minTempC: 90, maxTempC: 92, bloomMultiplier: 2.5),
  dark(label: 'Dark', minTempC: 85, maxTempC: 89, bloomMultiplier: 2);

  const RoastLevel({
    required this.label,
    required this.minTempC,
    required this.maxTempC,
    required this.bloomMultiplier,
  });

  final String label;
  final int minTempC;
  final int maxTempC;

  /// Pengali berat kopi untuk air bloom yang direkomendasikan (2x–3x).
  final double bloomMultiplier;

  String get tempRangeLabel => '$minTempC–$maxTempC °C';
}

/// "1:15" atau "1:15.5".
String formatRatio(double ratio) {
  final double rounded = (ratio * 10).round() / 10;
  final String text = rounded % 1 == 0
      ? rounded.toStringAsFixed(0)
      : rounded.toStringAsFixed(1);
  return '1:$text';
}

/// Kesan rasa setelah mencicip, dipakai asisten dial-in.
enum TasteFeedback {
  sour('Asam'),
  bitter('Pahit'),
  weak('Hambar'),
  harsh('Sepat'),
  balanced('Seimbang');

  const TasteFeedback(this.label);

  final String label;
}

/// Tag aroma dan rasa yang bisa dipilih saat mencatat seduhan.
enum FlavorTag {
  floral('Floral'),
  fruity('Buah'),
  citrus('Jeruk'),
  berry('Beri'),
  chocolate('Cokelat'),
  nutty('Kacang'),
  caramel('Karamel'),
  spicy('Rempah'),
  earthy('Tanah'),
  sweet('Manis');

  const FlavorTag(this.label);

  final String label;
}

/// Penyesuaian resep oleh pengguna. Nilai `null` berarti memakai bawaan
/// metode seduh.
@immutable
class BrewCustomization {
  const BrewCustomization({
    this.ratio,
    this.bloomSeconds,
    this.firstPourSeconds,
    this.secondPourSeconds,
  });

  static const double minRatio = 10;
  static const double maxRatio = 20;
  static const int minBloomSeconds = 15;
  static const int maxBloomSeconds = 90;
  static const int minPourSeconds = 15;
  static const int maxPourSeconds = 300;

  /// Gram air per 1 gram kopi (15 berarti 1:15).
  final double? ratio;
  final int? bloomSeconds;
  final int? firstPourSeconds;
  final int? secondPourSeconds;

  bool get isDefault =>
      ratio == null &&
      bloomSeconds == null &&
      firstPourSeconds == null &&
      secondPourSeconds == null;

  BrewCustomization withRatio(double? value) => BrewCustomization(
    ratio: value,
    bloomSeconds: bloomSeconds,
    firstPourSeconds: firstPourSeconds,
    secondPourSeconds: secondPourSeconds,
  );

  BrewCustomization withBloomSeconds(int? value) => BrewCustomization(
    ratio: ratio,
    bloomSeconds: value,
    firstPourSeconds: firstPourSeconds,
    secondPourSeconds: secondPourSeconds,
  );

  BrewCustomization withFirstPourSeconds(int? value) => BrewCustomization(
    ratio: ratio,
    bloomSeconds: bloomSeconds,
    firstPourSeconds: value,
    secondPourSeconds: secondPourSeconds,
  );

  BrewCustomization withSecondPourSeconds(int? value) => BrewCustomization(
    ratio: ratio,
    bloomSeconds: bloomSeconds,
    firstPourSeconds: firstPourSeconds,
    secondPourSeconds: value,
  );

  @override
  bool operator ==(Object other) =>
      other is BrewCustomization &&
      other.ratio == ratio &&
      other.bloomSeconds == bloomSeconds &&
      other.firstPourSeconds == firstPourSeconds &&
      other.secondPourSeconds == secondPourSeconds;

  @override
  int get hashCode =>
      Object.hash(ratio, bloomSeconds, firstPourSeconds, secondPourSeconds);
}

/// Satu fase pada timer seduh (Bloom, First Pour, Second Pour).
@immutable
class BrewStep {
  const BrewStep({
    required this.title,
    required this.instruction,
    required this.durationSeconds,
    required this.pourGrams,
    required this.targetWaterGrams,
  });

  final String title;
  final String instruction;
  final int durationSeconds;

  /// Air yang dituang pada fase ini.
  final double pourGrams;

  /// Total air kumulatif di akhir fase ini.
  final double targetWaterGrams;
}

/// Hasil perhitungan kalkulator. Immutable, dihitung ulang setiap input berubah.
@immutable
class BrewCalculation {
  const BrewCalculation({
    required this.coffeeGrams,
    required this.method,
    required this.roast,
    required this.totalWaterGrams,
    required this.bloomMinGrams,
    required this.bloomMaxGrams,
    required this.bloomRecommendedGrams,
    required this.steps,
    required this.ratio,
    this.customization = const BrewCustomization(),
  });

  final double coffeeGrams;
  final BrewMethod method;
  final RoastLevel roast;

  /// Rasio air:kopi yang dipakai (bawaan metode atau hasil penyesuaian).
  final double ratio;
  final BrewCustomization customization;
  final double totalWaterGrams;
  final double bloomMinGrams;
  final double bloomMaxGrams;
  final double bloomRecommendedGrams;
  final List<BrewStep> steps;

  String get ratioLabel => formatRatio(ratio);

  int get minTempC => roast.minTempC;
  int get maxTempC => roast.maxTempC;
  String get grindSize => method.grindSize;

  int get totalSeconds =>
      steps.fold<int>(0, (int sum, BrewStep s) => sum + s.durationSeconds);

  /// Indeks fase yang aktif pada [elapsed]; fase terakhir jika sudah lewat.
  int stepIndexAt(Duration elapsed) {
    int accumulatedMs = 0;
    for (int i = 0; i < steps.length; i++) {
      accumulatedMs += steps[i].durationSeconds * 1000;
      if (elapsed.inMilliseconds < accumulatedMs) {
        return i;
      }
    }
    return steps.length - 1;
  }

  /// Sisa detik (dibulatkan ke atas) pada fase yang aktif di [elapsed].
  int stepRemainingSecondsAt(Duration elapsed) {
    final int index = stepIndexAt(elapsed);
    final int stepMs = steps[index].durationSeconds * 1000;
    final int intoStepMs = (elapsed - stepStartOf(index)).inMilliseconds.clamp(
      0,
      stepMs,
    );
    return ((stepMs - intoStepMs) / 1000).ceil();
  }

  /// Waktu mulai fase ke-[index] sejak timer dimulai.
  Duration stepStartOf(int index) {
    int ms = 0;
    for (int i = 0; i < index && i < steps.length; i++) {
      ms += steps[i].durationSeconds * 1000;
    }
    return Duration(milliseconds: ms);
  }

  /// True jika kedua hasil berasal dari input yang sama.
  bool hasSameInputsAs(BrewCalculation? other) =>
      other != null &&
      other.coffeeGrams == coffeeGrams &&
      other.method == method &&
      other.roast == roast &&
      other.customization == customization;
}

/// Satu catatan seduhan di Brew Journal (disimpan di Hive).
@immutable
class BrewEntry {
  const BrewEntry({
    required this.id,
    required this.createdAt,
    required this.coffeeGrams,
    required this.waterGrams,
    required this.method,
    required this.roast,
    required this.rating,
    required this.tastingNotes,
    required this.brewSeconds,
    this.taste,
    this.flavorTags = const <FlavorTag>[],
    this.grinderSetting = '',
    this.photoName,
    this.beanId,
    this.beanName,
  }) : assert(rating >= 1 && rating <= 5, 'rating harus 1–5');

  final String id;
  final DateTime createdAt;
  final double coffeeGrams;
  final double waterGrams;
  final BrewMethod method;
  final RoastLevel roast;
  final int rating;
  final String tastingNotes;

  /// Durasi seduh yang tercatat oleh timer (0 jika timer tidak dipakai).
  final int brewSeconds;

  /// Kesan rasa untuk asisten dial-in; `null` bila belum dinilai.
  final TasteFeedback? taste;

  /// Tag aroma dan rasa yang dipilih.
  final List<FlavorTag> flavorTags;

  /// Setelan gilingan bebas, mis. "21 klik". Kosong bila tidak dicatat.
  final String grinderSetting;

  /// Nama berkas foto di penyimpanan aplikasi (bukan path penuh).
  final String? photoName;

  /// Biji yang dipakai: id dan nama saat dicatat (nama tetap meski biji
  /// kemudian dihapus).
  final String? beanId;
  final String? beanName;

  /// Rasio air:kopi aktual, mis. 15 untuk 1:15.
  double get ratio => coffeeGrams <= 0 ? 0 : waterGrams / coffeeGrams;

  /// Salinan dengan rating dan/atau tasting notes yang diubah.
  BrewEntry copyWith({
    int? rating,
    String? tastingNotes,
    TasteFeedback? taste,
    bool clearTaste = false,
    List<FlavorTag>? flavorTags,
    String? grinderSetting,
    String? photoName,
    bool clearPhoto = false,
  }) => BrewEntry(
    id: id,
    createdAt: createdAt,
    coffeeGrams: coffeeGrams,
    waterGrams: waterGrams,
    method: method,
    roast: roast,
    rating: rating ?? this.rating,
    tastingNotes: tastingNotes ?? this.tastingNotes,
    brewSeconds: brewSeconds,
    taste: clearTaste ? null : (taste ?? this.taste),
    flavorTags: flavorTags ?? this.flavorTags,
    grinderSetting: grinderSetting ?? this.grinderSetting,
    photoName: clearPhoto ? null : (photoName ?? this.photoName),
    beanId: beanId,
    beanName: beanName,
  );
}

/// Biji kopi di perpustakaan pengguna.
@immutable
class BrewBean {
  const BrewBean({
    required this.id,
    required this.name,
    required this.createdAt,
    this.roaster = '',
    this.origin = '',
    this.roastDate,
  });

  final String id;
  final String name;
  final DateTime createdAt;
  final String roaster;
  final String origin;

  /// Tanggal roasting; `null` bila tidak diketahui.
  final DateTime? roastDate;

  BrewBean copyWith({
    String? name,
    String? roaster,
    String? origin,
    DateTime? roastDate,
    bool clearRoastDate = false,
  }) => BrewBean(
    id: id,
    createdAt: createdAt,
    name: name ?? this.name,
    roaster: roaster ?? this.roaster,
    origin: origin ?? this.origin,
    roastDate: clearRoastDate ? null : (roastDate ?? this.roastDate),
  );
}

/// Resep favorit yang bisa dimuat ulang ke kalkulator.
@immutable
class BrewRecipe {
  const BrewRecipe({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.coffeeGrams,
    required this.method,
    required this.roast,
    this.customization = const BrewCustomization(),
  });

  final String id;
  final String name;
  final DateTime createdAt;
  final double coffeeGrams;
  final BrewMethod method;
  final RoastLevel roast;
  final BrewCustomization customization;
}
