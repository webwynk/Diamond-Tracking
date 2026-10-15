import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/errors/app_exceptions.dart';
import '../../core/utils/duty_time_helper.dart';
import '../../domain/entities/duty_session.dart';
import '../../domain/entities/location_point.dart';
import '../../domain/repositories/duty_repository.dart';

/// Production implementation of [DutyRepository] communicating with Supabase
/// Postgres schema and executing server-side duty rules.
class SupabaseDutyRepository implements DutyRepository {
  SupabaseDutyRepository([this._client]);

  final SupabaseClient? _client;

  SupabaseClient get _supabase => _client ?? Supabase.instance.client;

  @override
  Future<DutySession?> getActiveDutySession({required String employeeId}) async {
    try {
      final response = await _supabase
          .from('duty_sessions')
          .select()
          .eq('employee_id', employeeId)
          .eq('status', 'open')
          .maybeSingle();

      if (response == null) return null;
      return DutySession.fromJson(response);
    } catch (e) {
      // If table does not yet exist or network is offline, return null
      return null;
    }
  }

  @override
  Future<DutySession> startDutySession({required String employeeId}) async {
    // Client-side fast check against operating window (server also checks clock per BR-1)
    if (!DutyTimeHelper.isWithinDutyWindow()) {
      throw ValidationException(DutyTimeHelper.getDutyDisabledReason());
    }

    try {
      final now = DateTime.now().toUtc();
      final insertData = {
        'employee_id': employeeId,
        'status': 'open',
        'started_at': now.toIso8601String(),
        'total_distance_km': 0.0,
        'visits_count': 0,
        'mock_points_count': 0,
      };

      final response = await _supabase
          .from('duty_sessions')
          .insert(insertData)
          .select()
          .single();

      return DutySession.fromJson(response);
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        // Unique index violation: employee already has an open session (BR-4)
        final existing = await getActiveDutySession(employeeId: employeeId);
        if (existing != null) return existing;
      }
      throw ServerException('Failed to start duty: ${e.message}');
    } catch (e) {
      // Offline fallback: generate client session to enable offline tracking (docs/08)
      final now = DateTime.now().toUtc();
      return DutySession(
        id: 'offline_${now.millisecondsSinceEpoch}',
        employeeId: employeeId,
        startedAt: now,
        status: DutySessionStatus.open,
      );
    }
  }

  @override
  Future<DutySession> endDutySession({
    required String sessionId,
    String? endReason,
    String? notes,
  }) async {
    try {
      final now = DateTime.now().toUtc();
      final updateData = <String, dynamic>{
        'status': endReason == 'auto_curfew' ? 'auto_curfew' : 'completed',
        'ended_at': now.toIso8601String(),
        'end_reason': endReason ?? 'normal',
      };
      if (notes != null) {
        updateData['notes'] = notes;
      }

      final response = await _supabase
          .from('duty_sessions')
          .update(updateData)
          .eq('id', sessionId)
          .select()
          .single();

      return DutySession.fromJson(response);
    } catch (_) {
      // If offline, return a completed session record locally
      final now = DateTime.now().toUtc();
      return DutySession(
        id: sessionId,
        employeeId: '',
        startedAt: now.subtract(const Duration(hours: 8)),
        endedAt: now,
        status: DutySessionStatus.completed,
        endReason: endReason ?? 'normal',
      );
    }
  }

  @override
  Future<DutySession?> getYesterdayDutySession({
    required String employeeId,
  }) async {
    try {
      final now = DutyTimeHelper.nowIst;
      final yesterdayStart = DateTime(now.year, now.month, now.day - 1, 0, 0);
      final yesterdayEnd = DateTime(now.year, now.month, now.day - 1, 23, 59, 59);

      final response = await _supabase
          .from('duty_sessions')
          .select()
          .eq('employee_id', employeeId)
          .gte('started_at', yesterdayStart.toUtc().toIso8601String())
          .lte('started_at', yesterdayEnd.toUtc().toIso8601String())
          .order('started_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) return null;
      return DutySession.fromJson(response);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<DutySession>> getDutyHistory({
    required String employeeId,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 30,
    int offset = 0,
  }) async {
    try {
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

      return (response as List<dynamic>)
          .map((json) => DutySession.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return <DutySession>[];
    }
  }

  @override
  Future<void> uploadLocationPointsBatch({
    required List<LocationPoint> points,
  }) async {
    if (points.isEmpty) return;

    try {
      final payload = points.map((p) => p.toJson()).toList();
      await _supabase.from('location_points').upsert(payload);
    } catch (e) {
      throw const ServerException('Failed to upload location points batch.');
    }
  }
}
