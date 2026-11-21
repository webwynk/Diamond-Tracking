import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// Settings for the tracker's Android foreground service, used by the app
/// (to start it) and by Android (to restart it after a phone restart, which
/// reuses the saved settings).
abstract final class TrackerServiceConfig {
  const TrackerServiceConfig._();

  static const int serviceId = 4101;

  /// The service's heartbeat: uploads, battery check, 11:00 PM check.
  static const Duration tickInterval = Duration(minutes: 1);

  /// How often to ask for a GPS fix. The point filter decides what to keep.
  static const Duration gpsInterval = Duration(seconds: 30);

  /// Re-read the server time this often (the phone's clock may drift or be
  /// changed).
  static const int clockResyncTicks = 30;

  /// Whether to read the server time on this tick: every tick until the first
  /// read works (a phone restart with no internet, L44), then every
  /// [clockResyncTicks].
  static bool clockSyncDue(int tick, {required bool synced}) =>
      !synced || tick % clockResyncTicks == 0;

  static void init() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'duty_tracking',
        channelName: 'Duty tracking',
        channelDescription: 'Shown while your route is being recorded',
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(
          tickInterval.inMilliseconds,
        ),
        // Start again after a phone restart, and after an app update, unless
        // the service was stopped on purpose (duty over).
        autoRunOnBoot: true,
        autoRunOnMyPackageReplaced: true,
        // Restart the service if Android kills it.
        allowAutoRestart: true,
        // Keeps the minute timer running with the screen off.
        allowWakeLock: true,
      ),
    );
  }
}
