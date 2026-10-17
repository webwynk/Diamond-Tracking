import '../../domain/entities/visit_record.dart';
import '../../domain/repositories/visit_repository.dart';

/// In-memory and offline store for visit records during testing and offline operation.
class LocalVisitRepository implements VisitRepository {
  LocalVisitRepository();

  final List<VisitRecord> _visits = [];

  @override
  Future<VisitRecord> recordVisit(VisitRecord visit) async {
    // If visit with this id already exists, update it, else add
    final index = _visits.indexWhere((v) => v.id == visit.id);
    if (index != -1) {
      _visits[index] = visit;
    } else {
      _visits.add(visit);
    }
    return visit;
  }

  @override
  Future<List<VisitRecord>> getVisitsForSession(String sessionId) async {
    return _visits.where((v) => v.sessionId == sessionId).toList();
  }

  @override
  Future<List<VisitRecord>> getUnsyncedVisits() async {
    return _visits.where((v) => !v.synced).toList();
  }

  @override
  Future<void> markVisitSynced(String visitId) async {
    final index = _visits.indexWhere((v) => v.id == visitId);
    if (index != -1) {
      _visits[index] = _visits[index].copyWith(synced: true);
    }
  }

  @override
  Future<String?> uploadVisitPhoto({
    required String visitId,
    required String localPhotoPath,
  }) async {
    final publicId = 'visit-$visitId';
    final index = _visits.indexWhere((v) => v.id == visitId);
    if (index != -1) {
      _visits[index] = _visits[index].copyWith(
        photoPublicId: publicId,
        photoAttachedAt: DateTime.now().toUtc(),
      );
    }
    return publicId;
  }

  @override
  Future<void> syncPendingVisits() async {
    for (int i = 0; i < _visits.length; i++) {
      if (!_visits[i].synced) {
        _visits[i] = _visits[i].copyWith(synced: true);
      }
    }
  }
}
