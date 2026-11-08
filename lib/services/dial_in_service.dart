import '../core/utils/formatters.dart';
import '../models/brew_model.dart';

/// Hasil asisten dial-in: ringkasan, saran langkah, dan (bila ada) rasio
/// yang disarankan untuk diterapkan ke kalkulator.
class DialInAdvice {
  const DialInAdvice({
    required this.taste,
    required this.summary,
    required this.tips,
    this.suggestedRatio,
  });

  final TasteFeedback taste;
  final String summary;
  final List<String> tips;

  /// Rasio air:kopi yang disarankan, atau `null` bila rasio tidak diubah.
  final double? suggestedRatio;

  bool get hasRatioChange => suggestedRatio != null;
}

/// Aturan sederhana untuk menyetel seduhan berdasarkan kesan rasa.
class DialInService {
  const DialInService();

  /// Suhu air bawaan sebuah roast: titik tengah rentangnya.
  static int baseTempC(RoastLevel roast) =>
      ((roast.minTempC + roast.maxTempC) / 2).round();

  /// Saran untuk seduhan dengan [ratio] dan [brewSeconds] (0 jika tidak
  /// diketahui) yang terasa [taste]. [fahrenheit] hanya memengaruhi teks.
  DialInAdvice advise({
    required TasteFeedback taste,
    required BrewMethod method,
    required RoastLevel roast,
    required double ratio,
    required int brewSeconds,
    bool fahrenheit = false,
  }) {
    final int base = baseTempC(roast);
    String temp(int deltaC) =>
        formatTemp((base + deltaC).clamp(80, 96), fahrenheit: fahrenheit);
    String time(int deltaSeconds) => brewSeconds > 0
        ? 'sekitar ${formatClock(brewSeconds + deltaSeconds)}'
        : '${deltaSeconds.abs()} detik ${deltaSeconds > 0 ? 'lebih lama' : 'lebih singkat'}';

    switch (taste) {
      case TasteFeedback.sour:
        return DialInAdvice(
          taste: taste,
          summary: 'Terasa asam: seduhan kurang terekstraksi.',
          tips: <String>[
            'Giling 1–2 tingkat lebih halus.',
            'Naikkan suhu air menjadi ${temp(2)}.',
            'Perpanjang waktu seduh ${time(12)}.',
          ],
        );
      case TasteFeedback.bitter:
        return DialInAdvice(
          taste: taste,
          summary: 'Terasa pahit: seduhan terlalu terekstraksi.',
          tips: <String>[
            'Giling 1–2 tingkat lebih kasar.',
            'Turunkan suhu air menjadi ${temp(-2)}.',
            'Persingkat waktu seduh ${time(-12)}.',
          ],
        );
      case TasteFeedback.weak:
        final double stronger = _clampRatio(ratio - 1);
        return DialInAdvice(
          taste: taste,
          summary: 'Terasa hambar: seduhan terlalu encer.',
          tips: <String>[
            'Gunakan rasio lebih pekat, ${formatRatio(stronger)}.',
            'Giling sedikit lebih halus.',
            'Pastikan seluruh bubuk basah saat bloom.',
          ],
          suggestedRatio: stronger == ratio ? null : stronger,
        );
      case TasteFeedback.harsh:
        return DialInAdvice(
          taste: taste,
          summary: 'Terasa sepat atau kering: ekstraksi tidak merata.',
          tips: <String>[
            'Tuang lebih pelan dan kurangi pengadukan.',
            'Turunkan suhu air menjadi ${temp(-1)}.',
            'Giling sedikit lebih kasar.',
          ],
        );
      case TasteFeedback.balanced:
        return DialInAdvice(
          taste: taste,
          summary: 'Seimbang. Pertahankan resep ini.',
          tips: <String>[
            'Simpan sebagai resep favorit agar mudah diulang.',
            'Catat setelan gilingan dan sumber biji di tasting notes.',
          ],
        );
    }
  }

  static double _clampRatio(double value) =>
      value.clamp(BrewCustomization.minRatio, BrewCustomization.maxRatio);
}
