import 'dart:io';

import 'package:brewlogic/models/mocktail_model.dart';
import 'package:brewlogic/services/backup_service.dart';
import 'package:brewlogic/services/data_transfer_service.dart';
import 'package:brewlogic/services/journal_repository.dart';
import 'package:brewlogic/services/mocktail_scene.dart';
import 'package:brewlogic/services/mocktail_service.dart';
import 'package:brewlogic/viewmodels/brew_viewmodel.dart';
import 'package:brewlogic/viewmodels/mocktail_viewmodel.dart';
import 'package:brewlogic/viewmodels/recipe_viewmodel.dart';
import 'package:brewlogic/views/widgets/customization_panel.dart';
import 'package:brewlogic/views/widgets/mocktail_base_dialog.dart';
import 'package:brewlogic/views/widgets/mocktail_garnish_dialog.dart';
import 'package:brewlogic/views/widgets/mocktail_panel.dart';
import 'package:brewlogic/views/widgets/mocktail_result_card.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
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

  group('bahan dasar buatan sendiri', () {
    const MocktailCustomBase apple = MocktailCustomBase(
      'Jus apel',
      color: 0xFFF0D58A,
    );
    const MocktailCustomBase kombucha = MocktailCustomBase(
      'Kombucha',
      sparkling: true,
    );
    final MocktailSpec withApple = MocktailViewModel.defaultSpec.copyWith(
      customBase: apple,
    );

    test('mengganti bahan dasar preset di takaran, langkah, dan nama', () {
      final MocktailBlend blend = service.calculate(withApple)!;
      final MocktailIngredient base = blend.ingredients.firstWhere(
        (MocktailIngredient i) => i.kind == MocktailIngredientKind.base,
      );
      expect(base.name, 'Jus apel');
      expect(base.perServing, 136.5);
      final MocktailStep pour = blend.stepDetails.firstWhere(
        (MocktailStep s) => s.kind == MocktailStepKind.base,
      );
      expect(pour.title, 'Tuang jus apel');
      expect(pour.text, contains('jus apel'));
      expect(blend.summary, startsWith('Jus apel'));
      expect(withApple.baseLabel, 'Jus apel');
      expect(withApple.isBase(MocktailBase.soda), isFalse);
    });

    test('bersoda dituang perlahan 15 detik, tidak bersoda 10 detik', () {
      MocktailStep pourOf(MocktailCustomBase b) => service
          .calculate(MocktailViewModel.defaultSpec.copyWith(customBase: b))!
          .stepDetails
          .firstWhere((MocktailStep s) => s.kind == MocktailStepKind.base);
      expect(pourOf(kombucha).durationSeconds, 15);
      expect(pourOf(kombucha).text, contains('perlahan'));
      expect(pourOf(apple).durationSeconds, 10);
      expect(pourOf(apple).text, contains('hingga penuh'));
      expect(withApple.baseSparkling, isFalse);
      expect(withApple.copyWith(customBase: kombucha).baseSparkling, isTrue);
    });

    test('warna animasi: pilihan pengguna atau warna preset', () {
      expect(MocktailScene.baseColor(withApple).toARGB32(), 0xFFF0D58A);
      expect(
        MocktailScene.baseColor(MocktailViewModel.defaultSpec).toARGB32(),
        0xFFCDE7F0,
      );
    });

    test('kesetaraan dan penghapusan lewat copyWith', () {
      expect(withApple == withApple.copyWith(), isTrue);
      expect(withApple == MocktailViewModel.defaultSpec, isFalse);
      final MocktailSpec cleared = withApple.copyWith(clearCustomBase: true);
      expect(cleared == MocktailViewModel.defaultSpec, isTrue);
      expect(cleared.isBase(MocktailBase.soda), isTrue);
    });
  });

  group('takaran sirup ml sendiri', () {
    const MocktailSpec custom = MocktailSpec(
      syrups: <MocktailSyrup>[
        MocktailSyrup('Markisa', ml: 20),
        MocktailSyrup('Mint', ml: 15.2),
      ],
    );

    test('dipakai apa adanya (dibulatkan 0,5) dan sisa jadi bahan dasar', () {
      final MocktailBlend blend = service.calculate(custom)!;
      final Map<String, double> byName = <String, double>{
        for (final MocktailIngredient i in blend.ingredients)
          i.name: i.perServing,
      };
      expect(custom.customMl, isTrue);
      expect(byName['Sirup Markisa'], 20);
      expect(byName['Sirup Mint'], 15);
      expect(blend.syrupMl, 35);
      expect(byName['Soda'], 130.5); // 180 - 35 - 14,5
      expect(_sum(blend), blend.liquidMl);
    });

    test('tingkat manis tidak berpengaruh di mode ml sendiri', () {
      final MocktailBlend a = service.calculate(custom)!;
      final MocktailBlend b = service.calculate(
        custom.copyWith(sweetness: MocktailSweetness.sweet),
      )!;
      expect(b.syrupMl, a.syrupMl);
      expect(
        b.ingredients.map((MocktailIngredient i) => i.perServing),
        a.ingredients.map((MocktailIngredient i) => i.perServing),
      );
    });

    test('sebagian sirup saja yang punya ml dianggap otomatis', () {
      const MocktailSpec mixed = MocktailSpec(
        syrups: <MocktailSyrup>[
          MocktailSyrup('Markisa', ml: 99),
          MocktailSyrup('Mint'),
        ],
      );
      expect(mixed.customMl, isFalse);
      final MocktailBlend blend = service.calculate(mixed)!;
      expect(blend.syrupMl, closeTo(29, 1));
      expect(
        MocktailSyrup.normalized(mixed.syrups)
            .every((MocktailSyrup s) => s.ml == null),
        isTrue,
      );
    });

    test('validasi: batas per sirup dan sisa bahan dasar', () {
      MocktailSpec withMl(double a, [double? b]) => MocktailSpec(
        syrups: <MocktailSyrup>[
          MocktailSyrup('Markisa', ml: a),
          if (b != null) MocktailSyrup('Mint', ml: b),
        ],
      );
      expect(service.validate(withMl(20)), isNull);
      expect(service.validate(withMl(0.2)), contains('0.5'));
      expect(service.validate(withMl(151)), contains('150'));
      // 100 + 100 + jeruk 14,5 melebihi 180 ml cairan.
      expect(service.validate(withMl(100, 100)), contains('terlalu banyak'));
      expect(service.calculate(withMl(100, 100)), isNull);
      // Gelas lebih besar membuatnya muat.
      expect(service.validate(withMl(100, 100).copyWith(glassMl: 600)), isNull);
    });

    test('warna campuran berbobot ml, bukan bagian', () {
      const MocktailSpec mix = MocktailSpec(
        syrups: <MocktailSyrup>[
          MocktailSyrup('Blue curaçao', ml: 1),
          MocktailSyrup('Markisa', ml: 60),
        ],
      );
      final Color c = MocktailScene.syrupColor(mix);
      final Color markisa = Color(SyrupPresets.byName('Markisa')!.color);
      expect((c.r - markisa.r).abs(), lessThan(0.05));
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

    test('validasi ukuran gelas (ml) dan penanda penyesuaian', () {
      final MocktailViewModel vm = MocktailViewModel(repository: repo);
      expect(vm.validateGlassMl(''), isNotNull);
      expect(vm.validateGlassMl('abc'), 'Masukkan angka bulat');
      expect(vm.validateGlassMl('250.5'), 'Masukkan angka bulat');
      expect(vm.validateGlassMl('99'), contains('100'));
      expect(vm.validateGlassMl('601'), contains('600'));
      expect(vm.validateGlassMl(' 300 '), isNull);

      expect(vm.adjusted, isFalse);
      vm.setUseIce(value: false);
      expect(vm.adjusted, isTrue);
      vm
        ..setServings(4)
        ..setUseCitrus(value: false)
        ..toggleGarnish(MocktailGarnish.mint)
        ..toggleSyrup('Markisa')
        ..setBase(MocktailBase.tonic)
        ..resetAdjustments();
      expect(vm.adjusted, isFalse);
      // Bahan dasar dan sirup tidak ikut direset.
      expect(vm.spec.base, MocktailBase.tonic);
      expect(vm.hasSyrup('Markisa'), isTrue);
    });

    test('mode ml sendiri: ambil dari hitungan otomatis, ubah, kembalikan', () {
      final MocktailViewModel vm = MocktailViewModel(repository: repo);
      vm.setSyrupMl(0, 12); // di mode otomatis diabaikan
      expect(vm.spec.syrups.first.ml, isNull);

      vm.setSyrupMode(custom: true);
      expect(vm.spec.customMl, isTrue);
      expect(vm.spec.syrups.first.ml, 29); // sama dengan hitungan otomatis
      expect(vm.blend!.syrupMl, 29);

      vm.setSyrupMl(0, 12.5);
      expect(vm.blend!.syrupMl, 12.5);
      vm.changeSyrupMl(0, -100);
      expect(vm.spec.syrups.first.ml, MocktailSpec.minSyrupMl);
      vm.changeSyrupMl(0, 1000);
      expect(vm.spec.syrups.first.ml, MocktailSpec.maxSyrupMl);
      expect(vm.problem, contains('terlalu banyak'));
      expect(vm.blend, isNull);

      vm.setSyrupMl(0, 20);
      expect(vm.toggleSyrup('Mint'), isTrue);
      expect(vm.spec.syrups.last.ml, MocktailViewModel.defaultNewSyrupMl);
      expect(vm.spec.customMl, isTrue);

      vm.setSyrupMode(custom: false);
      expect(vm.spec.customMl, isFalse);
      expect(vm.spec.syrups.every((MocktailSyrup s) => s.ml == null), isTrue);
    });

    test('validasi takaran sirup yang diketik', () {
      final MocktailViewModel vm = MocktailViewModel(repository: repo);
      expect(vm.validateSyrupMl(''), isNotNull);
      expect(vm.validateSyrupMl('abc'), 'Masukkan angka');
      expect(vm.validateSyrupMl('0.4'), contains('0.5'));
      expect(vm.validateSyrupMl('151'), contains('150'));
      expect(vm.validateSyrupMl('12,5'), isNull);
      expect(vm.validateSyrupMl(' 30 '), isNull);
    });

    test(
      'bahan dasar buatan: validasi, tambah, pilih, hapus, dan batas',
      () async {
        final MocktailViewModel vm = MocktailViewModel(repository: repo);
        expect(vm.customBases, isEmpty);
        expect(vm.validateBaseName(' '), isNotNull);
        expect(vm.validateBaseName('x' * 21), isNotNull);
        expect(vm.validateBaseName('soda'), 'Bahan sudah ada'); // preset
        expect(vm.validateBaseName('Jus apel'), isNull);

        expect(
          await vm.addCustomBase(
            const MocktailCustomBase('  Jus apel ', color: 0xFFF0D58A),
          ),
          isNull,
        );
        expect(vm.customBases.single.name, 'Jus apel');
        expect(vm.spec.customBase?.name, 'Jus apel'); // langsung terpilih
        expect(vm.spec.isBase(MocktailBase.soda), isFalse);
        expect(vm.validateBaseName('JUS APEL'), 'Bahan sudah ada');
        expect(
          await vm.addCustomBase(const MocktailCustomBase('jus apel')),
          'Bahan sudah ada',
        );

        vm.setBase(MocktailBase.tonic); // preset menggantikan bahan buatan
        expect(vm.spec.customBase, isNull);
        expect(vm.spec.base, MocktailBase.tonic);
        expect(vm.isCustomBaseSelected(vm.customBases.single), isFalse);

        vm.selectCustomBase(vm.customBases.single);
        expect(vm.isCustomBaseSelected(vm.customBases.single), isTrue);

        await vm.removeCustomBase('jus APEL'); // tak peka huruf
        expect(vm.customBases, isEmpty);
        expect(vm.spec.customBase, isNull); // kembali ke preset

        for (int i = 0; i < MocktailCustomBase.maxSaved; i++) {
          expect(
            await vm.addCustomBase(MocktailCustomBase('Bahan $i')),
            isNull,
          );
        }
        expect(vm.canAddCustomBase, isFalse);
        expect(
          await vm.addCustomBase(const MocktailCustomBase('Satu lagi')),
          contains('Maksimal'),
        );
      },
    );

    test('daftar bahan buatan tersimpan setelah dibuka ulang', () async {
      final MocktailViewModel vm = MocktailViewModel(repository: repo);
      await vm.addCustomBase(
        const MocktailCustomBase(
          'Kombucha',
          sparkling: true,
          color: 0xFFB9DCA5,
        ),
      );
      await vm.addCustomBase(const MocktailCustomBase('Susu'));
      await repo.flushCache();

      await Hive.close();
      repo = await JournalRepository.open(path: dir.path);
      final MocktailViewModel reopened = MocktailViewModel(repository: repo);
      expect(
        reopened.customBases.map((MocktailCustomBase b) => b.name),
        <String>['Kombucha', 'Susu'],
      );
      expect(reopened.customBases.first.sparkling, isTrue);
      expect(reopened.customBases.first.color, 0xFFB9DCA5);
    });

    test('memuat resep dengan bahan buatan ikut menyimpannya', () async {
      final MocktailViewModel vm = MocktailViewModel(repository: repo);
      vm.applyRecipe(
        MocktailRecipe(
          id: 'r',
          name: 'Segar',
          createdAt: DateTime(2026),
          spec: MocktailViewModel.defaultSpec.copyWith(
            customBase: const MocktailCustomBase('Jus nanas'),
          ),
        ),
      );
      expect(vm.spec.customBase?.name, 'Jus nanas');
      expect(vm.customBases.single.name, 'Jus nanas');
    });

    test('hiasan buatan: validasi, tambah, pakai, hapus, dan batas', () async {
      final MocktailViewModel vm = MocktailViewModel(repository: repo);
      expect(vm.customGarnishes, isEmpty);
      expect(vm.validateGarnishName(' '), isNotNull);
      expect(vm.validateGarnishName('x' * 21), isNotNull);
      expect(vm.validateGarnishName('daun MINT'), 'Hiasan sudah ada'); // preset
      expect(vm.validateGarnishName('Rosemary'), isNull);

      expect(await vm.addCustomGarnish('  Rosemary '), isNull);
      expect(vm.customGarnishes, <String>['Rosemary']);
      expect(vm.spec.customGarnishes, <String>{'Rosemary'}); // langsung dipakai
      expect(vm.adjusted, isTrue);
      expect(vm.spec.garnishNames, <String>['Irisan jeruk nipis', 'Rosemary']);
      expect(await vm.addCustomGarnish('rosemary'), 'Hiasan sudah ada');

      vm.toggleCustomGarnish('Rosemary');
      expect(vm.isCustomGarnishSelected('Rosemary'), isFalse);
      vm.toggleCustomGarnish('Rosemary');
      expect(vm.isCustomGarnishSelected('Rosemary'), isTrue);

      vm.resetAdjustments();
      expect(vm.spec.customGarnishes, isEmpty);
      expect(vm.customGarnishes, <String>['Rosemary']); // daftar tetap
      expect(vm.adjusted, isFalse);

      vm.toggleCustomGarnish('Rosemary');
      await vm.removeCustomGarnish('Rosemary');
      expect(vm.customGarnishes, isEmpty);
      expect(vm.spec.customGarnishes, isEmpty); // dilepas dari resep aktif

      for (int i = 0; i < MocktailSpec.maxSavedGarnishes; i++) {
        expect(await vm.addCustomGarnish('Hiasan $i'), isNull);
      }
      expect(vm.canAddCustomGarnish, isFalse);
      expect(await vm.addCustomGarnish('Satu lagi'), contains('Maksimal'));
    });

    test(
      'hiasan buatan masuk langkah dan tersimpan setelah dibuka ulang',
      () async {
        final MocktailViewModel vm = MocktailViewModel(repository: repo);
        await vm.addCustomGarnish('Rosemary');
        final MocktailStep last = vm.blend!.stepDetails.last;
        expect(last.kind, MocktailStepKind.garnish);
        expect(last.text, contains('rosemary'));
        expect(last.text, contains('irisan jeruk nipis'));
        await repo.flushCache();

        await Hive.close();
        repo = await JournalRepository.open(path: dir.path);
        final MocktailViewModel reopened = MocktailViewModel(repository: repo);
        expect(reopened.customGarnishes, <String>['Rosemary']);
      },
    );

    test('resep dengan hiasan buatan: Hive, muat, dan sama-tidaknya', () async {
      final MocktailSpec spec = MocktailViewModel.defaultSpec.copyWith(
        customGarnishes: <String>{'Rosemary', 'Nanas'},
      );
      expect(spec == MocktailViewModel.defaultSpec, isFalse);
      expect(
        spec ==
            MocktailViewModel.defaultSpec.copyWith(
              customGarnishes: <String>{'Nanas', 'Rosemary'},
            ),
        isTrue,
      );

      await repo.saveMocktail(
        MocktailRecipe(
          id: 'g',
          name: 'Hiasan',
          createdAt: DateTime(2026),
          spec: spec,
        ),
      );
      await Hive.close();
      repo = await JournalRepository.open(path: dir.path);
      final MocktailRecipe loaded = repo.getMocktails().single;
      expect(loaded.spec.customGarnishes, <String>{'Rosemary', 'Nanas'});

      final MocktailViewModel vm = MocktailViewModel(repository: repo);
      vm.applyRecipe(loaded);
      expect(vm.spec.customGarnishes, <String>{'Rosemary', 'Nanas'});
      expect(vm.customGarnishes, <String>['Rosemary', 'Nanas']);
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

    test('takaran ml sendiri ikut cadangan; campuran dinormalkan', () {
      final String out = const BackupService().encodeJson(
        entries: const [],
        recipes: const [],
        beans: const [],
        now: DateTime(2026),
        mocktails: <MocktailRecipe>[
          MocktailRecipe(
            id: 'a',
            name: 'Pas',
            createdAt: DateTime(2026),
            spec: const MocktailSpec(
              syrups: <MocktailSyrup>[MocktailSyrup('Mint', ml: 12.5)],
            ),
          ),
        ],
      );
      final BackupData back = const BackupService().decodeJson(out);
      expect(back.mocktails.single.spec.syrups.single.ml, 12.5);
      expect(back.mocktails.single.spec.customMl, isTrue);

      const String partial =
          '{"app":"BrewLogic","version":1,"mocktails":[{"id":"b","name":"X",'
          '"createdAt":1,"syrups":[{"name":"Mint","ml":10},{"name":"Mawar"}]}]}';
      final MocktailSpec spec = const BackupService()
          .decodeJson(partial)
          .mocktails
          .single
          .spec;
      expect(spec.customMl, isFalse);
      expect(spec.syrups.every((MocktailSyrup s) => s.ml == null), isTrue);
    });

    test('bahan dasar buatan ikut cadangan dan tahan data rusak', () {
      final String out = const BackupService().encodeJson(
        entries: const [],
        recipes: const [],
        beans: const [],
        now: DateTime(2026),
        mocktails: <MocktailRecipe>[
          MocktailRecipe(
            id: 'a',
            name: 'Kombucha',
            createdAt: DateTime(2026),
            spec: MocktailViewModel.defaultSpec.copyWith(
              customBase: const MocktailCustomBase(
                'Kombucha',
                sparkling: true,
                color: 0xFFB9DCA5,
              ),
            ),
          ),
        ],
      );
      final MocktailCustomBase? back = const BackupService()
          .decodeJson(out)
          .mocktails
          .single
          .spec
          .customBase;
      expect(back?.name, 'Kombucha');
      expect(back?.sparkling, isTrue);
      expect(back?.color, 0xFFB9DCA5);

      const String broken =
          '{"app":"BrewLogic","version":1,"mocktails":['
          '{"id":"b","name":"X","createdAt":1,"customBase":"bukan-objek",'
          '"syrups":[{"name":"Mint"}]},'
          '{"id":"c","name":"Y","createdAt":1,"customBase":{"sparkling":true},'
          '"syrups":[{"name":"Mint"}]}]}';
      final BackupData data = const BackupService().decodeJson(broken);
      expect(data.mocktails, hasLength(2));
      expect(
        data.mocktails.every((MocktailRecipe r) => r.spec.customBase == null),
        isTrue,
      );
    });

    test('hiasan buatan ikut cadangan dan tahan data rusak', () {
      final String out = const BackupService().encodeJson(
        entries: const [],
        recipes: const [],
        beans: const [],
        now: DateTime(2026),
        mocktails: <MocktailRecipe>[
          MocktailRecipe(
            id: 'a',
            name: 'Segar',
            createdAt: DateTime(2026),
            spec: MocktailViewModel.defaultSpec.copyWith(
              customGarnishes: <String>{'Rosemary', 'Nanas'},
            ),
          ),
        ],
      );
      expect(
        const BackupService()
            .decodeJson(out)
            .mocktails
            .single
            .spec
            .customGarnishes,
        <String>{'Rosemary', 'Nanas'},
      );

      final String long = 'x' * 40;
      final String broken =
          '{"app":"BrewLogic","version":1,"mocktails":['
          '{"id":"b","name":"X","createdAt":1,"syrups":[{"name":"Mint"}],'
          '"customGarnishes":["Ok",7,"  ",null,"$long"]},'
          '{"id":"c","name":"Y","createdAt":1,"syrups":[{"name":"Mint"}],'
          '"customGarnishes":"bukan-daftar"}]}';
      final BackupData data = const BackupService().decodeJson(broken);
      expect(data.mocktails, hasLength(2));
      expect(data.mocktails.first.spec.customGarnishes, <String>{
        'Ok',
        'x' * MocktailSpec.maxGarnishNameLength,
      });
      expect(data.mocktails.last.spec.customGarnishes, isEmpty);
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
                  onAddCustomBase: () {},
                  onDeleteCustomBase: (MocktailCustomBase _) {},
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

      // Tingkat manis dan teknik berupa segmented control berikon.
      await tester.tap(find.text('Manis'));
      await tester.tap(find.text('Kocok'));
      await tester.pump();
      expect(vm.spec.sweetness, MocktailSweetness.sweet);
      expect(vm.spec.method, MocktailMethod.shake);
    });

    testWidgets('ukuran gelas: field angka, chip cepat, dan sinkron resep', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1170, 6000);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      final MocktailViewModel vm = MocktailViewModel(repository: repo);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ListenableBuilder(
                listenable: vm,
                builder: (BuildContext _, Widget? _) => MocktailPanel(
                  viewModel: vm,
                  onAddCustomSyrup: () {},
                  onSyrupLimit: () {},
                  onAddCustomBase: () {},
                  onDeleteCustomBase: (MocktailCustomBase _) {},
                ),
              ),
            ),
          ),
        ),
      );

      final Finder field = find.byType(TextFormField);
      expect(tester.widget<TextFormField>(field).controller?.text, '300');

      await tester.enterText(field, '350');
      await tester.pump();
      expect(vm.spec.glassMl, 350);

      // Nilai tidak valid tidak mengubah ViewModel (error tampil di field).
      await tester.enterText(field, '50');
      await tester.pump();
      expect(vm.spec.glassMl, 350);
      expect(find.text('Ukuran gelas 100–600 ml'), findsOneWidget);

      await tester.tap(find.text('250 ml'));
      await tester.pump();
      expect(vm.spec.glassMl, 250);
      expect(tester.widget<TextFormField>(field).controller?.text, '250');

      // Memuat resep dengan ukuran lain menyamakan field.
      vm.applyRecipe(
        MocktailRecipe(
          id: 'x',
          name: 'Besar',
          createdAt: DateTime(2026),
          spec: MocktailViewModel.defaultSpec.copyWith(glassMl: 400),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(tester.widget<TextFormField>(field).controller?.text, '400');
    });

    testWidgets('bahan dasar: pil Bahan lain, pilih, dan tahan untuk hapus', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1170, 8000);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      final MocktailViewModel vm = MocktailViewModel(repository: repo);
      // Hive menulis di zona asli, bukan zona waktu palsu widget test.
      await tester.runAsync(
        () => vm.addCustomBase(
          const MocktailCustomBase('Kombucha', sparkling: true),
        ),
      );
      vm.setBase(MocktailBase.soda);
      int added = 0;
      MocktailCustomBase? deleted;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ListenableBuilder(
                listenable: vm,
                builder: (BuildContext _, Widget? _) => MocktailPanel(
                  viewModel: vm,
                  onAddCustomSyrup: () {},
                  onSyrupLimit: () {},
                  onAddCustomBase: () => added++,
                  onDeleteCustomBase: (MocktailCustomBase b) => deleted = b,
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Bahan lain'), findsOneWidget);
      expect(find.text('Kombucha'), findsOneWidget);
      expect(find.textContaining('Tahan bahan buatan'), findsOneWidget);

      await tester.tap(find.text('Bahan lain'));
      expect(added, 1);

      await tester.tap(find.text('Kombucha'));
      await tester.pump();
      expect(vm.spec.customBase?.name, 'Kombucha');
      await tester.tap(find.text('Tonic'));
      await tester.pump();
      expect(vm.spec.customBase, isNull);
      expect(vm.spec.base, MocktailBase.tonic);

      await tester.longPress(find.text('Kombucha'));
      await tester.pump();
      expect(deleted?.name, 'Kombucha');
    });

    testWidgets('dialog Bahan lain: isian, validasi, dan hasil', (
      WidgetTester tester,
    ) async {
      final MocktailViewModel vm = MocktailViewModel(repository: repo);
      MocktailCustomBase? result;
      bool done = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (BuildContext context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await showMocktailBaseDialog(
                    context,
                    validator: vm.validateBaseName,
                  );
                  done = true;
                },
                child: const Text('buka'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('buka'));
      await tester.pumpAndSettle();

      expect(find.text('Bahan dasar lain'), findsOneWidget);

      // Nama kosong dan duplikat ditolak dengan pesan.
      await tester.tap(find.text('Tambah'));
      await tester.pump();
      expect(find.text('Nama bahan wajib diisi'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), 'Tonic');
      await tester.pump();
      expect(find.text('Nama bahan wajib diisi'), findsNothing);
      await tester.tap(find.text('Tambah'));
      await tester.pump();
      expect(find.text('Bahan sudah ada'), findsOneWidget);
      expect(done, isFalse);

      // Isian valid: nama, bersoda, dan warna terakhir.
      await tester.enterText(find.byType(TextFormField), 'Kombucha');
      await tester.tap(find.byType(Switch));
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Warna cairan').last);
      await tester.pump();
      await tester.tap(find.text('Tambah'));
      await tester.pumpAndSettle();

      expect(done, isTrue);
      expect(result?.name, 'Kombucha');
      expect(result?.sparkling, isTrue);
      expect(result?.color, MocktailCustomBase.palette.last);
    });

    testWidgets('hiasan: pil Hiasan lain, pakai, dan tahan untuk hapus', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1170, 8000);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      final MocktailViewModel vm = MocktailViewModel(repository: repo);
      await tester.runAsync(() => vm.addCustomGarnish('Rosemary'));
      vm.toggleCustomGarnish('Rosemary'); // lepas dulu
      int added = 0;
      String? deleted;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ListenableBuilder(
                listenable: vm,
                builder: (BuildContext _, Widget? _) => MocktailAdjustPanel(
                  viewModel: vm,
                  onAddCustomGarnish: () => added++,
                  onDeleteCustomGarnish: (String n) => deleted = n,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Sesuaikan mocktail'));
      await tester.pumpAndSettle();

      expect(find.text('Hiasan lain'), findsOneWidget);
      expect(find.text('Rosemary'), findsOneWidget);
      expect(find.textContaining('Tahan hiasan buatan'), findsOneWidget);

      await tester.tap(find.text('Hiasan lain'));
      expect(added, 1);

      await tester.tap(find.text('Rosemary'));
      await tester.pump();
      expect(vm.spec.customGarnishes, <String>{'Rosemary'});

      await tester.longPress(find.text('Rosemary'));
      await tester.pump();
      expect(deleted, 'Rosemary');
    });

    testWidgets('dialog Hiasan lain: validasi dan hasil', (
      WidgetTester tester,
    ) async {
      final MocktailViewModel vm = MocktailViewModel(repository: repo);
      String? result;
      bool done = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (BuildContext context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await showMocktailGarnishDialog(
                    context,
                    validator: vm.validateGarnishName,
                  );
                  done = true;
                },
                child: const Text('buka'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('buka'));
      await tester.pumpAndSettle();
      expect(find.text('Hiasan lain'), findsOneWidget);

      await tester.tap(find.text('Tambah'));
      await tester.pump();
      expect(find.text('Nama hiasan wajib diisi'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), 'Daun mint');
      await tester.tap(find.text('Tambah'));
      await tester.pump();
      expect(find.text('Hiasan sudah ada'), findsOneWidget);
      expect(done, isFalse);

      await tester.enterText(find.byType(TextFormField), ' Rosemary ');
      await tester.tap(find.text('Tambah'));
      await tester.pumpAndSettle();
      expect(done, isTrue);
      expect(result, 'Rosemary');
    });

    testWidgets('sirup ml sendiri: mode, field, dan batas', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1170, 8000);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      final MocktailViewModel vm = MocktailViewModel(repository: repo);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ListenableBuilder(
                listenable: vm,
                builder: (BuildContext _, Widget? _) => MocktailPanel(
                  viewModel: vm,
                  onAddCustomSyrup: () {},
                  onSyrupLimit: () {},
                  onAddCustomBase: () {},
                  onDeleteCustomBase: (MocktailCustomBase _) {},
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Tingkat manis'.toUpperCase()), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('ml-Grenadine')), findsNothing);

      await tester.tap(find.text('Sendiri (ml)'));
      await tester.pump();
      expect(vm.spec.customMl, isTrue);
      // Tingkat manis disembunyikan di mode ini.
      expect(find.text('Tingkat manis'.toUpperCase()), findsNothing);
      final Finder row = find.byKey(const ValueKey<String>('ml-Grenadine'));
      expect(row, findsOneWidget);
      final Finder field = find.descendant(
        of: row,
        matching: find.byType(TextField),
      );
      expect(tester.widget<TextField>(field).controller?.text, '29');
      expect(find.textContaining('Total sirup 29 ml'), findsOneWidget);

      await tester.enterText(field, '35');
      await tester.pump();
      expect(vm.spec.syrups.first.ml, 35);

      // Tidak valid: ViewModel tidak berubah.
      await tester.enterText(field, '0');
      await tester.pump();
      expect(vm.spec.syrups.first.ml, 35);

      // Tombol + menyamakan field.
      final SemanticsHandle semantics = tester.ensureSemantics();
      await tester.enterText(field, '35');
      await tester.tap(find.bySemanticsLabel('Tambah takaran Grenadine'));
      await tester.pump();
      semantics.dispose();
      expect(vm.spec.syrups.first.ml, 36);
      expect(tester.widget<TextField>(field).controller?.text, '36');

      await tester.tap(find.text('Otomatis'));
      await tester.pump();
      expect(vm.spec.customMl, isFalse);
      expect(find.text('Tingkat manis'.toUpperCase()), findsOneWidget);
    });

    testWidgets('baris ml sendiri tampil di iOS (tanpa induk Material)', (
      WidgetTester tester,
    ) async {
      double? typed;
      await tester.pumpWidget(
        CupertinoApp(
          // Seperti aplikasi asli: Cupertino, tetapi dengan lokalisasi Material.
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: CupertinoPageScaffold(
            child: SyrupMlRow(
              syrup: const MocktailSyrup('Grenadine', ml: 29),
              onMinus: () {},
              onPlus: () {},
              validator: MocktailViewModel(repository: repo).validateSyrupMl,
              onValid: (double v) => typed = v,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      final Finder field = find.byType(TextField);
      expect(tester.widget<TextField>(field).controller?.text, '29');
      await tester.enterText(field, '42');
      expect(typed, 42);
    });

    testWidgets('slider rasio kopi tampil di iOS (tanpa induk Material)', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1170, 3000);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      final BrewViewModel vm = BrewViewModel(repository: repo);
      addTearDown(vm.dispose);
      await tester.pumpWidget(
        CupertinoApp(
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: CupertinoPageScaffold(
            child: SingleChildScrollView(
              child: CustomizationPanel(viewModel: vm),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Sesuaikan resep'));
      await tester.pump(const Duration(milliseconds: 500));

      expect(tester.takeException(), isNull);
      expect(find.text('Rasio air:kopi'), findsOneWidget);
    });

    testWidgets('panel Sesuaikan: porsi, es, jeruk, hiasan, dan kembalikan', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1170, 6000);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      final MocktailViewModel vm = MocktailViewModel(repository: repo);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ListenableBuilder(
                listenable: vm,
                builder: (BuildContext _, Widget? _) => MocktailAdjustPanel(
                  viewModel: vm,
                  onAddCustomGarnish: () {},
                  onDeleteCustomGarnish: (String _) {},
                ),
              ),
            ),
          ),
        ),
      );

      // Tertutup bawaan, tanpa lencana.
      expect(find.text('Jumlah porsi'), findsNothing);
      expect(find.text('Disesuaikan'), findsNothing);

      await tester.tap(find.text('Sesuaikan mocktail'));
      await tester.pumpAndSettle();
      expect(find.text('Jumlah porsi'), findsOneWidget);
      expect(find.text('Kembalikan ke bawaan'), findsNothing);

      final SemanticsHandle semantics = tester.ensureSemantics();
      await tester.tap(find.bySemanticsLabel('Tambah porsi'));
      await tester.tap(find.text('Daun mint'));
      await tester.pumpAndSettle();
      semantics.dispose();
      expect(vm.spec.servings, 2);
      expect(vm.spec.garnishes, contains(MocktailGarnish.mint));
      expect(vm.adjusted, isTrue);
      expect(find.text('Disesuaikan'), findsOneWidget);

      await tester.tap(find.text('Kembalikan ke bawaan'));
      await tester.pumpAndSettle();
      expect(vm.spec.servings, 1);
      expect(vm.spec.garnishes, MocktailViewModel.defaultSpec.garnishes);
      expect(vm.adjusted, isFalse);
      expect(find.text('Disesuaikan'), findsNothing);
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
      expect(find.textContaining('Total 58 ml'), findsWidgets); // 2 porsi
      expect(find.textContaining('Isi gelas dengan es batu'), findsOneWidget);
      expect(find.textContaining('Ulangi untuk 2 porsi'), findsOneWidget);
    });
  });
}
