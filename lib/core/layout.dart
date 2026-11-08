import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/widgets.dart';

/// Ukuran dan padding layar yang menyesuaikan app bar kaca dan chrome native.
abstract final class AppLayout {
  /// Tinggi isi app bar kaca, di luar inset status bar.
  static const double headerHeight = 68;

  static const double _iosTabBarClearance = 120;

  /// App bar kaca melayang di atas konten, jadi konten diberi inset atas
  /// sebesar status bar + [headerHeight]. Di iOS 26+ tab bar native juga
  /// melayang di bawah konten sehingga butuh ruang bawah ekstra.
  static EdgeInsets screenPadding(
    BuildContext context, {
    bool hasBottomBar = true,
  }) {
    final double top = MediaQuery.paddingOf(context).top + headerHeight + 12;
    final bool underTabBar = PlatformInfo.isIOS26OrHigher();
    return EdgeInsets.fromLTRB(
      16,
      top,
      16,
      hasBottomBar ? (underTabBar ? _iosTabBarClearance : 24) : 40,
    );
  }
}
