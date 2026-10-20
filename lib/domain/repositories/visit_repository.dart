import '../entities/visit_record.dart';

/// Repository interface managing field agricultural visits and in-situ photo proof.
abstract class VisitRepository {
  /// Records a new visit, inserting to backend or queuing locally if offline.
  /// If [visit.localPhotoPath] is present, executes the signed Cloudinary upload flow.
  Future<VisitRecord> recordVisit(VisitRecord visit);

  /// Syncs any locally queued visits and pending photo uploads to the server.
  Future<void> syncPendingVisits();
}
