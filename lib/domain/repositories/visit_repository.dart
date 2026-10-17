import '../entities/visit_record.dart';

/// Repository interface managing field agricultural visits and in-situ photo proof.
abstract class VisitRepository {
  /// Records a new visit, inserting to backend or queuing locally if offline.
  /// If [visit.localPhotoPath] is present, executes the signed Cloudinary upload flow.
  Future<VisitRecord> recordVisit(VisitRecord visit);

  /// Fetches all visits recorded for a specific duty session.
  Future<List<VisitRecord>> getVisitsForSession(String sessionId);

  /// Retrieves any queued visits awaiting remote sync.
  Future<List<VisitRecord>> getUnsyncedVisits();

  /// Marks a visit as successfully synced to the remote server.
  Future<void> markVisitSynced(String visitId);

  /// Uploads a visit photo through the signed Cloudinary handshake via `visit-photos` Edge Function.
  /// Returns the confirmed Cloudinary public_id or throws on error.
  Future<String?> uploadVisitPhoto({
    required String visitId,
    required String localPhotoPath,
  });

  /// Syncs any locally queued visits and pending photo uploads to the server.
  Future<void> syncPendingVisits();
}
