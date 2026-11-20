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
  String? _locationProblem;
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
      if (_ticks % TrackerServiceConfig.clockResyncTicks == 0) {
        await _clock?.sync();
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
    FlutterForegroundTask.sendDataToMain(TrackerMessages.status);
  }

  /// Starts the GPS stream if it is not running, and notes why it cannot.
  Future<void> _ensureGps() async {
    if (_positions != null) return;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _locationProblem = 'Location is off. Turn it on.';
        return;
      }
      final LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever ||
          permission == LocationPermission.unableToDetermine) {
        _locationProblem = 'Location permission is off. Open the app.';
        return;
      }
      _locationProblem = null;
      _positions =
          Geolocator.getPositionStream(
            locationSettings: AndroidSettings(
              intervalDuration: TrackerServiceConfig.gpsInterval,
            ),
          ).listen(
            _onPosition,
            onError: (Object e) {
              AppLog.failure('Tracker.gps', e);
              _locationProblem = e is LocationServiceDisabledException
                  ? 'Location is off. Turn it on.'
                  : 'GPS problem. Open the app.';
              unawaited(_positions?.cancel());
              _positions = null;
              unawaited(_updateNotification());
            },
          );
    } on Object catch (e, st) {
      AppLog.failure('Tracker.ensureGps', e, st);
      _locationProblem = 'GPS problem. Open the app.';
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
          _locationProblem ??
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
