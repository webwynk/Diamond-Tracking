import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/local/drift_tracking_queue_store.dart';
import '../../data/local/tracking_database.dart';
import '../../data/repositories/supabase_duty_repository.dart';
import '../config/env.dart';
import 'tracker_engine.dart';
import 'tracking_uploader.dart';

/// Entry point of the background tracking service. It runs in its own isolate,
/// owned by the Android foreground service, so tracking does not depend on any
/// screen and survives the app being swiped away (docs/08 section 5).
///
/// It must be a top-level function marked as an entry point.
@pragma('vm:entry-point')
void trackingTaskCallback() {
  FlutterForegroundTask.setTaskHandler(TrackingTaskHandler());
}

/// Thin Android glue around [TrackerEngine]: opens the on-phone queue, signs in
/// to Supabase from the stored session, listens to GPS, and reports to the app.
/// The decisions (what to record, when to stop) live in the engine, where they
/// are tested.
///
/// No location data is ever written to the log (docs/05 section 6).
class TrackingTaskHandler extends TaskHandler {
  TrackingDatabase? _database;
  TrackingUploader? _uploader;
  TrackerEngine? _engine;
  StreamSubscription<Position>? _positions;
  SupabaseDutyRepository? _repository;
  DateTime? _lastGpsDisabledAlertTime;
  bool _lastReportedGpsEnabled = true;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    try {
      Env.validate();

      // This isolate has its own Supabase client; it recovers the employee's
      // session from the phone's storage.
      await Supabase.initialize(
        url: Env.supabaseUrl,
        publishableKey: Env.supabasePublishableKey,
      );

      final database = TrackingDatabase.onDevice();
      _database = database;
      final queue = DriftTrackingQueueStore(database);
      final repository = SupabaseDutyRepository();
      _repository = repository;
      final uploader = TrackingUploader(queue: queue, ingestor: repository);
      _uploader = uploader;
      final battery = Battery();

      late final TrackerEngine engine;
      engine = TrackerEngine(
        queue: queue,
        uploader: uploader,
        isSessionOpen: (sessionId) async {
          final employeeId = engine.session?.employeeId;
          if (employeeId == null) return true;
          final open = await repository.getActiveDutySession(
            employeeId: employeeId,
          );
          return open?.id == sessionId;
        },
        onPoint: (point) => FlutterForegroundTask.sendDataToMain(
          <String, Object?>{'type': 'point', 'point': point.toJson()},
        ),
        onStopped: (reason) {
          FlutterForegroundTask.sendDataToMain(<String, Object?>{
            'type': 'stopped',
            'reason': reason.name,
          });
          unawaited(FlutterForegroundTask.stopService());
        },
        onNotice: (notice) => FlutterForegroundTask.sendDataToMain(
          <String, Object?>{'type': 'notice', 'notice': notice.name},
        ),
        batteryLevel: () => battery.batteryLevel,
      );
      _engine = engine;

      // With no session passed in, the engine resumes the one stored on the
      // phone (the system restarted this service), but only if it is from
      // today and before 23:00 IST. Otherwise duty must be started by hand.
      if (!await engine.start()) {
        FlutterForegroundTask.sendDataToMain(<String, Object?>{
          'type': 'stopped',
          'reason': TrackerStopReason.noActiveSession.name,
        });
        await FlutterForegroundTask.stopService();
        return;
      }

      uploader.start();

      _listenToGps();
      unawaited(_checkGpsAndHeartbeat());
    } catch (error) {
      debugPrint('Tracker: could not start (${error.runtimeType})');
      await FlutterForegroundTask.stopService();
    }
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    unawaited(_engine?.tick());
    unawaited(_checkGpsAndHeartbeat());
  }

  Future<void> _checkGpsAndHeartbeat() async {
    if (!(_engine?.isTracking ?? false)) return;

    final locationEnabled = await Geolocator.isLocationServiceEnabled();
    final permission = await Geolocator.checkPermission();
    final hasPermission =
        permission != LocationPermission.denied &&
        permission != LocationPermission.deniedForever;

    if (!locationEnabled || !hasPermission) {
      if (_positions != null) {
        await _positions?.cancel();
        _positions = null;
      }
      await _reportGpsStatus(false);
      return;
    }

    // GPS switched off and on again, or a permission restored: the position
    // stream ends when it fails, so start listening again.
    if (_positions == null) {
      _listenToGps();
      await _reportGpsStatus(true);
    }
  }

  Future<void> _reportGpsStatus(bool enabled) async {
    final repository = _repository;
    if (repository == null) return;

    if (enabled) {
      if (!_lastReportedGpsEnabled) {
        _lastReportedGpsEnabled = true;
        _lastGpsDisabledAlertTime = null;
        try {
          await repository.reportGpsStatus(enabled: true);
        } catch (_) {}
      }
      return;
    }

    // Rate limit reporting when GPS remains disabled (server deduplicates at 5 min,
    // client deduplicates at 4 min to prevent redundant network hits every 15 s).
    final now = DateTime.now();
    if (_lastGpsDisabledAlertTime != null &&
        now.difference(_lastGpsDisabledAlertTime!) < const Duration(minutes: 4)) {
      return;
    }
    _lastGpsDisabledAlertTime = now;
    _lastReportedGpsEnabled = false;

    try {
      await repository.reportGpsStatus(enabled: false);
    } catch (e) {
      debugPrint('Tracker: could not report GPS disabled (${e.runtimeType})');
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    await _positions?.cancel();
    _positions = null;
    _engine?.stop();
    _repository = null;

    final uploader = _uploader;
    if (uploader != null) {
      // One last try to send what is waiting; the rest is sent later.
      await uploader.flush(timeout: const Duration(seconds: 5));
      uploader.stop();
    }
    await _database?.close();
  }

  /// A reading every 30 s whether or not the phone moved: the engine decides
  /// what to record (30 s while moving, 3 min stationary), so a stationary
  /// employee still shows as alive on the admin map.
  void _listenToGps() {
    final engine = _engine;
    if (engine == null) return;

    try {
      _positions =
          Geolocator.getPositionStream(
            locationSettings: AndroidSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 0,
              intervalDuration: const Duration(seconds: 30),
              // The service has no screen, so Google's "turn on location
              // accuracy" prompt can never be shown: with the fused provider a
              // phone whose location accuracy setting is off would fail here
              // forever. The platform LocationManager has no such prompt (and
              // also works on phones without Google services).
              forceLocationManager: true,
            ),
          ).listen(
            (position) => unawaited(engine.handleFix(_toFix(position))),
            onError: (Object error) {
              debugPrint('Tracker: GPS stream error (${error.runtimeType})');
              unawaited(_positions?.cancel());
              _positions = null;
              unawaited(_reportGpsStatus(false));
            },
            cancelOnError: true,
          );
    } catch (error) {
      debugPrint('Tracker: could not start GPS stream (${error.runtimeType})');
      _positions = null;
      unawaited(_reportGpsStatus(false));
    }
  }

  TrackerFix _toFix(Position position) {
    return TrackerFix(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy,
      speed: position.speed,
      heading: position.heading,
      altitude: position.altitude,
      isMock: position.isMocked,
    );
  }
}
