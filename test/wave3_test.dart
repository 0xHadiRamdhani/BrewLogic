import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:brewlogic/models/brew_model.dart';
import 'package:brewlogic/services/backup_service.dart';
import 'package:brewlogic/services/bean_freshness.dart';
import 'package:brewlogic/services/brew_calculator_service.dart';
import 'package:brewlogic/services/data_transfer_service.dart';
import 'package:brewlogic/services/journal_repository.dart';
import 'package:brewlogic/services/photo_storage.dart';
import 'package:brewlogic/services/stats_service.dart';
import 'package:brewlogic/viewmodels/bean_viewmodel.dart';
import 'package:brewlogic/viewmodels/journal_viewmodel.dart';
import 'package:brewlogic/views/widgets/share_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

BrewEntry _entry(
  String id, {
  required DateTime at,
  BrewMethod method = BrewMethod.v60,
  RoastLevel roast = RoastLevel.medium,
  int rating = 4,
  int seconds = 150,
  String notes = '',
  List<FlavorTag> tags = const <FlavorTag>[],
  String grinder = '',
  String? bean,
}) => BrewEntry(
  id: id,
  createdAt: at,
  coffeeGrams: 18,
  waterGrams: 270,
  method: method,
  roast: roast,
  rating: rating,
  tastingNotes: notes,
  brewSeconds: seconds,
  flavorTags: tags,
  grinderSetting: grinder,
  beanName: bean,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final DateTime now = DateTime(2026, 11, 8, 12);

  group('kesegaran biji', () {
    const BeanFreshnessService svc = BeanFreshnessService();
    BeanFreshness at(int daysAgo) =>
        svc.evaluate(now.subtract(Duration(days: daysAgo)), now)!;

    test('tahap mengikuti jumlah hari', () {
      expect(at(0).stage, FreshnessStage.resting);
      expect(at(4).stage, FreshnessStage.resting);
      expect(at(5).stage, FreshnessStage.peak);
      expect(at(21).stage, FreshnessStage.peak);
      expect(at(22).stage, FreshnessStage.good);
      expect(at(35).stage, FreshnessStage.good);
      expect(at(36).stage, FreshnessStage.fading);
      expect(at(12).summary, 'Hari ke-12 · Puncak rasa');
    });

    test('tanpa tanggal null; tanggal masa depan dianggap hari ke-0', () {
      expect(svc.evaluate(null, now), isNull);
      expect(
        svc.evaluate(now.add(const Duration(days: 3)), now)!.daysSinceRoast,
        0,
      );
    });
  });

  group('statistik', () {
    const StatsService svc = StatsService();

    test('jurnal kosong', () {
      final JournalStats s = svc.compute(const <BrewEntry>[], now);
      expect(s.isEmpty, isTrue);
      expect(s.currentStreak, 0);
      expect(s.last7Days, hasLength(7));
      expect(s.bestCombo, isNull);
    });

    test('ringkasan, streak, kombinasi terbaik, dan tag', () {
      final List<BrewEntry> entries = <BrewEntry>[
        _entry('a', at: now, rating: 5, tags: <FlavorTag>[FlavorTag.floral]),
        _entry('b', at: now.subtract(const Duration(days: 1)), rating: 5),
        _entry(
          'c',
          at: now.subtract(const Duration(days: 2)),
          rating: 3,
          method: BrewMethod.chemex,
          tags: <FlavorTag>[FlavorTag.floral, FlavorTag.sweet],
        ),
        _entry(
          'd',
          at: now.subtract(const Duration(days: 5)),
          rating: 2,
          seconds: 0,
        ),
        _entry(
          'e',
          at: now.subtract(const Duration(days: 6)),
          rating: 4,
          method: BrewMethod.chemex,
        ),
      ];
      final JournalStats s = svc.compute(entries, now);
      expect(s.totalBrews, 5);
      expect(s.averageRating, closeTo(3.8, 0.001));
      expect(s.averageBrewSeconds, 150, reason: 'durasi 0 diabaikan');
      expect(s.currentStreak, 3);
      expect(s.longestStreak, 3);
      expect(s.recentRatings, <int>[
        4,
        2,
        3,
        5,
        5,
      ], reason: 'terlama → terbaru');
      expect(s.favoriteMethod?.method, BrewMethod.v60);
      expect(s.perMethod.first.count, 3);
      expect(s.last7Days.last.count, 1, reason: 'hari ini');
      expect(s.last7Days.fold<int>(0, (int a, DayCount d) => a + d.count), 5);
      // Kombinasi minimal 2 catatan: V60·Medium (5,5,2 → 4.0), Chemex·Medium (3,4 → 3.5).
      expect(s.bestCombo?.method, BrewMethod.v60);
      expect(s.bestCombo?.count, 3);
      expect(s.topTags.first.tag, FlavorTag.floral);
      expect(s.topTags.first.count, 2);
    });

    test('streak tetap hidup bila kemarin menyeduh dan hari ini belum', () {
      final JournalStats s = svc.compute(<BrewEntry>[
        _entry('a', at: now.subtract(const Duration(days: 1))),
        _entry('b', at: now.subtract(const Duration(days: 2))),
      ], now);
      expect(s.currentStreak, 2);
    });

    test('streak putus bila lebih dari sehari tanpa seduhan', () {
      final JournalStats s = svc.compute(<BrewEntry>[
        _entry('a', at: now.subtract(const Duration(days: 2))),
        _entry('b', at: now.subtract(const Duration(days: 3))),
        _entry('c', at: now.subtract(const Duration(days: 4))),
      ], now);
      expect(s.currentStreak, 0);
      expect(s.longestStreak, 3);
    });

    test('tanpa kombinasi dengan 2 catatan, bestCombo null', () {
      final JournalStats s = svc.compute(<BrewEntry>[
        _entry('a', at: now),
        _entry('b', at: now, method: BrewMethod.chemex),
      ], now);
      expect(s.bestCombo, isNull);
    });
  });

  group('cadangan JSON dan CSV', () {
    const BackupService svc = BackupService();
    final BrewEntry rich = _entry(
      'e1',
      at: DateTime.fromMillisecondsSinceEpoch(1700000000000),
      method: BrewMethod.chemex,
      roast: RoastLevel.dark,
      rating: 5,
      notes: 'Cokelat, “manis”\nbaris dua — ☕',
      tags: <FlavorTag>[FlavorTag.chocolate, FlavorTag.nutty],
      grinder: '21 klik',
      bean: 'Gayo Natural',
    ).copyWith(taste: TasteFeedback.balanced);
    final BrewRecipe recipe = BrewRecipe(
      id: 'r1',
      name: 'Pagi',
      createdAt: DateTime.fromMillisecondsSinceEpoch(1700000001000),
      coffeeGrams: 20,
      method: BrewMethod.v60,
      roast: RoastLevel.light,
      customization: const BrewCustomization(ratio: 16, bloomSeconds: 45),
    );
    final BrewBean bean = BrewBean(
      id: 'b1',
      name: 'Gayo Natural',
      roaster: 'Roaster X',
      origin: 'Aceh',
      roastDate: DateTime.fromMillisecondsSinceEpoch(1699000000000),
      createdAt: DateTime.fromMillisecondsSinceEpoch(1699000001000),
    );

    test('round-trip menjaga semua field', () {
      final String json = svc.encodeJson(
        entries: <BrewEntry>[rich],
        recipes: <BrewRecipe>[recipe],
        beans: <BrewBean>[bean],
        now: now,
      );
      final BackupData data = svc.decodeJson(json);
      expect(data.skipped, 0);
      expect(data.total, 3);
      final BrewEntry e = data.entries.single;
      expect(e.id, 'e1');
      expect(e.method, BrewMethod.chemex);
      expect(e.roast, RoastLevel.dark);
      expect(e.rating, 5);
      expect(e.tastingNotes, rich.tastingNotes);
      expect(e.taste, TasteFeedback.balanced);
      expect(e.flavorTags, <FlavorTag>[FlavorTag.chocolate, FlavorTag.nutty]);
      expect(e.grinderSetting, '21 klik');
      expect(e.beanName, 'Gayo Natural');
      expect(e.createdAt, rich.createdAt);
      final BrewRecipe r = data.recipes.single;
      expect(r.customization.ratio, 16);
      expect(r.customization.bloomSeconds, 45);
      expect(r.customization.firstPourSeconds, isNull);
      expect(data.beans.single.roastDate, bean.roastDate);
    });

    test('berkas tidak valid ditolak dengan pesan jelas', () {
      expect(
        () => svc.decodeJson('bukan json'),
        throwsA(isA<BackupException>()),
      );
      expect(() => svc.decodeJson('[1,2]'), throwsA(isA<BackupException>()));
      expect(
        () => svc.decodeJson('{"app":"Lain","version":1}'),
        throwsA(isA<BackupException>()),
      );
      expect(
        () => svc.decodeJson('{"app":"BrewLogic","version":99}'),
        throwsA(
          isA<BackupException>().having(
            (BackupException e) => e.message,
            'message',
            contains('lebih baru'),
          ),
        ),
      );
      expect(
        () => svc.decodeJson('{"app":"BrewLogic"}'),
        throwsA(isA<BackupException>()),
      );
    });

    test('item rusak dilewati dan nilai ekstrem dijepit', () {
      final String json = jsonEncode(<String, Object?>{
        'app': 'BrewLogic',
        'version': 1,
        'entries': <Object?>[
          'bukan objek',
          <String, Object?>{'id': 'x'},
          <String, Object?>{
            'id': 'ok',
            'createdAt': 1700000000000,
            'coffeeGrams': 18,
            'waterGrams': 270,
            'method': 'v60',
            'roast': 'medium',
            'rating': 99,
            'tastingNotes': 'n' * 900,
            'grinderSetting': 'g' * 100,
            'brewSeconds': -5,
            'flavorTags': <Object?>['floral', 'tidak-ada', 7],
          },
          <String, Object?>{
            'id': 'bad-enum',
            'createdAt': 1,
            'coffeeGrams': 18,
            'waterGrams': 270,
            'method': 'espresso',
            'roast': 'medium',
            'rating': 3,
          },
          <String, Object?>{
            'id': 'neg',
            'createdAt': 1,
            'coffeeGrams': -1,
            'waterGrams': 270,
            'method': 'v60',
            'roast': 'medium',
            'rating': 3,
          },
        ],
        'recipes': 'bukan list',
      });
      final BackupData data = svc.decodeJson(json);
      expect(data.entries.map((BrewEntry e) => e.id), <String>['ok']);
      expect(data.skipped, 4);
      final BrewEntry e = data.entries.single;
      expect(e.rating, 5);
      expect(e.tastingNotes.length, 500);
      expect(e.grinderSetting.length, 24);
      expect(e.brewSeconds, 0);
      expect(e.flavorTags, <FlavorTag>[FlavorTag.floral]);
    });

    test('CSV: kutip, header, dan netralisasi rumus', () {
      final BrewEntry evil = _entry(
        'e2',
        at: now,
        notes: '=HYPERLINK("http://x")',
        grinder: '+cmd',
      );
      final String csv = svc.encodeCsv(<BrewEntry>[rich, evil]);
      final List<String> lines = csv.split('\n');
      expect(lines.first, startsWith('Tanggal,Metode,Roast'));
      expect(csv, contains('"Cokelat, “manis”\nbaris dua — ☕"'));
      expect(csv, contains("\"'=HYPERLINK(\"\"http://x\"\")\""));
      expect(csv, contains("'+cmd"));
      expect(csv, isNot(contains(',=HYPERLINK')));
    });
  });

  group('penyimpanan (Hive dan berkas)', () {
    late Directory dir;
    late JournalRepository repo;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('brewlogic_wave3_test');
      repo = await JournalRepository.open(path: '${dir.path}/hive');
    });

    tearDown(() async {
      await Hive.close();
      await dir.delete(recursive: true);
    });

    test(
      'PhotoStorage: salin, resolve, hapus, dan tolak path berbahaya',
      () async {
        final PhotoStorage storage = PhotoStorage(
          documentsDirectory: () async => Directory('${dir.path}/docs'),
        );
        final File source = File('${dir.path}/asli.PNG')
          ..writeAsBytesSync(<int>[1, 2, 3]);

        final String name = await storage.importFile(source.path);
        expect(name, endsWith('.png'));
        expect(name.contains('/'), isFalse);
        expect((await storage.resolve(name))!.readAsBytesSync(), <int>[
          1,
          2,
          3,
        ]);

        expect(await storage.resolve('../../etc/passwd'), isNull);
        expect(await storage.resolve(null), isNull);
        expect(await storage.resolve('tidak-ada.jpg'), isNull);

        await storage.delete(name);
        expect(await storage.resolve(name), isNull);
        await storage.delete('tidak-ada.jpg'); // tidak melempar
      },
    );

    test('adapter menyimpan field baru catatan dan biji', () async {
      await repo.save(
        _entry(
          'p1',
          at: now,
          tags: <FlavorTag>[FlavorTag.berry, FlavorTag.spicy],
          grinder: '18 klik',
          bean: 'Biji A',
        ).copyWith(photoName: 'foto.jpg'),
      );
      await repo.saveBean(
        BrewBean(id: 'bb', name: 'Biji A', createdAt: now, roastDate: now),
      );
      await Hive.close();
      repo = await JournalRepository.open(path: '${dir.path}/hive');

      final BrewEntry e = repo.getAll().single;
      expect(e.flavorTags, <FlavorTag>[FlavorTag.berry, FlavorTag.spicy]);
      expect(e.grinderSetting, '18 klik');
      expect(e.photoName, 'foto.jpg');
      expect(e.beanName, 'Biji A');
      expect(repo.getBeans().single.roastDate, now);
    });

    test('BeanViewModel: validasi, simpan, aktif, dan hapus', () async {
      final BeanViewModel vm = BeanViewModel(
        repository: repo,
        clock: () => now,
      );
      expect(vm.validateName(''), isNotNull);
      expect(vm.validateName('x' * 41), isNotNull);
      expect(vm.validateRoastDate(now.add(const Duration(days: 1))), isNotNull);
      expect(vm.validateRoastDate(now), isNull);

      expect(await vm.saveBean(name: '  '), isNotNull);
      expect(
        await vm.saveBean(
          name: 'Gayo',
          roaster: 'R',
          roastDate: now.subtract(const Duration(days: 10)),
        ),
        isNull,
      );
      expect(vm.beans, hasLength(1));
      expect(await vm.saveBean(name: 'gayo'), isNotNull, reason: 'kembar');

      final BrewBean gayo = vm.beans.single;
      expect(vm.freshnessOf(gayo)?.stage, FreshnessStage.peak);

      // Ubah (nama sendiri tidak dianggap kembar).
      expect(await vm.saveBean(id: gayo.id, name: 'Gayo Natural'), isNull);
      expect(vm.beans.single.name, 'Gayo Natural');
      expect(vm.beans.single.createdAt, gayo.createdAt);

      vm.selectActive(gayo.id);
      expect(vm.active?.id, gayo.id);
      expect(
        BeanViewModel(repository: repo).active?.id,
        gayo.id,
        reason: 'persisten',
      );
      vm.selectActive(gayo.id);
      expect(vm.active, isNull, reason: 'ketuk lagi melepas');

      vm.selectActive(gayo.id);
      expect(await vm.deleteBean(gayo.id), isNull);
      expect(vm.beans, isEmpty);
      expect(vm.active, isNull);
    });

    test(
      'jurnal: tag, gilingan, biji, pencarian, dan pembersihan foto',
      () async {
        final PhotoStorage storage = PhotoStorage(
          documentsDirectory: () async => Directory('${dir.path}/docs'),
        );
        final JournalViewModel vm = JournalViewModel(
          repository: repo,
          photos: storage,
        );
        File photo(String n) =>
            File('${dir.path}/$n')..writeAsBytesSync(<int>[9, 9]);
        final String photoA = await storage.importFile(photo('a.jpg').path);
        final String photoB = await storage.importFile(photo('b.jpg').path);

        final BrewCalculation c = const BrewCalculatorService().calculate(
          coffeeGrams: 18,
          method: BrewMethod.v60,
          roast: RoastLevel.medium,
        );
        expect(
          await vm.saveBrew(
            calculation: c,
            rating: 4,
            tastingNotes: '',
            brewSeconds: 100,
            grinderSetting: 'g' * 30,
          ),
          isNotNull,
          reason: 'gilingan terlalu panjang',
        );
        expect(
          await vm.saveBrew(
            calculation: c,
            rating: 4,
            tastingNotes: 'enak',
            brewSeconds: 100,
            flavorTags: <FlavorTag>[FlavorTag.citrus],
            grinderSetting: ' 21 klik ',
            photoName: photoA,
            bean: BrewBean(id: 'z', name: 'Kerinci', createdAt: now),
          ),
          isNull,
        );
        final BrewEntry saved = vm.entries.single;
        expect(saved.grinderSetting, '21 klik');
        expect(saved.beanId, 'z');
        expect(saved.beanName, 'Kerinci');

        vm.setQuery('kerinci');
        expect(vm.visibleEntries, hasLength(1));
        vm.setQuery('jeruk');
        expect(vm.visibleEntries, hasLength(1));
        vm.setQuery('21 klik');
        expect(vm.visibleEntries, hasLength(1));
        vm.setQuery('tidak ada');
        expect(vm.visibleEntries, isEmpty);
        vm.resetFilters();

        // Ganti foto → foto lama dihapus.
        expect(
          await vm.updateEntry(
            id: saved.id,
            rating: 4,
            tastingNotes: 'enak',
            flavorTags: <FlavorTag>[FlavorTag.citrus, FlavorTag.sweet],
            grinderSetting: '22 klik',
            photoName: photoB,
          ),
          isNull,
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(await storage.resolve(photoA), isNull);
        expect(await storage.resolve(photoB), isNotNull);
        expect(vm.entries.single.flavorTags, hasLength(2));
        expect(
          vm.entries.single.beanName,
          'Kerinci',
          reason: 'biji dipertahankan',
        );

        // Hapus foto lewat clearPhoto.
        expect(
          await vm.updateEntry(
            id: saved.id,
            rating: 4,
            tastingNotes: 'enak',
            clearPhoto: true,
          ),
          isNull,
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(await storage.resolve(photoB), isNull);
        expect(vm.entries.single.photoName, isNull);

        // Hapus catatan membersihkan fotonya.
        final String photoC = await storage.importFile(photo('c.jpg').path);
        await vm.updateEntry(
          id: saved.id,
          rating: 4,
          tastingNotes: 'enak',
          photoName: photoC,
        );
        expect(await vm.deleteEntry(saved.id), isNull);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(await storage.resolve(photoC), isNull);
      },
    );

    test('impor: menggabungkan tanpa menimpa dan menghitung hasil', () async {
      final DataTransferService transfer = DataTransferService(
        repository: repo,
      );
      await repo.save(_entry('same', at: now, notes: 'versi lokal'));

      final String json = const BackupService().encodeJson(
        entries: <BrewEntry>[
          _entry('same', at: now, notes: 'versi berkas'),
          _entry('baru', at: now.subtract(const Duration(days: 1))),
        ],
        recipes: <BrewRecipe>[
          BrewRecipe(
            id: 'r',
            name: 'R',
            createdAt: now,
            coffeeGrams: 15,
            method: BrewMethod.v60,
            roast: RoastLevel.light,
          ),
        ],
        beans: <BrewBean>[BrewBean(id: 'b', name: 'B', createdAt: now)],
        now: now,
      );

      final ImportResult first = await transfer.importJson(json);
      expect(first.addedEntries, 1);
      expect(first.addedRecipes, 1);
      expect(first.addedBeans, 1);
      expect(first.alreadyPresent, 1);
      expect(first.summary, contains('1 catatan'));
      expect(
        repo.getAll().firstWhere((BrewEntry e) => e.id == 'same').tastingNotes,
        'versi lokal',
        reason: 'tidak menimpa',
      );

      final ImportResult again = await transfer.importJson(json);
      expect(again.added, 0);
      expect(again.alreadyPresent, 4);
      expect(again.summary, startsWith('Tidak ada data baru'));
      expect(repo.getAll(), hasLength(2));

      expect(() => transfer.importJson('{}'), throwsA(isA<BackupException>()));
    });

    test('ekspor: byte UTF-8 utuh dan CSV ber-BOM', () async {
      final DataTransferService transfer = DataTransferService(
        repository: repo,
      );
      await repo.save(_entry('u', at: now, notes: 'Cokelat — ☕ “manis”'));

      final String jsonText = utf8.decode(transfer.jsonBytes(now));
      expect(jsonText, contains('Cokelat — ☕ “manis”'));
      expect(jsonDecode(jsonText), isA<Map<String, Object?>>());

      final List<int> csv = transfer.csvBytes();
      expect(csv.take(3), <int>[0xEF, 0xBB, 0xBF]);
      expect(utf8.decode(csv.skip(3).toList()), contains('Cokelat — ☕'));
    });
  });

  testWidgets('kartu bagikan dirender menjadi PNG 1080x1350', (
    WidgetTester tester,
  ) async {
    final BrewEntry entry = _entry(
      'card',
      at: now,
      rating: 5,
      notes: 'Floral dan manis',
      tags: <FlavorTag>[FlavorTag.floral, FlavorTag.sweet],
      bean: 'Gayo',
    );
    late BuildContext captured;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext context) {
            captured = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    final List<int> png = (await tester.runAsync(() async {
      final Future<List<int>> pending = captureShareCard(captured, entry);
      await tester.pump();
      await tester.pump();
      return pending;
    }))!;

    expect(png.take(8), <int>[137, 80, 78, 71, 13, 10, 26, 10]);
    final ByteData header = ByteData.sublistView(
      Uint8List.fromList(png.sublist(16, 24)),
    );
    expect(header.getUint32(0), 1080);
    expect(header.getUint32(4), 1350);
  });
}
