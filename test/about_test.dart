import 'package:brewlogic/core/app_info.dart';
import 'package:brewlogic/views/about_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'Tentang menampilkan aplikasi, versi, pengembang, dan tech stack',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1170, 9000);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const MaterialApp(home: AboutScreen()));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(seconds: 3));

      await tester.tap(find.textContaining('teknologi dipakai'));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Hadi Ramdhani'), findsOneWidget);
      expect(find.text('Versi ${AppInfo.version}'), findsOneWidget);
      expect(find.text('BrewLogic'), findsWidgets);
      for (final TechItem item in AppInfo.techStack) {
        expect(find.text(item.name), findsOneWidget, reason: item.name);
      }
      expect(find.byType(Image), findsNWidgets(2));
      expect(find.text(AppInfo.developerRole), findsOneWidget);
      expect(find.text(AppInfo.developerLocation), findsOneWidget);
      expect(find.text(AppInfo.githubHandle), findsOneWidget);
      expect(find.text(AppInfo.instagramHandle), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
