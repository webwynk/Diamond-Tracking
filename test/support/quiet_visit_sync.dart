import 'package:diamond_tracking/core/services/visit_sync_service.dart';

import 'local_visit_repository.dart';

/// A [VisitSyncService] that never starts. The employee shell starts visit
/// sending (a timer, the on-phone database); tests that are not about that use
/// this so nothing real is opened.
class QuietVisitSync extends VisitSyncService {
  QuietVisitSync() : super(LocalVisitRepository());

  @override
  void start() {}
}
