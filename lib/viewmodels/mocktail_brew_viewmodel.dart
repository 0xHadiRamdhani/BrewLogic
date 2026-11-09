import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/utils/haptics.dart';
import '../models/mocktail_model.dart';
import '../services/brew_timer_service.dart';
import '../services/timer_alerts.dart';
import 'brew_viewmodel.dart' show BrewTimerStatus;
import 'settings_viewmodel.dart';

/// Timer "Mulai Buat Mocktail": langkah berjalan otomatis menurut durasinya
/// (seperti timer kopi), dengan jeda, reset, lompat ke langkah tertentu, dan
/// pengulangan per gelas.
class MocktailBrewViewModel extends ChangeNotifier {
  MocktailBrewViewModel({
    required this.blend,
    required this._alerts,
    this._prefs = const DefaultTimerPrefs(),
  }) {
    _timer = BrewTimerService(
      onTick: _handleTick,
      // Rapat agar animasi gelas terisi mulus.
      tickInterval: const Duration(milliseconds: 33),
    );
  }

  final MocktailBlend blend;
  final TimerAlerts _alerts;
  final TimerPrefs _prefs;
  late final BrewTimerService _timer;

  final ValueNotifier<Duration> _elapsed = ValueNotifier<Duration>(
    Duration.zero,
  );
  BrewTimerStatus _status = BrewTimerStatus.idle;
  int _stepIndex = 0;

  /// Waktu langkah yang dilompati; ditambahkan ke waktu stopwatch.
  Duration _offset = Duration.zero;
  int _glass = 0;
  final Set<int> _checked = <int>{};
  bool _disposed = false;

  // --- Status -------------------------------------------------------------

  BrewTimerStatus get status => _status;
  int get currentStepIndex => _stepIndex;
  MocktailStep get currentStep => blend.stepDetails[_stepIndex];
  int get stepCount => blend.stepDetails.length;
  Duration get total => Duration(seconds: blend.totalSeconds);

  /// Waktu berjalan untuk gelas ini; dengarkan dengan
  /// `ValueListenableBuilder`.
  ValueListenable<Duration> get elapsed => _elapsed;

  int get glassCount => blend.spec.servings;

  /// Nomor gelas yang sedang dibuat, mulai 1.
  int get glassNumber => _glass + 1;
  bool get hasNextGlass => _glass < glassCount - 1;

  // --- Persiapan bahan ----------------------------------------------------

  /// Bahan per gelas, lalu gelas dan alatnya.
  List<MocktailPrepItem> get prepItems => <MocktailPrepItem>[
    for (final MocktailIngredient i in blend.ingredients)
      MocktailPrepItem(i.name, '${_fmt(i.perServing)} ${i.unit}', i.color),
    MocktailPrepItem('Gelas', '${blend.spec.glassMl} ml'),
    MocktailPrepItem(
      blend.spec.method == MocktailMethod.shake ? 'Shaker' : 'Sendok bar',
      '',
    ),
  ];

  static String _fmt(double v) =>
      v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  int get checkedCount => _checked.length;
  bool isChecked(int index) => _checked.contains(index);
  bool get allChecked => _checked.length >= prepItems.length;

  void toggleChecked(int index) {
    if (!_checked.add(index)) {
      _checked.remove(index);
    }
    Haptics.selection();
    notifyListeners();
  }

  // --- Timer --------------------------------------------------------------

  void start() {
    if (_status == BrewTimerStatus.running) {
      return;
    }
    if (_status == BrewTimerStatus.finished) {
      _resetState();
    }
    _status = BrewTimerStatus.running;
    _timer.start();
    Haptics.light();
    _armKeepAwake();
    notifyListeners();
  }

  void pause() {
    if (_status != BrewTimerStatus.running) {
      return;
    }
    _timer.pause();
    _status = BrewTimerStatus.paused;
    Haptics.selection();
    notifyListeners();
  }

  void toggle() {
    switch (_status) {
      case BrewTimerStatus.idle:
      case BrewTimerStatus.finished:
      case BrewTimerStatus.paused:
        start();
      case BrewTimerStatus.running:
        pause();
    }
  }

  void reset() {
    if (_status == BrewTimerStatus.idle && _elapsed.value == Duration.zero) {
      return;
    }
    _resetState();
    notifyListeners();
  }

  /// Lompat ke awal langkah [index] dan langsung berjalan.
  void jumpTo(int index) {
    if (index < 0 || index >= stepCount) {
      return;
    }
    _timer.reset();
    _offset = blend.stepStartOf(index);
    _elapsed.value = _offset;
    _stepIndex = index;
    _status = BrewTimerStatus.running;
    _timer.start();
    Haptics.medium();
    _armKeepAwake();
    notifyListeners();
  }

  /// Gelas berikutnya: timer kembali ke awal (bahan sudah siap).
  void nextGlass() {
    if (!hasNextGlass) {
      return;
    }
    _glass++;
    _resetState();
    Haptics.light();
    notifyListeners();
  }

  void _resetState() {
    _timer.reset();
    _offset = Duration.zero;
    _elapsed.value = Duration.zero;
    _stepIndex = 0;
    _status = BrewTimerStatus.idle;
    _releaseKeepAwake();
  }

  void _armKeepAwake() {
    if (_prefs.keepAwakeEnabled) {
      unawaited(_alerts.setKeepAwake(enabled: true));
    }
  }

  void _releaseKeepAwake() {
    unawaited(_alerts.setKeepAwake(enabled: false));
  }

  void _handleTick(Duration swElapsed) {
    if (_disposed) {
      return;
    }
    final Duration now = _offset + swElapsed;
    if (now >= total) {
      _timer.pause();
      _elapsed.value = total;
      _stepIndex = stepCount - 1;
      _status = BrewTimerStatus.finished;
      Haptics.heavy();
      _releaseKeepAwake();
      if (_prefs.soundEnabled) {
        unawaited(_alerts.playDoneCue());
      }
      notifyListeners();
      return;
    }
    _elapsed.value = now;
    final int index = blend.stepIndexAt(now);
    if (index != _stepIndex) {
      _stepIndex = index;
      Haptics.medium();
      if (_prefs.soundEnabled) {
        unawaited(_alerts.playPhaseCue());
      }
      notifyListeners();
    }
  }

  /// Hanya untuk pengujian: mensimulasikan waktu stopwatch yang sudah berjalan.
  @visibleForTesting
  void debugTick(Duration stopwatchElapsed) => _handleTick(stopwatchElapsed);

  @override
  void dispose() {
    _disposed = true;
    _releaseKeepAwake();
    _timer.dispose();
    _elapsed.dispose();
    super.dispose();
  }
}

/// Satu baris daftar persiapan.
@immutable
class MocktailPrepItem {
  const MocktailPrepItem(this.name, this.amount, [this.color]);

  final String name;

  /// Takaran per gelas; kosong untuk alat.
  final String amount;
  final int? color;
}
