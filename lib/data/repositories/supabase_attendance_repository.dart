import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/errors/app_exceptions.dart';
import '../../domain/entities/admin_duty_session.dart';
import '../../domain/repositories/attendance_repository.dart';
import '../network_failure.dart';
import '../server_reads.dart';

/// Supabase implementation of [AttendanceRepository].
///
/// Reads `public.duty_sessions` (admin SELECT policy; kept indefinitely, the
/// permanent attendance record), the employee's `created_at` from
/// `public.profiles`, the server clock, and for a session still open the
/// server's running distance (`admin_session_distance()`, because a session's
/// stored total is only written when it closes).
class SupabaseAttendanceRepository implements AttendanceRepository {
  SupabaseAttendanceRepository([SupabaseClient? client]) : _injected = client;

  /// Safety cap on sessions read for one month. A month normally has about
  /// thirty; beyond the cap the month is shown from what was read and flagged.
  static const int maxSessions = 1000;

  static const String _sessionColumns =
      'id, status, started_at, ended_at, total_distance_km, visits_count, '
      'mock_points_count';

  final SupabaseClient? _injected;

  SupabaseClient get _client => _injected ?? Supabase.instance.client;

  @override
  Future<AttendanceSource> fetchMonth({
    required String employeeId,
    required DateTime monthStartUtc,
    required DateTime monthEndUtc,
  }) {
    return _run('load the attendance', () async {
      final rows = await _client
          .from('duty_sessions')
          .select(_sessionColumns)
          .eq('employee_id', employeeId)
          .gte('started_at', monthStartUtc.toUtc().toIso8601String())
          .lt('started_at', monthEndUtc.toUtc().toIso8601String())
          .order('started_at', ascending: true)
          .limit(maxSessions);

      final sessions = <AdminDutySession>[];
      for (final row in rows) {
        final open = row['ended_at'] == null;
        final running = open
            ? await ServerReads.runningDistanceKm(_client, row['id'])
            : null;
        final session = AdminDutySession.tryParse(
          row,
          runningDistanceKm: running,
        );
        if (session != null) sessions.add(session);
      }

      final created = await _employeeCreatedAt(employeeId);
      final serverNow = await ServerReads.serverTime(_client);
      return AttendanceSource(
        sessions: sessions,
        serverNow: serverNow,
        employeeCreatedAt: created,
        truncated: rows.length >= maxSessions,
      );
    });
  }

  /// The employee's first day is only a refinement (days before it are not
  /// absences). If it cannot be read the month is still shown, counting from
  /// the 1st, rather than failing the whole screen.
  Future<DateTime?> _employeeCreatedAt(String employeeId) async {
    try {
      final row = await _client
          .from('profiles')
          .select('created_at')
          .eq('id', employeeId)
          .maybeSingle();
      final value = row?['created_at'];
      return value is String ? DateTime.tryParse(value)?.toUtc() : null;
    } on Object catch (e) {
      debugPrint('AttendanceRepository: first day unknown: $e');
      return null;
    }
  }

  Future<T> _run<T>(String action, Future<T> Function() body) async {
    try {
      return await body();
    } on AppException {
      rethrow;
    } on PostgrestException catch (e) {
      if (e.code == '42501') {
        throw const UnauthorizedRoleException(
          'Only active administrators can see attendance.',
        );
      }
      throw ServerException('Could not $action. Please try again.');
    } catch (e, st) {
      final network = asNetworkFailure(e);
      if (network != null) throw network;
      debugPrint('AttendanceRepository: could not $action: $e\n$st');
      throw ServerException('Could not $action. Please try again.');
    }
  }
}
