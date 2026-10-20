import 'package:diamond_tracking/domain/entities/visit_record.dart';
import 'package:diamond_tracking/domain/repositories/visit_repository.dart';

/// An in-memory [VisitRepository] for tests: nothing leaves the process.
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

  Future<List<VisitRecord>> getVisitsForSession(String sessionId) async {
    return _visits.where((v) => v.sessionId == sessionId).toList();
  }

  Future<List<VisitRecord>> getUnsyncedVisits() async {
    return _visits.where((v) => !v.synced).toList();
  }

  Future<void> markVisitSynced(String visitId) async {
    final index = _visits.indexWhere((v) => v.id == visitId);
    if (index != -1) {
      _visits[index] = _visits[index].copyWith(synced: true);
    }
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
