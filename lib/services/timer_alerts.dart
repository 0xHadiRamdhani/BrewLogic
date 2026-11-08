import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:wakelock_plus/wakelock_plus.dart';

/// Umpan balik di luar layar untuk timer seduh: layar tetap menyala, nada
/// pengingat, dan notifikasi saat seduhan selesai.
///
/// Semua metode aman dipanggil kapan saja; kegagalan platform (izin ditolak,
/// plugin tidak tersedia) diabaikan agar timer tidak pernah terganggu.
abstract interface class TimerAlerts {
  Future<void> setKeepAwake({required bool enabled});
  Future<void> playPhaseCue();
  Future<void> playDoneCue();

  /// Meminta izin notifikasi. `true` jika notifikasi boleh ditampilkan.
  Future<bool> requestNotificationPermission();

  /// Menjadwalkan notifikasi [after] dari sekarang, menggantikan yang lama.
  Future<void> scheduleFinishNotification({
    required Duration after,
    required String title,
    required String body,
  });

  Future<void> cancelFinishNotification();
  Future<void> dispose();
}

/// Tidak melakukan apa-apa; dipakai di tes dan sebagai nilai bawaan.
class NoopTimerAlerts implements TimerAlerts {
  const NoopTimerAlerts();

  @override
  Future<void> setKeepAwake({required bool enabled}) async {}

  @override
  Future<void> playPhaseCue() async {}

  @override
  Future<void> playDoneCue() async {}

  @override
  Future<bool> requestNotificationPermission() async => false;

  @override
  Future<void> scheduleFinishNotification({
    required Duration after,
    required String title,
    required String body,
  }) async {}

  @override
  Future<void> cancelFinishNotification() async {}

  @override
  Future<void> dispose() async {}
}

/// Implementasi nyata memakai `wakelock_plus`, `audioplayers`, dan
/// `flutter_local_notifications`.
class PlatformTimerAlerts implements TimerAlerts {
  static const int _finishNotificationId = 1;
  static const String _channelId = 'brew_timer';

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  AudioPlayer? _player;
  Future<void>? _initializing;

  Future<void> _ensureNotifications() => _initializing ??= _initialize();

  Future<void> _initialize() async {
    tzdata.initializeTimeZones();
    await _notifications.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
  }

  @override
  Future<void> setKeepAwake({required bool enabled}) async {
    try {
      await WakelockPlus.toggle(enable: enabled);
    } catch (_) {
      return;
    }
  }

  Future<void> _play(String asset) async {
    try {
      final AudioPlayer player = _player ??= AudioPlayer();
      await player.stop();
      await player.play(AssetSource(asset));
    } catch (_) {
      return;
    }
  }

  @override
  Future<void> playPhaseCue() => _play('sounds/phase.wav');

  @override
  Future<void> playDoneCue() => _play('sounds/done.wav');

  @override
  Future<bool> requestNotificationPermission() async {
    try {
      await _ensureNotifications();
      final bool? ios = await _notifications
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, sound: true);
      final bool? android = await _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
      return (ios ?? android) ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> scheduleFinishNotification({
    required Duration after,
    required String title,
    required String body,
  }) async {
    try {
      await _ensureNotifications();
      await _notifications.cancel(id: _finishNotificationId);
      await _notifications.zonedSchedule(
        id: _finishNotificationId,
        title: title,
        body: body,
        scheduledDate: tz.TZDateTime.now(tz.UTC).add(after),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            'Timer seduh',
            channelDescription: 'Pengingat saat seduhan selesai',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentSound: true,
            interruptionLevel: InterruptionLevel.timeSensitive,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (_) {
      return;
    }
  }

  @override
  Future<void> cancelFinishNotification() async {
    try {
      await _ensureNotifications();
      await _notifications.cancel(id: _finishNotificationId);
    } catch (_) {
      return;
    }
  }

  @override
  Future<void> dispose() async {
    try {
      await _player?.dispose();
      _player = null;
    } catch (_) {
      return;
    }
  }
}
