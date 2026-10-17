import '../entities/admin_activity_event.dart';

/// Contract for the admin Recent activity feed.
///
/// Implemented by `SupabaseAdminActivityRepository`. Returns real server data
/// or throws an `AppException`; nothing is invented.
abstract class AdminActivityRepository {
  /// The newest events, newest first: duty started, duty ended (normally,
  /// automatically at 23:00 IST, or by a block), and employee created, blocked
  /// or unblocked.
  ///
  /// Throws [NetworkException] when offline, [UnauthorizedRoleException] when
  /// the caller may not read it, or [ServerException] otherwise.
  Future<List<AdminActivityEvent>> fetchRecent({int limit = 10});
}
