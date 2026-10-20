import 'package:diamond_tracking/core/errors/app_exceptions.dart';
import 'package:diamond_tracking/data/repositories/supabase_live_location_repository.dart';
import 'package:diamond_tracking/domain/repositories/live_location_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'flutter_test_config.dart';
import 'support/mock_supabase.dart';

/// These tests drive the real [SupabaseLiveLocationRepository] and the real
/// Supabase client; only the network is replaced.
Map<String, Object?> _row({
  String employeeId = 'e1',
  Object? latitude = 19.99,
}) => <String, Object?>{
  'employee_id': employeeId,
  'session_id': 's-$employeeId',
  'latitude': latitude,
  'longitude': 73.79,
  'accuracy': 6,
  'battery_level': 80,
  'is_mock': false,
  'recorded_at': '2026-10-17T07:59:30+00:00',
  'updated_at': '2026-10-17T07:59:31+00:00',
};

void main() {
  late List<http.Request> requests;

  SupabaseLiveLocationRepository repositoryAnswering(
    http.Response Function(http.Request request) answer,
  ) {
    final supabase = MockSupabase(answer);
    requests = supabase.requests;
    return SupabaseLiveLocationRepository(supabase.client);
  }

  group('fetchAll', () {
    test('reads live_locations into positions', () async {
      final repository = repositoryAnswering(
        (request) => jsonResponse(<Object>[_row(), _row(employeeId: 'e2')]),
      );

      final positions = await repository.fetchAll();

      expect(requests.single.url.path, endsWith('/live_locations'));
      expect(positions.map((p) => p.employeeId), ['e1', 'e2']);
      expect(positions.first.latitude, 19.99);
    });

    test('skips a row that cannot be a position instead of failing', () async {
      final repository = repositoryAnswering(
        (request) => jsonResponse(<Object>[
          _row(latitude: 'north'),
          _row(employeeId: 'e2'),
        ]),
      );

      final positions = await repository.fetchAll();

      expect(positions.single.employeeId, 'e2');
    });

    test('a lost connection is a network error', () async {
      final repository = SupabaseLiveLocationRepository(
        MockSupabase.offline().client,
      );

      expect(repository.fetchAll(), throwsA(isA<NetworkException>()));
    });

    test('a permission refusal is explained, not shown raw', () async {
      final repository = repositoryAnswering(
        (request) => jsonResponse(<String, Object>{
          'code': '42501',
          'message': 'permission denied for table live_locations',
        }, 403),
      );

      await expectLater(
        repository.fetchAll(),
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
      final repository = repositoryAnswering(
        (request) => jsonResponse(<String, Object>{
          'code': 'XX000',
          'message': 'relation "secret" exploded',
        }, 500),
      );

      await expectLater(
        repository.fetchAll(),
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

  group('getServerTime', () {
    test('reads the server clock as UTC', () async {
      final repository = repositoryAnswering(
        (request) => jsonResponse('2026-10-17T08:00:00.123+00:00'),
      );

      final time = await repository.getServerTime();

      expect(requests.single.url.path, endsWith('/rpc/server_time'));
      expect(time, DateTime.utc(2026, 10, 17, 8, 0, 0, 123));
    });

    test('an unexpected answer is an error, not a made-up time', () async {
      final repository = repositoryAnswering((request) => jsonResponse(42));

      expect(repository.getServerTime(), throwsA(isA<ServerException>()));
    });
  });

  group('watch', () {
    test('a channel that cannot be opened is reported as not connected, '
        'not thrown into the zone', () async {
      // This test is about the missing client, so the guard is told.
      expectStrayClient();
      // No injected client and Supabase is not initialised, so opening the
      // channel fails. This used to reach the zone as an uncaught error.
      final events = await SupabaseLiveLocationRepository()
          .watch()
          .first
          .timeout(const Duration(seconds: 2));

      expect(events, isA<LiveConnectionChanged>());
      expect((events as LiveConnectionChanged).connected, isFalse);
    });
  });
}
