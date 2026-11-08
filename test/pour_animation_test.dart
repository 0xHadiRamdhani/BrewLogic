import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';

import 'package:brewlogic/viewmodels/brew_viewmodel.dart';
import 'package:brewlogic/views/widgets/pour_animation.dart';

Widget _host(BrewTimerStatus status, {bool reduceMotion = false}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: Scaffold(body: PourAnimation(status: status)),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('berkas pour.json valid: 240x225, 150 frame, ada aliran dan uap', () {
    final Map<String, dynamic> json =
        jsonDecode(File(PourAnimation.asset).readAsStringSync())
            as Map<String, dynamic>;
    expect(json['w'], 240);
    expect(json['h'], 225);
    expect(json['op'], 150);
    final List<String> names = (json['layers'] as List<dynamic>)
        .map((dynamic l) => (l as Map<String, dynamic>)['nm'] as String)
        .toList();
    expect(names, containsAll(<String>['stream', 'kettle', 'steam-a']));
  });

  testWidgets('animasi Lottie dimuat dan mengikuti status timer', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_host(BrewTimerStatus.idle));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(LottieBuilder), findsOneWidget);

    for (final BrewTimerStatus status in <BrewTimerStatus>[
      BrewTimerStatus.running,
      BrewTimerStatus.paused,
      BrewTimerStatus.running,
      BrewTimerStatus.finished,
    ]) {
      await tester.pumpWidget(_host(status));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
    }

    // Lepas widget agar controller berulang dibuang tanpa kebocoran ticker.
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('mode kurangi gerakan tidak menjalankan animasi berulang', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_host(BrewTimerStatus.running, reduceMotion: true));
    await tester.pump(const Duration(milliseconds: 200));
    // Tidak ada frame terjadwal -> pumpAndSettle selesai (tidak menggantung).
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
