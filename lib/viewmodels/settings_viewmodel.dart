import 'package:flutter/foundation.dart';

import '../core/theme/app_theme.dart';
import '../core/utils/haptics.dart';
import '../services/journal_repository.dart';

/// Pilihan ukuran teks aplikasi.
enum TextSizeOption {
  small('Kecil', 0.92),
  normal('Normal', 1),
  large('Besar', 1.14);

  const TextSizeOption(this.label, this.factor);

  final String label;
  final double factor;
}

/// Preferensi timer yang dibaca [BrewViewModel] setiap kali timer berjalan.
abstract interface class TimerPrefs {
  bool get soundEnabled;
  bool get keepAwakeEnabled;
  bool get notifyEnabled;
}

/// Semua preferensi timer aktif; nilai bawaan di tes.
class DefaultTimerPrefs implements TimerPrefs {
  const DefaultTimerPrefs();

  @override
  bool get soundEnabled => true;

  @override
  bool get keepAwakeEnabled => true;

  @override
  bool get notifyEnabled => true;
}

/// ViewModel Pengaturan: haptic serta suara, layar menyala, dan notifikasi
/// timer. Semuanya tersimpan di Hive.
class SettingsViewModel extends ChangeNotifier implements TimerPrefs {
  SettingsViewModel({required this._repository}) {
    _hapticsEnabled = _repository.hapticsEnabled;
    _soundEnabled = _repository.readFlag(_soundKey, fallback: true);
    _keepAwakeEnabled = _repository.readFlag(_keepAwakeKey, fallback: true);
    _notifyEnabled = _repository.readFlag(_notifyKey, fallback: true);
    _useFahrenheit = _repository.readFlag(_fahrenheitKey, fallback: false);
    Haptics.enabled = _hapticsEnabled;
    final int savedSize = _repository.readInt(_textSizeKey, fallback: 1);
    _textSize = savedSize >= 0 && savedSize < TextSizeOption.values.length
        ? TextSizeOption.values[savedSize]
        : TextSizeOption.normal;
    TextScalePrefs.factor.value = _textSize.factor;
  }

  static const String _soundKey = 'timerSound';
  static const String _keepAwakeKey = 'timerKeepAwake';
  static const String _notifyKey = 'timerNotify';
  static const String _fahrenheitKey = 'useFahrenheit';
  static const String _textSizeKey = 'textSize';

  final JournalRepository _repository;
  late bool _hapticsEnabled;
  late bool _soundEnabled;
  late bool _keepAwakeEnabled;
  late bool _notifyEnabled;
  late bool _useFahrenheit;
  late TextSizeOption _textSize;

  bool get hapticsEnabled => _hapticsEnabled;

  TextSizeOption get textSize => _textSize;

  void setTextSize(TextSizeOption option) {
    if (option == _textSize) {
      return;
    }
    _textSize = option;
    TextScalePrefs.factor.value = option.factor;
    _repository.writeInt(_textSizeKey, value: option.index);
    Haptics.selection();
    notifyListeners();
  }

  @override
  bool get soundEnabled => _soundEnabled;

  @override
  bool get keepAwakeEnabled => _keepAwakeEnabled;

  @override
  bool get notifyEnabled => _notifyEnabled;

  /// Tampilkan suhu dalam °F (bawaan °C).
  bool get useFahrenheit => _useFahrenheit;

  void setHaptics({required bool value}) {
    if (value == _hapticsEnabled) {
      return;
    }
    _hapticsEnabled = value;
    Haptics.enabled = value;
    if (value) {
      Haptics.selection();
    }
    _repository.setHapticsEnabled(value: value);
    notifyListeners();
  }

  void setSound({required bool value}) {
    if (value == _soundEnabled) {
      return;
    }
    _soundEnabled = value;
    _repository.writeFlag(_soundKey, value: value);
    Haptics.selection();
    notifyListeners();
  }

  void setKeepAwake({required bool value}) {
    if (value == _keepAwakeEnabled) {
      return;
    }
    _keepAwakeEnabled = value;
    _repository.writeFlag(_keepAwakeKey, value: value);
    Haptics.selection();
    notifyListeners();
  }

  void setFahrenheit({required bool value}) {
    if (value == _useFahrenheit) {
      return;
    }
    _useFahrenheit = value;
    _repository.writeFlag(_fahrenheitKey, value: value);
    Haptics.selection();
    notifyListeners();
  }

  void setNotify({required bool value}) {
    if (value == _notifyEnabled) {
      return;
    }
    _notifyEnabled = value;
    _repository.writeFlag(_notifyKey, value: value);
    Haptics.selection();
    notifyListeners();
  }
}
