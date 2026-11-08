import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Membuka halaman penuh dengan transisi native: geser dari kanan beserta
/// swipe-back di iOS, transisi Material di Android.
Future<T?> pushPlatformPage<T>(BuildContext context, Widget page) {
  final Route<T> route = PlatformInfo.isIOS
      ? CupertinoPageRoute<T>(builder: (_) => page)
      : MaterialPageRoute<T>(builder: (_) => page);
  return Navigator.of(context).push<T>(route);
}
