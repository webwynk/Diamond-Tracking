import 'dart:convert';

import 'package:diamond_tracking/core/errors/app_exceptions.dart';
import 'package:diamond_tracking/core/utils/duty_time_helper.dart';
import 'package:diamond_tracking/data/repositories/supabase_duty_repository.dart';
import 'package:diamond_tracking/domain/entities/location_point.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'support/mock_supabase.dart';

/// These tests drive the real [SupabaseDutyRepository] and the real Supabase
/// client; only the network is replaced, so they check the requests it sends
/// and how it reads the server's answers.
Map<String, Object?> _session({String id = 's1', String? endedAt}) => {
  'id': id,
  'employee_id': 'e1',
  'status': endedAt == null ? 'open' : 'completed',
  'started_at': '2026-10-17T03:00:00Z',
  'ended_at': endedAt,
  'total_distance_km': 0,
  'visits_count': 0,
  'mock_points_count': 0,
};

void main() {
  late List<http.Request> requests;

  SupabaseDutyRepository repositoryAnswering(
    http.Response Function(http.Request request) answer,
  ) {
    final supabase = MockSupabase(answer);
    requests = supabase.requests;
    return SupabaseDutyRepository(supabase.client);
  }

  Map<String, dynamic> bodyOf(http.Request request) =>
      jsonDecode(request.body) as Map<String, dynamic>;

  group('startDutySession', () {
    test(
      'sends only the owner; the server decides time, status and counters',
      () async {
        final repository = repositoryAnswering(
          (_) => jsonResponse(_session(), 201),
        );

        final session = await repository.startDutySession(employeeId: 'e1');

        expect(requests.single.method, 'POST');
        expect(requests.single.url.path, '/rest/v1/duty_sessions');
        expect(bodyOf(requests.single), <String, Object>{'employee_id': 'e1'});
        expect(session.id, 's1');
        expect(session.isOpen, isTrue);
      },
    );

    test(
      'a second start returns the session that is already open (BR-4)',
      () async {
        final repository = repositoryAnswering((request) {
          if (request.method == 'POST') {
            return jsonResponse({
              'code': '23505',
              'message': 'duplicate key',
            }, 409);
          }
          return jsonResponse(_session(id: 'already-open'));
        });

        final session = await repository.startDutySession(employeeId: 'e1');

        expect(session.id, 'already-open');
      },
    );

    test(
      'the server refusing the window becomes a message, not a fake session',
      () async {
        final repository = repositoryAnswering(
          (_) => jsonResponse({
            'code': 'P0001',
            'message': 'duty_outside_window',
          }, 400),
        );

        await expectLater(
          repository.startDutySession(employeeId: 'e1'),
          throwsA(isA<ValidationException>()),
        );
      },
    );

    test('a blocked account cannot start duty', () async {
      final repository = repositoryAnswering(
        (_) => jsonResponse({
          'code': 'P0001',
          'message': 'account_not_active',
        }, 400),
      );

      await expectLater(
        repository.startDutySession(employeeId: 'e1'),
        throwsA(isA<AccountBlockedException>()),
      );
    });

    test(
      'with no internet duty does not start, and no offline session is invented',
      () async {
        final supabase = MockSupabase.offline();
        final repository = SupabaseDutyRepository(supabase.client);

        await expectLater(
          repository.startDutySession(employeeId: 'e1'),
          throwsA(isA<NetworkException>()),
        );
      },
    );
  });

  group('endDutySession', () {
    test(
      'sends only the reason and note; the server stamps the end time',
      () async {
        final repository = repositoryAnswering(
          (_) => jsonResponse(_session(endedAt: '2026-10-17T12:00:00Z')),
        );

        final session = await repository.endDutySession(
          sessionId: 's1',
          endReason: 'auto_curfew',
          notes: 'Duty ended automatically',
        );

        expect(requests.single.method, 'PATCH');
        expect(bodyOf(requests.single), <String, Object>{
          'status': 'auto_curfew',
          'end_reason': 'auto_curfew',
          'notes': 'Duty ended automatically',
        });
        expect(session.endedAt, isNotNull);
      },
    );

    test(
      'ending a session the server already closed returns the closed record',
      () async {
        final repository = repositoryAnswering((request) {
          if (request.method == 'PATCH') {
            return jsonResponse({
              'code': 'P0001',
              'message': 'session_already_closed',
            }, 400);
          }
          return jsonResponse(_session(endedAt: '2026-10-17T17:30:00Z'));
        });

        final session = await repository.endDutySession(sessionId: 's1');

        expect(session.endedAt, DateTime.utc(2026, 10, 17, 17, 30));
      },
    );

    test('with no internet the end fails; no end time is invented', () async {
      final repository = SupabaseDutyRepository(MockSupabase.offline().client);

      await expectLater(
        repository.endDutySession(sessionId: 's1'),
        throwsA(isA<NetworkException>()),
      );
    });
  });

  group('reads', () {
    test('the active session is the one with no end time', () async {
      final repository = repositoryAnswering((_) => jsonResponse(_session()));

      final session = await repository.getActiveDutySession(employeeId: 'e1');

      expect(session?.id, 's1');
      expect(requests.single.url.queryParameters['ended_at'], 'is.null');
    });

    test('a failed read is an error, not "off duty"', () async {
      final repository = repositoryAnswering(
        (_) => jsonResponse({'code': '500', 'message': 'boom'}, 500),
      );

      await expectLater(
        repository.getActiveDutySession(employeeId: 'e1'),
        throwsA(isA<ServerException>()),
      );
    });

    test(
      'yesterday is a calendar day in IST, not in the phone timezone',
      () async {
        DutyTimeHelper.debugNow = DateTime.utc(
          2026,
          10,
          15,
          4,
          30,
        ); // 10:00 IST
        addTearDown(() => DutyTimeHelper.debugNow = null);
        final repository = repositoryAnswering((_) => jsonResponse(<Object>[]));

        await repository.getYesterdayDutySession(employeeId: 'e1');

        final bounds = requests.single.url.queryParametersAll['started_at'];
        // 14 Oct 00:00 IST to 15 Oct 00:00 IST, written in UTC.
        expect(bounds, contains('gte.2026-10-13T18:30:00.000Z'));
        expect(bounds, contains('lt.2026-10-14T18:30:00.000Z'));
      },
    );
  });

  group('ingestLocationPoints', () {
    LocationPoint point(String id) => LocationPoint(
      id: id,
      sessionId: 's1',
      latitude: 20.0,
      longitude: 73.0,
      accuracy: 5,
      recordedAt: DateTime.utc(2026, 10, 17, 4, 30),
    );

    test('calls the server function with only real columns', () async {
      final repository = repositoryAnswering(
        (_) => jsonResponse({
          'results': [
            {'id': 'p1', 'status': 'accepted'},
          ],
        }),
      );

      await repository.ingestLocationPoints(points: [point('p1')]);

      final request = requests.single;
      expect(request.url.path, '/rest/v1/rpc/ingest_location_points');
      final points = bodyOf(request)['p_points'] as List;
      final row = points.single as Map<String, dynamic>;
      expect(row.containsKey('is_synced'), isFalse);
      expect(row['id'], 'p1');
      expect(row['session_id'], 's1');
      expect(row['recorded_at'], '2026-10-17T04:30:00.000Z');
    });

    test(
      'accepted and duplicate are both confirmed; rejected carries its reason',
      () async {
        final repository = repositoryAnswering(
          (_) => jsonResponse({
            'results': [
              {'id': 'a', 'status': 'accepted'},
              {'id': 'd', 'status': 'duplicate'},
              {
                'id': 'r',
                'status': 'rejected',
                'reason': 'point_outside_session',
              },
            ],
          }),
        );

        final result = await repository.ingestLocationPoints(
          points: [point('a'), point('d'), point('r'), point('unmentioned')],
        );

        expect(result.confirmedIds, {'a', 'd'});
        expect(result.rejected, {'r': 'point_outside_session'});
        expect(
          result.confirmedIds.contains('unmentioned'),
          isFalse,
          reason: 'a point the server did not mention must stay on the phone',
        );
      },
    );

    test('an empty batch makes no request', () async {
      final repository = repositoryAnswering((_) => jsonResponse({}));

      final result = await repository.ingestLocationPoints(points: const []);

      expect(requests, isEmpty);
      expect(result.confirmedIds, isEmpty);
    });

    test('no internet is a network error', () async {
      final repository = SupabaseDutyRepository(MockSupabase.offline().client);

      await expectLater(
        repository.ingestLocationPoints(points: [point('p1')]),
        throwsA(isA<NetworkException>()),
      );
    });

    test(
      'a signed-out call becomes a sign-in request, not an outage',
      () async {
        final repository = repositoryAnswering(
          (_) => jsonResponse({
            'code': '28000',
            'message': 'not_authenticated',
          }, 401),
        );

        await expectLater(
          repository.ingestLocationPoints(points: [point('p1')]),
          throwsA(isA<UnauthorizedRoleException>()),
        );
      },
    );

    test('an answer without results is an error, not a success', () async {
      final repository = repositoryAnswering((_) => jsonResponse({'oops': 1}));

      await expectLater(
        repository.ingestLocationPoints(points: [point('p1')]),
        throwsA(isA<ServerException>()),
      );
    });
  });
}
