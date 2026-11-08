import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/utils/formatters.dart';
import '../core/utils/haptics.dart';

import '../models/brew_model.dart';
import '../services/brew_calculator_service.dart';
import '../services/brew_timer_service.dart';
import '../services/journal_repository.dart';
import '../services/timer_alerts.dart';
import 'settings_viewmodel.dart';

enum BrewTimerStatus { idle, running, paused, finished }

/// ViewModel kalkulator seduh dan timer step-by-step.
///
/// `notifyListeners` hanya dipanggil saat input, status timer, atau fase
/// berubah. Waktu yang berjalan (10x per detik) dipancarkan lewat [elapsed]
/// agar hanya widget yang membutuhkannya yang rebuild.
class BrewViewModel extends ChangeNotifier {
  BrewViewModel({
    required this._repository,
    this._calculator = const BrewCalculatorService(),
    this._alerts = const NoopTimerAlerts(),
    this._prefs = const DefaultTimerPrefs(),
  }) {
    _timer = BrewTimerService(onTick: _handleTick);
    _restoreFromCache();
  }

  final JournalRepository _repository;
  final BrewCalculatorService _calculator;
  final TimerAlerts _alerts;
  final TimerPrefs _prefs;
  late final BrewTimerService _timer;
  final ValueNotifier<Duration> _elapsed = ValueNotifier<Duration>(
    Duration.zero,
  );

  String _gramsText = '';
  String _waterText = '';
  BrewInputMode _inputMode = BrewInputMode.coffee;
  BrewMethod _method = BrewMethod.v60;
  RoastLevel _roast = RoastLevel.medium;
  BrewCustomization _customization = const BrewCustomization();
  BrewCalculation? _calculation;

  BrewTimerStatus _status = BrewTimerStatus.idle;
  int _stepIndex = 0;
  bool _disposed = false;

  // --- Kalkulator -----------------------------------------------------------

  String get gramsText => _gramsText;
  String get waterText => _waterText;
  BrewInputMode get inputMode => _inputMode;
  BrewMethod get method => _method;
  RoastLevel get roast => _roast;

  /// Penyesuaian rasio dan durasi fase dari pengguna.
  BrewCustomization get customization => _customization;

  /// `null` jika input gramasi belum valid.
  BrewCalculation? get calculation => _calculation;

  /// Dipakai sebagai `validator` field gramasi.
  String? validateGrams(String? raw) => _calculator.validateGrams(raw);

  /// Dipakai sebagai `validator` field target air (bergantung pada metode).
  String? validateWater(String? raw) =>
      _calculator.validateWater(raw, _method, ratio: _customization.ratio);

  void updateGrams(String raw) {
    _gramsText = raw;
    _recalculate();
  }

  void updateWater(String raw) {
    _waterText = raw;
    _recalculate();
  }

  void selectInputMode(BrewInputMode value) {
    if (value == _inputMode) {
      return;
    }
    _inputMode = value;
    _recalculate();
  }

  void selectMethod(BrewMethod value) {
    if (value == _method) {
      return;
    }
    _method = value;
    // Bawaan rasio dan durasi berbeda per metode, jadi penyesuaian dibuang.
    _customization = const BrewCustomization();
    _recalculate();
  }

  void selectRoast(RoastLevel value) {
    if (value == _roast) {
      return;
    }
    _roast = value;
    _recalculate();
  }

  // --- Penyesuaian resep ------------------------------------------------------

  /// Mengatur rasio air:kopi; `null` (atau nilai sama dengan bawaan metode)
  /// mengembalikan bawaan.
  void setRatio(double? value) {
    final double? snapped = value == null
        ? null
        : ((value * 2).round() / 2).clamp(
            BrewCustomization.minRatio,
            BrewCustomization.maxRatio,
          );
    _setCustomization(
      _customization.withRatio(snapped == _method.waterRatio ? null : snapped),
    );
  }

  void setBloomSeconds(int? value) {
    final int? clamped = value?.clamp(
      BrewCustomization.minBloomSeconds,
      BrewCustomization.maxBloomSeconds,
    );
    _setCustomization(
      _customization.withBloomSeconds(
        clamped == _method.bloomSeconds ? null : clamped,
      ),
    );
  }

  void setFirstPourSeconds(int? value) {
    final int? clamped = value?.clamp(
      BrewCustomization.minPourSeconds,
      BrewCustomization.maxPourSeconds,
    );
    _setCustomization(
      _customization.withFirstPourSeconds(
        clamped == _method.firstPourSeconds ? null : clamped,
      ),
    );
  }

