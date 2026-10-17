import 'package:diamond_tracking/core/errors/app_exceptions.dart';
import 'package:diamond_tracking/data/repositories/supabase_route_repository.dart';
import 'package:diamond_tracking/domain/entities/route_day.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'support/mock_supabase.dart';

/// These tests drive the real [SupabaseRouteRepository] and the real Supabase
/// client; only the network is replaced.
final DateTime _dayStart = DateTime.utc(2026, 10, 16, 18, 30); // 00:00 IST
final DateTime _dayEnd = _dayStart.add(const Duration(days: 1));

Map<String, Object?> _session(
  String id, {
  String status = 'completed',
  String started = '2026-10-17T02:34:00+00:00',
  String? ended = '2026-10-17T10:00:00+00:00',
  Object? km = 12.345,
}) => <String, Object?>{
  'id': id,
  'status': status,
  'started_at': started,
  'ended_at': ended,
  'total_distance_km': km,
  'visits_count': 2,
};

Map<String, Object?> _point(int i, {String session = 's1'}) =>
    <String, Object?>{
      'session_id': session,
      'latitude': 20 + i * 0.0001,
      'longitude': 73.0,
      'accuracy': 5,
      'is_mock': false,
      'recorded_at': DateTime.utc(
        2026,
        10,
        17,
        3,
      ).add(Duration(seconds: i)).toIso8601String(),
    };

