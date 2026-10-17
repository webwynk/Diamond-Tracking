import 'package:diamond_tracking/core/errors/app_exceptions.dart';
import 'package:diamond_tracking/data/repositories/supabase_attendance_repository.dart';
import 'package:diamond_tracking/domain/repositories/attendance_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'support/mock_supabase.dart';

/// These tests drive the real [SupabaseAttendanceRepository] and the real
/// Supabase client; only the network is replaced.
final DateTime _monthStart = DateTime.utc(
  2026,
  9,
  30,
  18,
  30,
); // 00:00 IST, 1 Oct
final DateTime _monthEnd = DateTime.utc(
  2026,
  10,
  31,
  18,
  30,
); // 00:00 IST, 1 Nov

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
  'mock_points_count': 3,
};

void main() {
  late List<http.Request> requests;

  SupabaseAttendanceRepository repositoryAnswering({
    List<Object> sessions = const [],
    Object? profile = const <String, Object?>{
      'created_at': '2026-10-12T03:00:00+00:00',
    },
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
      if (path.endsWith('/profiles')) {
        // No row: PostgREST answers 406 with PGRST116 for a single object.
        return profile == null
            ? jsonResponse(<String, Object?>{
                'code': 'PGRST116',
                'details': 'The result contains 0 rows',
                'hint': null,
                'message':
                    'JSON object requested, multiple (or no) rows returned',
              }, 406)
            : jsonResponse(profile);
      }
      return jsonResponse(<String, Object>{'message': 'unexpected'}, 404);
    });
    requests = supabase.requests;
    return SupabaseAttendanceRepository(supabase.client);
  }

  Future<AttendanceSource> fetch(SupabaseAttendanceRepository repository) {
    return repository.fetchMonth(
      employeeId: 'e1',
      monthStartUtc: _monthStart,
      monthEndUtc: _monthEnd,
    );
  }

  group('sessions', () {
    test(
      'are read for this employee and this IST month only, oldest first',
      () async {
        final repository = repositoryAnswering(sessions: [_session('s1')]);

        await fetch(repository);

        final read = requests.firstWhere(
          (r) => r.url.path.endsWith('/duty_sessions'),
        );
        final q = read.url.queryParameters;
        expect(q['employee_id'], 'eq.e1');
        expect(q['order'], 'started_at.asc.nullslast');
        expect(q['limit'], '${SupabaseAttendanceRepository.maxSessions}');
        expect(read.url.query, contains('started_at=gte.2026-09-30T18%3A30'));
        expect(read.url.query, contains('started_at=lt.2026-10-31T18%3A30'));
      },
    );

    test('carry the stored total, visits and the server flag count', () async {
      final repository = repositoryAnswering(sessions: [_session('s1')]);

      final source = await fetch(repository);

      final s = source.sessions.single;
      expect(s.distanceKm, 12.345);
      expect(s.visitsCount, 2);
      expect(s.mockPointsCount, 3);
      expect(s.isOpen, isFalse);
      expect(source.truncated, isFalse);
    });

    test(
      'an open session gets the server running distance, not the stored 0',
      () async {
        final repository = repositoryAnswering(
          sessions: [_session('s1', status: 'open', ended: null, km: 0)],
        );

        final source = await fetch(repository);

        expect(source.sessions.single.isOpen, isTrue);
        expect(source.sessions.single.distanceKm, 3.456);
        final call = requests.firstWhere(
          (r) => r.url.path.endsWith('/rpc/admin_session_distance'),
        );
        expect(call.body, contains('"p_session":"s1"'));
      },
    );

    test('a finished session never asks for a running distance', () async {
      final repository = repositoryAnswering(sessions: [_session('s1')]);

      await fetch(repository);

      expect(
        requests.where((r) => r.url.path.endsWith('/admin_session_distance')),
        isEmpty,
      );
    });

    test(
      'a running distance that is not available is unknown, not guessed',
      () async {
        final repository = repositoryAnswering(
          sessions: [_session('s1', status: 'open', ended: null, km: 0)],
          distance: (request) => jsonResponse(<String, Object>{
            'code': 'PGRST202',
            'message': 'Could not find the function',
          }, 404),
        );

        final source = await fetch(repository);

        expect(source.sessions.single.distanceKm, isNull);
      },
    );

    test('a row that cannot be a session is skipped', () async {
      final repository = repositoryAnswering(
        sessions: [
          <String, Object?>{'id': 's0', 'status': 'completed'},
          _session('s1'),
        ],
      );

      final source = await fetch(repository);

      expect(source.sessions.map((s) => s.id), ['s1']);
    });

    test('a month at the safety cap says it was cut', () async {
      final repository = repositoryAnswering(
        sessions: [
          for (var i = 0; i < SupabaseAttendanceRepository.maxSessions; i++)
            _session('s$i'),
        ],
      );

      final source = await fetch(repository);

      expect(source.truncated, isTrue);
    });
  });

  group('the employee and the clock', () {
    test(
      'reads when the employee started, so earlier days are not absences',
      () async {
        final repository = repositoryAnswering();

        final source = await fetch(repository);

        expect(source.employeeCreatedAt, DateTime.utc(2026, 10, 12, 3));
        final read = requests.firstWhere(
          (r) => r.url.path.endsWith('/profiles'),
        );
        expect(read.url.queryParameters['id'], 'eq.e1');
        expect(read.url.queryParameters['select'], 'created_at');
      },
    );

    test(
      'an employee that cannot be read leaves the first day unknown',
      () async {
        final repository = repositoryAnswering(profile: null);

        final source = await fetch(repository);

        expect(source.employeeCreatedAt, isNull);
      },
    );

    test('a failed profile read does not fail the month', () async {
      final supabase = MockSupabase((request) {
        final path = request.url.path;
        if (path.endsWith('/profiles')) {
          return jsonResponse(<String, Object>{
            'code': 'XX000',
            'message': 'boom',
          }, 500);
        }
        if (path.endsWith('/rpc/server_time')) {
          return jsonResponse('2026-10-17T04:30:00+00:00');
        }
        return jsonResponse(<Object>[_session('s1')]);
      });
      final repository = SupabaseAttendanceRepository(supabase.client);

      final source = await fetch(repository);

      expect(source.sessions, hasLength(1));
      expect(source.employeeCreatedAt, isNull);
    });

    test('reads the server clock as UTC', () async {
      final repository = repositoryAnswering();

      final source = await fetch(repository);

      expect(source.serverNow, DateTime.utc(2026, 10, 17, 4, 30));
    });

    test(
      'an unexpected server time is an error, not a made-up clock',
      () async {
        final repository = repositoryAnswering(serverTime: 42);

        expect(fetch(repository), throwsA(isA<ServerException>()));
      },
    );
  });

  group('failures', () {
    test('a lost connection is a network error', () async {
      final repository = SupabaseAttendanceRepository(
        MockSupabase.offline().client,
      );

      expect(fetch(repository), throwsA(isA<NetworkException>()));
    });

    test('a permission refusal is explained, not shown raw', () async {
      final supabase = MockSupabase(
        (request) => jsonResponse(<String, Object>{
          'code': '42501',
          'message': 'permission denied for table duty_sessions',
        }, 403),
      );
      final repository = SupabaseAttendanceRepository(supabase.client);

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
      final repository = SupabaseAttendanceRepository(supabase.client);

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
  });
}