  void setSecondPourSeconds(int? value) {
    final int? clamped = value?.clamp(
      BrewCustomization.minPourSeconds,
      BrewCustomization.maxPourSeconds,
    );
    _setCustomization(
      _customization.withSecondPourSeconds(
        clamped == _method.secondPourSeconds ? null : clamped,
      ),
    );
  }

  void resetCustomization() => _setCustomization(const BrewCustomization());

  void _setCustomization(BrewCustomization value) {
    if (value == _customization) {
      return;
    }
    _customization = value;
    _recalculate();
  }

  /// Memuat resep favorit ke kalkulator (mode "Dari kopi").
  void applyRecipe(BrewRecipe recipe) {
    _method = recipe.method;
    _roast = recipe.roast;
    _inputMode = BrewInputMode.coffee;
    _gramsText = formatGrams(recipe.coffeeGrams);
    _customization = recipe.customization;
    _recalculate();
  }

  /// Menerapkan seduhan lama dengan rasio hasil saran dial-in.
  void applyAdjustment({
    required BrewMethod method,
    required RoastLevel roast,
    required double coffeeGrams,
    required double ratio,
  }) {
    _method = method;
    _roast = roast;
    _inputMode = BrewInputMode.coffee;
    _gramsText = formatGrams(coffeeGrams);
    _customization = const BrewCustomization().withRatio(
      ((ratio * 2).round() / 2).clamp(
        BrewCustomization.minRatio,
        BrewCustomization.maxRatio,
      ),
    );
    _recalculate();
  }

  void _restoreFromCache() {
    _customization = _repository.cachedCustomization;
    _method = _repository.cachedMethod ?? _method;
    _roast = _repository.cachedRoast ?? _roast;
    _inputMode = _repository.cachedInputMode ?? _inputMode;
    final String cachedGrams = _repository.cachedGrams ?? '';
    if (_calculator.validateGrams(cachedGrams) == null) {
      _gramsText = cachedGrams;
    }
    final String cachedWater = _repository.cachedWater ?? '';
    if (_calculator.validateWater(
          cachedWater,
          _method,
          ratio: _customization.ratio,
        ) ==
        null) {
      _waterText = cachedWater;
    }
    _recalculate(persist: false);
  }

  void _recalculate({bool persist = true}) {
    final BrewCalculation? previous = _calculation;
    final double? grams = _resolveCoffeeGrams();

    _calculation = grams == null
        ? null
        : _calculator.calculate(
            coffeeGrams: grams,
            method: _method,
            roast: _roast,
            customization: _customization,
          );

    // Rencana timer bergantung pada hasil kalkulasi, jadi timer yang sedang
    // berjalan dibatalkan bila input efektif berubah.
    final BrewCalculation? next = _calculation;
    final bool inputsChanged =
        previous == null || next == null || !next.hasSameInputsAs(previous);
    if (_status != BrewTimerStatus.idle && inputsChanged) {
      _resetTimerState();
    }

    if (persist && next != null) {
      unawaited(
        _repository.cacheInputs(
          grams: _gramsText.trim(),
          water: _waterText.trim(),
          inputMode: _inputMode,
          method: _method,
          roast: _roast,
          customization: _customization,
        ),
      );
    }
    notifyListeners();
  }

  /// Gramasi kopi efektif sesuai [inputMode], atau `null` jika input aktif
  /// belum valid.
  double? _resolveCoffeeGrams() {
    switch (_inputMode) {
      case BrewInputMode.coffee:
        return _calculator.validateGrams(_gramsText) == null
            ? _calculator.parseGrams(_gramsText)
            : null;
      case BrewInputMode.water:
        final double? water =
            _calculator.validateWater(
                  _waterText,
                  _method,
                  ratio: _customization.ratio,
                ) ==
                null
            ? _calculator.parseGrams(_waterText)
            : null;
        return water == null
            ? null
            : _calculator.coffeeForWater(
                water,
                _method,
                ratio: _customization.ratio,
              );
    }
  }

  // --- Timer ----------------------------------------------------------------

  BrewTimerStatus get timerStatus => _status;
  int get currentStepIndex => _stepIndex;

  /// Waktu berjalan; dengarkan dengan `ValueListenableBuilder`.
  ValueListenable<Duration> get elapsed => _elapsed;

  bool get canStartTimer => _calculation != null;

