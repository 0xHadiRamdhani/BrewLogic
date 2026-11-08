import 'dart:io';

import 'package:brewlogic/core/theme/app_theme.dart';
import 'package:brewlogic/core/utils/formatters.dart';
import 'package:brewlogic/models/brew_model.dart';
import 'package:brewlogic/services/journal_repository.dart';
import 'package:brewlogic/viewmodels/settings_viewmodel.dart';
import 'package:brewlogic/views/widgets/brew_icons.dart';
import 'package:brewlogic/views/widgets/glass_controls.dart';
import 'package:brewlogic/views/widgets/star_rating_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('label hari jurnal', () {
    final DateTime now = DateTime(2026, 11, 8, 21, 30);

    test('hari ini, kemarin, dan tanggal lama', () {
      expect(dayLabel(DateTime(2026, 11, 8, 0, 5), now: now), 'Hari ini');
      expect(dayLabel(DateTime(2026, 11, 7, 23, 59), now: now), 'Kemarin');
      expect(dayLabel(DateTime(2026, 11, 5, 9), now: now), '5 Nov 2026');
    });

    test('isSameDay membandingkan tanggal kalender', () {
      expect(
        isSameDay(DateTime(2026, 11, 8, 1), DateTime(2026, 11, 8, 23)),
        isTrue,
      );
      expect(
        isSameDay(DateTime(2026, 11, 8, 23), DateTime(2026, 11, 9, 1)),
        isFalse,
      );
    });
  });

  group('ukuran teks', () {
    late Directory dir;
    late JournalRepository repo;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('brewlogic_design_test');
      repo = await JournalRepository.open(path: dir.path);
      TextScalePrefs.factor.value = 1;
    });

    tearDown(() async {
      await Hive.close();
      await dir.delete(recursive: true);
      TextScalePrefs.factor.value = 1;
    });

    test('pilihan tersimpan dan mengubah faktor skala', () async {
      final SettingsViewModel vm = SettingsViewModel(repository: repo);
      expect(vm.textSize, TextSizeOption.normal);

      vm.setTextSize(TextSizeOption.large);
      expect(TextScalePrefs.factor.value, TextSizeOption.large.factor);
      await repo.flushCache();

      await Hive.close();
      repo = await JournalRepository.open(path: dir.path);
      final SettingsViewModel reopened = SettingsViewModel(repository: repo);
      expect(reopened.textSize, TextSizeOption.large);
      expect(TextScalePrefs.factor.value, TextSizeOption.large.factor);
    });
  });

  group('widget desain', () {
    testWidgets('rating memakai lima biji kopi', (WidgetTester tester) async {
      int tapped = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StarRatingBar(rating: 3, onChanged: (int v) => tapped = v),
          ),
        ),
      );
      expect(find.byType(BeanIcon), findsNWidgets(5));
      await tester.tap(find.byType(BeanIcon).at(4));
      expect(tapped, 5);
    });

    testWidgets('segmented control menampilkan ikon dan memilih segmen', (
      WidgetTester tester,
    ) async {
      int selected = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GlassSegmentedControl(
              labels: <String>[
                for (final BrewMethod m in BrewMethod.values) m.label,
              ],
              iconBuilders: <Widget Function(Color, double)>[
                for (final BrewMethod m in BrewMethod.values)
                  (Color c, double s) =>
                      BrewMethodIcon(method: m, color: c, size: s),
              ],
              selectedIndex: selected,
              onChanged: (int i) => selected = i,
            ),
          ),
        ),
      );
      expect(find.byType(BrewMethodIcon), findsNWidgets(4));
      await tester.tap(find.text('Chemex'));
      expect(selected, 3);
      expect(tester.takeException(), isNull);
    });
  });
}
