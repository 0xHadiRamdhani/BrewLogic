import 'package:brewlogic/views/splash_screen.dart';
import 'package:brewlogic/views/widgets/motion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child, {bool disableAnimations = false}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: child,
    ),
  );
}

/// Timer penundaan harus lebih dulu menjalankan controller; baru frame
/// berikutnya yang memajukan animasi, jadi diperlukan dua `pump`.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(seconds: 2));
}

void main() {
  testWidgets('splash memanggil onFinished setelah durasi habis', (
    WidgetTester tester,
  ) async {
    int finished = 0;
    await tester.pumpWidget(_host(SplashScreen(onFinished: () => finished++)));
    await tester.pump(const Duration(milliseconds: 1800));
    expect(finished, 0);
    await tester.pump(const Duration(milliseconds: 2000));
    expect(finished, 1);
    await tester.pump(const Duration(seconds: 2));
    expect(finished, 1, reason: 'onFinished hanya boleh sekali');
  });

  testWidgets('ketuk melewati splash dan tidak memanggil dua kali', (
    WidgetTester tester,
  ) async {
    int finished = 0;
    await tester.pumpWidget(_host(SplashScreen(onFinished: () => finished++)));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byType(SplashScreen));
    expect(finished, 1);
    await tester.pump(const Duration(seconds: 5));
    expect(finished, 1);
  });

  testWidgets('reduce motion melewati animasi dengan cepat', (
    WidgetTester tester,
  ) async {
    int finished = 0;
    await tester.pumpWidget(
      _host(
        SplashScreen(onFinished: () => finished++),
        disableAnimations: true,
      ),
    );
    await tester.pump(const Duration(milliseconds: 800));
    expect(finished, 1);
  });

  testWidgets('StaggerIn tampil penuh setelah animasi selesai', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _host(const StaggerIn(index: 2, child: Text('halo'))),
    );
    expect(
      tester.widget<Opacity>(find.byType(Opacity)).opacity,
      0,
      reason: 'mulai transparan',
    );
    await _settle(tester);
    expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 1);
  });

  testWidgets('StaggerIn diputar ulang saat tab kembali aktif', (
    WidgetTester tester,
  ) async {
    Widget build({required bool active}) => _host(
      TabActivity(
        active: active,
        child: const StaggerIn(child: Text('halo')),
      ),
    );

    await tester.pumpWidget(build(active: true));
    await _settle(tester);
    expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 1);

    await tester.pumpWidget(build(active: false));
    expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 0);

    await tester.pumpWidget(build(active: true));
    await _settle(tester);
    expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 1);
  });
}