  /// Detik seduh yang layak dicatat ke jurnal.
  int get brewedSeconds {
    final BrewCalculation? calc = _calculation;
    if (calc == null) {
      return 0;
    }
    if (_status == BrewTimerStatus.finished) {
      return calc.totalSeconds;
    }
    return _elapsed.value.inSeconds;
  }

  void startTimer() {
    if (_calculation == null || _status == BrewTimerStatus.running) {
      return;
    }
    if (_status == BrewTimerStatus.finished) {
      _resetTimerState();
    }
    _status = BrewTimerStatus.running;
    _timer.start();
    Haptics.light();
    _armAlerts();
    notifyListeners();
  }

  /// Mengaktifkan layar menyala dan menjadwalkan notifikasi selesai sesuai
  /// sisa waktu. Dipanggil setiap timer mulai atau dilanjutkan.
  void _armAlerts() {
    final BrewCalculation? calc = _calculation;
    if (calc == null) {
      return;
    }
    if (_prefs.keepAwakeEnabled) {
      unawaited(_alerts.setKeepAwake(enabled: true));
    }
    if (_prefs.notifyEnabled) {
      final Duration remaining =
          Duration(seconds: calc.totalSeconds) - _timer.elapsed;
      unawaited(_scheduleFinishNotification(calc, remaining));
    }
  }

  Future<void> _scheduleFinishNotification(
    BrewCalculation calc,
    Duration remaining,
  ) async {
    if (!await _alerts.requestNotificationPermission()) {
      return;
    }
    // Hanya jadwalkan jika timer masih berjalan setelah dialog izin.
    if (_status != BrewTimerStatus.running || _disposed) {
      return;
    }
    await _alerts.scheduleFinishNotification(
      // Tambahan 1 detik agar saat aplikasi di depan, penyelesaian dari
      // dalam aplikasi membatalkan notifikasi sebelum sempat tampil.
      after: remaining + const Duration(seconds: 1),
      title: 'Seduhan selesai',
      body:
          '${calc.method.label} · ${formatGrams(calc.coffeeGrams)} g kopi '
          'siap dinikmati.',
    );
  }

  /// Melepas layar menyala dan membatalkan notifikasi terjadwal.
  void _disarmAlerts() {
    unawaited(_alerts.setKeepAwake(enabled: false));
    unawaited(_alerts.cancelFinishNotification());
  }

  void pauseTimer() {
    if (_status != BrewTimerStatus.running) {
      return;
    }
    _timer.pause();
    _elapsed.value = _timer.elapsed;
    _status = BrewTimerStatus.paused;
    _disarmAlerts();
    notifyListeners();
  }

  void resumeTimer() {
    if (_status != BrewTimerStatus.paused) {
      return;
    }
    startTimer();
  }

  /// Tombol utama: mulai → jeda → lanjutkan → ulangi.
  void toggleTimer() {
    switch (_status) {
      case BrewTimerStatus.idle:
      case BrewTimerStatus.finished:
        startTimer();
      case BrewTimerStatus.running:
        pauseTimer();
      case BrewTimerStatus.paused:
        resumeTimer();
    }
  }

  void resetTimer() {
    if (_status == BrewTimerStatus.idle && _elapsed.value == Duration.zero) {
      return;
    }
    _resetTimerState();
    notifyListeners();
  }

  void _resetTimerState() {
    _disarmAlerts();
    _timer.reset();
    _elapsed.value = Duration.zero;
    _stepIndex = 0;
    _status = BrewTimerStatus.idle;
  }

  void _handleTick(Duration elapsed) {
    final BrewCalculation? calc = _calculation;
    if (_disposed || calc == null) {
      return;
    }
    final Duration total = Duration(seconds: calc.totalSeconds);
    if (elapsed >= total) {
      _timer.pause();
      _elapsed.value = total;
      _stepIndex = calc.steps.length - 1;
      _status = BrewTimerStatus.finished;
      Haptics.heavy();
      _disarmAlerts();
      if (_prefs.soundEnabled) {
        unawaited(_alerts.playDoneCue());
      }
      notifyListeners();
      return;
    }

    _elapsed.value = elapsed;
    final int index = calc.stepIndexAt(elapsed);
    if (index != _stepIndex) {
      _stepIndex = index;
      Haptics.medium();
      if (_prefs.soundEnabled) {
        unawaited(_alerts.playPhaseCue());
      }
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _disarmAlerts();
    unawaited(_alerts.dispose());
    _timer.dispose();
    _elapsed.dispose();
    super.dispose();
  }
}
