import 'package:flutter/foundation.dart';

/// Memungkinkan halaman mana pun meminta pindah tab di `MainShell`.
class ShellNavigation extends ChangeNotifier {
  static const int calculator = 0;
  static const int timer = 1;
  static const int journal = 2;
  static const int settings = 3;

  int _requestedTab = calculator;
  int _requestId = 0;

  /// Tab yang terakhir diminta.
  int get requestedTab => _requestedTab;

  /// Bertambah setiap permintaan, sehingga permintaan ke tab yang sama
  /// berulang tetap terdeteksi.
  int get requestId => _requestId;

  void goTo(int tab) {
    _requestedTab = tab;
    _requestId++;
    notifyListeners();
  }
}
