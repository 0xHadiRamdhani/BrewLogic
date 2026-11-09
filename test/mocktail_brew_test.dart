import 'dart:convert';
import 'dart:io';

import 'package:brewlogic/models/mocktail_model.dart';
import 'package:brewlogic/services/mocktail_scene.dart';
import 'package:brewlogic/services/mocktail_service.dart';
import 'package:brewlogic/services/timer_alerts.dart';
import 'package:brewlogic/viewmodels/brew_viewmodel.dart' show BrewTimerStatus;
import 'package:brewlogic/viewmodels/mocktail_brew_viewmodel.dart';
import 'package:brewlogic/viewmodels/mocktail_viewmodel.dart';
import 'package:brewlogic/viewmodels/settings_viewmodel.dart';
import 'package:brewlogic/views/widgets/mocktail_timer_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Alerts extends NoopTimerAlerts {
  _Alerts();

  final List<String> calls = <String>[];

  @override
  Future<void> setKeepAwake({required bool enabled}) async =>
      calls.add('awake:$enabled');

  @override
  Future<void> playPhaseCue() async => calls.add('phase');

  @override
  Future<void> playDoneCue() async => calls.add('done');
}

class _Prefs implements TimerPrefs {
  const _Prefs({this.awake = true});

  final bool awake;

  @override
  bool get soundEnabled => true;

  @override
  bool get keepAwakeEnabled => awake;

  @override
  bool get notifyEnabled => false;
}

