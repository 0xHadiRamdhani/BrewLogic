import 'dart:io';

import 'package:brewlogic/models/brew_model.dart';
import 'package:brewlogic/services/journal_repository.dart';
import 'package:brewlogic/services/timer_alerts.dart';
import 'package:brewlogic/viewmodels/brew_viewmodel.dart';
import 'package:brewlogic/viewmodels/settings_viewmodel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

class _RecordingAlerts implements TimerAlerts {
  final List<String> calls = <String>[];
  Duration? scheduledAfter;
  bool permission = true;

  @override
  Future<void> setKeepAwake({required bool enabled}) async =>
      calls.add('awake:$enabled');

  @override
  Future<void> playPhaseCue() async => calls.add('phase');

  @override
  Future<void> playDoneCue() async => calls.add('done');

  @override
  Future<bool> requestNotificationPermission() async {
    calls.add('permission');
    return permission;
  }

  @override
  Future<void> scheduleFinishNotification({
    required Duration after,
    required String title,
    required String body,
  }) async {
    scheduledAfter = after;
    calls.add('schedule');
  }

  @override
  Future<void> cancelFinishNotification() async => calls.add('cancel');

  @override
  Future<void> dispose() async => calls.add('dispose');
}

class _Prefs implements TimerPrefs {
  const _Prefs({this.awake = true, this.notify = true});

  final bool awake;
  final bool notify;

  @override
  bool get soundEnabled => true;

  @override
  bool get keepAwakeEnabled => awake;

  @override
  bool get notifyEnabled => notify;
}

Future<void> _flush() => Future<void>.delayed(Duration.zero);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;
  late JournalRepository repo;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('brewlogic_alerts_test');
    repo = await JournalRepository.open(path: dir.path);
  });

  tearDown(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  test(
    'mulai menyalakan layar dan menjadwalkan notifikasi sisa waktu',
    () async {
      final _RecordingAlerts alerts = _RecordingAlerts();
      final BrewViewModel vm = BrewViewModel(repository: repo, alerts: alerts);
      addTearDown(vm.dispose);

      vm.updateGrams('18');
      final int total = vm.calculation!.totalSeconds;
      vm.startTimer();
      await _flush();

      expect(alerts.calls, containsAllInOrder(<String>['awake:true']));
      expect(alerts.calls, containsAll(<String>['permission', 'schedule']));
      expect(
        alerts.scheduledAfter!.inSeconds,
        inInclusiveRange(total, total + 1),
        reason: 'sisa waktu + 1 detik',
      );
    },
  );

  test('jeda dan reset melepas layar dan membatalkan notifikasi', () async {
    final _RecordingAlerts alerts = _RecordingAlerts();
    final BrewViewModel vm = BrewViewModel(repository: repo, alerts: alerts);
    addTearDown(vm.dispose);

    vm.updateGrams('18');
    vm.startTimer();
    await _flush();
    alerts.calls.clear();

    vm.pauseTimer();
    expect(alerts.calls, containsAll(<String>['awake:false', 'cancel']));

    alerts.calls.clear();
    vm.resetTimer();
    expect(alerts.calls, containsAll(<String>['awake:false', 'cancel']));
  });

  test('izin ditolak: tidak ada notifikasi yang dijadwalkan', () async {
    final _RecordingAlerts alerts = _RecordingAlerts()..permission = false;
    final BrewViewModel vm = BrewViewModel(repository: repo, alerts: alerts);
    addTearDown(vm.dispose);

    vm.updateGrams('18');
    vm.startTimer();
    await _flush();

    expect(alerts.calls, contains('permission'));
    expect(alerts.calls, isNot(contains('schedule')));
  });

  test('preferensi dimatikan: layar dan notifikasi tidak disentuh', () async {
    final _RecordingAlerts alerts = _RecordingAlerts();
    final BrewViewModel vm = BrewViewModel(
      repository: repo,
      alerts: alerts,
      prefs: const _Prefs(awake: false, notify: false),
    );
    addTearDown(vm.dispose);

    vm.updateGrams('18');
    vm.startTimer();
    await _flush();

    expect(alerts.calls, isNot(contains('awake:true')));
    expect(alerts.calls, isNot(contains('permission')));
    expect(alerts.calls, isNot(contains('schedule')));
  });

  test('SettingsViewModel menyimpan preferensi timer', () async {
    final SettingsViewModel settings = SettingsViewModel(repository: repo);
    expect(settings.soundEnabled, isTrue);
    expect(settings.keepAwakeEnabled, isTrue);
    expect(settings.notifyEnabled, isTrue);

    settings
      ..setSound(value: false)
      ..setKeepAwake(value: false)
      ..setNotify(value: false);
    await _flush();

    final SettingsViewModel reloaded = SettingsViewModel(repository: repo);
    expect(reloaded.soundEnabled, isFalse);
    expect(reloaded.keepAwakeEnabled, isFalse);
    expect(reloaded.notifyEnabled, isFalse);
  });

  test('model BrewInputMode ikut tersimpan di cache', () async {
    final BrewViewModel vm = BrewViewModel(repository: repo);
    vm.selectInputMode(BrewInputMode.water);
    vm.updateWater('300');
    await _flush();
    vm.dispose();

    final BrewViewModel again = BrewViewModel(repository: repo);
    addTearDown(again.dispose);
    expect(again.inputMode, BrewInputMode.water);
    expect(again.waterText, '300');
    expect(again.calculation?.coffeeGrams, 20);
  });
}
