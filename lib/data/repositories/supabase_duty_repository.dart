import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/errors/app_exceptions.dart';
import '../../core/utils/duty_time_helper.dart';
import '../../domain/entities/duty_session.dart';
import '../../domain/entities/location_point.dart';
import '../../domain/entities/point_ingest_result.dart';
import '../../domain/repositories/duty_repository.dart';
import '../network_failure.dart';
import '../server_reads.dart';

/// Production implementation of [DutyRepository] communicating with Supabase
/// Postgres schema and executing server-side duty rules.
///
/// Every failure is an `AppException`; nothing is invented when the server
/// cannot be reached, because a pretend session or end time would corrupt the
/// attendance record (docs/08 sections 2 and 7).
class SupabaseDutyRepository implements DutyRepository {
  SupabaseDutyRepository([this._client]);

  final SupabaseClient? _client;

  SupabaseClient get _supabase => _client ?? Supabase.instance.client;

  @override
  Future<DutySession?> getActiveDutySession({required String employeeId}) {
    return _run('check your duty status', () async {
      final response = await _supabase
          .from('duty_sessions')
          .select()
          .eq('employee_id', employeeId)
          .isFilter('ended_at', null)
          .maybeSingle();

      return response == null ? null : DutySession.fromJson(response);
    });
  }

  @override
  Future<DutySession> startDutySession({required String employeeId}) {
    return _run('start duty', () async {
      try {
        // Only the owner is sent: the server stamps the start time, status and
        // counters, and judges the 08:00-23:00 IST window on its own clock
        // (BR-1), so the phone clock decides nothing.
        final response = await _supabase
            .from('duty_sessions')
            .insert(<String, dynamic>{'employee_id': employeeId})
            .select()
            .single();
        return DutySession.fromJson(response);
      } on PostgrestException catch (e) {
        if (e.code == '23505') {
          // BR-4: a second start returns the session that is already open.
          final existing = await getActiveDutySession(employeeId: employeeId);
          if (existing != null) return existing;
        }
        rethrow;
      }
    });
  }

  @override
  Future<DutySession> endDutySession({
    required String sessionId,
    String? endReason,
    String? notes,
  }) {
    return _run('end duty', () async {
      try {
        final response = await _supabase
            .from('duty_sessions')
            .update(<String, dynamic>{
              'status': endReason == 'auto_curfew'
                  ? 'auto_curfew'
                  : 'completed',
              'end_reason': endReason ?? 'normal',
              'notes': ?notes,
            })
            .eq('id', sessionId)
            .select()
            .single();
        return DutySession.fromJson(response);
      } on PostgrestException catch (e) {
        if (e.message.contains('session_already_closed')) {
          // The server already closed it (23:00 job, block). Ending twice is
          // not an error: report the record as the server holds it.
          final closed = await _supabase
              .from('duty_sessions')
              .select()
              .eq('id', sessionId)
              .single();
          return DutySession.fromJson(closed);
        }
        rethrow;
      }
    });
  }

  @override
  Future<DutySession?> getYesterdayDutySession({required String employeeId}) {
    return _run('load yesterday\'s shift', () async {
      // "Yesterday" is a calendar day in IST (docs/08 section 4), so its
      // bounds are IST midnights expressed in UTC.
      final todayIst = DutyTimeHelper.nowIst;
      final yesterdayStartUtc = DateTime.utc(
        todayIst.year,
        todayIst.month,
        todayIst.day - 1,
      ).subtract(DutyTimeHelper.istOffset);
      final todayStartUtc = yesterdayStartUtc.add(const Duration(days: 1));

      final response = await _supabase
          .from('duty_sessions')
          .select()
          .eq('employee_id', employeeId)
          .gte('started_at', yesterdayStartUtc.toIso8601String())
          .lt('started_at', todayStartUtc.toIso8601String())
          .order('started_at', ascending: false)
          .limit(1)
          .maybeSingle();

      return response == null ? null : DutySession.fromJson(response);
    });
  }

  @override
  Future<List<DutySession>> getDutyHistory({
    required String employeeId,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 30,
    int offset = 0,
  }) {
    return _run('load your duty history', () async {
      var query = _supabase
          .from('duty_sessions')
          .select()
          .eq('employee_id', employeeId);

      if (startDate != null) {
        query = query.gte('started_at', startDate.toUtc().toIso8601String());
      }
      if (endDate != null) {
        query = query.lte('started_at', endDate.toUtc().toIso8601String());
      }

      final response = await query
          .order('started_at', ascending: false)
          .range(offset, offset + limit - 1);

      return response.map(DutySession.fromJson).toList();
    });
  }

  @override
  Future<DateTime> getServerTime() {
    return _run(
      'read the server time',
      () => ServerReads.serverTime(_supabase),
    );
  }

  @override
  Future<PointIngestResult> ingestLocationPoints({
    required List<LocationPoint> points,
  }) {
    if (points.isEmpty) return Future.value(const PointIngestResult());

    return _run('upload location points', () async {
      // The server judges every point on its own (docs/06 section 5): a bad
      // point is rejected without blocking the rest, and a point it already
      // holds is reported as a duplicate, so a retry after a timeout is safe.
      final response = await _supabase.rpc<dynamic>(
        'ingest_location_points',
        params: <String, dynamic>{
          'p_points': points.map((p) => p.toJson()).toList(),
        },
      );

      final results = response is Map ? response['results'] : null;
      if (results is! List) {
        throw const ServerException(
          'The server gave an unexpected answer to the upload.',
        );
      }

      final confirmed = <String>{};
      final rejected = <String, String>{};
      for (final result in results.whereType<Map<dynamic, dynamic>>()) {
        final id = result['id'];
        if (id is! String) continue;
        switch (result['status']) {
          case 'accepted' || 'duplicate':
            confirmed.add(id);
          case 'rejected':
            rejected[id] = result['reason'] as String? ?? 'rejected';
        }
      }
      return PointIngestResult(confirmedIds: confirmed, rejected: rejected);
    });
  }

  Future<T> _run<T>(String action, Future<T> Function() body) async {
    try {
      return await body();
    } on AppException {
      rethrow;
    } on PostgrestException catch (e) {
      throw _translate(e, action);
    } catch (e, st) {
      final network = asNetworkFailure(e);
      if (network != null) throw network;
      // Raw text is never shown to the employee, and no location data is logged.
      debugPrint('DutyRepository: could not $action: ${e.runtimeType}\n$st');
      throw ServerException('Could not $action. Please try again.');
    }
  }

  AppException _translate(PostgrestException e, String action) {
    if (e.message.contains('duty_outside_window')) {
      return ValidationException(DutyTimeHelper.getDutyDisabledReason());
    }
    if (e.message.contains('account_not_active')) {
      return const AccountBlockedException();
    }
    if (e.code == '42501' || e.code == '28000' || e.code == 'PGRST301') {
      // Not signed in (or the token is no longer valid): the upload must stop
      // and ask the employee to sign in, not retry as if it were an outage.
      return const UnauthorizedRoleException(
        'Your session has expired. Sign in again to sync your points.',
      );
    }
    return ServerException('Could not $action. Please try again.');
  }
}
