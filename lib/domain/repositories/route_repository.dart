import '../entities/route_day.dart';

/// Contract for reading one employee's stored route for one day (admin).
///
/// Implemented by `SupabaseRouteRepository`. Returns real server data or
/// throws an `AppException`; nothing is invented.
abstract class RouteRepository {
  /// Sessions that started in `[dayStartUtc, dayEndUtc)`, with their points and
  /// the server's distance figures. With [withPoints] false only the sessions
  /// are read (a day whose detailed route has expired still has its totals).
  ///
  /// Throws [NetworkException] when offline, [UnauthorizedRoleException] when
  /// the caller may not read it, or [ServerException] otherwise.
  Future<RouteDay> fetchDay({
    required String employeeId,
    required DateTime dayStartUtc,
    required DateTime dayEndUtc,
    bool withPoints = true,
  });
}
