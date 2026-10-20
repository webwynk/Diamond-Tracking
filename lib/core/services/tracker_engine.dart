import 'dart:async';

import '../../domain/entities/location_point.dart';
import '../../domain/repositories/tracking_queue_store.dart';
import '../utils/duty_time_helper.dart';
import '../utils/geo_math.dart';
import '../utils/id_generator.dart';
import 'tracking_uploader.dart';

/// One reading from the phone's GPS, before it becomes a recorded point.
class TrackerFix {
  const TrackerFix({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    this.speed,
    this.heading,
    this.altitude,
    this.isMock = false,
  });

  final double latitude;
  final double longitude;
  final double accuracy;
  final double? speed;
  final double? heading;
  final double? altitude;

  /// The OS says the position was faked (BR-9): recorded and flagged, never
  /// dropped, never a reason to end duty.
  final bool isMock;
}

/// Why the tracker stopped by itself.
enum TrackerStopReason {
  /// 23:00 IST passed (BR-2). The server also closes the session.
  curfew,

  /// The server no longer has this session open (blocked, curfew job, closed
  /// elsewhere), so recording more points is pointless.
  sessionClosedByServer,

  /// There was no valid session to track: none stored, or one from an earlier
  /// day. Duty must be started again by hand (decision 2026-10-17).
  noActiveSession,
}

/// Something the employee should be told while tracking carries on.
enum TrackerNotice {
  /// The sign-in is no longer valid, so points cannot reach the server. They
  /// stay safely on the phone; signing in again lets them through.
  needsSignIn,
}

/// The tracking logic, separate from Android so it can be tested: it turns GPS
/// readings into recorded points, writes them to the on-phone queue first, and
/// decides when to stop. The background service feeds it.
class TrackerEngine {
  TrackerEngine({
    required this._queue,
    required this._uploader,
    required this._isSessionOpen,
    required this._onPoint,
    required this._onStopped,
    this._onNotice,
    DateTime Function()? now,
    Future<int?> Function()? batteryLevel,
  }) : _deviceNow = now ?? DateTime.now,
       _batteryLevel = batteryLevel ?? (() async => null);

  /// While moving (speed at least this, or moved at least [movingDistance]) a
  /// point is recorded about every [movingInterval]; stationary, every
  /// [stationaryInterval] (PRD F4).
  static const double movingSpeed = 0.5;
  static const double movingDistance = 25.0;
  static const Duration movingInterval = Duration(seconds: 25);
  static const Duration stationaryInterval = Duration(minutes: 3);

  /// Right after tracking starts the phone often reports a poor first fix (the
  /// GPS is still locking, or it hands back its last known place). Until the
  /// first point is recorded, fixes worse than [goodFixAccuracy] metres are
  /// skipped, for at most [warmUpLimit]; after that whatever arrives is
  /// recorded, so tracking never waits on a bad signal for good. A fake
  /// location is never skipped (BR-9: recorded and flagged, never dropped).
  static const double goodFixAccuracy = 50.0;
  static const Duration warmUpLimit = Duration(seconds: 30);

  final TrackingQueueStore _queue;
  final TrackingUploader _uploader;
  final Future<bool> Function(String sessionId) _isSessionOpen;
  final void Function(LocationPoint point) _onPoint;
  final void Function(TrackerStopReason reason) _onStopped;
  final void Function(TrackerNotice notice)? _onNotice;
  final DateTime Function() _deviceNow;
  final Future<int?> Function() _batteryLevel;

  ActiveTrackingSession? _session;
  DateTime? _lastRecordedAt;
  TrackerFix? _lastRecordedFix;
  DateTime? _trackingSince;
  bool _stopping = false;
  bool _signInNoticeSent = false;

  /// The session being tracked, or null when not tracking.
  ActiveTrackingSession? get session => _session;

  bool get isTracking => _session != null;

  /// The server's time, derived from the phone's clock and the offset measured
  /// when duty started. Never the bare phone clock (docs/08 section 4).
  DateTime serverNow() =>
      _deviceNow().toUtc().add(_session?.clockOffset ?? Duration.zero);

  /// Whether [session] may still be tracked at [serverNow]: it must have started
  /// on the same IST calendar day, and the 23:00 IST curfew must not have
  /// passed. A tracker never resumes an earlier day's session.
  static bool isResumable(ActiveTrackingSession session, DateTime serverNow) {
    final started = DutyTimeHelper.toIst(session.startedAt);
    final now = DutyTimeHelper.toIst(serverNow);
    final sameDay =
        started.year == now.year &&
        started.month == now.month &&
        started.day == now.day;
    return sameDay && now.hour < 23;
  }

