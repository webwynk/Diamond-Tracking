import 'package:diamond_tracking/core/errors/app_exceptions.dart';
import 'package:diamond_tracking/data/repositories/supabase_admin_visit_repository.dart';
import 'package:diamond_tracking/features/admin/visits/presentation/controllers/visit_photo_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'support/mock_supabase.dart';

Map<String, dynamic> _row(
  int n, {
  String? photo,
  String? removedAt,
  String? store = 'Shop',
}) => <String, dynamic>{
  'id': '00000000-0000-0000-0000-${n.toString().padLeft(12, '0')}',
  'session_id': 'session-1',
  'employee_id': 'emp-1',
  'store_name': store,
  'note': null,
  'latitude': 19.99,
  'longitude': 73.78,
  'accuracy': 5,
  'captured_at':
      '2026-10-18T04:${n.toString().padLeft(2, '0')}:00.123456+00:00',
  'created_at': '2026-10-18T04:30:00+00:00',
  'photo_public_id': photo,
  'photo_attached_at': null,
  'photo_removed_at': removedAt,
};

void main() {
  group('SupabaseAdminVisitRepository.fetchPage', () {
    test(
      'asks for one employee, newest first, one row more than a page',
      () async {
        late http.Request seen;
        final server = MockSupabase((request) {
          seen = request;
          return jsonResponse(<Map<String, dynamic>>[_row(2), _row(1)]);
        });

        final page = await SupabaseAdminVisitRepository(
          server.client,
        ).fetchPage(employeeId: 'emp-1', limit: 20);

        final query = seen.url.queryParameters;
        expect(seen.url.path, contains('/rest/v1/visits'));
        expect(query['employee_id'], 'eq.emp-1');
        expect(
          query['order'],
          'captured_at.desc.nullsfirst,id.desc.nullsfirst',
        );
        expect(query['limit'], '21');
        expect(query.containsKey('or'), isFalse);
        expect(page.visits.map((v) => v.id.substring(30)), <String>[
          '000002',
          '000001',
        ]);
        expect(page.hasMore, isFalse);
      },
    );

    test(
      'a full extra row means another page exists and is not returned',
      () async {
        final server = MockSupabase(
          (request) =>
              jsonResponse(<Map<String, dynamic>>[_row(3), _row(2), _row(1)]),
        );

        final page = await SupabaseAdminVisitRepository(
          server.client,
        ).fetchPage(employeeId: 'emp-1', limit: 2);

        expect(page.visits, hasLength(2));
        expect(page.hasMore, isTrue);
      },
    );

    test('the next page starts strictly after the last visit shown', () async {
      late http.Request seen;
      final repo = SupabaseAdminVisitRepository(
        MockSupabase((request) {
          seen = request;
          return jsonResponse(<Map<String, dynamic>>[_row(5), _row(4)]);
        }).client,
      );
      final first = await repo.fetchPage(employeeId: 'emp-1', limit: 2);

      await repo.fetchPage(
        employeeId: 'emp-1',
        after: first.visits.last,
        limit: 2,
      );

      final at = first.visits.last.capturedAt.toUtc().toIso8601String();
      final id = first.visits.last.id;
      expect(
        seen.url.queryParameters['or'],
        '(captured_at.lt.$at,and(captured_at.eq.$at,id.lt.$id))',
      );
    });

    test('keeps the photo facts: photo, no photo, removed', () async {
      final server = MockSupabase(
        (request) => jsonResponse(<Map<String, dynamic>>[
          _row(3, photo: 'visit-abc'),
          _row(2),
          _row(1, removedAt: '2026-10-19T00:00:00+00:00', store: null),
        ]),
      );

      final page = await SupabaseAdminVisitRepository(
        server.client,
      ).fetchPage(employeeId: 'emp-1');

      expect(page.visits[0].hasRemotePhoto, isTrue);
      expect(page.visits[1].hasRemotePhoto, isFalse);
      expect(page.visits[1].photoRemovedAt, isNull);
      expect(page.visits[2].hasRemotePhoto, isFalse);
      expect(page.visits[2].photoRemovedAt, isNotNull);
      expect(page.visits[2].storeName, isNull);
    });

    test('an empty answer is an empty page, not an error', () async {
      final server = MockSupabase((request) => jsonResponse(<dynamic>[]));

      final page = await SupabaseAdminVisitRepository(
        server.client,
      ).fetchPage(employeeId: 'emp-1');

      expect(page.visits, isEmpty);
      expect(page.hasMore, isFalse);
    });

    test('no internet is a NetworkException', () async {
      await expectLater(
        SupabaseAdminVisitRepository(
          MockSupabase.offline().client,
        ).fetchPage(employeeId: 'emp-1'),
        throwsA(isA<NetworkException>()),
      );
    });

    test('a permission refusal is UnauthorizedRoleException', () async {
      final server = MockSupabase(
        (request) => jsonResponse(<String, dynamic>{
          'code': '42501',
          'message': 'permission denied',
        }, 403),
      );

      await expectLater(
        SupabaseAdminVisitRepository(
          server.client,
        ).fetchPage(employeeId: 'emp-1'),
        throwsA(isA<UnauthorizedRoleException>()),
      );
    });

    test('any other failure is a ServerException', () async {
      final server = MockSupabase((request) => jsonResponse(null, 500));

      await expectLater(
        SupabaseAdminVisitRepository(
          server.client,
        ).fetchPage(employeeId: 'emp-1'),
        throwsA(isA<ServerException>()),
      );
    });
  });

  group('VisitPhotoRequest.build', () {
    test('points at the visit-photos function with the admin sign-in', () {
      final request = VisitPhotoRequest.build(
        functionsBaseUrl: 'https://x.supabase.co/functions/v1/visit-photos',
        publishableKey: 'anon',
        accessToken: 'jwt-123',
        visitId: 'abc',
        size: VisitPhotoSize.thumb,
      );

      expect(
        request!.url,
        'https://x.supabase.co/functions/v1/visit-photos?visit_id=abc&size=thumb',
      );
      expect(request.headers['Authorization'], 'Bearer jwt-123');
      expect(request.headers['apikey'], 'anon');
    });

    test('asks for the full size when told to', () {
      final request = VisitPhotoRequest.build(
        functionsBaseUrl: 'https://x.supabase.co/functions/v1/visit-photos',
        publishableKey: 'anon',
        accessToken: 'jwt-123',
        visitId: 'abc',
        size: VisitPhotoSize.full,
      );

      expect(request!.url, endsWith('size=full'));
    });

    test('nobody signed in means no request', () {
      expect(
        VisitPhotoRequest.build(
          functionsBaseUrl: 'https://x.supabase.co/functions/v1/visit-photos',
          publishableKey: 'anon',
          accessToken: null,
          visitId: 'abc',
          size: VisitPhotoSize.thumb,
        ),
        isNull,
      );
    });
  });
}
