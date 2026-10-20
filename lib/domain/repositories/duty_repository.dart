import '../entities/duty_session.dart';
import '../entities/location_point.dart';
import '../entities/point_ingest_result.dart';

/// Repository interface managing duty sessions and GPS telemetry synchronization.
abstract class DutyRepository {
  /// Fetches the currently open duty session for [employeeId], or null if off duty.
  Future<DutySession?> getActiveDutySession({required String employeeId});

  /// Starts a new duty session. Fails if outside the 08:00–23:00 IST window (BR-1)
  /// or if an open session already exists (BR-4).
  Future<DutySession> startDutySession({required String employeeId});

  /// Ends an active duty session and returns the finalized session record.
  Future<DutySession> endDutySession({
    required String sessionId,
    String? endReason,
    String? notes,
  });

  /// Fetches the duty session record from yesterday (if any) for the home screen summary.
  Future<DutySession?> getYesterdayDutySession({required String employeeId});

  /// Fetches historical duty sessions for [employeeId] within an optional date range.
  Future<List<DutySession>> getDutyHistory({
    required String employeeId,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 30,
    int offset = 0,
  });

  /// The server's clock (`server_time()`), so the phone can correct for a wrong
  /// local clock (docs/08 section 4).
  Future<DateTime> getServerTime();

  /// Sends a batch (at most 200) of GPS points through `ingest_location_points`
  /// and returns the server's verdict for each point.
  ///
  /// Idempotent: a point sent twice is reported as confirmed, never duplicated.
  /// Throws [NetworkException] when offline, [UnauthorizedRoleException] when
  /// the session is no longer valid, or [ServerException].
  Future<PointIngestResult> ingestLocationPoints({
    required List<LocationPoint> points,
  });

  /// Reports the device's GPS status (enabled or disabled) to the server during duty.
  /// If [enabled] is false and an active duty session exists, this immediately
  /// triggers an operational alert (`gps_disabled`) to admins.
  Future<bool> reportGpsStatus({required bool enabled});
}
