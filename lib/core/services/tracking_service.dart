import 'dart:async';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../../domain/entities/location_point.dart';

/// Contract for the background GPS tracking engine.
///
/// Abstracted so presentation and integration tests can verify UI transitions,
/// offline queue indicators, and telemetry events without requiring native Android
/// hardware or mocking low-level platform channels.
abstract class TrackingService {
  /// Whether the tracking engine is currently active.
  bool get isTracking;

  /// Stream of emitted telemetry points captured from the GPS engine.
  Stream<LocationPoint> get pointStream;

  /// Starts the foreground tracking service with a persistent notification.
  Future<bool> startTracking({required String sessionId});

  /// Stops tracking and dismisses the foreground notification.
  Future<void> stopTracking();

  /// Returns the current number of points stored in the offline queue.
  Future<int> getQueuedPointsCount();

  /// Retrieves all unsynced points from the offline queue.
  Future<List<LocationPoint>> getQueuedPoints();

  /// Marks a batch of point IDs as acknowledged by the server.
  Future<void> markPointsSynced(List<String> pointIds);
}

/// Production implementation of [TrackingService] backed by `geolocator`
/// and `battery_plus`.
class DeviceTrackingService implements TrackingService {
  DeviceTrackingService({Battery? battery})
      : _battery = battery ?? Battery();

  final Battery _battery;
  final _pointStreamController = StreamController<LocationPoint>.broadcast();
  final List<LocationPoint> _offlineQueue = <LocationPoint>[];

  StreamSubscription<Position>? _positionSubscription;
  String? _activeSessionId;
  DateTime? _lastEmittedTime;
  Position? _lastPosition;
  bool _isTracking = false;

  @override
  bool get isTracking => _isTracking;

  @override
  Stream<LocationPoint> get pointStream => _pointStreamController.stream;

  @override
  Future<bool> startTracking({required String sessionId}) async {
    if (_isTracking && _activeSessionId == sessionId) return true;

    _activeSessionId = sessionId;

    // Verify location services and permission before starting foreground stream
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return false;
    }

    // Configure foreground notification for Android persistent tracking (PRD F3, F4)
    late final LocationSettings locationSettings;
    if (defaultTargetPlatform == TargetPlatform.android) {
      locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
        intervalDuration: const Duration(seconds: 30),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'Tracking active • Diamond Agritech',
          notificationText: 'Duty tracking is actively recording GPS coordinates',
          enableWakeLock: true,
        ),
      );
    } else {
      locationSettings = const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      );
    }

    await _positionSubscription?.cancel();
    _isTracking = true;

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      _handlePositionUpdate,
      onError: (Object error) {
        // Stream errors should not crash the foreground loop
        debugPrint('Geolocator stream error: $error');
      },
    );

    return true;
  }

  Future<void> _handlePositionUpdate(Position position) async {
    final sessionId = _activeSessionId;
    if (!_isTracking || sessionId == null) return;

    final now = DateTime.now().toUtc();

    // Adaptive frequency check (PRD F4):
    // - Moving (speed >= 0.5 m/s or distance > 25 m): ~30 seconds interval
    // - Stationary: ~3 minutes interval
    if (_lastPosition != null && _lastEmittedTime != null) {
      final elapsed = now.difference(_lastEmittedTime!);
      final distanceMoved = Geolocator.distanceBetween(
        _lastPosition!.latitude,
        _lastPosition!.longitude,
        position.latitude,
        position.longitude,
      );

      final isMoving = (position.speed >= 0.5) || (distanceMoved >= 25.0);
      final minInterval = isMoving
          ? const Duration(seconds: 25)
          : const Duration(minutes: 3);

      if (elapsed < minInterval) {
        // Skip point to conserve battery and avoid cluttering database with stationary noise
        return;
      }
    }

    int? batteryLevel;
    try {
      batteryLevel = await _battery.batteryLevel;
    } catch (_) {
      batteryLevel = null;
    }

    final point = LocationPoint(
      id: '${sessionId}_${now.millisecondsSinceEpoch}',
      sessionId: sessionId,
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy,
      speed: position.speed,
      heading: position.heading,
      altitude: position.altitude,
      batteryLevel: batteryLevel,
      isMock: position.isMocked,
      recordedAt: now,
      isSynced: false,
    );

    _lastPosition = position;
    _lastEmittedTime = now;

    // Buffer into local queue first (offline-first architecture per docs/08)
    _offlineQueue.add(point);
    _pointStreamController.add(point);
  }

  @override
  Future<void> stopTracking() async {
    _isTracking = false;
    _activeSessionId = null;
    _lastPosition = null;
    _lastEmittedTime = null;
    await _positionSubscription?.cancel();
    _positionSubscription = null;
  }

  @override
  Future<int> getQueuedPointsCount() async {
    return _offlineQueue.where((p) => !p.isSynced).length;
  }

  @override
  Future<List<LocationPoint>> getQueuedPoints() async {
    return List<LocationPoint>.unmodifiable(
      _offlineQueue.where((p) => !p.isSynced),
    );
  }

  @override
  Future<void> markPointsSynced(List<String> pointIds) async {
    final idSet = pointIds.toSet();
    for (var i = 0; i < _offlineQueue.length; i++) {
      if (idSet.contains(_offlineQueue[i].id)) {
        _offlineQueue[i] = _offlineQueue[i].copyWith(isSynced: true);
      }
    }
  }

  void dispose() {
    stopTracking();
    _pointStreamController.close();
  }
}
