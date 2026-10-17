import 'package:diamond_tracking/core/errors/app_exceptions.dart';
import 'package:diamond_tracking/data/repositories/supabase_admin_activity_repository.dart';
import 'package:diamond_tracking/domain/entities/admin_activity_event.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'support/mock_supabase.dart';

/// These tests drive the real [SupabaseAdminActivityRepository] and the real
/// Supabase client; only the network is replaced.
Map<String, Object?> _session(
  String id, {
  String status = 'completed',
  String started = '2026-10-17T03:00:00+00:00',
  String? ended,
  String employeeId = 'e1',
}) => <String, Object?>{
  'id': id,
  'employee_id': employeeId,
  'status': status,
  'started_at': started,
  'ended_at': ended,
};

/// The people the sessions above belong to.
final List<Object> _people = <Object>[
  <String, Object?>{
    'id': 'e1',
    'full_name': 'Asha Patil',
    'employee_code': 'DA-101',
  },
  <String, Object?>{
    'id': 'e2',
    'full_name': 'Ravi Kumar',
    'employee_code': 'DA-102',
  },
];

void main() {
  late List<http.Request> requests;

  SupabaseAdminActivityRepository repositoryAnswering({
    List<Object> byStart = const [],
    List<Object> byEnd = const [],
    List<Object> audit = const [],
    List<Object>? profiles,
  }) {
    final supabase = MockSupabase((request) {
      final path = request.url.path;
      if (path.endsWith('/duty_sessions')) {
        final isEndRead = request.url.queryParameters.containsKey('ended_at');
        return jsonResponse(isEndRead ? byEnd : byStart);
      }
      if (path.endsWith('/audit_log')) return jsonResponse(audit);
      if (path.endsWith('/profiles')) return jsonResponse(profiles ?? _people);
      return jsonResponse(<String, Object>{'message': 'unexpected'}, 404);
    });
    requests = supabase.requests;
    return SupabaseAdminActivityRepository(supabase.client);
  }

  group('duty events', () {
    test(
      'a start and an end from different reads are merged, once each, newest first',
      () async {
        // s1 started long ago and just ended: only the end-ordered read has it
        // near the top. s2 is open: only a start.
        final repository = repositoryAnswering(
          byStart: [
            _session(
              's2',
              started: '2026-10-17T06:00:00+00:00',
              employeeId: 'e2',
            ),
            _session(
              's1',
              started: '2026-10-17T03:00:00+00:00',
              ended: '2026-10-17T07:00:00+00:00',
            ),
          ],
          byEnd: [
            _session(
              's1',
              started: '2026-10-17T03:00:00+00:00',
              ended: '2026-10-17T07:00:00+00:00',
            ),
          ],
        );

        final events = await repository.fetchRecent();

        expect(events.map((e) => e.id), ['end:s1', 'start:s2', 'start:s1']);
        expect(events.map((e) => e.kind), [
          AdminActivityKind.dutyEnded,
          AdminActivityKind.dutyStarted,
          AdminActivityKind.dutyStarted,
        ]);
        expect(events.first.personName, 'Asha Patil');
        expect(events.first.employeeCode, 'DA-101');
        expect(events.first.occurredAt, DateTime.utc(2026, 10, 17, 7));
      },
    );

    test(
      'reads starts by started_at and ends by ended_at, newest first',
      () async {
        final repository = repositoryAnswering();

        await repository.fetchRecent(limit: 7);

        final sessionReads = requests
            .where((r) => r.url.path.endsWith('/duty_sessions'))
            .toList();
        expect(sessionReads, hasLength(2));
        expect(
          sessionReads.map((r) => r.url.queryParameters['order']),
          containsAll(<String>[
            'started_at.desc.nullslast',
            'ended_at.desc.nullslast',
          ]),
        );
        expect(
          sessionReads.every((r) => r.url.queryParameters['limit'] == '7'),
          isTrue,
        );
        final endRead = sessionReads.firstWhere(
          (r) => r.url.queryParameters.containsKey('ended_at'),
        );
        expect(endRead.url.queryParameters['ended_at'], 'not.is.null');
      },
    );

    test('a 23:00 auto-end is its own kind; a block explains itself', () async {
      final repository = repositoryAnswering(
        byEnd: [
          _session(
            'a',
            status: 'auto_curfew',
            ended: '2026-10-17T17:30:00+00:00',
          ),
          _session('b', status: 'blocked', ended: '2026-10-17T08:00:00+00:00'),
        ],
      );

      final events = await repository.fetchRecent();
      final auto = events.firstWhere((e) => e.id == 'end:a');
      final blocked = events.firstWhere((e) => e.id == 'end:b');

      expect(auto.kind, AdminActivityKind.dutyAutoEnded);
      expect(blocked.kind, AdminActivityKind.dutyEnded);
      expect(blocked.detail, 'Employee was blocked');
    });

    test(
      'a row without a usable id or start time is skipped, not fatal',
      () async {
        final repository = repositoryAnswering(
          byStart: [
            <String, Object?>{'id': 's1', 'started_at': 'not a date'},
            <String, Object?>{'started_at': '2026-10-17T03:00:00+00:00'},
            _session('s3'),
          ],
        );

        final events = await repository.fetchRecent();

        expect(events.map((e) => e.id), ['start:s3']);
      },
    );

    test('stops at the limit', () async {
      final repository = repositoryAnswering(
        byStart: [
          for (var i = 0; i < 8; i++)
            _session('s$i', started: '2026-10-17T0$i:00:00+00:00'),
        ],
      );

      final events = await repository.fetchRecent(limit: 3);

      expect(events, hasLength(3));
      expect(events.first.id, 'start:s7');
    });
  });

  group('account events', () {
    test('are read from the audit log with the names of both people', () async {
      final repository = repositoryAnswering(
        audit: [
          <String, Object?>{
            'id': 11,
            'actor_id': 'admin-1',
            'action': 'employee_blocked',
            'target_id': 'e1',
            'details': <String, Object?>{},
            'created_at': '2026-10-17T09:00:00+00:00',
          },
          <String, Object?>{
            'id': 10,
            'actor_id': 'admin-1',
            'action': 'employee_created',
            'target_id': 'e1',
            'details': <String, Object?>{'employee_code': 'DA-101'},
            'created_at': '2026-10-16T09:00:00+00:00',
          },
        ],
        profiles: [
          <String, Object?>{
            'id': 'admin-1',
            'full_name': 'Operations Administrator',
            'employee_code': null,
          },
          <String, Object?>{
            'id': 'e1',
            'full_name': 'Asha Patil',
            'employee_code': 'DA-101',
          },
        ],
      );

      final events = await repository.fetchRecent();

      expect(events.map((e) => e.id), ['audit:11', 'audit:10']);
      expect(events.first.kind, AdminActivityKind.employeeBlocked);
      expect(events.first.personName, 'Asha Patil');
      expect(events.first.detail, 'by Operations Administrator');
      expect(events.last.kind, AdminActivityKind.employeeCreated);

      final auditRead = requests.firstWhere(
        (r) => r.url.path.endsWith('/audit_log'),
      );
      expect(
        auditRead.url.queryParameters['action'],
        'in.("employee_created","employee_blocked","employee_unblocked")',
      );
    });

    test(
      'use the code from the audit details when the profile is gone',
      () async {
        final repository = repositoryAnswering(
          audit: [
            <String, Object?>{
              'id': 1,
              'actor_id': null,
              'action': 'employee_created',
              'target_id': 'gone',
              'details': <String, Object?>{'employee_code': 'DA-144'},
              'created_at': '2026-10-17T09:00:00+00:00',
            },
          ],
        );

        final event = (await repository.fetchRecent()).single;

        expect(event.personName, 'An employee');
        expect(event.employeeCode, 'DA-144');
        expect(event.detail, isNull);
      },
    );

    test('ignore an action it does not know', () async {
      final repository = repositoryAnswering(
        audit: [
          <String, Object?>{
            'id': 1,
            'actor_id': 'a',
            'action': 'something_else',
            'target_id': 'b',
            'details': <String, Object?>{},
            'created_at': '2026-10-17T09:00:00+00:00',
          },
        ],
      );

      final events = await repository.fetchRecent();

      expect(events, isEmpty);
    });

    test('with nothing to name, no profile lookup is made', () async {
      final repository = repositoryAnswering();

      await repository.fetchRecent();

      expect(requests.where((r) => r.url.path.endsWith('/profiles')), isEmpty);
    });

    test('one profile lookup names everyone, once each', () async {
      final repository = repositoryAnswering(
        byStart: [
          _session('s1'),
          _session('s2', employeeId: 'e2'),
        ],
        byEnd: [_session('s1', ended: '2026-10-17T07:00:00+00:00')],
      );

      await repository.fetchRecent();

      final lookups = requests
          .where((r) => r.url.path.endsWith('/profiles'))
          .toList();
      expect(lookups, hasLength(1));
      expect(lookups.single.url.queryParameters['id'], 'in.("e1","e2")');
    });

    test('a session whose person cannot be found still shows', () async {
      final repository = repositoryAnswering(
        byStart: [_session('s1', employeeId: 'ghost')],
      );

      final event = (await repository.fetchRecent()).single;

      expect(event.personName, 'An employee');
      expect(event.employeeCode, isNull);
    });
  });

  group('failures', () {
    test('a lost connection is a network error', () async {
      final repository = SupabaseAdminActivityRepository(
        MockSupabase.offline().client,
      );

      expect(repository.fetchRecent(), throwsA(isA<NetworkException>()));
    });

    test('a permission refusal is explained, not shown raw', () async {
      final supabase = MockSupabase(
        (request) => jsonResponse(<String, Object>{
          'code': '42501',
          'message': 'permission denied for table audit_log',
        }, 403),
      );
      final repository = SupabaseAdminActivityRepository(supabase.client);

      await expectLater(
        repository.fetchRecent(),
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
      final repository = SupabaseAdminActivityRepository(supabase.client);

      await expectLater(
        repository.fetchRecent(),
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
