import '../entities/visit_record.dart';

/// A visit waiting on the phone, and how far its sending has got.
class PendingVisit {
  const PendingVisit({required this.visit, required this.rowSent});

  /// The visit as saved. [VisitRecord.localPhotoPath] is the phone's own copy of
  /// the photo, or null when there is no photo (or it has been sent).
  final VisitRecord visit;

  /// The server has confirmed the visit row; only the photo is left to send.
  final bool rowSent;
}

/// The phone's durable list of visits not yet fully confirmed by the server.
///
/// A visit is written here BEFORE anything is sent, so it survives a restart, a
/// force-kill and a long time offline (PRD F10, docs/08 section 6). It is
/// removed only when the server holds the row and the photo, or when the server
/// refuses it for good.
abstract class VisitQueueStore {
  /// Saves a new visit that the server has not confirmed yet. Saving the same
  /// id again keeps the first entry.
  Future<void> enqueue(VisitRecord visit);

  /// Every waiting visit, oldest first.
  Future<List<PendingVisit>> all();

  /// The waiting visits of one employee, oldest first.
  Future<List<PendingVisit>> pendingFor(String employeeId);

  /// The server has confirmed the visit row.
  Future<void> markRowSent(String visitId);

  /// Forgets the visit entirely.
  Future<void> remove(String visitId);
}
