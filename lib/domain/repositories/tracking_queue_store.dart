import '../entities/location_point.dart';

/// The duty session the phone is currently tracking. Kept on the phone so the
/// tracker can resume the right session after the app or the phone restarts.
class ActiveTrackingSession {
  const ActiveTrackingSession({
    required this.sessionId,
    required this.employeeId,
    required this.startedAt,
    this.clockOffset = Duration.zero,
  });

  final String sessionId;
  final String employeeId;

  /// The server's start time (UTC).
  final DateTime startedAt;

  /// Server time minus the phone's clock, measured when duty started. The
  /// tracker adds it to the phone's clock so point times and the 23:00 cutoff
  /// follow the server even if the phone's clock is wrong (docs/08 section 4).
  final Duration clockOffset;
}

/// The phone's own durable notebook for tracking (docs/08 section 6): GPS
/// points waiting for the server and the active session.
///
/// Everything here is personal location data. It is kept only until the server
/// confirms it, is capped, and is wiped on sign-out (docs/05 section 6).
abstract class TrackingQueueStore {
  /// The most points kept on the phone. Beyond it the oldest are thinned.
  static const int maxQueuedPoints = 3000;

  /// Stores a point. A point with an id already stored is ignored. When the
  /// queue passes [maxQueuedPoints], every other point among the oldest half is
  /// removed so the route keeps its shape and the newest points are never lost.
  Future<void> enqueuePoint(LocationPoint point);

  /// How many points are waiting for the server.
  Future<int> pendingPointCount();

  /// The oldest waiting points, oldest first, at most [limit].
  Future<List<LocationPoint>> nextBatch({int limit = 100});

  /// Removes points the server confirmed (stored now, or already stored).
  /// This is the ONLY normal way a point leaves the phone.
  Future<void> removeConfirmedPoints(List<String> ids);

  /// Removes points the server will never accept.
  Future<void> discardRejectedPoints(List<String> ids);

  Future<void> saveActiveSession(ActiveTrackingSession session);
  Future<ActiveTrackingSession?> activeSession();
  Future<void> clearActiveSession();

  /// Deletes everything (sign-out). Another employee on the same phone must
  /// never see the previous employee's data.
  Future<void> wipeAll();
}
