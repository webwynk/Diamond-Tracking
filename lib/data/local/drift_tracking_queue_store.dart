import 'package:drift/drift.dart';

import '../../domain/entities/location_point.dart';
import '../../domain/repositories/tracking_queue_store.dart';
import 'tracking_database.dart';

/// [TrackingQueueStore] backed by the on-phone drift database.
class DriftTrackingQueueStore implements TrackingQueueStore {
  DriftTrackingQueueStore(this._db);

  final TrackingDatabase _db;

  @override
  Future<void> enqueuePoint(LocationPoint point) {
    return _db.transaction(() async {
      await _db
          .into(_db.queuedPoints)
          .insert(_toCompanion(point), mode: InsertMode.insertOrIgnore);

      final total = await _count();
      if (total > TrackingQueueStore.maxQueuedPoints) {
        await _thinOldest();
      }
    });
  }

  @override
  Future<int> pendingPointCount() => _count();

  @override
  Future<List<LocationPoint>> nextBatch({int limit = 100}) async {
    final rows =
        await (_db.select(_db.queuedPoints)
              ..orderBy([
                (t) => OrderingTerm.asc(t.recordedAt),
                (t) => OrderingTerm.asc(t.id),
              ])
              ..limit(limit))
            .get();
    return rows.map(_toPoint).toList();
  }

  @override
  Future<void> removeConfirmedPoints(List<String> ids) async {
    if (ids.isEmpty) return;
    await (_db.delete(_db.queuedPoints)..where((t) => t.id.isIn(ids))).go();
  }

  @override
  Future<void> discardRejectedPoints(List<String> ids) async {
    if (ids.isEmpty) return;
    await (_db.delete(_db.queuedPoints)..where((t) => t.id.isIn(ids))).go();
  }

  @override
  Future<void> saveActiveSession(ActiveTrackingSession session) {
    return _db.transaction(() async {
      await _db.delete(_db.activeSessions).go();
      await _db
          .into(_db.activeSessions)
          .insert(
            ActiveSessionsCompanion.insert(
              sessionId: session.sessionId,
              employeeId: session.employeeId,
              startedAt: session.startedAt.toUtc(),
              clockOffsetMs: Value(session.clockOffset.inMilliseconds),
            ),
          );
    });
  }

  @override
  Future<ActiveTrackingSession?> activeSession() async {
    final row = await _db.select(_db.activeSessions).getSingleOrNull();
    if (row == null) return null;
    return ActiveTrackingSession(
      sessionId: row.sessionId,
      employeeId: row.employeeId,
      startedAt: row.startedAt.toUtc(),
      clockOffset: Duration(milliseconds: row.clockOffsetMs),
    );
  }

  @override
  Future<void> clearActiveSession() async {
    await _db.delete(_db.activeSessions).go();
  }

  @override
  Future<void> wipeAll() {
    return _db.transaction(() async {
      await _db.delete(_db.queuedPoints).go();
      await _db.delete(_db.activeSessions).go();
    });
  }

  Future<int> _count() async {
    final count = _db.queuedPoints.id.count();
    final query = _db.selectOnly(_db.queuedPoints)..addColumns([count]);
    return await query.map((row) => row.read(count)).getSingle() ?? 0;
  }

  /// Over the cap: remove every other point among the oldest half. The route
  /// keeps its shape (just with fewer dots) and the newest points are never
  /// touched.
  Future<void> _thinOldest() async {
    final oldest =
        await (_db.selectOnly(_db.queuedPoints)
              ..addColumns([_db.queuedPoints.id])
              ..orderBy([
                OrderingTerm.asc(_db.queuedPoints.recordedAt),
                OrderingTerm.asc(_db.queuedPoints.id),
              ])
              ..limit(TrackingQueueStore.maxQueuedPoints ~/ 2))
            .map((row) => row.read(_db.queuedPoints.id)!)
            .get();

    final toRemove = <String>[
      for (var i = 1; i < oldest.length; i += 2) oldest[i],
    ];
    await (_db.delete(
      _db.queuedPoints,
    )..where((t) => t.id.isIn(toRemove))).go();
  }

  QueuedPointsCompanion _toCompanion(LocationPoint p) {
    return QueuedPointsCompanion.insert(
      id: p.id,
      sessionId: p.sessionId,
      latitude: p.latitude,
      longitude: p.longitude,
      accuracy: p.accuracy,
      speed: Value(p.speed),
      heading: Value(p.heading),
      altitude: Value(p.altitude),
      batteryLevel: Value(p.batteryLevel),
      isMock: Value(p.isMock),
      recordedAt: p.recordedAt.toUtc(),
    );
  }

  LocationPoint _toPoint(QueuedPointRow r) {
    return LocationPoint(
      id: r.id,
      sessionId: r.sessionId,
      latitude: r.latitude,
      longitude: r.longitude,
      accuracy: r.accuracy,
      speed: r.speed,
      heading: r.heading,
      altitude: r.altitude,
      batteryLevel: r.batteryLevel,
      isMock: r.isMock,
      recordedAt: r.recordedAt.toUtc(),
    );
  }
}