void main() {
  late List<http.Request> requests;

  /// [points] is the whole table for the day; the answer honours the page
  /// the client asks for, as the real API does.
  SupabaseRouteRepository repositoryAnswering({
    List<Object> sessions = const [],
    List<Map<String, Object?>> points = const [],
    Object? serverTime = '2026-10-17T04:30:00+00:00',
    http.Response Function(http.Request request)? distance,
  }) {
    final supabase = MockSupabase((request) {
      final path = request.url.path;
      if (path.endsWith('/rpc/server_time')) return jsonResponse(serverTime);
      if (path.endsWith('/rpc/admin_session_distance')) {
        return distance != null ? distance(request) : jsonResponse(3.456);
      }
      if (path.endsWith('/duty_sessions')) return jsonResponse(sessions);
      if (path.endsWith('/location_points')) {
        final offset = int.parse(request.url.queryParameters['offset'] ?? '0');
        final limit = int.parse(request.url.queryParameters['limit'] ?? '1000');
        final end = (offset + limit).clamp(0, points.length);
        return jsonResponse(
          offset >= points.length ? <Object>[] : points.sublist(offset, end),
        );
      }
      return jsonResponse(<String, Object>{'message': 'unexpected'}, 404);
    });
    requests = supabase.requests;
    return SupabaseRouteRepository(supabase.client);
  }

  Future<RouteDay> fetch(
    SupabaseRouteRepository repository, {
    bool withPoints = true,
  }) {
    return repository.fetchDay(
      employeeId: 'e1',
      dayStartUtc: _dayStart,
      dayEndUtc: _dayEnd,
      withPoints: withPoints,
    );
  }

  group('sessions', () {
    test(
      'are read for this employee and this IST day only, oldest first',
      () async {
        final repository = repositoryAnswering(sessions: [_session('s1')]);

        await fetch(repository);

        final read = requests.firstWhere(
          (r) => r.url.path.endsWith('/duty_sessions'),
        );
        final q = read.url.queryParameters;
        expect(q['employee_id'], 'eq.e1');
        expect(q['order'], 'started_at.asc.nullslast');
        expect(read.url.query, contains('started_at=gte.2026-10-16T18%3A30'));
        expect(read.url.query, contains('started_at=lt.2026-10-17T18%3A30'));
      },
    );

    test(
      'a finished session carries the server total stored on its row',
      () async {
        final repository = repositoryAnswering(sessions: [_session('s1')]);

        final day = await fetch(repository);

        expect(day.sessions.single.distanceKm, 12.345);
        expect(day.sessions.single.visitsCount, 2);
        expect(day.sessions.single.isOpen, isFalse);
        expect(day.serverNow, DateTime.utc(2026, 10, 17, 4, 30));
      },
    );

    test('a total that arrives as text is still read', () async {
      final repository = repositoryAnswering(
        sessions: [_session('s1', km: '7.250')],
      );

      final day = await fetch(repository);

      expect(day.sessions.single.distanceKm, 7.25);
    });

    test(
      'an open session gets the server running distance, not the stored 0',
      () async {
        final repository = repositoryAnswering(
          sessions: [_session('s1', status: 'open', ended: null, km: 0)],
        );

        final day = await fetch(repository);

        expect(day.sessions.single.isOpen, isTrue);
        expect(day.sessions.single.distanceKm, 3.456);
        final call = requests.firstWhere(
          (r) => r.url.path.endsWith('/rpc/admin_session_distance'),
        );
        expect(call.body, contains('"p_session":"s1"'));
      },
    );

    test('a finished session never asks for the running distance', () async {
      final repository = repositoryAnswering(sessions: [_session('s1')]);

      await fetch(repository);

      expect(
        requests.where((r) => r.url.path.endsWith('/admin_session_distance')),
        isEmpty,
      );
    });

    test(
      'if the running distance is not available it is unknown, not guessed',
      () async {
        final repository = repositoryAnswering(
          sessions: [_session('s1', status: 'open', ended: null, km: 0)],
          distance: (request) => jsonResponse(<String, Object>{
            'code': 'PGRST202',
            'message': 'Could not find the function',
          }, 404),
        );

        final day = await fetch(repository);

        expect(day.sessions.single.distanceKm, isNull);
      },
    );

    test('a row that cannot be a session is skipped', () async {
      final repository = repositoryAnswering(
        sessions: [
          <String, Object?>{'id': 's0', 'status': 'completed'},
          _session('s1'),
        ],
      );

      final day = await fetch(repository);

      expect(day.sessions.map((s) => s.id), ['s1']);
    });
  });

  group('points', () {
    test(
      'are read for those sessions in time order, with a tie-break',
      () async {
        final repository = repositoryAnswering(
          sessions: [_session('s1')],
          points: [_point(0), _point(1)],
        );

        final day = await fetch(repository);

        final read = requests.firstWhere(
          (r) => r.url.path.endsWith('/location_points'),
        );
        expect(read.url.queryParameters['session_id'], 'in.("s1")');
        expect(
          read.url.queryParameters['order'],
          'recorded_at.asc.nullslast,id.asc.nullslast',
        );
        expect(day.points, hasLength(2));
        expect(day.points.first.sessionId, 's1');
        expect(day.truncated, isFalse);
      },
    );

    test(
      'a long day is read in pages of 1,000 until the last short page',
      () async {
        final repository = repositoryAnswering(
          sessions: [_session('s1')],
          points: [for (var i = 0; i < 2500; i++) _point(i)],
        );

        final day = await fetch(repository);

        expect(day.points, hasLength(2500));
        final reads = requests
            .where((r) => r.url.path.endsWith('/location_points'))
            .toList();
        expect(reads.map((r) => r.url.queryParameters['offset']), [
          '0',
          '1000',
          '2000',
        ]);
        expect(day.truncated, isFalse);
      },
    );

    test(
      'exactly a full page needs one more read to know it is the end',
      () async {
        final repository = repositoryAnswering(
          sessions: [_session('s1')],
          points: [for (var i = 0; i < 1000; i++) _point(i)],
        );

        final day = await fetch(repository);

        expect(day.points, hasLength(1000));
        expect(
          requests.where((r) => r.url.path.endsWith('/location_points')),
          hasLength(2),
        );
      },
    );

    test('a day beyond the safety cap is cut and says so', () async {
      final repository = repositoryAnswering(
        sessions: [_session('s1')],
        points: [
          for (var i = 0; i < SupabaseRouteRepository.maxPoints + 500; i++)
            _point(i),
        ],
      );

      final day = await fetch(repository);

      expect(day.points, hasLength(SupabaseRouteRepository.maxPoints));
      expect(day.truncated, isTrue);
    });

    test('a bad row is skipped, not fatal', () async {
      final repository = repositoryAnswering(
        sessions: [_session('s1')],
        points: [
          <String, Object?>{'session_id': 's1', 'latitude': 'north'},
          _point(1),
        ],
      );

      final day = await fetch(repository);

      expect(day.points, hasLength(1));
    });

    test('no sessions means no point read at all', () async {
      final repository = repositoryAnswering();

      final day = await fetch(repository);

      expect(day.sessions, isEmpty);
      expect(day.points, isEmpty);
      expect(
        requests.where((r) => r.url.path.endsWith('/location_points')),
        isEmpty,
      );
    });

    test('an expired day reads its totals only, no points', () async {
      final repository = repositoryAnswering(
        sessions: [_session('s1')],
        points: [_point(0)],
      );

      final day = await fetch(repository, withPoints: false);

      expect(day.sessions, hasLength(1));
      expect(day.points, isEmpty);
      expect(
        requests.where((r) => r.url.path.endsWith('/location_points')),
        isEmpty,
      );
    });
  });

  group('failures', () {
    test('a lost connection is a network error', () async {
      final repository = SupabaseRouteRepository(MockSupabase.offline().client);

      expect(fetch(repository), throwsA(isA<NetworkException>()));
    });

    test('a permission refusal is explained, not shown raw', () async {
      final supabase = MockSupabase(
        (request) => jsonResponse(<String, Object>{
          'code': '42501',
          'message': 'permission denied for table location_points',
        }, 403),
      );
      final repository = SupabaseRouteRepository(supabase.client);

      await expectLater(
        fetch(repository),
        throwsA(
          isA<UnauthorizedRoleException>().having(
            (e) => e.message,
            'message',
            isNot(contains('42501')),
          ),
        ),
      );
    });

    test('a server error never leaks database text', () async {
      final supabase = MockSupabase(
        (request) => jsonResponse(<String, Object>{
          'code': 'XX000',
          'message': 'relation "secret" exploded',
        }, 500),
      );
      final repository = SupabaseRouteRepository(supabase.client);

      await expectLater(
        fetch(repository),
        throwsA(
          isA<ServerException>().having(
            (e) => e.message,
            'message',
            isNot(contains('secret')),
          ),
        ),
      );
    });

    test(
      'an unexpected server time is an error, not a made-up clock',
      () async {
        final repository = repositoryAnswering(
          sessions: [_session('s1')],
          serverTime: 42,
        );

        expect(fetch(repository), throwsA(isA<ServerException>()));
      },
    );
  });
}
