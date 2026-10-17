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

/// A duty-off the phone has recorded but the server has not yet confirmed
/// (the employee ended duty with no signal). [endedAt] is the phone's time; the
/// server accepts it only within the evidence (migration 20261017030000).
class PendingSessionEnd {
  const PendingSessionEnd({
    required this.sessionId,
    required this.endedAt,
    required this.reason,
    this.notes,
  });

  final String sessionId;
  final DateTime endedAt;
  final String reason;
  final String? notes;
}

/// The phone's own durable notebook for tracking (docs/08 section 6): GPS
/// points waiting for the server, the active session, and a pending duty-off.
///
/// Everything here is personal location data. It is kept only until the server
/// confirms it, is capped, and is wiped on sign-out (docs/05 section 6).
abstract class TrackingQueueStore {
  /// The most points kept on the phone. Beyond it the oldest are thinned.
  static const int maxQueuedPoints = 3000;

  /// Points older than this are never uploaded: the server deletes raw points
  /// after 30 days anyway (PRD, docs/05 section 6).
  static const Duration maxPointAge = Duration(days: 30);

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

  /// Removes points the server will never accept, and counts them.
  Future<void> discardRejectedPoints(List<String> ids);

  /// Total points discarded as rejected since the last wipe, for the
  /// "N points could not be synced" diagnostic.
  Future<int> rejectedPointsCount();

  /// Removes points older than [maxPointAge] relative to [now]; returns how
  /// many were removed.
  Future<int> purgeExpiredPoints(DateTime now);

  Future<void> saveActiveSession(ActiveTrackingSession session);
  Future<ActiveTrackingSession?> activeSession();
  Future<void> clearActiveSession();

  Future<void> savePendingEnd(PendingSessionEnd end);
  Future<PendingSessionEnd?> pendingEnd();
  Future<void> clearPendingEnd();

  /// Deletes everything (sign-out). Another employee on the same phone must
  /// never see the previous employee's data.
  Future<void> wipeAll();
}
