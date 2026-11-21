import 'dart:async';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/logging/app_log.dart';
import '../data/tracker_files.dart';
import '../domain/tracking_session.dart';
import '../service/tracker_directory.dart';
import '../service/tracker_messages.dart';
import '../service/tracker_service_config.dart';
import '../service/tracker_task_handler.dart';

/// What the phone must allow before duty on.
enum TrackerRequirement {
  /// Location (GPS) is switched on.
  locationService(required: true),

  /// Location permission ("while using the app").
  locationPermission(required: true),

  /// "Allow all the time": Android needs it to restart tracking after a phone
  /// restart.
  backgroundLocation(required: true),

  /// Notifications: the "on duty" notification and battery warnings.
  notifications(required: true),

  /// No battery optimisation, so the phone does not stop the tracker. Asked
  /// for, but duty on still works without it.
  batteryOptimization(required: false);

  const TrackerRequirement({required this.required});

  final bool required;
}

/// The tracker as the app sees it. Overridden with a fake in tests.
abstract interface class TrackerControl {
  /// What is still missing, in the order to ask for it.
  Future<List<TrackerRequirement>> missingRequirements();

  /// Asks for one requirement (system dialog or settings page).
  Future<void> request(TrackerRequirement requirement);

  /// The current session file, if any.
  Future<TrackingSession?> session();

  /// Saves the session and makes sure the service runs.
  Future<void> start(TrackingSession session);

  /// Duty off: saves the time and lets the service send what is left and
  /// stop. [confirmed] says the server already has the duty off.
  Future<void> dutyOff(DateTime offAt, {required bool confirmed});

  /// Starts the service if the session or the queue needs it (after the app
  /// was closed, or Android stopped the service).
  Future<void> ensureRunning();

  Future<bool> isRunning();

  /// Whether the phone still has work for the server: duty is on, or points
  /// or a duty off have not been sent yet. Logging out must wait.
  Future<bool> hasUnsentWork();

  /// The server refused the saved session's upload pass (a password reset
  /// replaced it): the app should ask for a new pass and [start] again.
  Future<bool> passRefused();

  /// Battery warnings from the service while the app is open.
  Stream<int> get batteryWarnings;

  /// Sign out: stop and forget everything.
  Future<void> clear();
}

/// Thrown when Android refuses to start the service.
class TrackerStartFailed implements Exception {
  const TrackerStartFailed(this.error);

  final Object error;

  @override
  String toString() => 'TrackerStartFailed($error)';
}

/// The real tracker: the flutter_foreground_task service.
class ForegroundTrackerControl implements TrackerControl {
  ForegroundTrackerControl() {
    FlutterForegroundTask.addTaskDataCallback(_onData);
  }

  final StreamController<int> _battery = StreamController<int>.broadcast();
  TrackerFiles? _files;

  Future<TrackerFiles> _getFiles() async =>
      _files ??= TrackerFiles(await trackerDirectory());

  void _onData(Object data) {
    final int? level = TrackerMessages.batteryLevelOf(data);
    if (level != null) _battery.add(level);
  }

  @override
  Stream<int> get batteryWarnings => _battery.stream;

  @override
  Future<List<TrackerRequirement>> missingRequirements() async {
    final LocationPermission permission = await Geolocator.checkPermission();
    return <TrackerRequirement>[
      if (!await Geolocator.isLocationServiceEnabled())
        TrackerRequirement.locationService,
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever ||
          permission == LocationPermission.unableToDetermine)
        TrackerRequirement.locationPermission,
      if (permission != LocationPermission.always)
        TrackerRequirement.backgroundLocation,
      if (await FlutterForegroundTask.checkNotificationPermission() !=
          NotificationPermission.granted)
        TrackerRequirement.notifications,
      if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations)
        TrackerRequirement.batteryOptimization,
    ];
  }

  @override
  Future<void> request(TrackerRequirement requirement) async {
    switch (requirement) {
      case TrackerRequirement.locationService:
        await Geolocator.openLocationSettings();
      case TrackerRequirement.locationPermission:
        final LocationPermission result = await Geolocator.requestPermission();
        if (result == LocationPermission.deniedForever) {
          await Geolocator.openAppSettings();
        }
      case TrackerRequirement.backgroundLocation:
        // With "while using" already given, this asks for "all the time"
        // (Android 11+ shows the settings page). If Android will not ask
        // again, open the app's settings instead.
        final LocationPermission result = await Geolocator.requestPermission();
        if (result != LocationPermission.always) {
          await Geolocator.openAppSettings();
        }
      case TrackerRequirement.notifications:
        final NotificationPermission result =
            await FlutterForegroundTask.requestNotificationPermission();
        if (result == NotificationPermission.permanently_denied) {
          await Geolocator.openAppSettings();
        }
      case TrackerRequirement.batteryOptimization:
        await FlutterForegroundTask.requestIgnoreBatteryOptimization();
    }
  }

  @override
  Future<TrackingSession?> session() async => (await _getFiles()).readSession();

  @override
  Future<void> start(TrackingSession session) async {
    (await _getFiles()).writeSession(session);
    await _startService();
  }

  @override
  Future<void> dutyOff(DateTime offAt, {required bool confirmed}) async {
    final TrackerFiles files = await _getFiles();
    final TrackingSession? session = files.readSession();
    if (session == null) return;
    files.writeSession(session.withDutyOff(offAt, confirmed: confirmed));
    if (await isRunning()) {
      FlutterForegroundTask.sendDataToTask(TrackerMessages.refresh);
    } else {
      await _startService();
    }
  }

  @override
  Future<void> ensureRunning() async {
    if (await isRunning()) {
      FlutterForegroundTask.sendDataToTask(TrackerMessages.refresh);
      return;
    }
    if (await hasUnsentWork()) await _startService();
  }

  @override
  Future<bool> hasUnsentWork() async {
    final TrackerFiles files = await _getFiles();
    final TrackingSession? session = files.readSession();
    if (files.queue.pendingCount > 0) return true;
    if (session == null) return false;
    if (session.isActiveAt(DateTime.now().toUtc())) return true;
    return session.isOff &&
        !session.offConfirmed &&
        files.readState().dutyOffSentFor != session.dayId;
  }

  @override
  Future<bool> passRefused() async {
    final TrackerFiles files = await _getFiles();
    final String? pass = files.readSession()?.pass;
    return pass != null && files.readState().refusedPass == pass;
  }

  @override
  Future<bool> isRunning() => FlutterForegroundTask.isRunningService;

  @override
  Future<void> clear() async {
    if (await isRunning()) await FlutterForegroundTask.stopService();
    (await _getFiles()).clear();
  }

  Future<void> _startService() async {
    if (await isRunning()) {
      FlutterForegroundTask.sendDataToTask(TrackerMessages.refresh);
      return;
    }
    final ServiceRequestResult result =
        await FlutterForegroundTask.startService(
          serviceId: TrackerServiceConfig.serviceId,
          serviceTypes: const <ForegroundServiceTypes>[
            ForegroundServiceTypes.location,
          ],
          notificationTitle: 'On duty',
          notificationText: 'Your route is being recorded.',
          callback: startTrackerService,
        );
    if (result is ServiceRequestFailure) {
      AppLog.failure('TrackerControl.start', result.error);
      throw TrackerStartFailed(result.error);
    }
  }
}