MocktailBlend _blend({
  int servings = 1,
  MocktailMethod method = MocktailMethod.build,
}) => const MocktailService().calculate(
  MocktailViewModel.defaultSpec.copyWith(servings: servings, method: method),
)!;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('langkah dan durasi', () {
    test('build: urutan, jenis, dan durasi (total 50 detik)', () {
      final MocktailBlend blend = _blend();
      expect(
        blend.stepDetails.map((MocktailStep s) => s.kind),
        <MocktailStepKind>[
          MocktailStepKind.ice,
          MocktailStepKind.syrup,
          MocktailStepKind.citrus,
          MocktailStepKind.stir,
          MocktailStepKind.base,
          MocktailStepKind.garnish,
        ],
      );
      expect(
        blend.stepDetails.map((MocktailStep s) => s.durationSeconds),
        <int>[8, 8, 6, 5, 15, 8],
      );
      expect(blend.totalSeconds, 50);
    });

    test('kocok: mixIn, shake, strain lalu bahan dasar dan hiasan', () {
      final MocktailBlend blend = _blend(method: MocktailMethod.shake);
      expect(
        blend.stepDetails.map((MocktailStep s) => s.kind).take(3),
        <MocktailStepKind>[
          MocktailStepKind.mixIn,
          MocktailStepKind.shake,
          MocktailStepKind.strain,
        ],
      );
      expect(
        blend.stepDetails.any(
          (MocktailStep s) => s.kind == MocktailStepKind.ice,
        ),
        isFalse,
      );
      expect(
        blend.stepDetails
            .firstWhere((MocktailStep s) => s.kind == MocktailStepKind.shake)
            .durationSeconds,
        12,
      );
    });

    test('bahan dasar tanpa karbonasi dituang lebih singkat', () {
      final MocktailBlend water = const MocktailService().calculate(
        MocktailViewModel.defaultSpec.copyWith(base: MocktailBase.water),
      )!;
      expect(
        water.stepDetails
            .firstWhere((MocktailStep s) => s.kind == MocktailStepKind.base)
            .durationSeconds,
        10,
      );
    });

    test('waktu mulai dan indeks langkah pada batas waktu', () {
      final MocktailBlend blend = _blend();
      expect(blend.stepStartOf(0), Duration.zero);
      expect(blend.stepStartOf(3), const Duration(seconds: 22));
      expect(blend.stepIndexAt(Duration.zero), 0);
      expect(blend.stepIndexAt(const Duration(milliseconds: 7999)), 0);
      expect(blend.stepIndexAt(const Duration(seconds: 8)), 1);
      expect(blend.stepIndexAt(const Duration(seconds: 49)), 5);
      expect(blend.stepIndexAt(const Duration(seconds: 99)), 5);
    });

    test('teks "ulangi" hanya di daftar ringkas, bukan di panduan', () {
      final MocktailBlend blend = _blend(servings: 3);
      expect(blend.steps.length, blend.stepDetails.length + 1);
      expect(blend.steps.last, contains('3 porsi'));
    });
  });

  group('adegan animasi gelas', () {
    test('berkas mocktail.json cocok dengan konstanta Dart', () {
      final Map<String, dynamic> json = jsonDecode(
        File(MocktailScene.asset).readAsStringSync(),
      ) as Map<String, dynamic>;
      expect(json['op'], MocktailScene.totalFrames);
      expect(json['fr'], MocktailScene.fps);
      final Set<String> names = (json['layers'] as List<dynamic>)
          .map((dynamic l) => (l as Map<String, dynamic>)['nm'] as String)
          .toSet();
      expect(
        names,
        containsAll(<String>[
          'base',
          'syrup',
          'ice',
          'citrus',
          'bubbles',
          'spoon',
          'shaker',
          'garnish-lime',
          'garnish-mint',
          'garnish-lemon',
          'garnish-berries',
          'garnish-cucumber',
        ]),
      );
      // Semua segmen berada dalam rentang animasi dan berurutan.
      for (final MocktailSegment seg in MocktailScene.segments.values) {
        expect(seg.from, lessThan(seg.to));
        expect(seg.to, lessThanOrEqualTo(MocktailScene.totalFrames));
      }
    });

    test('frame mengikuti waktu: awal, tengah langkah, dan selesai', () {
      final MocktailBlend build = _blend();
      // Langkah pertama = es (frame 80-105, 8 detik).
      expect(MocktailScene.frameAt(build, Duration.zero), 80);
      expect(
        MocktailScene.frameAt(build, const Duration(seconds: 4)),
        closeTo(92.5, 1e-9),
      );
      // Langkah sirup (detik 8-16) mulai di frame 105.
      expect(MocktailScene.frameAt(build, const Duration(seconds: 8)), 105);
      expect(
        MocktailScene.frameAt(build, const Duration(seconds: 50)),
        MocktailScene.totalFrames,
      );
    });

    test('aduk berulang di frame 155-180 selama langkahnya', () {
      final MocktailBlend build = _blend();
      // Aduk dimulai di detik 22 (8+8+6).
      for (int ms = 0; ms < 5000; ms += 250) {
        final double f = MocktailScene.frameAt(
          build,
          Duration(seconds: 22, milliseconds: ms),
        );
        expect(f, inInclusiveRange(155, 180));
      }
      // Satu putaran (25 frame / 30 fps) lalu kembali ke awal siklus.
      final double a = MocktailScene.frameAt(
        build,
        const Duration(seconds: 22, milliseconds: 100),
      );
      final double b = MocktailScene.frameAt(
        build,
        const Duration(seconds: 22, milliseconds: 100 + 833),
      );
      expect(b - a, closeTo(0, 0.2));
    });

    test('mode kocok mulai dari shaker masuk (frame 0)', () {
      final MocktailBlend shake = _blend(method: MocktailMethod.shake);
      expect(MocktailScene.frameAt(shake, Duration.zero), 0);
    });

    test('warna sirup dirata-ratakan menurut bagian', () {
      const MocktailSpec one = MocktailSpec(
        syrups: <MocktailSyrup>[MocktailSyrup('Grenadine')],
      );
      expect(
        MocktailScene.syrupColor(one).toARGB32(),
        SyrupPresets.byName('Grenadine')!.color,
      );
      const MocktailSpec mix = MocktailSpec(
        syrups: <MocktailSyrup>[
          MocktailSyrup('Blue curaçao'),
          MocktailSyrup('Markisa', parts: 3),
        ],
      );
      final Color c = MocktailScene.syrupColor(mix);
      // Markisa (kuning) 3 bagian dominan atas biru 1 bagian.
      expect(c.r, greaterThan(c.b));
      expect(
        MocktailScene.syrupColor(const MocktailSpec()).toARGB32(),
        0xFFD9A566,
      );
    });
  });

  group('MocktailBrewViewModel', () {
    testWidgets('mulai, langkah berganti dengan bunyi, jeda, dan reset', (
      WidgetTester tester,
    ) async {
      final _Alerts alerts = _Alerts();
      final MocktailBrewViewModel vm = MocktailBrewViewModel(
        blend: _blend(),
        alerts: alerts,
      );
      addTearDown(vm.dispose);

      expect(vm.status, BrewTimerStatus.idle);
      expect(vm.currentStepIndex, 0);

      vm.start();
      expect(vm.status, BrewTimerStatus.running);
      expect(alerts.calls, contains('awake:true'));

      vm.debugTick(const Duration(seconds: 3));
      expect(vm.elapsed.value, const Duration(seconds: 3));
      expect(vm.currentStepIndex, 0);
      expect(alerts.calls, isNot(contains('phase')));

      vm.debugTick(const Duration(milliseconds: 8500));
      expect(vm.currentStepIndex, 1);
      expect(alerts.calls.where((String c) => c == 'phase'), hasLength(1));

      vm.pause();
      expect(vm.status, BrewTimerStatus.paused);
      vm.toggle();
      expect(vm.status, BrewTimerStatus.running);

      vm.reset();
      expect(vm.status, BrewTimerStatus.idle);
      expect(vm.elapsed.value, Duration.zero);
      expect(vm.currentStepIndex, 0);
      expect(alerts.calls.last, 'awake:false');
    });

    testWidgets('lompat ke langkah memulai dari awal langkah itu', (
      WidgetTester tester,
    ) async {
      final MocktailBrewViewModel vm = MocktailBrewViewModel(
        blend: _blend(),
        alerts: _Alerts(),
      );

      vm.jumpTo(3); // Aduk
      expect(vm.status, BrewTimerStatus.running);
      expect(vm.currentStep.kind, MocktailStepKind.stir);
      expect(vm.elapsed.value, const Duration(seconds: 22));

      // Waktu stopwatch dihitung dari titik lompat.
      vm.debugTick(const Duration(seconds: 2));
      expect(vm.elapsed.value, const Duration(seconds: 24));
      expect(vm.currentStepIndex, 3);

      vm.jumpTo(99); // di luar batas diabaikan
      vm.jumpTo(-1);
      expect(vm.currentStepIndex, 3);
      vm.dispose(); // membatalkan timer berulang
    });

    testWidgets('selesai: bunyi, layar dilepas, dan bisa diulang', (
      WidgetTester tester,
    ) async {
      final _Alerts alerts = _Alerts();
      final MocktailBrewViewModel vm = MocktailBrewViewModel(
        blend: _blend(),
        alerts: alerts,
      );

      vm.start();
      vm.debugTick(const Duration(seconds: 51));
      expect(vm.status, BrewTimerStatus.finished);
      expect(vm.elapsed.value, vm.total);
      expect(vm.currentStepIndex, vm.stepCount - 1);
      expect(
        alerts.calls,
        containsAllInOrder(<String>['awake:true', 'awake:false', 'done']),
      );

      vm.start(); // dari selesai: mulai ulang
      expect(vm.status, BrewTimerStatus.running);
      expect(vm.elapsed.value, Duration.zero);
      vm.dispose(); // membatalkan timer berulang
    });

    testWidgets('banyak gelas: gelas berikutnya mulai dari nol', (
      WidgetTester tester,
    ) async {
      final MocktailBrewViewModel vm = MocktailBrewViewModel(
        blend: _blend(servings: 2),
        alerts: _Alerts(),
      );
      addTearDown(vm.dispose);

      expect(vm.glassCount, 2);
      expect(vm.glassNumber, 1);
      expect(vm.hasNextGlass, isTrue);
      vm.start();
      vm.debugTick(const Duration(seconds: 60));
      expect(vm.status, BrewTimerStatus.finished);

      vm.nextGlass();
      expect(vm.glassNumber, 2);
      expect(vm.status, BrewTimerStatus.idle);
      expect(vm.elapsed.value, Duration.zero);
      expect(vm.hasNextGlass, isFalse);
      vm.nextGlass(); // sudah gelas terakhir
      expect(vm.glassNumber, 2);
    });

    testWidgets('layar menyala mengikuti pengaturan dan dilepas saat ditutup', (
      WidgetTester tester,
    ) async {
      final _Alerts on = _Alerts();
      final MocktailBrewViewModel a = MocktailBrewViewModel(
        blend: _blend(),
        alerts: on,
      )..start();
      a.dispose();
      expect(on.calls, <String>['awake:true', 'awake:false']);

      final _Alerts off = _Alerts();
      final MocktailBrewViewModel b = MocktailBrewViewModel(
        blend: _blend(),
        alerts: off,
        prefs: const _Prefs(awake: false),
      )..start();
      b.dispose();
      expect(off.calls, <String>['awake:false']);
    });

    testWidgets('daftar persiapan dan centang', (WidgetTester tester) async {
      final MocktailBrewViewModel vm = MocktailBrewViewModel(
        blend: _blend(),
        alerts: _Alerts(),
      );
      addTearDown(vm.dispose);

      // 4 bahan (sirup, jeruk, soda, es) + gelas + sendok bar.
      expect(vm.prepItems, hasLength(6));
      expect(vm.prepItems.last.name, 'Sendok bar');
      expect(vm.allChecked, isFalse);
      for (int i = 0; i < 6; i++) {
        vm.toggleChecked(i);
      }
      expect(vm.allChecked, isTrue);
      vm.toggleChecked(0);
      expect(vm.isChecked(0), isFalse);
      expect(vm.checkedCount, 5);

      final MocktailBrewViewModel shake = MocktailBrewViewModel(
        blend: _blend(method: MocktailMethod.shake),
        alerts: _Alerts(),
      );
      addTearDown(shake.dispose);
      expect(shake.prepItems.last.name, 'Shaker');
    });
  });

  Widget host(MocktailBlend? blend) => MaterialApp(
    home: Scaffold(
      body: MocktailTimerView(
        blend: blend,
        alerts: _Alerts(),
        prefs: const _Prefs(),
      ),
    ),
  );

  testWidgets('tab Timer mocktail: mulai, lompat langkah, jeda, dan reset', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 4000);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(host(_blend()));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('SIAP'), findsOneWidget);
    expect(find.text('Mulai'), findsOneWidget);
    expect(find.text('00:08'), findsWidgets); // sisa langkah pertama
    expect(find.text('Total 00:00 / 00:50'), findsOneWidget);
    expect(find.text('Isi es'), findsOneWidget); // daftar langkah
    expect(find.text('Tuang soda'), findsOneWidget);
    expect(find.text('Siapkan bahan'), findsOneWidget);

    await tester.tap(find.text('Mulai'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('ISI ES'), findsOneWidget);
    expect(find.text('Jeda'), findsOneWidget);

    await tester.tap(find.text('Aduk'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('ADUK'), findsOneWidget);
    expect(find.text('Aduk 5 detik hingga sirup larut.'), findsOneWidget);

    await tester.tap(find.text('Jeda'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Lanjutkan'), findsOneWidget);
    expect(find.text('DIJEDA · ADUK'), findsOneWidget);

    await tester.tap(find.text('Reset'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('SIAP'), findsOneWidget);
    expect(find.text('Mulai'), findsOneWidget);

    // Lepas tampilan agar timer berulang dibatalkan.
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('timer tetap berjalan bila resep sama, diatur ulang bila beda', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 4000);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(host(_blend()));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.text('Mulai'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Jeda'), findsOneWidget);

    // Hasil hitungan baru dengan resep yang sama (mis. rebuild induk).
    await tester.pumpWidget(host(_blend()));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Jeda'), findsOneWidget);

    // Resep berubah: timer baru, kembali ke siap.
    await tester.pumpWidget(host(_blend(servings: 2)));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('SIAP'), findsOneWidget);
    expect(find.text('Mulai'), findsOneWidget);
    expect(find.text('Gelas 1/2'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('resep belum valid menampilkan petunjuk, bukan timer', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(host(null));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.textContaining('minimal satu sirup'), findsOneWidget);
    expect(find.text('Mulai'), findsNothing);

    // Resep menjadi valid lalu hilang lagi: timer dibuat dan dibuang.
    await tester.pumpWidget(host(_blend()));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Mulai'), findsOneWidget);
    await tester.pumpWidget(host(null));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Mulai'), findsNothing);
  });

  test('MocktailSpec: kesetaraan nilai untuk daftar sirup dan hiasan', () {
    final MocktailSpec a = MocktailViewModel.defaultSpec;
    final MocktailSpec b = a.copyWith();
    expect(a == b, isTrue);
    expect(a.hashCode, b.hashCode);
    expect(a == a.copyWith(servings: 2), isFalse);
    expect(
      a ==
          a.copyWith(
            syrups: const <MocktailSyrup>[MocktailSyrup('Grenadine', parts: 2)],
          ),
      isFalse,
    );
    expect(
      a == a.copyWith(garnishes: const <MocktailGarnish>{MocktailGarnish.mint}),
      isFalse,
    );
  });
}
