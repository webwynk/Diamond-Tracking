import '../entities/visit_page.dart';
import '../entities/visit_record.dart';

/// Contract for reading one employee's visits (admin).
///
/// Implemented by `SupabaseAdminVisitRepository`. Returns real server data or
/// throws an `AppException`; nothing is invented.
abstract class AdminVisitRepository {
  /// [limit] visits of [employeeId], newest first, starting after [after]
  /// (the last visit of the previous page), or from the newest when null.
  ///
  /// Throws [NetworkException] when offline, [UnauthorizedRoleException] when
  /// the caller may not read visits, or [ServerException] otherwise.
  Future<VisitPage> fetchPage({
    required String employeeId,
    VisitRecord? after,
    int limit = 20,
  });
}
