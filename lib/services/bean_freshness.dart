/// Tahap kesegaran biji sejak tanggal roasting.
enum FreshnessStage { resting, peak, good, fading }

class BeanFreshness {
  const BeanFreshness({
    required this.daysSinceRoast,
    required this.stage,
    required this.label,
    required this.tip,
  });

  final int daysSinceRoast;
  final FreshnessStage stage;
  final String label;
  final String tip;

  /// Teks ringkas, mis. "Hari ke-12 · Puncak rasa".
  String get summary => 'Hari ke-$daysSinceRoast · $label';
}

/// Menilai kesegaran biji dari tanggal roasting (aturan umum untuk seduh
/// manual: puncak rasa sekitar 5–21 hari setelah roasting).
class BeanFreshnessService {
  const BeanFreshnessService();

  static const int restingUntilDay = 4;
  static const int peakUntilDay = 21;
  static const int goodUntilDay = 35;

  /// `null` jika [roastDate] tidak diketahui.
  BeanFreshness? evaluate(DateTime? roastDate, DateTime now) {
    if (roastDate == null) {
      return null;
    }
    final DateTime roast = DateTime(
      roastDate.year,
      roastDate.month,
      roastDate.day,
    );
    final DateTime today = DateTime(now.year, now.month, now.day);
    final int days = today.difference(roast).inDays.clamp(0, 100000);

    if (days <= restingUntilDay) {
      return BeanFreshness(
        daysSinceRoast: days,
        stage: FreshnessStage.resting,
        label: 'Masih istirahat',
        tip:
            'Biji masih mengeluarkan gas. Bloom lebih lama (+10 detik) '
            'membantu hasil lebih merata.',
      );
    }
    if (days <= peakUntilDay) {
      return BeanFreshness(
        daysSinceRoast: days,
        stage: FreshnessStage.peak,
        label: 'Puncak rasa',
        tip: 'Waktu terbaik untuk menyeduh biji ini.',
      );
    }
    if (days <= goodUntilDay) {
      return BeanFreshness(
        daysSinceRoast: days,
        stage: FreshnessStage.good,
        label: 'Masih bagus',
        tip:
            'Rasa mulai lebih mellow. Bila terasa hambar, giling sedikit '
            'lebih halus.',
      );
    }
    return BeanFreshness(
      daysSinceRoast: days,
      stage: FreshnessStage.fading,
      label: 'Mulai menurun',
      tip:
          'Habiskan segera. Suhu air sedikit lebih tinggi bisa membantu '
          'menggali rasa.',
    );
  }
}
