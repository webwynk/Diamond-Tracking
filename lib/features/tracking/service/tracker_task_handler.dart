import 'dart:async';
import 'dart:io';

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/env.dart';
import '../../../core/logging/app_log.dart';
import '../../../core/supabase/supabase_time_source.dart';
import '../../../core/time/ist_format.dart';
import '../../../core/time/server_clock.dart';
import '../data/track_uploader.dart';
import '../data/tracker_files.dart';
import '../domain/track_fix.dart';
import '../domain/tracker_status.dart';
import '../engine/tracker_engine.dart';
import 'battery_alerts.dart';
import 'proc_system_info.dart';
import 'tracker_directory.dart';
import 'tracker_messages.dart';
import 'tracker_service_config.dart';

/// Entry point of the tracker's own Flutter engine, inside the Android
/// foreground service. Android also calls it after a phone restart.
@pragma('vm:entry-point')
void startTrackerService() {
  FlutterForegroundTask.setTaskHandler(TrackerTaskHandler());
}

/// Connects the [TrackerEngine] to Android: GPS, battery, the notification
/// and messages to the app. Kept thin; the decisions are in the engine.
class TrackerTaskHandler extends TaskHandler {
  final Battery _battery = Battery();
  final BatteryAlerts _alerts = BatteryAlerts();

  TrackerEngine? _engine;
  ServerClock? _clock;
  StreamSubscription<Position>? _positions;
  TrackerMode _mode = TrackerMode.tracking;
  TrackerProblem? _problem;
  DateTime? _problemSince;
  bool _ticking = false;
  int _ticks = 0;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    WidgetsFlutterBinding.ensureInitialized();
    try {
      Env.validate();
      final ServerClock clock = ServerClock(
        source: supabaseTimeSource(
          supabaseUrl: Env.supabaseUrl,
          publishableKey: Env.supabasePublishableKey,
        ),
      );
      _clock = clock;
      await clock.sync();

      // Its own client with no sign-in session: the day's pass is the
      // permission, and the app's session is never refreshed from here.
      final SupabaseClient client = SupabaseClient(
        Env.supabaseUrl,
        Env.supabasePublishableKey,
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      final TrackerEngine engine = TrackerEngine(
        files: TrackerFiles(await trackerDirectory()),
        uploader: SupabaseTrackUploader(client),
        now: clock.now,
        system: const ProcSystemInfo(),
        onBatteryWarning: _onBatteryWarning,
      );
      _engine = engine;
      await _alerts.init();
      AppLog.info('Tracker started by ${starter.name}');
      await _apply(await engine.start());
    } on Object catch (e, st) {
      AppLog.failure('Tracker.onStart', e, st);
      await FlutterForegroundTask.stopService();
    }
  }

  @override
  void onRepeatEvent(DateTime timestamp) => unawaited(_tick());

  @override
  void onReceiveData(Object data) {
    if (data == TrackerMessages.refresh) unawaited(_tick());
  }

