import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/errors/app_exceptions.dart';
import '../../domain/entities/admin_duty_session.dart';
import '../../domain/entities/route_day.dart';
import '../../domain/repositories/route_repository.dart';
import '../network_failure.dart';
import '../server_reads.dart';

/// Supabase implementation of [RouteRepository].
///
/// Reads `public.duty_sessions` and `public.location_points` (admin SELECT
/// policies), plus two server functions: `server_time()` and
/// `admin_session_distance()` (the running distance of a session that is still
/// open, because a session's stored total is only written when it closes).
class SupabaseRouteRepository implements RouteRepository {
  SupabaseRouteRepository([SupabaseClient? client]) : _injected = client;

  /// The API returns at most this many rows per request, so a long day is read
  /// in pages.
  static const int pageSize = 1000;

  /// Safety cap on points read for one day (about 8 hours of 1-second points).
  /// Beyond it the route is drawn from what was read and flagged as truncated.
  static const int maxPoints = 30000;

  static const String _sessionColumns =
      'id, status, started_at, ended_at, total_distance_km, visits_count';

  static const String _pointColumns =
      'session_id, latitude, longitude, accuracy, is_mock, recorded_at';

  final SupabaseClient? _injected;

  SupabaseClient get _client => _injected ?? Supabase.instance.client;

  @override
  Future<RouteDay> fetchDay({
    required String employeeId,
    required DateTime dayStartUtc,
    required DateTime dayEndUtc,
    bool withPoints = true,
  }) {
    return _run('load the route', () async {
      final rows = await _client
          .from('duty_sessions')
          .select(_sessionColumns)
          .eq('employee_id', employeeId)
          .gte('started_at', dayStartUtc.toUtc().toIso8601String())
          .lt('started_at', dayEndUtc.toUtc().toIso8601String())
          .order('started_at', ascending: true);

      final serverNow = await ServerReads.serverTime(_client);

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

      if (sessions.isEmpty || !withPoints) {
        return RouteDay(
          sessions: sessions,
          points: const <RoutePoint>[],
          serverNow: serverNow,
        );
      }

      final read = await _readPoints(sessions.map((s) => s.id).toList());
      return RouteDay(
        sessions: sessions,
        points: read.points,
        serverNow: serverNow,
        truncated: read.truncated,
      );
    });
  }

  Future<({List<RoutePoint> points, bool truncated})> _readPoints(
    List<String> sessionIds,
  ) async {
    final points = <RoutePoint>[];
    var truncated = false;
    for (var from = 0; ; from += pageSize) {
      final page = await _client
          .from('location_points')
          .select(_pointColumns)
          .inFilter('session_id', sessionIds)
          // The id breaks ties, so paging never skips or repeats a row.
          .order('recorded_at', ascending: true)
          .order('id', ascending: true)
          .range(from, from + pageSize - 1);
      for (final row in page) {
        final point = RoutePoint.tryParse(row);
        if (point != null) points.add(point);
      }
      if (page.length < pageSize) break;
      if (from + pageSize >= maxPoints) {
        truncated = true;
        break;
      }
    }
    return (points: points, truncated: truncated);
  }

  Future<T> _run<T>(String action, Future<T> Function() body) async {
    try {
      return await body();
    } on AppException {
      rethrow;
    } on PostgrestException catch (e) {
      if (e.code == '42501') {
        throw const UnauthorizedRoleException(
          'Only active administrators can see routes.',
        );
      }
      throw ServerException('Could not $action. Please try again.');
    } catch (e, st) {
      final network = asNetworkFailure(e);
      if (network != null) throw network;
      debugPrint('RouteRepository: could not $action: $e\n$st');
      throw ServerException('Could not $action. Please try again.');
    }
  }
}
