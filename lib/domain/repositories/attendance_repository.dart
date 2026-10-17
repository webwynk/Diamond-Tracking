import '../entities/admin_duty_session.dart';

/// What the server holds for one employee in one month.
class AttendanceSource {
  const AttendanceSource({
    required this.sessions,
    required this.serverNow,
    this.employeeCreatedAt,
    this.truncated = false,
  });

  /// Sessions that started in the month, oldest first.
  final List<AdminDutySession> sessions;

  /// The server's clock when this was read (UTC).
  final DateTime serverNow;

  /// When the employee's profile was created, so the days before their first
  /// day are not counted absent. Null if it could not be read.
  final DateTime? employeeCreatedAt;

  /// More sessions exist than the safety cap allows to be read.
  final bool truncated;
}

/// Contract for reading one employee's duty sessions for one month (admin).
///
/// Implemented by `SupabaseAttendanceRepository`. Returns real server data or
/// throws an `AppException`; nothing is invented.
abstract class AttendanceRepository {
  /// Sessions that started in `[monthStartUtc, monthEndUtc)`.
  ///
  /// Throws [NetworkException] when offline, [UnauthorizedRoleException] when
  /// the caller may not read it, or [ServerException] otherwise.
  Future<AttendanceSource> fetchMonth({
    required String employeeId,
    required DateTime monthStartUtc,
    required DateTime monthEndUtc,
  });
}