  @override
  void onNotificationPressed() => FlutterForegroundTask.launchApp();

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    await _positions?.cancel();
    _positions = null;
    _engine?.shutdown();
  }

  Future<void> _tick() async {
    final TrackerEngine? engine = _engine;
    if (engine == null || _ticking) return;
    _ticking = true;
    try {
      _ticks++;
      final ServerClock? clock = _clock;
      if (clock != null &&
          TrackerServiceConfig.clockSyncDue(_ticks, synced: clock.isSynced)) {
        await clock.sync();
      }
      int? level;
      try {
        level = await _battery.batteryLevel;
      } on Object {
        level = null;
      }
      await _apply(await engine.tick(batteryLevel: level));
    } on Object catch (e, st) {
      AppLog.failure('Tracker.tick', e, st);
    } finally {
      _ticking = false;
    }
  }

  Future<void> _apply(TrackerMode mode) async {
    _mode = mode;
    switch (mode) {
      case TrackerMode.tracking:
        if (_engine?.takeGpsRestart() ?? false) await _restartGps();
        await _ensureGps();
      case TrackerMode.finishing:
        await _positions?.cancel();
        _positions = null;
      case TrackerMode.stop:
        await _positions?.cancel();
        _positions = null;
        FlutterForegroundTask.sendDataToMain(TrackerMessages.stopped);
        await FlutterForegroundTask.stopService();
        return;
    }
    await _updateNotification();
    _sendStatus();
  }

  /// Tells the app (when it is open) what Home should show (points waiting,
  /// no internet, recording stopped).
  void _sendStatus() {
    final TrackerEngine? engine = _engine;
    if (engine == null) return;
    FlutterForegroundTask.sendDataToMain(
      TrackerStatus(
        pendingPoints: engine.pendingCount,
        offline: engine.isOffline,
        problem: _problem,
        problemSince: _problemSince,
      ).toMessage(),
    );
  }

  /// Notes why recording stopped, keeping the time it first stopped.
  void _setProblem(TrackerProblem? problem) {
    if (problem == null) {
      _problemSince = null;
    } else if (_problem == null) {
      _problemSince = _clock?.now() ?? DateTime.now().toUtc();
    }
    _problem = problem;
    _engine?.onProblem(problem);
  }

  /// The notification's line for [_problem].
  String? get _problemText => switch (_problem) {
    TrackerProblem.locationOff => 'Location is off. Turn it on.',
    TrackerProblem.permissionOff => 'Location permission is off. Open the app.',
    TrackerProblem.gps => 'GPS problem. Open the app.',
    null => null,
  };

  /// Starts the GPS stream if it is not running, and notes why it cannot.
  Future<void> _ensureGps() async {
    if (_positions != null) return;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _setProblem(TrackerProblem.locationOff);
        return;
      }
      final LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever ||
          permission == LocationPermission.unableToDetermine) {
        _setProblem(TrackerProblem.permissionOff);
        return;
      }
      _setProblem(null);
      _positions =
          Geolocator.getPositionStream(
            locationSettings: AndroidSettings(
              intervalDuration: TrackerServiceConfig.gpsInterval,
            ),
          ).listen(
            _onPosition,
            onError: (Object e) {
              AppLog.failure('Tracker.gps', e);
              _setProblem(
                e is LocationServiceDisabledException
                    ? TrackerProblem.locationOff
                    : TrackerProblem.gps,
              );
              unawaited(_positions?.cancel());
              _positions = null;
              unawaited(_updateNotification());
              _sendStatus();
            },
          );
    } on Object catch (e, st) {
      AppLog.failure('Tracker.ensureGps', e, st);
      _setProblem(TrackerProblem.gps);
    }
  }

  /// The watchdog found GPS silent: Android or the phone's battery saving
  /// may have paused the stream without an error. Starts it again and asks
  /// for one position now.
  Future<void> _restartGps() async {
    AppLog.info('Tracker: GPS silent, restarting it');
    await _positions?.cancel();
    _positions = null;
    await _ensureGps();
    if (_positions == null) return;
    try {
      _onPosition(
        await Geolocator.getCurrentPosition(
          locationSettings: AndroidSettings(
            timeLimit: TrackerServiceConfig.rescueTimeout,
          ),
        ),
      );
    } on Object catch (e) {
      // No position in time: the stream may still send one later.
      AppLog.info('Tracker: no rescue position ($e)');
    }
  }

  void _onPosition(Position p) {
    try {
      _engine?.onFix(
        TrackFix(
          time: p.timestamp,
          latitude: p.latitude,
          longitude: p.longitude,
          accuracyM: p.accuracy,
          mocked: p.isMocked,
        ),
      );
    } on FileSystemException catch (e) {
      AppLog.failure('Tracker.onPosition', e);
    }
  }

  void _onBatteryWarning(int level) {
    unawaited(_alerts.show(level));
    FlutterForegroundTask.sendDataToMain(TrackerMessages.battery(level));
  }

  Future<void> _updateNotification() async {
    final TrackerEngine? engine = _engine;
    if (engine == null) return;
    final String title;
    final String text;
    if (_mode == TrackerMode.finishing) {
      title = 'Duty over';
      text = 'Waiting for internet to send your route.';
    } else {
      final DateTime? since = engine.session?.dutyOnAt;
      title = since == null
          ? 'On duty'
          : 'On duty since ${IstFormat.time(since)}';
      final int pending = engine.pendingCount;
      text =
          _problemText ??
          (engine.isOffline && pending > 0
              ? 'No internet. $pending points saved on the phone.'
              : 'Your route is being recorded.');
    }
    await FlutterForegroundTask.updateService(
      notificationTitle: title,
      notificationText: text,
    );
  }
}
