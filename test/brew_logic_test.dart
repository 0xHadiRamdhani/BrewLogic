import 'dart:io';

import 'package:brewlogic/models/brew_adapters.dart';
import 'package:brewlogic/models/brew_model.dart';
import 'package:brewlogic/services/brew_calculator_service.dart';
import 'package:brewlogic/services/journal_repository.dart';
import 'package:brewlogic/viewmodels/brew_viewmodel.dart';
import 'package:brewlogic/viewmodels/journal_viewmodel.dart';
import 'package:brewlogic/viewmodels/settings_viewmodel.dart';
import 'package:brewlogic/core/utils/haptics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const BrewCalculatorService calc = BrewCalculatorService();

  group('validateGrams', () {
    test('menolak kosong, null, huruf, nol, negatif, dan di luar rentang', () {
      expect(calc.validateGrams(null), isNotNull);
      expect(calc.validateGrams(''), isNotNull);
      expect(calc.validateGrams('   '), isNotNull);
      expect(calc.validateGrams('abc'), isNotNull);
      expect(calc.validateGrams('1e3'), isNotNull);
      expect(calc.validateGrams('NaN'), isNotNull);
      expect(calc.validateGrams('Infinity'), isNotNull);
      expect(calc.validateGrams('0x10'), isNotNull);
      expect(calc.validateGrams('-5'), isNotNull);
      expect(calc.validateGrams('0'), 'Gramasi harus lebih dari 0 g');
      expect(calc.validateGrams('0.0'), 'Gramasi harus lebih dari 0 g');
      expect(calc.validateGrams('0.5'), isNotNull);
      expect(calc.validateGrams('201'), isNotNull);
    });

    test('menerima titik dan koma desimal', () {
      expect(calc.validateGrams('18'), isNull);
      expect(calc.validateGrams('18.5'), isNull);
      expect(calc.validateGrams('18,5'), isNull);
      expect(calc.parseGrams('18,5'), 18.5);
    });
  });

  group('validateWater', () {
    test('menolak input tidak valid dan di luar rentang metode', () {
      expect(calc.validateWater(null, BrewMethod.v60), isNotNull);
      expect(calc.validateWater('', BrewMethod.v60), isNotNull);
      expect(calc.validateWater('abc', BrewMethod.v60), isNotNull);
      expect(calc.validateWater('0', BrewMethod.v60), isNotNull);
      expect(calc.validateWater('10', BrewMethod.v60), isNotNull);
      expect(calc.validateWater('3001', BrewMethod.v60), isNotNull);
      expect(calc.validateWater('250', BrewMethod.v60), isNull);
      expect(calc.validateWater('250,5', BrewMethod.v60), isNull);
      expect(calc.coffeeForWater(250, BrewMethod.v60), closeTo(16.7, 0.001));
    });
  });

  group('calculate', () {
    test('V60 1:15, medium roast, 20 g', () {
      final BrewCalculation c = calc.calculate(
        coffeeGrams: 20,
        method: BrewMethod.v60,
        roast: RoastLevel.medium,
      );
      expect(c.totalWaterGrams, 300);
      expect(c.minTempC, 90);
      expect(c.maxTempC, 92);
      expect(c.grindSize, 'Medium-Fine');
      expect(c.bloomMinGrams, 40);
      expect(c.bloomMaxGrams, 60);
      expect(c.bloomRecommendedGrams, 50);
      expect(c.steps.map((BrewStep s) => s.title), <String>[
        'Bloom',
        'First Pour',
        'Second Pour',
      ]);
      expect(c.steps.last.targetWaterGrams, c.totalWaterGrams);
      final double poured = c.steps.fold<double>(
        0,
        (double sum, BrewStep s) => sum + s.pourGrams,
      );
      expect(poured, closeTo(c.totalWaterGrams, 0.11));
    });

    test('suhu per roasting dan bloom selalu di rentang 2x–3x', () {
      for (final BrewMethod m in BrewMethod.values) {
        for (final RoastLevel r in RoastLevel.values) {
          final BrewCalculation c = calc.calculate(
            coffeeGrams: 17.5,
            method: m,
            roast: r,
          );
          expect(c.bloomRecommendedGrams, inInclusiveRange(35, 52.5));
          expect(m.bloomSeconds, inInclusiveRange(30, 45));
          expect(c.totalSeconds, greaterThan(0));
        }
      }
      expect(RoastLevel.light.tempRangeLabel, '93–95 °C');
      expect(RoastLevel.dark.tempRangeLabel, '85–89 °C');
    });

    test('melempar ArgumentError untuk gramasi tidak valid', () {
      expect(
        () => calc.calculate(
          coffeeGrams: 0,
          method: BrewMethod.v60,
          roast: RoastLevel.light,
        ),
        throwsArgumentError,
      );
    });

    test('stepIndexAt mengikuti durasi tiap fase', () {
      final BrewCalculation c = calc.calculate(
        coffeeGrams: 20,
        method: BrewMethod.v60,
        roast: RoastLevel.light,
      );
      expect(c.stepIndexAt(Duration.zero), 0);
      expect(c.stepIndexAt(const Duration(seconds: 39)), 0);
      expect(c.stepIndexAt(const Duration(seconds: 40)), 1);
      expect(c.stepIndexAt(const Duration(seconds: 90)), 2);
      expect(c.stepIndexAt(const Duration(hours: 1)), 2);
    });
  });

  group('Hive + ViewModel', () {
    late Directory dir;
    late JournalRepository repo;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('brewlogic_test');
      repo = await JournalRepository.open(path: dir.path);
    });

    tearDown(() async {
      await Hive.close();
      await dir.delete(recursive: true);
    });

    test('adapter menyimpan dan membaca ulang BrewEntry', () async {
      final BrewEntry entry = BrewEntry(
        id: 'a1',
        createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
        coffeeGrams: 18.5,
        waterGrams: 277.5,
        method: BrewMethod.chemex,
        roast: RoastLevel.dark,
        rating: 4,
        tastingNotes: 'Cokelat, kacang',
        brewSeconds: 180,
      );
      await repo.save(entry);
      await Hive.close();
      registerBrewAdapters();
      repo = await JournalRepository.open(path: dir.path);

      final BrewEntry loaded = repo.getAll().single;
      expect(loaded.id, 'a1');
      expect(loaded.coffeeGrams, 18.5);
      expect(loaded.method, BrewMethod.chemex);
      expect(loaded.roast, RoastLevel.dark);
      expect(loaded.rating, 4);
      expect(loaded.tastingNotes, 'Cokelat, kacang');
      expect(loaded.brewSeconds, 180);
    });

    test('BrewViewModel menghitung real-time dan mereset timer', () {
      final BrewViewModel vm = BrewViewModel(repository: repo);
      addTearDown(vm.dispose);

      expect(vm.calculation, isNull);
      vm.updateGrams('abc');
      expect(vm.calculation, isNull);
      vm.updateGrams('0');
      expect(vm.calculation, isNull);

      vm.updateGrams('18');
      expect(vm.calculation?.totalWaterGrams, 270);

      vm.startTimer();
      expect(vm.timerStatus, BrewTimerStatus.running);
      vm.pauseTimer();
      expect(vm.timerStatus, BrewTimerStatus.paused);
      vm.resumeTimer();
      expect(vm.timerStatus, BrewTimerStatus.running);

      vm.selectMethod(BrewMethod.chemex);
      expect(vm.timerStatus, BrewTimerStatus.idle);
      expect(vm.calculation?.totalWaterGrams, 288);

      vm.startTimer();
      vm.resetTimer();
      expect(vm.timerStatus, BrewTimerStatus.idle);
      expect(vm.elapsed.value, Duration.zero);
    });

    test('JournalViewModel memvalidasi, menyimpan, dan menghapus', () async {
      final JournalViewModel vm = JournalViewModel(repository: repo);
      final BrewCalculation c = calc.calculate(
        coffeeGrams: 15,
        method: BrewMethod.v60,
        roast: RoastLevel.light,
      );

      expect(
        await vm.saveBrew(
          calculation: c,
          rating: 0,
          tastingNotes: '',
          brewSeconds: 0,
        ),
        isNotNull,
      );
      expect(vm.isEmpty, isTrue);

      expect(
        await vm.saveBrew(
          calculation: c,
          rating: 5,
          tastingNotes: '  floral  ',
          brewSeconds: 150,
        ),
        isNull,
      );
      expect(vm.entries, hasLength(1));
      expect(vm.entries.single.tastingNotes, 'floral');
      expect(vm.averageRating, 5);

      expect(await vm.deleteEntry(vm.entries.single.id), isNull);
      expect(vm.isEmpty, isTrue);
    });

    test('SettingsViewModel menyimpan pengaturan haptic', () async {
      final SettingsViewModel vm = SettingsViewModel(repository: repo);
      expect(vm.hapticsEnabled, isTrue);
      expect(Haptics.enabled, isTrue);

      vm.setHaptics(value: false);
      expect(vm.hapticsEnabled, isFalse);
      expect(Haptics.enabled, isFalse);
      await Future<void>.delayed(Duration.zero);
      expect(repo.hapticsEnabled, isFalse);

      expect(SettingsViewModel(repository: repo).hapticsEnabled, isFalse);
      vm.setHaptics(value: true);
      expect(Haptics.enabled, isTrue);
    });

    test('JournalViewModel.clearAll menghapus semua catatan', () async {
      final JournalViewModel vm = JournalViewModel(repository: repo);
      final BrewCalculation c = calc.calculate(
        coffeeGrams: 20,
        method: BrewMethod.chemex,
        roast: RoastLevel.light,
      );
      for (int i = 0; i < 3; i++) {
        await vm.saveBrew(
          calculation: c,
          rating: 3,
          tastingNotes: '',
          brewSeconds: 0,
        );
        await Future<void>.delayed(const Duration(milliseconds: 2));
      }
      expect(vm.entries, hasLength(3));
      expect(await vm.clearAll(), isNull);
      expect(vm.isEmpty, isTrue);
    });

    test('kalkulator terbalik: target air menjadi gramasi kopi', () {
      final BrewViewModel vm = BrewViewModel(repository: repo);
      addTearDown(vm.dispose);

      vm.selectMethod(BrewMethod.v60);
      vm.selectInputMode(BrewInputMode.water);
      expect(vm.calculation, isNull);

      vm.updateWater('300');
      expect(vm.calculation?.coffeeGrams, 20);
      expect(vm.calculation?.totalWaterGrams, 300);

      vm.selectMethod(BrewMethod.chemex);
      expect(vm.calculation?.coffeeGrams, 18.8);

      vm.updateWater('abc');
      expect(vm.calculation, isNull);
      vm.updateWater('0');
      expect(vm.calculation, isNull);
      vm.updateWater('9');
      expect(vm.calculation, isNull);
      vm.updateWater('99999');
      expect(vm.calculation, isNull);

      vm.selectInputMode(BrewInputMode.coffee);
      vm.updateGrams('18');
      expect(vm.calculation?.coffeeGrams, 18);
    });

    test('jurnal: cari, filter, urutkan, dan ubah catatan', () async {
      final JournalViewModel vm = JournalViewModel(repository: repo);
      Future<void> add(BrewMethod m, int rating, String notes) async {
        await vm.saveBrew(
          calculation: calc.calculate(
            coffeeGrams: 18,
            method: m,
            roast: RoastLevel.medium,
          ),
          rating: rating,
          tastingNotes: notes,
          brewSeconds: 120,
        );
        await Future<void>.delayed(const Duration(milliseconds: 3));
      }

      await add(BrewMethod.v60, 5, 'Floral dan jeruk');
      await add(BrewMethod.chemex, 3, 'Manis karamel');
      await add(BrewMethod.v60, 2, 'Pahit');
      expect(vm.visibleEntries, hasLength(3));
      expect(vm.visibleEntries.first.tastingNotes, 'Pahit', reason: 'terbaru');

      vm.setMethodFilter(BrewMethod.v60);
      expect(vm.visibleEntries, hasLength(2));
      expect(vm.hasActiveFilters, isTrue);

      vm.cycleMinRating(); // 3★ ke atas
      expect(vm.minRating, 3);
      expect(vm.visibleEntries.single.tastingNotes, 'Floral dan jeruk');

      vm.resetFilters();
      expect(vm.hasActiveFilters, isFalse);
      vm.setQuery('KARAMEL');
      expect(vm.visibleEntries.single.method, BrewMethod.chemex);
      vm.setQuery('chemex');
      expect(vm.visibleEntries, hasLength(1));
      vm.setQuery('tidak ada');
      expect(vm.visibleEntries, isEmpty);
      vm.resetFilters();

      vm.cycleSort(); // terlama
      expect(vm.visibleEntries.first.tastingNotes, 'Floral dan jeruk');
      vm.cycleSort(); // rating tertinggi
      expect(vm.visibleEntries.first.rating, 5);
      vm.cycleSort(); // rating terendah
      expect(vm.visibleEntries.first.rating, 2);

      final BrewEntry target = vm.visibleEntries.first;
      expect(
        await vm.updateEntry(id: target.id, rating: 0, tastingNotes: 'x'),
        isNotNull,
      );
      expect(
        await vm.updateEntry(
          id: target.id,
          rating: 4,
          tastingNotes: ' Seimbang ',
        ),
        isNull,
      );
      final BrewEntry updated = vm.entryById(target.id)!;
      expect(updated.rating, 4);
      expect(updated.tastingNotes, 'Seimbang');
      expect(updated.createdAt, target.createdAt);
      expect(
        await vm.updateEntry(id: 'tidak-ada', rating: 3, tastingNotes: ''),
        isNotNull,
      );
    });
  });
}
