import 'dart:async';

/// Mesin stopwatch berbasis [Stopwatch] (monotonic) sehingga waktu tetap akurat
/// walau frame terlewat. Tidak mengenal fase seduh; itu urusan ViewModel.
class BrewTimerService {
  BrewTimerService({
    required this._onTick,
    this._tickInterval = const Duration(milliseconds: 100),
  });

  final void Function(Duration elapsed) _onTick;
  final Duration _tickInterval;
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _ticker;

  Duration get elapsed => _stopwatch.elapsed;
  bool get isRunning => _stopwatch.isRunning;

  /// Memulai atau melanjutkan penghitungan. Aman dipanggil berulang.
  void start() {
    if (_stopwatch.isRunning) {
      return;
    }
    _stopwatch.start();
    _ticker?.cancel();
    _ticker = Timer.periodic(_tickInterval, (_) => _onTick(_stopwatch.elapsed));
  }

  /// Menghentikan sementara tanpa menghapus waktu yang sudah berjalan.
  void pause() {
    _stopwatch.stop();
    _ticker?.cancel();
    _ticker = null;
  }

  /// Menghentikan dan mengembalikan waktu ke nol.
  void reset() {
    pause();
    _stopwatch.reset();
  }

  void dispose() {
    _ticker?.cancel();
    _ticker = null;
    _stopwatch.stop();
  }
}
