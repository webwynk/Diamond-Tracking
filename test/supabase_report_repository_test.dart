import 'dart:convert';

import 'package:diamond_tracking/core/errors/app_exceptions.dart';
import 'package:diamond_tracking/data/repositories/supabase_report_repository.dart';
import 'package:diamond_tracking/domain/entities/report_data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'support/mock_supabase.dart';

/// These tests drive the real [SupabaseReportRepository] and the real Supabase
/// client; only the network is replaced.
Map<String, Object?> _session(
  int n, {
  String employee = 'e1',
  String status = 'completed',
  String? ended = '2026-10-17T10:00:00+00:00',
  Object? km = 12.345,
}) => <String, Object?>{
  'id': 's$n',
  'employee_id': employee,
  'status': status,
  'started_at': '2026-10-17T02:34:00+00:00',
  'ended_at': ended,
  'total_distance_km': km,
  'visits_count': 2,
  'mock_points_count': 3,
};

Map<String, Object?> _profile(String id, String name, {String? status}) =>
    <String, Object?>{
      'id': id,
      'full_name': name,
      'employee_code': 'DA-$id',
      'created_at': '2026-10-12T03:00:00+00:00',
      'status': status ?? 'active',
    };

void main() {
  late List<http.Request> requests;

  SupabaseReportRepository repositoryAnswering({
    List<Object> Function(int offset, int limit)? sessions,
    List<Object> profiles = const [],
    Object? serverTime = '2026-10-17T04:30:00+00:00',
    http.Response Function(http.Request request)? distance,
    http.Response Function(http.Request request)? export,
  }) {
    final supabase = MockSupabase((request) {
      final path = request.url.path;
      if (path.endsWith('/rpc/server_time')) return jsonResponse(serverTime);
      if (path.endsWith('/rpc/admin_session_distance')) {
        return distance != null ? distance(request) : jsonResponse(3.456);
      }
      if (path.endsWith('/rpc/log_report_export')) {
        return export != null ? export(request) : jsonResponse(null, 204);
      }
      if (path.endsWith('/duty_sessions')) {
        final offset = int.parse(request.url.queryParameters['offset'] ?? '0');
        final limit = int.parse(request.url.queryParameters['limit'] ?? '1000');
        return jsonResponse(
          sessions == null ? <Object>[] : sessions(offset, limit),
        );
      }
      if (path.endsWith('/profiles')) return jsonResponse(profiles);
      return jsonResponse(<String, Object>{'message': 'unexpected'}, 404);
    });
    requests = supabase.requests;
    return SupabaseReportRepository(supabase.client);
  }

  Future<ReportSource> fetch(
    SupabaseReportRepository repository, {
    String? employeeId,
  }) => repository.fetch(
    from: DateTime(2026, 10),
    to: DateTime(2026, 10, 17),
    employeeId: employeeId,
  );

  group('sessions', () {
    test(
      'are read for the IST days asked, with their owner, oldest first',
      () async {
        final repository = repositoryAnswering(
          sessions: (_, _) => [_session(1)],
          profiles: [_profile('e1', 'Asha')],
        );

        final source = await fetch(repository);

        final read = requests.firstWhere(
          (r) => r.url.path.endsWith('/duty_sessions'),
        );
        final query = read.url.toString();
        // 00:00 IST on 1 Oct = 18:30 UTC on 30 Sep; the end is 00:00 IST on 18 Oct.
        expect(query, contains('started_at=gte.2026-09-30T18%3A30%3A00.000Z'));
        expect(query, contains('started_at=lt.2026-10-17T18%3A30%3A00.000Z'));
        expect(
          query,
          contains('order=started_at.asc.nullslast%2Cid.asc.nullslast'),
        );
        expect(query, isNot(contains('employee_id=eq')));
        expect(source.sessions.single.employeeId, 'e1');
        expect(source.sessions.single.distanceKm, 12.345);
        expect(source.truncated, isFalse);
      },
    );

    test(
      'can be limited to one employee, who is then the only profile',
      () async {
        final repository = repositoryAnswering(
          sessions: (_, _) => [_session(1)],
          profiles: [_profile('e1', 'Asha')],
        );

        await fetch(repository, employeeId: 'e1');

        final sessionsRead = requests.firstWhere(
          (r) => r.url.path.endsWith('/duty_sessions'),
        );
        final profilesRead = requests.firstWhere(
          (r) => r.url.path.endsWith('/profiles'),
        );
        expect(sessionsRead.url.toString(), contains('employee_id=eq.e1'));
        expect(profilesRead.url.toString(), contains('id=eq.e1'));
      },
    );

    test('are read page by page until a short page', () async {
      final repository = repositoryAnswering(
        sessions: (offset, limit) {
          if (offset == 0) return [for (var i = 0; i < 1000; i++) _session(i)];
          return [_session(1000), _session(1001)];
        },
      );

      final source = await fetch(repository);

      expect(source.sessions.length, 1002);
      expect(source.truncated, isFalse);
    });

    test('stop at the safety cap and say so', () async {
      final repository = repositoryAnswering(
        sessions: (offset, limit) => [
          for (var i = 0; i < 1000; i++) _session(offset + i),
        ],
      );

      final source = await fetch(repository);

      expect(source.sessions.length, SupabaseReportRepository.maxSessions);
      expect(source.truncated, isTrue);
    });

    test('a row that cannot be a session is left out', () async {
      final repository = repositoryAnswering(
        sessions: (_, _) => [
          _session(1),
          <String, Object?>{'id': 'bad'},
        ],
      );

      final source = await fetch(repository);

      expect(source.sessions.length, 1);
    });
  });

  group('open sessions', () {
    test('get the server running distance, finished ones do not', () async {
      final repository = repositoryAnswering(
        sessions: (_, _) => [
          _session(1),
          _session(2, status: 'open', ended: null, km: 0),
        ],
        distance: (_) => jsonResponse(7.5),
      );

      final source = await fetch(repository);

      expect(
        requests.where(
          (r) => r.url.path.endsWith('/rpc/admin_session_distance'),
        ),
        hasLength(1),
      );
      expect(source.sessions.last.distanceKm, 7.5);
      expect(source.sessions.first.distanceKm, 12.345);
    });

    test('only the first twenty are measured, the rest stay unknown', () async {
      final repository = repositoryAnswering(
        sessions: (_, _) => [
          for (var i = 0; i < 25; i++)
            _session(i, employee: 'e$i', status: 'open', ended: null, km: 0),
        ],
      );

      final source = await fetch(repository);

      expect(
        requests.where(
          (r) => r.url.path.endsWith('/rpc/admin_session_distance'),
        ),
        hasLength(SupabaseReportRepository.maxRunningDistances),
      );
      expect(source.sessions.where((s) => s.distanceKm == null), hasLength(5));
    });

    test('a distance the server cannot give stays unknown, not zero', () async {
      final repository = repositoryAnswering(
        sessions: (_, _) => [_session(1, status: 'open', ended: null, km: 0)],
        distance: (_) => jsonResponse(<String, Object>{'message': 'no'}, 404),
      );

      final source = await fetch(repository);

      expect(source.sessions.single.distanceKm, isNull);
    });
  });

  group('employees and the clock', () {
    test('are read as report employees, blocked ones marked', () async {
      final repository = repositoryAnswering(
        profiles: [
          _profile('e1', 'Asha'),
          _profile('e2', 'Bala', status: 'blocked'),
        ],
      );

      final source = await fetch(repository);

      expect(source.employees.map((e) => e.name), ['Asha', 'Bala']);
      expect(source.employees.map((e) => e.isActive), [true, false]);
      expect(source.employees.first.code, 'DA-e1');
      expect(source.employees.first.createdAt, DateTime.utc(2026, 10, 12, 3));
      expect(
        requests
            .firstWhere((r) => r.url.path.endsWith('/profiles'))
            .url
            .toString(),
        contains('role=eq.employee'),
      );
    });

    test('come with the server time, not the phone time', () async {
      final repository = repositoryAnswering(
        serverTime: '2026-10-17T04:30:00+00:00',
      );

      final source = await fetch(repository);

      expect(source.serverNow, DateTime.utc(2026, 10, 17, 4, 30));
    });
  });

  group('failures', () {
    test('offline is a network failure', () async {
      final repository = SupabaseReportRepository(
        MockSupabase.offline().client,
      );

      expect(() => fetch(repository), throwsA(isA<NetworkException>()));
    });

    test('a refusal by the database is an unauthorized role', () async {
      final supabase = MockSupabase(
        (_) => jsonResponse(<String, Object>{
          'code': '42501',
          'message': 'forbidden',
        }, 403),
      );
      final repository = SupabaseReportRepository(supabase.client);

      expect(
        () => fetch(repository),
        throwsA(isA<UnauthorizedRoleException>()),
      );
    });

    test('any other server error is a server exception', () async {
      final supabase = MockSupabase(
        (_) => jsonResponse(<String, Object>{
          'code': 'XX000',
          'message': 'boom',
        }, 500),
      );
      final repository = SupabaseReportRepository(supabase.client);

      expect(() => fetch(repository), throwsA(isA<ServerException>()));
    });
  });

  group('logging an export', () {
    test(
      'sends the type, the IST dates, the format and the employee',
      () async {
        final repository = repositoryAnswering();

        await repository.logExport(
          kind: ReportKind.employeeSummary,
          from: DateTime(2026, 9, 3),
          to: DateTime(2026, 10, 17),
          employeeId: 'e1',
        );

        final call = requests.singleWhere(
          (r) => r.url.path.endsWith('/rpc/log_report_export'),
        );
        expect(jsonDecode(call.body), <String, Object?>{
          'p_type': 'employee_summary',
          'p_from': '2026-09-03',
          'p_to': '2026-10-17',
          'p_format': 'pdf',
          'p_employee': 'e1',
        });
      },
    );

    test('a refusal is thrown, so no file is handed over', () async {
      final repository = repositoryAnswering(
        export: (_) => jsonResponse(<String, Object>{
          'code': '42501',
          'message': 'forbidden',
        }, 403),
      );

      expect(
        () => repository.logExport(
          kind: ReportKind.teamSummary,
          from: DateTime(2026, 10),
          to: DateTime(2026, 10, 17),
        ),
        throwsA(isA<UnauthorizedRoleException>()),
      );
    });

    test('offline is thrown too', () async {
      final repository = SupabaseReportRepository(
        MockSupabase.offline().client,
      );

      expect(
        () => repository.logExport(
          kind: ReportKind.teamSummary,
          from: DateTime(2026, 10),
          to: DateTime(2026, 10, 17),
        ),
        throwsA(isA<NetworkException>()),
      );
    });
  });
}
