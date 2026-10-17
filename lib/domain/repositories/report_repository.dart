import '../entities/report_data.dart';

/// Contract for what a report needs from the server (admin only).
///
/// Implemented by `SupabaseReportRepository`. Returns real server data or
/// throws an `AppException`; nothing is invented.
abstract class ReportRepository {
  /// The duty sessions that started on the IST days [from]..[to] (both
  /// included; only year, month and day matter), the employees, and the
  /// server's clock. With [employeeId] only that employee's sessions and
  /// profile are read.
  ///
  /// Throws [NetworkException] when offline, [UnauthorizedRoleException] when
  /// the caller may not read it, or [ServerException] otherwise.
  Future<ReportSource> fetch({
    required DateTime from,
    required DateTime to,
    String? employeeId,
  });

  /// Writes the audit-log entry for an export. The file is handed over only
  /// after this succeeds ("no audit, no export"), so a failure is thrown, never
  /// swallowed.
  Future<void> logExport({
    required ReportKind kind,
    required DateTime from,
    required DateTime to,
    String? employeeId,
    String format = 'pdf',
  });
}
