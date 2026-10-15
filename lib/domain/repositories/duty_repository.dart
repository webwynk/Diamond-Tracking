import '../entities/duty_session.dart';
import '../entities/location_point.dart';

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

  /// Uploads a batch of telemetry GPS points to the server.
  Future<void> uploadLocationPointsBatch({
    required List<LocationPoint> points,
  });
}
