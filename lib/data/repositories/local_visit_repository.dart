import '../../domain/entities/visit_record.dart';
import '../../domain/repositories/visit_repository.dart';

/// In-memory and offline queue repository for visit records.
class LocalVisitRepository implements VisitRepository {
  LocalVisitRepository();

  final List<VisitRecord> _visits = [];

  @override
  Future<VisitRecord> recordVisit(VisitRecord visit) async {
    // Add to local store
    _visits.add(visit);
    return visit;
  }

  @override
  Future<List<VisitRecord>> getVisitsForSession(String sessionId) async {
    return _visits.where((v) => v.dutySessionId == sessionId).toList();
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
}
