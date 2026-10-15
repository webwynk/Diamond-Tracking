import '../entities/visit_record.dart';

/// Repository interface managing field agricultural visits and in-situ photo proof.
abstract class VisitRepository {
  /// Records a new visit, queuing it locally if offline.
  Future<VisitRecord> recordVisit(VisitRecord visit);

  /// Fetches all visits recorded for a specific duty session.
  Future<List<VisitRecord>> getVisitsForSession(String sessionId);

  /// Retrieves any queued visits awaiting remote sync.
  Future<List<VisitRecord>> getUnsyncedVisits();

  /// Marks a visit as successfully synced to the remote server.
  Future<void> markVisitSynced(String visitId);
}
