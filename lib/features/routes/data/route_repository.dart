import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/time/ist.dart';
import '../../duty/domain/duty_day.dart';
import '../../tracking/domain/track_break.dart';
import '../domain/day_route.dart';
import '../domain/live_position.dart';

/// Routes, history and live positions. Row-level security decides what each
/// user may read (own rows, or everything for admins).
abstract interface class RouteRepository {
  /// A day's route, or null before the first points arrive.
  Future<DayRoute?> dayRoute(int dayId);

  /// One duty day.
  Future<DutyDay?> day(int dayId);

  /// A user's days, newest first, back to [since] (an IST date).
  Future<List<DutyDay>> history(String userId, DateTime since);

  /// Every employee's record for [day] (admin).
  Future<List<DutyDay>> daysOn(DateTime day);

  /// Asks the server to look up missing stop addresses. Returns how many it
  /// found.
  Future<int> requestAddresses(int dayId);

  /// Latest positions, updated live.
  Stream<List<LivePosition>> livePositions();
}

class SupabaseRouteRepository implements RouteRepository {
  SupabaseRouteRepository(this._client);

  final SupabaseClient _client;

  static const String _dayColumns =
      'id, user_id, day, status, duty_on_at, duty_off_at, end_reason, '
      'worked_minutes, distance_m, leave_type';

  @override
  Future<DayRoute?> dayRoute(int dayId) async {
    final List<Object?> results = await Future.wait(<Future<Object?>>[
      _client
          .from('day_routes')
          .select(
            'duty_day_id, segments, stops, gaps, point_count, distance_m, '
            'mocked_points',
          )
          .eq('duty_day_id', dayId)
          .maybeSingle(),
      _client
          .from('duty_breaks')
          .select('started_at, ended_at, kind')
          .eq('duty_day_id', dayId)
          .order('started_at'),
    ]);
    final Map<String, dynamic>? row = results[0] as Map<String, dynamic>?;
    if (row == null) return null;
    final List<TrackBreak> breaks = <TrackBreak>[
      for (final Map<String, dynamic> b
          in (results[1]! as List<Object?>).cast<Map<String, dynamic>>())
        TrackBreak(
          from: DateTime.parse(b['started_at'] as String).toUtc(),
          to: DateTime.parse(b['ended_at'] as String).toUtc(),
          kind: TrackBreakKind.fromWire(b['kind'] as String),
        ),
    ];
    return DayRoute.fromRow(row, breaks);
  }

  @override
  Future<DutyDay?> day(int dayId) async {
    final Map<String, dynamic>? row = await _client
        .from('duty_days')
        .select(_dayColumns)
        .eq('id', dayId)
        .maybeSingle();
    return row == null ? null : DutyDay.fromJson(row);
  }

  @override
  Future<List<DutyDay>> history(String userId, DateTime since) async {
    final List<Map<String, dynamic>> rows = await _client
        .from('duty_days')
        .select(_dayColumns)
        .eq('user_id', userId)
        .gte('day', isoDate(since))
        .order('day', ascending: false);
    return rows.map(DutyDay.fromJson).toList();
  }

  @override
  Future<List<DutyDay>> daysOn(DateTime day) async {
    final List<Map<String, dynamic>> rows = await _client
        .from('duty_days')
        .select(_dayColumns)
        .eq('day', isoDate(day));
    return rows.map(DutyDay.fromJson).toList();
  }

  @override
  Future<int> requestAddresses(int dayId) async {
    final FunctionResponse res = await _client.functions.invoke(
      'stop-addresses',
      body: <String, Object?>{'day_id': dayId},
    );
    final Object? data = res.data;
    return data is Map ? ((data['looked_up'] as num?)?.toInt() ?? 0) : 0;
  }

  @override
  Stream<List<LivePosition>> livePositions() => _client
      .from('live_positions')
      .stream(primaryKey: <String>['user_id'])
      .map(
        (List<Map<String, dynamic>> rows) =>
            rows.map(LivePosition.fromRow).toList(),
      );
}