  /// Begins tracking [session], or the one stored on the phone when null (the
  /// service was restarted by the system). Returns false when there is nothing
  /// valid to track; the stored session is then cleared.
  Future<bool> start([ActiveTrackingSession? session]) async {
    final candidate = session ?? await _queue.activeSession();
    if (candidate == null) return false;

    final serverNow = _deviceNow().toUtc().add(candidate.clockOffset);
    if (!isResumable(candidate, serverNow)) {
      await _queue.clearActiveSession();
      return false;
    }

    _session = candidate;
    _stopping = false;
    _lastRecordedAt = null;
    _lastRecordedFix = null;
    _trackingSince = serverNow;
    return true;
  }

  /// Handles one GPS reading: records it if the adaptive interval allows.
  Future<void> handleFix(TrackerFix fix) async {
    final session = _session;
    if (session == null || _stopping) return;

    final at = serverNow();
    if (_isStillWarmingUp(fix, at)) return;
    if (!_shouldRecord(fix, at)) return;

    int? battery;
    try {
      battery = await _batteryLevel();
    } catch (_) {
      battery = null; // a missing battery reading must not lose the point
    }

    final point = LocationPoint(
      id: IdGenerator.uuidV4(),
      sessionId: session.sessionId,
      latitude: fix.latitude,
      longitude: fix.longitude,
      accuracy: fix.accuracy,
      speed: fix.speed,
      heading: fix.heading,
      altitude: fix.altitude,
      batteryLevel: battery,
      isMock: fix.isMock,
      recordedAt: at,
    );

    _lastRecordedAt = at;
    _lastRecordedFix = fix;

    // Durable first, then tell the screen: a point that was shown must exist.
    await _queue.enqueuePoint(point);
    _onPoint(point);
  }

  /// Called every few seconds by the service: stops at the 23:00 IST curfew,
  /// and stops when the server says the session is no longer open.
  Future<void> tick() async {
    final session = _session;
    if (session == null || _stopping) return;

    if (!DutyTimeHelper.isWithinDutyWindow(serverNow())) {
      await _finish(TrackerStopReason.curfew);
      return;
    }

    final outcome = _uploader.lastOutcome;

    // Tell the employee once per streak, not every 15 seconds.
    if (outcome?.needsSignIn ?? false) {
      if (!_signInNoticeSent) {
        _signInNoticeSent = true;
        _onNotice?.call(TrackerNotice.needsSignIn);
      }
    } else {
      _signInNoticeSent = false;
    }

    if (outcome != null &&
        outcome.refusedSessionIds.contains(session.sessionId)) {
      // A refusal can also come from a wrong phone clock, so ask the server
      // before giving up. If it cannot be reached, keep tracking.
      bool open;
      try {
        open = await _isSessionOpen(session.sessionId);
      } catch (_) {
        open = true;
      }
      if (!open) await _finish(TrackerStopReason.sessionClosedByServer);
    }
  }

  /// Stops tracking (duty ended by the employee). The stored session is left
  /// for the caller to clear.
  void stop() {
    _session = null;
    _stopping = true;
  }

  Future<void> _finish(TrackerStopReason reason) async {
    _stopping = true;
    await _queue.clearActiveSession();
    _session = null;
    _onStopped(reason);
  }

  /// True while waiting for a good first fix: nothing recorded yet, the fix is
  /// weak and not a fake location, and [warmUpLimit] has not passed.
  bool _isStillWarmingUp(TrackerFix fix, DateTime at) {
    final since = _trackingSince;
    if (_lastRecordedAt != null || since == null) return false;
    if (fix.isMock || fix.accuracy <= goodFixAccuracy) return false;
    return at.difference(since) < warmUpLimit;
  }

  bool _shouldRecord(TrackerFix fix, DateTime at) {
    final lastAt = _lastRecordedAt;
    final lastFix = _lastRecordedFix;
    if (lastAt == null || lastFix == null) return true;

    final elapsed = at.difference(lastAt);
    final moved = GeoMath.distanceMeters(
      lastFix.latitude,
      lastFix.longitude,
      fix.latitude,
      fix.longitude,
    );
    final moving = (fix.speed ?? 0) >= movingSpeed || moved >= movingDistance;
    return elapsed >= (moving ? movingInterval : stationaryInterval);
  }
}
