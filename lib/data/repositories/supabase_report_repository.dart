import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/errors/app_exceptions.dart';
import '../../core/utils/duty_time_helper.dart';
import '../../domain/entities/admin_duty_session.dart';
import '../../domain/entities/report_data.dart';
import '../../domain/repositories/report_repository.dart';
import '../network_failure.dart';
import '../server_reads.dart';

final reportRepositoryProvider = Provider<ReportRepository>(
  (ref) => SupabaseReportRepository(),
);

/// Supabase implementation of [ReportRepository].
///
/// Reads `public.duty_sessions` (admin SELECT policy; the permanent attendance
/// record), `public.profiles`, the server clock, and for a session still open
/// the server's running distance (`admin_session_distance()`). The audit entry
/// is written by `log_report_export()`, the only way into `audit_log`.
class SupabaseReportRepository implements ReportRepository {
  SupabaseReportRepository([SupabaseClient? client]) : _injected = client;

  /// PostgREST returns at most this many rows per request.
  static const int pageSize = 1000;

  /// Safety cap on sessions read for one report (a 31-day report of 150
  /// employees is about 5,000). At the cap the report is flagged as cut short.
  static const int maxSessions = 10000;

  /// Running distances asked for. A report is a snapshot, so only this many
  /// open sessions are measured; the rest show "—" rather than a guess.
  static const int maxRunningDistances = 20;

  static const int _distanceBatch = 5;

  static const String _sessionColumns =
      'id, employee_id, status, started_at, ended_at, total_distance_km, '
      'visits_count, mock_points_count';

  final SupabaseClient? _injected;

  SupabaseClient get _client => _injected ?? Supabase.instance.client;

  @override
  Future<ReportSource> fetch({
    required DateTime from,
    required DateTime to,
    String? employeeId,
  }) {
    return _run('load the report data', () async {
      // The IST days as a UTC interval (IST has no daylight saving).
      final startUtc = DateTime.utc(
        from.year,
        from.month,
        from.day,
      ).subtract(DutyTimeHelper.istOffset);
      final endUtc = DateTime.utc(
        to.year,
        to.month,
        to.day + 1,
      ).subtract(DutyTimeHelper.istOffset);

      final rows = <Map<String, dynamic>>[];
      var cut = false;
      while (true) {
        var query = _client
            .from('duty_sessions')
            .select(_sessionColumns)
            .gte('started_at', startUtc.toIso8601String())
            .lt('started_at', endUtc.toIso8601String());
        if (employeeId != null) query = query.eq('employee_id', employeeId);
        final page = await query
            .order('started_at', ascending: true)
            .order('id', ascending: true)
            .range(rows.length, rows.length + pageSize - 1);
        rows.addAll(page);
        if (page.length < pageSize) break;
        if (rows.length >= maxSessions) {
          cut = true;
          break;
        }
      }

      var profiles = _client
          .from('profiles')
          .select('id, full_name, employee_code, created_at, status')
          .eq('role', 'employee');
      if (employeeId != null) profiles = profiles.eq('id', employeeId);
      final profileRows = await profiles
          .order('full_name', ascending: true)
          .order('id', ascending: true);
      final employees = <ReportEmployee>[
        for (final row in profileRows) ?ReportEmployee.tryParse(row),
      ];

      final serverNow = await ServerReads.serverTime(_client);
      final running = await _runningDistances(rows);

      final sessions = <AdminDutySession>[];
      for (final row in rows) {
        final session = AdminDutySession.tryParse(
          row,
          runningDistanceKm: running[row['id']],
        );
        if (session != null) sessions.add(session);
      }

      return ReportSource(
        sessions: sessions,
        employees: employees,
        serverNow: serverNow,
        truncated: cut,
      );
    });
  }

  /// Server distances for the first [maxRunningDistances] open sessions, a few
  /// at a time. A session not measured has no entry (shown as unknown).
  Future<Map<Object?, double?>> _runningDistances(
    List<Map<String, dynamic>> rows,
  ) async {
    final open = [
      for (final row in rows)
        if (row['ended_at'] == null) row['id'],
    ].take(maxRunningDistances).toList();

    final result = <Object?, double?>{};
    for (var i = 0; i < open.length; i += _distanceBatch) {
      final batch = open.skip(i).take(_distanceBatch).toList();
      final answers = await Future.wait([
        for (final id in batch) ServerReads.runningDistanceKm(_client, id),
      ]);
      for (var j = 0; j < batch.length; j++) {
        result[batch[j]] = answers[j];
      }
    }
    return result;
  }

  @override
  Future<void> logExport({
    required ReportKind kind,
    required DateTime from,
    required DateTime to,
    String? employeeId,
    String format = 'pdf',
  }) {
    return _run('record the export', () async {
      await _client.rpc<dynamic>(
        'log_report_export',
        params: <String, dynamic>{
          'p_type': kind.wire,
          'p_from': _date(from),
          'p_to': _date(to),
          'p_format': format,
          'p_employee': employeeId,
        },
      );
    });
  }

  static String _date(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';

  Future<T> _run<T>(String action, Future<T> Function() body) async {
    try {
      return await body();
    } on AppException {
      rethrow;
    } on PostgrestException catch (e) {
      if (e.code == '42501') {
        throw const UnauthorizedRoleException(
          'Only active administrators can export reports.',
        );
      }
      throw ServerException('Could not $action. Please try again.');
    } catch (e, st) {
      final network = asNetworkFailure(e);
      if (network != null) throw network;
      debugPrint('ReportRepository: could not $action: $e\n$st');
      throw ServerException('Could not $action. Please try again.');
    }
  }
}
