import 'package:flutter/services.dart';

/// "18" untuk 18.0 dan "18.5" untuk 18.5.
String formatGrams(double value) =>
    value % 1 == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(1);

/// mm:ss dari detik (dibulatkan ke atas oleh pemanggil bila perlu).
String formatClock(int totalSeconds) {
  final int safe = totalSeconds < 0 ? 0 : totalSeconds;
  final String minutes = (safe ~/ 60).toString().padLeft(2, '0');
  final String seconds = (safe % 60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

/// Suhu dari derajat Celsius, mis. "92 °C" atau "198 °F".
String formatTemp(int celsius, {required bool fahrenheit}) =>
    fahrenheit ? '${(celsius * 9 / 5 + 32).round()} °F' : '$celsius °C';

/// Rentang suhu, mis. "90–92 °C" atau "194–198 °F".
String formatTempRange(int minC, int maxC, {required bool fahrenheit}) {
  if (!fahrenheit) {
    return '$minC–$maxC °C';
  }
  final int low = (minC * 9 / 5 + 32).round();
  final int high = (maxC * 9 / 5 + 32).round();
  return '$low–$high °F';
}

const List<String> _months = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'Mei',
  'Jun',
  'Jul',
  'Agu',
  'Sep',
  'Okt',
  'Nov',
  'Des',
];

/// "8 Nov 2026"
String formatDate(DateTime date) =>
    '${date.day} ${_months[date.month - 1]} ${date.year}';

/// "Hari ini", "Kemarin", atau tanggal ("8 Nov 2026"). [now] untuk tes.
String dayLabel(DateTime date, {DateTime? now}) {
  final DateTime today = now ?? DateTime.now();
  final DateTime d0 = DateTime(date.year, date.month, date.day);
  final DateTime t0 = DateTime(today.year, today.month, today.day);
  final int diff = t0.difference(d0).inDays;
  if (diff == 0) {
    return 'Hari ini';
  }
  if (diff == 1) {
    return 'Kemarin';
  }
  return formatDate(date);
}

/// Apakah dua waktu jatuh pada tanggal kalender yang sama.
bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// "8 Nov 2026 · 15:50"
String formatDateTime(DateTime date) {
  final String hh = date.hour.toString().padLeft(2, '0');
  final String mm = date.minute.toString().padLeft(2, '0');
  return '${date.day} ${_months[date.month - 1]} ${date.year} · $hh:$mm';
}

/// Hanya mengizinkan angka dengan satu pemisah desimal (titik atau koma)
/// dan batas digit, sehingga huruf dan simbol tidak pernah masuk ke field.
class DecimalTextInputFormatter extends TextInputFormatter {
  DecimalTextInputFormatter({int maxIntegerDigits = 3, int maxDecimals = 1})
    : _pattern = RegExp(
        '^\\d{0,$maxIntegerDigits}([.,]\\d{0,$maxDecimals})?\$',
      );

  final RegExp _pattern;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) => _pattern.hasMatch(newValue.text) ? newValue : oldValue;
}
