import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';

import '../../domain/entities/location_point.dart';
import '../../domain/repositories/tracking_queue_store.dart';
import 'tracker_engine.dart';
import 'tracking_task_handler.dart';

/// Contract for the background GPS tracking engine, as the app screens see it.
///
/// The real work happens in an Android foreground service ([TrackingTaskHandler])
/// that keeps running when the app is closed. Abstracted so presentation tests
/// can verify duty transitions without Android hardware.
abstract class TrackingService {
  /// Points the tracker records, for the screen. The points themselves are
  /// already safe in the on-phone queue.
  Stream<LocationPoint> get pointStream;

  /// Emits when the tracker stopped by itself (curfew, session closed by the
  /// server, nothing valid to track), so the screen can follow.
  Stream<TrackerStopReason> get stopStream;

  /// Things the employee should be told while tracking carries on (for example
  /// the sign-in expired and points are waiting).
  Stream<TrackerNotice> get noticeStream;

  /// Starts the foreground service for [session] with its persistent
  /// notification. Returns false when it cannot (location off, permission or
  /// notification permission missing, service refused).
  Future<bool> startTracking({required ActiveTrackingSession session});

  /// Stops tracking and dismisses the notification. A system restart will not
  /// resume it.
  Future<void> stopTracking();

  /// Whether the background service is running right now, whoever started it
  /// (it may have outlived the app screens).
  Future<bool> isTrackerRunning();

  /// Returns the number of points waiting on the phone for the server.
  Future<int> getQueuedPointsCount();

  /// Stops tracking and deletes everything recorded on this phone: points, the
  /// active session and any pending duty-off. Used when an employee signs out,
  /// so the next person on the same phone never sees their data.
  Future<void> clearLocalData();
}

/// Production implementation of [TrackingService]: starts and stops the Android
/// foreground service and relays what it reports.
class DeviceTrackingService implements TrackingService {
  DeviceTrackingService(this._queue) {
    FlutterForegroundTask.addTaskDataCallback(_onTaskData);
  }

  static const int _serviceId = 7301;

  /// The persistent notification (PRD F3): the employee is never tracked
  /// invisibly.
  static const String _notificationTitle = 'Diamond Agritech: duty tracking on';
  static const String _notificationText =
      'Your location is recorded while you are on duty.';

  final TrackingQueueStore _queue;
  final _points = StreamController<LocationPoint>.broadcast();
  final _stops = StreamController<TrackerStopReason>.broadcast();
  final _notices = StreamController<TrackerNotice>.broadcast();
  bool _isTracking = false;

  @override
  Stream<LocationPoint> get pointStream => _points.stream;

  @override
  Stream<TrackerStopReason> get stopStream => _stops.stream;

  @override
  Stream<TrackerNotice> get noticeStream => _notices.stream;

  @override
  Future<bool> startTracking({required ActiveTrackingSession session}) async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;

    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return false;
    }

    // Without notification permission the foreground notification is hidden on
    // Android 13+, and tracking must never be invisible.
    var notifications =
        await FlutterForegroundTask.checkNotificationPermission();
    if (notifications != NotificationPermission.granted) {
      notifications =
          await FlutterForegroundTask.requestNotificationPermission();
    }
    if (notifications != NotificationPermission.granted) return false;

    // The service reads the session from the phone's storage, also when the
    // system restarts it later with no app running.
    await _queue.saveActiveSession(session);

    _configureService();
    if (await FlutterForegroundTask.isRunningService) {
      final stored = await _queue.activeSession();
      if (stored?.sessionId == session.sessionId && _isTracking) return true;
      await FlutterForegroundTask.stopService();
    }

    final result = await FlutterForegroundTask.startService(
      serviceId: _serviceId,
      serviceTypes: const [ForegroundServiceTypes.location],
      notificationTitle: _notificationTitle,
      notificationText: _notificationText,
      callback: trackingTaskCallback,
    );
    if (result is ServiceRequestFailure) {
      await _queue.clearActiveSession();
      return false;
    }

    _isTracking = true;
    return true;
  }

  @override
  Future<void> stopTracking() async {
    _isTracking = false;
    // Clear first: a service the system restarts after this must find nothing
    // to resume.
    await _queue.clearActiveSession();
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
    }
  }

  @override
  Future<bool> isTrackerRunning() async {
    final running = await FlutterForegroundTask.isRunningService;
    if (running) _isTracking = true;
    return running;
  }

  @override
  Future<int> getQueuedPointsCount() => _queue.pendingPointCount();

  @override
  Future<void> clearLocalData() async {
    await stopTracking();
    await _queue.wipeAll();
  }

  void dispose() {
    FlutterForegroundTask.removeTaskDataCallback(_onTaskData);
    _points.close();
    _stops.close();
    _notices.close();
  }

  void _configureService() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'duty_tracking',
        channelName: 'Duty tracking',
        channelDescription: 'Shown while your duty is on.',
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        // The service checks the 23:00 curfew and the session every 15 s.
        eventAction: ForegroundTaskEventAction.repeat(15000),
        // Never starts by itself after a reboot: the employee turns duty on.
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        allowWakeLock: true,
        // Restarts after the system kills it (needs the battery exemption),
        // and keeps running when the app is swiped away.
        allowAutoRestart: true,
        stopWithTask: false,
      ),
    );
  }

  void _onTaskData(Object data) {
    if (data is! Map) return;
    switch (data['type']) {
      case 'point':
        final raw = data['point'];
        if (raw is Map) {
          _points.add(LocationPoint.fromJson(Map<String, dynamic>.from(raw)));
        }
      case 'stopped':
        _isTracking = false;
        final reason = TrackerStopReason.values.asNameMap()[data['reason']];
        if (reason != null) _stops.add(reason);
      case 'notice':
        final notice = TrackerNotice.values.asNameMap()[data['notice']];
        if (notice != null) _notices.add(notice);
      default:
        debugPrint('Tracker: ignored an unknown message');
    }
  }
}
