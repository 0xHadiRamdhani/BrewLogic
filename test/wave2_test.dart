import 'dart:io';

import 'package:brewlogic/core/utils/formatters.dart';
import 'package:brewlogic/models/brew_model.dart';
import 'package:brewlogic/services/brew_calculator_service.dart';
import 'package:brewlogic/services/dial_in_service.dart';
import 'package:brewlogic/services/journal_repository.dart';
import 'package:brewlogic/viewmodels/brew_viewmodel.dart';
import 'package:brewlogic/viewmodels/journal_viewmodel.dart';
import 'package:brewlogic/viewmodels/recipe_viewmodel.dart';
import 'package:brewlogic/viewmodels/settings_viewmodel.dart';
import 'package:brewlogic/viewmodels/shell_navigation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

Future<void> _flush() => Future<void>.delayed(Duration.zero);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const BrewCalculatorService calc = BrewCalculatorService();

  group('kustomisasi resep', () {
    test('rasio dan durasi kustom memengaruhi hasil', () {
      final BrewCalculation c = calc.calculate(
        coffeeGrams: 20,
        method: BrewMethod.v60,
        roast: RoastLevel.medium,
        customization: const BrewCustomization(
          ratio: 16.5,
          bloomSeconds: 45,
          firstPourSeconds: 60,
        ),
      );
      expect(c.ratio, 16.5);
      expect(c.ratioLabel, '1:16.5');
      expect(c.totalWaterGrams, 330);
      expect(c.steps[0].durationSeconds, 45);
      expect(c.steps[1].durationSeconds, 60);
      expect(c.steps[2].durationSeconds, BrewMethod.v60.secondPourSeconds);
      expect(c.steps.last.targetWaterGrams, 330);
    });

    test('nilai di luar batas dijepit', () {
      final BrewCalculation c = calc.calculate(
        coffeeGrams: 10,
        method: BrewMethod.v60,
        roast: RoastLevel.light,
        customization: const BrewCustomization(
          ratio: 99,
          bloomSeconds: 1,
          secondPourSeconds: 9999,
        ),
      );
      expect(c.ratio, BrewCustomization.maxRatio);
      expect(c.steps[0].durationSeconds, BrewCustomization.minBloomSeconds);
      expect(c.steps[2].durationSeconds, BrewCustomization.maxPourSeconds);
    });

    test('kalkulator terbalik memakai rasio kustom', () {
      expect(
        calc.coffeeForWater(300, BrewMethod.v60, ratio: 16),
        closeTo(18.8, 0.001),
      );
      expect(calc.validateWater('300', BrewMethod.v60, ratio: 16), isNull);
    });

    test('customization: kesetaraan dan isDefault', () {
      expect(const BrewCustomization().isDefault, isTrue);
      expect(const BrewCustomization(ratio: 15).isDefault, isFalse);
      expect(
        const BrewCustomization(ratio: 15),
        const BrewCustomization(ratio: 15),
      );
      expect(
        const BrewCustomization().withRatio(14).withRatio(null).isDefault,
        isTrue,
      );
    });
  });

  group('suhu', () {
    test('format Celsius dan Fahrenheit', () {
      expect(formatTemp(92, fahrenheit: false), '92 °C');
      expect(formatTemp(92, fahrenheit: true), '198 °F');
      expect(formatTempRange(93, 95, fahrenheit: true), '199–203 °F');
      expect(formatTempRange(90, 92, fahrenheit: false), '90–92 °C');
    });
  });

  group('asisten dial-in', () {
    const DialInService service = DialInService();

    DialInAdvice advise(TasteFeedback t, {double ratio = 15, int secs = 150}) =>
        service.advise(
          taste: t,
          method: BrewMethod.v60,
          roast: RoastLevel.medium,
          ratio: ratio,
          brewSeconds: secs,
        );

    test('setiap kesan rasa punya saran', () {
      for (final TasteFeedback t in TasteFeedback.values) {
        final DialInAdvice a = advise(t);
        expect(a.summary, isNotEmpty);
        expect(a.tips, isNotEmpty);
      }
    });

    test('asam: lebih halus, lebih panas, lebih lama', () {
      final DialInAdvice a = advise(TasteFeedback.sour);
      expect(a.tips.join(' '), contains('lebih halus'));
      expect(a.tips.join(' '), contains('93 °C'), reason: '91 + 2');
      expect(a.tips.join(' '), contains('02:42'), reason: '02:30 + 12 detik');
      expect(a.suggestedRatio, isNull);
    });

    test('pahit: lebih kasar dan lebih dingin', () {
      final DialInAdvice a = advise(TasteFeedback.bitter);
      expect(a.tips.join(' '), contains('lebih kasar'));
      expect(a.tips.join(' '), contains('89 °C'));
    });

    test('hambar: rasio dipekatkan satu tingkat', () {
      expect(advise(TasteFeedback.weak).suggestedRatio, 14);
      expect(
        advise(TasteFeedback.weak, ratio: 10).suggestedRatio,
        isNull,
        reason: 'sudah di batas terpekat',
      );
    });

    test('tanpa durasi, saran waktu memakai selisih detik', () {
      final DialInAdvice a = advise(TasteFeedback.sour, secs: 0);
      expect(a.tips.join(' '), contains('12 detik lebih lama'));
    });

    test('suhu mengikuti satuan Fahrenheit', () {
      final DialInAdvice a = service.advise(
        taste: TasteFeedback.sour,
        method: BrewMethod.v60,
        roast: RoastLevel.medium,
        ratio: 15,
        brewSeconds: 150,
        fahrenheit: true,
      );
      expect(a.tips.join(' '), contains('199 °F'));
    });
  });

  group('Hive + ViewModel (gelombang 2)', () {
    late Directory dir;
    late JournalRepository repo;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('brewlogic_wave2_test');
      repo = await JournalRepository.open(path: dir.path);
    });

    tearDown(() async {
      await Hive.close();
      await dir.delete(recursive: true);
    });

    test('BrewViewModel: setter kustom, normalisasi, dan reset metode', () {
      final BrewViewModel vm = BrewViewModel(repository: repo);
      addTearDown(vm.dispose);
      vm.selectMethod(BrewMethod.v60);
      vm.updateGrams('20');

      vm.setRatio(16);
      expect(vm.calculation?.totalWaterGrams, 320);
      expect(vm.customization.ratio, 16);

      vm.setRatio(15); // sama dengan bawaan V60 → dianggap bawaan
      expect(vm.customization.isDefault, isTrue);

      vm.setBloomSeconds(55);
      expect(vm.calculation?.steps.first.durationSeconds, 55);
      vm.setBloomSeconds(BrewMethod.v60.bloomSeconds);
      expect(vm.customization.isDefault, isTrue);

      vm.setRatio(16.3); // dibulatkan ke kelipatan 0,5
      expect(vm.customization.ratio, 16.5);
      vm.selectMethod(BrewMethod.chemex);
      expect(vm.customization.isDefault, isTrue, reason: 'ganti metode');
    });

    test('BrewViewModel: kustomisasi ikut tersimpan di cache', () async {
      final BrewViewModel vm = BrewViewModel(repository: repo);
      vm.updateGrams('18');
      vm.setRatio(14);
      vm.setFirstPourSeconds(70);
      await repo.flushCache();
      vm.dispose();

      final BrewViewModel again = BrewViewModel(repository: repo);
      addTearDown(again.dispose);
      expect(again.customization.ratio, 14);
      expect(again.customization.firstPourSeconds, 70);
      expect(again.calculation?.totalWaterGrams, 252);

      again.resetCustomization();
      await repo.flushCache();
      expect(repo.cachedCustomization.isDefault, isTrue);
    });

    test('timer di-reset saat penyesuaian berubah', () {
      final BrewViewModel vm = BrewViewModel(repository: repo);
      addTearDown(vm.dispose);
      vm.updateGrams('18');
      vm.startTimer();
      expect(vm.timerStatus, BrewTimerStatus.running);
      vm.setRatio(16);
      expect(vm.timerStatus, BrewTimerStatus.idle);
    });

    test('resep: simpan, validasi nama, muat, dan hapus', () async {
      final BrewViewModel brew = BrewViewModel(repository: repo);
      addTearDown(brew.dispose);
      final RecipeViewModel recipes = RecipeViewModel(repository: repo);

      brew.updateGrams('18');
      brew.selectRoast(RoastLevel.light);
      brew.setRatio(16);
      final BrewCalculation c = brew.calculation!;

      expect(recipes.validateName(''), isNotNull);
      expect(recipes.validateName('x' * 30), isNotNull);
      expect(await recipes.saveRecipe(name: '  ', calculation: c), isNotNull);

      expect(
        await recipes.saveRecipe(name: 'Pagi V60', calculation: c),
        isNull,
      );
      expect(recipes.recipes, hasLength(1));
      expect(
        await recipes.saveRecipe(name: 'pagi v60', calculation: c),
        isNotNull,
        reason: 'nama kembar tanpa memandang huruf besar-kecil',
      );

      // Ubah kalkulator, lalu muat resepnya kembali.
      brew.selectMethod(BrewMethod.chemex);
      brew.updateGrams('30');
      brew.applyRecipe(recipes.recipes.single);
      expect(brew.method, BrewMethod.v60);
      expect(brew.roast, RoastLevel.light);
      expect(brew.inputMode, BrewInputMode.coffee);
      expect(brew.calculation?.coffeeGrams, 18);
      expect(brew.customization.ratio, 16);

      // Tetap ada setelah buka ulang.
      await Hive.close();
      repo = await JournalRepository.open(path: dir.path);
      final RecipeViewModel reloaded = RecipeViewModel(repository: repo);
      expect(reloaded.recipes.single.name, 'Pagi V60');
      expect(reloaded.recipes.single.customization.ratio, 16);

      expect(await reloaded.deleteRecipe(reloaded.recipes.single.id), isNull);
      expect(reloaded.isEmpty, isTrue);
    });

    test('applyAdjustment menerapkan rasio saran dari seduhan lama', () {
      final BrewViewModel vm = BrewViewModel(repository: repo);
      addTearDown(vm.dispose);
      vm.applyAdjustment(
        method: BrewMethod.aeropress,
        roast: RoastLevel.dark,
        coffeeGrams: 17.5,
        ratio: 12.2,
      );
      expect(vm.method, BrewMethod.aeropress);
      expect(vm.roast, RoastLevel.dark);
      expect(vm.calculation?.coffeeGrams, 17.5);
      expect(vm.customization.ratio, 12);
    });

    test('jurnal menyimpan dan mengubah kesan rasa', () async {
      final JournalViewModel vm = JournalViewModel(repository: repo);
      final BrewCalculation c = calc.calculate(
        coffeeGrams: 18,
        method: BrewMethod.v60,
        roast: RoastLevel.medium,
      );
      await vm.saveBrew(
        calculation: c,
        rating: 3,
        tastingNotes: '',
        brewSeconds: 150,
        taste: TasteFeedback.sour,
      );
      final BrewEntry saved = vm.entries.single;
      expect(saved.taste, TasteFeedback.sour);

      // Tetap ada setelah buka ulang (adapter field 9).
      await Hive.close();
      repo = await JournalRepository.open(path: dir.path);
      final JournalViewModel reloaded = JournalViewModel(repository: repo);
      expect(reloaded.entries.single.taste, TasteFeedback.sour);

      expect(
        await reloaded.updateEntry(
          id: saved.id,
          rating: 4,
          tastingNotes: '',
          taste: TasteFeedback.balanced,
        ),
        isNull,
      );
      expect(reloaded.entries.single.taste, TasteFeedback.balanced);
      expect(
        await reloaded.updateEntry(id: saved.id, rating: 4, tastingNotes: ''),
        isNull,
      );
      expect(reloaded.entries.single.taste, isNull, reason: 'dihapus');
    });

    test('satuan Fahrenheit tersimpan', () async {
      final SettingsViewModel settings = SettingsViewModel(repository: repo);
      expect(settings.useFahrenheit, isFalse);
      settings.setFahrenheit(value: true);
      await _flush();
      expect(SettingsViewModel(repository: repo).useFahrenheit, isTrue);
    });
  });

  test('ShellNavigation: permintaan berulang ke tab sama tetap terdeteksi', () {
    final ShellNavigation nav = ShellNavigation();
    int notified = 0;
    nav.addListener(() => notified++);
    nav.goTo(ShellNavigation.calculator);
    nav.goTo(ShellNavigation.calculator);
    expect(notified, 2);
    expect(nav.requestId, 2);
    expect(nav.requestedTab, ShellNavigation.calculator);
  });
}
