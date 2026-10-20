import 'package:drift/drift.dart';

import '../../domain/entities/visit_record.dart';
import '../../domain/repositories/visit_queue_store.dart';
import 'tracking_database.dart';

/// [VisitQueueStore] backed by the on-phone drift database.
class DriftVisitQueueStore implements VisitQueueStore {
  DriftVisitQueueStore(this._db);

  final TrackingDatabase _db;

  @override
  Future<void> enqueue(VisitRecord visit) {
    return _db
        .into(_db.pendingVisits)
        .insert(
          PendingVisitsCompanion.insert(
            id: visit.id,
            sessionId: visit.sessionId,
            employeeId: visit.employeeId,
            storeName: Value(visit.storeName),
            note: Value(visit.note),
            latitude: visit.latitude,
            longitude: visit.longitude,
            accuracy: Value(visit.accuracy),
            capturedAt: visit.capturedAt,
            photoPath: Value(visit.localPhotoPath),
          ),
          mode: InsertMode.insertOrIgnore,
        );
  }

  @override
  Future<List<PendingVisit>> all() => _read(null);

  @override
  Future<List<PendingVisit>> pendingFor(String employeeId) => _read(employeeId);

  @override
  Future<void> markRowSent(String visitId) {
    return (_db.update(_db.pendingVisits)..where((t) => t.id.equals(visitId)))
        .write(const PendingVisitsCompanion(rowSent: Value(true)));
  }

  @override
  Future<void> remove(String visitId) {
    return (_db.delete(
      _db.pendingVisits,
    )..where((t) => t.id.equals(visitId))).go();
  }

  Future<List<PendingVisit>> _read(String? employeeId) async {
    final query = _db.select(_db.pendingVisits)
      ..orderBy([
        (t) => OrderingTerm.asc(t.capturedAt),
        (t) => OrderingTerm.asc(t.id),
      ]);
    if (employeeId != null) {
      query.where((t) => t.employeeId.equals(employeeId));
    }
    final rows = await query.get();
    return rows.map(_toPending).toList();
  }

  PendingVisit _toPending(PendingVisitRow row) {
    return PendingVisit(
      rowSent: row.rowSent,
      visit: VisitRecord(
        id: row.id,
        sessionId: row.sessionId,
        employeeId: row.employeeId,
        storeName: row.storeName,
        note: row.note,
        latitude: row.latitude,
        longitude: row.longitude,
        accuracy: row.accuracy,
        capturedAt: row.capturedAt.toUtc(),
        localPhotoPath: row.photoPath,
        synced: row.rowSent,
      ),
    );
  }
}
