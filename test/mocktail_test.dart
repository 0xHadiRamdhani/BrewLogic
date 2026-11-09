import 'dart:io';

import 'package:brewlogic/models/mocktail_model.dart';
import 'package:brewlogic/services/backup_service.dart';
import 'package:brewlogic/services/data_transfer_service.dart';
import 'package:brewlogic/services/journal_repository.dart';
import 'package:brewlogic/services/mocktail_service.dart';
import 'package:brewlogic/viewmodels/mocktail_viewmodel.dart';
import 'package:brewlogic/viewmodels/recipe_viewmodel.dart';
import 'package:brewlogic/views/widgets/mocktail_panel.dart';
import 'package:brewlogic/views/widgets/mocktail_result_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

double _sum(MocktailBlend b) => b.ingredients
    .where((MocktailIngredient i) => i.unit == 'ml')
    .fold<double>(0, (double a, MocktailIngredient i) => a + i.perServing);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const MocktailService service = MocktailService();

  group('perhitungan mocktail', () {
    test('resep bawaan: takaran per porsi dan es', () {
      final MocktailBlend blend = service.calculate(
        MocktailViewModel.defaultSpec,
      )!;
      // Gelas 300 ml, 40% es -> 180 ml cairan.
      expect(blend.liquidMl, 180);
      expect(blend.syrupMl, 29); // 16% dari 180 = 28,8 -> 29
      final Map<String, double> byName = <String, double>{
        for (final MocktailIngredient i in blend.ingredients)
          i.name: i.perServing,
      };
      expect(byName['Sirup Grenadine'], 29);
      expect(byName['Perasan jeruk nipis'], 14.5);
      expect(byName['Soda'], 136.5);
      expect(byName['Es batu'], 110);
      // Semua cairan menjumlah tepat ke volume cairan.
      expect(_sum(blend), 180);
    });

    test('beberapa sirup dibagi menurut bagian', () {
      final MocktailBlend blend = service.calculate(
        const MocktailSpec(
          syrups: <MocktailSyrup>[
            MocktailSyrup('Markisa'),
            MocktailSyrup('Mint', parts: 3),
          ],
        ),
      )!;
      final List<MocktailIngredient> syrups = blend.ingredients
          .where((MocktailIngredient i) => i.name.startsWith('Sirup'))
          .toList();
      expect(syrups, hasLength(2));
      expect(syrups[0].perServing, 7); // 28,8 * 1/4 = 7,2
      expect(syrups[1].perServing, 21.5); // 28,8 * 3/4 = 21,6
      expect(_sum(blend), blend.liquidMl);
    });

    test('tanpa es memakai 90% gelas dan tanpa baris es', () {
      final MocktailBlend blend = service.calculate(
        MocktailViewModel.defaultSpec.copyWith(useIce: false),
      )!;
      expect(blend.liquidMl, 270);
      expect(
        blend.ingredients.any((MocktailIngredient i) => i.name == 'Es batu'),
        isFalse,
      );
    });

    test('tanpa jeruk nipis dan tingkat manis memengaruhi sirup', () {
      final MocktailBlend sweet = service.calculate(
        MocktailViewModel.defaultSpec.copyWith(
          useCitrus: false,
          sweetness: MocktailSweetness.sweet,
        ),
      )!;
      expect(sweet.syrupMl, 36); // 20% dari 180
      expect(
        sweet.ingredients.any(
          (MocktailIngredient i) => i.name == 'Perasan jeruk nipis',
        ),
        isFalse,
      );
    });

    test('nama "Simple syrup" tidak digandakan kata sirup', () {
      final MocktailBlend blend = service.calculate(
        const MocktailSpec(
          syrups: <MocktailSyrup>[MocktailSyrup('Simple syrup')],
        ),
      )!;
      expect(blend.ingredients.first.name, 'Simple syrup');
    });

    test('validasi: tanpa sirup, porsi, dan gelas di luar batas', () {
      expect(service.calculate(const MocktailSpec()), isNull);
      expect(service.validate(const MocktailSpec()), contains('sirup'));
      final MocktailSpec ok = MocktailViewModel.defaultSpec;
      expect(service.validate(ok), isNull);
      expect(service.validate(ok.copyWith(servings: 0)), isNotNull);
      expect(service.validate(ok.copyWith(servings: 13)), isNotNull);
      expect(service.validate(ok.copyWith(glassMl: 50)), isNotNull);
      expect(service.validate(ok.copyWith(glassMl: 900)), isNotNull);
    });

    test('langkah: soda dituang perlahan, kocok, hiasan, dan banyak porsi', () {
      final MocktailBlend build = service.calculate(
        MocktailViewModel.defaultSpec,
      )!;
      expect(build.steps.first, startsWith('Isi gelas dengan es batu'));
      expect(build.steps.any((String s) => s.contains('perlahan')), isTrue);
      expect(build.steps.last, contains('irisan jeruk nipis'));

      final MocktailBlend shake = service.calculate(
        MocktailViewModel.defaultSpec.copyWith(
          method: MocktailMethod.shake,
          base: MocktailBase.water,
          servings: 4,
          garnishes: const <MocktailGarnish>{},
        ),
      )!;
      expect(shake.steps.any((String s) => s.contains('Kocok')), isTrue);
      expect(shake.steps.any((String s) => s.contains('hingga penuh')), isTrue);
      expect(shake.steps.last, contains('4 porsi'));
      expect(shake.totalOf(shake.ingredients.first), 29 * 4);
    });
  });

  group('MocktailViewModel', () {
    late Directory dir;
    late JournalRepository repo;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('brewlogic_mocktail_test');
      repo = await JournalRepository.open(path: dir.path);
    });

    tearDown(() async {
      await Hive.close();
      await dir.delete(recursive: true);
    });

    test('sirup: tambah, lepas, dan batas tiga', () {
      final MocktailViewModel vm = MocktailViewModel(repository: repo);
      expect(vm.spec.syrups.map((MocktailSyrup s) => s.name), <String>[
        'Grenadine',
      ]);
      expect(vm.toggleSyrup('Markisa'), isTrue);
      expect(vm.toggleSyrup('Mint'), isTrue);
      expect(vm.canAddSyrup, isFalse);
      expect(vm.toggleSyrup('Mawar'), isFalse);
      expect(vm.spec.syrups, hasLength(3));

      expect(vm.toggleSyrup('markisa'), isTrue); // lepas, tak peka huruf
      expect(vm.hasSyrup('Markisa'), isFalse);
      expect(vm.canAddSyrup, isTrue);

      vm
        ..toggleSyrup('Mint')
        ..toggleSyrup('Grenadine');
      expect(vm.blend, isNull);
      expect(vm.problem, contains('sirup'));
    });

    test('bagian sirup dijepit 1–4', () {
      final MocktailViewModel vm = MocktailViewModel(repository: repo)
        ..changeParts(0, 10);
      expect(vm.spec.syrups.first.parts, MocktailSpec.maxParts);
      vm.changeParts(0, -10);
      expect(vm.spec.syrups.first.parts, MocktailSpec.minParts);
    });

    test('validasi nama sirup buatan sendiri', () {
      final MocktailViewModel vm = MocktailViewModel(repository: repo);
      expect(vm.validateSyrupName('  '), isNotNull);
      expect(vm.validateSyrupName('x' * 21), isNotNull);
      expect(vm.validateSyrupName('grenadine'), 'Sirup sudah dipilih');
      expect(vm.validateSyrupName('Lavender'), isNull);
    });

    test('mode mocktail tersimpan setelah aplikasi dibuka ulang', () async {
      final MocktailViewModel vm = MocktailViewModel(repository: repo);
      expect(vm.isActive, isFalse);
      await vm.setActive(value: true);

      await Hive.close();
      repo = await JournalRepository.open(path: dir.path);
      expect(MocktailViewModel(repository: repo).isActive, isTrue);
    });
  });

  group('Resep Saya: mocktail', () {
    late Directory dir;
    late JournalRepository repo;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('brewlogic_mocktail_repo');
      repo = await JournalRepository.open(path: dir.path);
    });

    tearDown(() async {
      await Hive.close();
      await dir.delete(recursive: true);
    });

    const MocktailSpec spec = MocktailSpec(
      servings: 3,
      glassMl: 350,
      base: MocktailBase.tonic,
      sweetness: MocktailSweetness.sweet,
      method: MocktailMethod.shake,
      useIce: false,
      useCitrus: false,
      syrups: <MocktailSyrup>[
        MocktailSyrup('Markisa', parts: 2),
        MocktailSyrup('Lavender'),
      ],
      garnishes: <MocktailGarnish>{
        MocktailGarnish.mint,
        MocktailGarnish.berries,
      },
    );

    test('tersimpan lengkap dan terbaca lagi setelah dibuka ulang', () async {
      final RecipeViewModel recipes = RecipeViewModel(repository: repo);
      expect(recipes.isEmpty, isTrue);
      expect(await recipes.saveMocktail(name: 'Tropis Ungu', spec: spec), null);
      expect(recipes.mocktails, hasLength(1));
      expect(recipes.isEmpty, isFalse);

      await Hive.close();
      repo = await JournalRepository.open(path: dir.path);
      final MocktailRecipe loaded = RecipeViewModel(repository: repo)
          .mocktails
          .single;
      expect(loaded.name, 'Tropis Ungu');
      expect(loaded.spec.servings, 3);
      expect(loaded.spec.glassMl, 350);
      expect(loaded.spec.base, MocktailBase.tonic);
      expect(loaded.spec.sweetness, MocktailSweetness.sweet);
      expect(loaded.spec.method, MocktailMethod.shake);
      expect(loaded.spec.useIce, isFalse);
      expect(loaded.spec.useCitrus, isFalse);
      expect(loaded.spec.syrups, spec.syrups);
      expect(loaded.spec.garnishes, spec.garnishes);
    });

    test(
      'nama unik di antara resep kopi dan mocktail, lalu bisa dihapus',
      () async {
        final RecipeViewModel recipes = RecipeViewModel(repository: repo);
        await recipes.saveMocktail(name: 'Segar', spec: spec);
        expect(recipes.validateName('segar'), 'Nama resep sudah dipakai');
        expect(
          await recipes.saveMocktail(name: 'SEGAR', spec: spec),
          'Nama resep sudah dipakai',
        );

        await recipes.deleteMocktail(recipes.mocktails.single.id);
        expect(recipes.mocktails, isEmpty);
        expect(recipes.validateName('Segar'), isNull);
      },
    );
  });

  group('cadangan JSON memuat mocktail', () {
    test('cadangan lama tanpa kunci mocktails tetap terbaca', () {
      const String old =
          '{"app":"BrewLogic","version":1,"entries":[],"recipes":[],"beans":[]}';
      final BackupData data = const BackupService().decodeJson(old);
      expect(data.mocktails, isEmpty);
      expect(data.skipped, 0);
    });

    test('item mocktail rusak dilewati, nilai di luar batas dijepit', () {
      const String json =
          '{"app":"BrewLogic","version":1,"mocktails":['
          '{"id":"a","name":"Ok","createdAt":1,"servings":99,"glassMl":5,'
          '"base":"tidakAda","syrups":[{"name":"Mint","parts":9}]},'
          '{"id":"b","name":"TanpaSirup","createdAt":1,"syrups":[]},'
          '"bukan-objek"]}';
      final BackupData data = const BackupService().decodeJson(json);
      expect(data.mocktails, hasLength(1));
      expect(data.skipped, 2);
      final MocktailSpec spec = data.mocktails.single.spec;
      expect(spec.servings, MocktailSpec.maxServings);
      expect(spec.glassMl, MocktailSpec.minGlassMl);
      expect(spec.base, MocktailBase.soda);
      expect(spec.syrups.single.parts, MocktailSpec.maxParts);
    });

    test('ekspor lalu impor ke perangkat lain tanpa menimpa', () async {
      final Directory dirA = await Directory.systemTemp.createTemp('mkA');
      final Directory dirB = await Directory.systemTemp.createTemp('mkB');
      addTearDown(() async {
        await Hive.close();
        await dirA.delete(recursive: true);
        await dirB.delete(recursive: true);
      });

      final JournalRepository a = await JournalRepository.open(path: dirA.path);
      await RecipeViewModel(repository: a).saveMocktail(
        name: 'Tropis',
        spec: const MocktailSpec(
          base: MocktailBase.coconut,
          syrups: <MocktailSyrup>[
            MocktailSyrup('Markisa', parts: 2),
            MocktailSyrup('Mint'),
          ],
          garnishes: <MocktailGarnish>{MocktailGarnish.mint},
        ),
      );
      final String json = DataTransferService(repository: a)
          .buildJsonBackup(DateTime(2026, 11, 9));
      await Hive.close();

      final JournalRepository b = await JournalRepository.open(path: dirB.path);
      final DataTransferService transfer = DataTransferService(repository: b);
      final ImportResult first = await transfer.importJson(json);
      expect(first.addedMocktails, 1);
      expect(first.summary, contains('1 resep mocktail'));
      final MocktailRecipe loaded = b.getMocktails().single;
      expect(loaded.name, 'Tropis');
      expect(loaded.spec.base, MocktailBase.coconut);
      expect(loaded.spec.syrups, hasLength(2));
      expect(loaded.spec.garnishes, <MocktailGarnish>{MocktailGarnish.mint});

      final ImportResult second = await transfer.importJson(json);
      expect(second.addedMocktails, 0);
      expect(second.alreadyPresent, 1);
      expect(b.getMocktails(), hasLength(1));
    });
  });

  group('widget mocktail', () {
    late Directory dir;
    late JournalRepository repo;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('brewlogic_mocktail_ui');
      repo = await JournalRepository.open(path: dir.path);
    });

    tearDown(() async {
      await Hive.close();
      await dir.delete(recursive: true);
    });

    testWidgets('panel mengubah ViewModel dan melapor batas sirup', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1170, 6000);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      final MocktailViewModel vm = MocktailViewModel(repository: repo);
      int limit = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ListenableBuilder(
                listenable: vm,
                builder: (BuildContext _, Widget? _) => MocktailPanel(
                  viewModel: vm,
                  onAddCustomSyrup: () {},
                  onSyrupLimit: () => limit++,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Markisa'));
      await tester.tap(find.text('Mint'));
      await tester.pump();
      expect(vm.spec.syrups, hasLength(3));

      await tester.tap(find.text('Mawar'));
      await tester.pump();
      expect(limit, 1);
      expect(vm.spec.syrups, hasLength(3));

      await tester.tap(find.text('Tonic'));
      await tester.pump();
      expect(vm.spec.base, MocktailBase.tonic);

      final SemanticsHandle semantics = tester.ensureSemantics();
      await tester.tap(find.bySemanticsLabel('Tambah porsi'));
      await tester.pump();
      expect(vm.spec.servings, 2);
      semantics.dispose();
    });

    testWidgets('kartu hasil menampilkan bahan, total, dan langkah', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1170, 6000);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      final MocktailBlend blend = service.calculate(
        MocktailViewModel.defaultSpec.copyWith(servings: 2),
      )!;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MocktailResultCard(blend: blend),
            ),
          ),
        ),
      );

      expect(find.text('Sirup Grenadine'), findsOneWidget);
      expect(find.text('29 ml'), findsOneWidget);
      expect(find.text('· 58 ml'), findsOneWidget); // total 2 porsi
      expect(find.textContaining('Isi gelas dengan es batu'), findsOneWidget);
      expect(find.textContaining('Ulangi untuk 2 porsi'), findsOneWidget);
    });
  });
}
