import 'dart:convert';

import 'package:diamond_tracking/core/errors/app_exceptions.dart';
import 'package:diamond_tracking/data/repositories/supabase_visit_repository.dart';
import 'package:diamond_tracking/domain/entities/visit_record.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/mock_supabase.dart';

void main() {
  const visitId = '11111111-2222-3333-4444-555555555555';
  const sessionId = 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee';

  VisitRecord sampleVisit({String? photoPath}) => VisitRecord(
        id: visitId,
        sessionId: sessionId,
        storeName: 'Kisan Kendra',
        note: 'Delivered seeds sample',
        latitude: 19.9975,
        longitude: 73.7898,
        accuracy: 4.2,
        capturedAt: DateTime.parse('2026-10-18T04:00:00Z'),
        localPhotoPath: photoPath,
      );

  group('SupabaseVisitRepository.recordVisit without photo', () {
    test('sends only granted columns to public.visits and marks synced', () async {
      late http.Request insertRequest;

      final mockSupabase = MockSupabase((request) {
        if (request.url.path.contains('/rest/v1/visits')) {
          insertRequest = request;
          return jsonResponse(<Map<String, dynamic>>[
            {
              'id': visitId,
              'session_id': sessionId,
              'employee_id': 'user-1',
              'store_name': 'Kisan Kendra',
              'note': 'Delivered seeds sample',
              'latitude': 19.9975,
              'longitude': 73.7898,
              'accuracy': 4.2,
              'captured_at': '2026-10-18T04:00:00Z',
              'created_at': '2026-10-18T04:00:01Z',
            }
          ], 201);
        }
        return jsonResponse(null, 404);
      });

      final repository = SupabaseVisitRepository(mockSupabase.client);
      final result = await repository.recordVisit(sampleVisit());

      expect(result.synced, isTrue);
      expect(result.id, visitId);

      // Verify payload excludes employee_id per database column privilege rules
      final body = jsonDecode(insertRequest.body) as Map<String, dynamic>;
      expect(body['id'], visitId);
      expect(body['session_id'], sessionId);
      expect(body['store_name'], 'Kisan Kendra');
      expect(body['note'], 'Delivered seeds sample');
      expect(body['latitude'], 19.9975);
      expect(body['longitude'], 73.7898);
      expect(body.containsKey('employee_id'), isFalse);
    });

    test('handles 23505 duplicate ID conflict idempotently without error', () async {
      final mockSupabase = MockSupabase((request) {
        if (request.url.path.contains('/rest/v1/visits')) {
          return jsonResponse(
            {'code': '23505', 'message': 'duplicate key value violates unique constraint'},
            409,
          );
        }
        return jsonResponse(null, 404);
      });

      final repository = SupabaseVisitRepository(mockSupabase.client);
      final result = await repository.recordVisit(sampleVisit());

      expect(result.synced, isTrue);
      expect(result.id, visitId);
    });
  });

  group('SupabaseVisitRepository.recordVisit with photo', () {
    test('executes sign -> cloudinary upload -> confirm handshake', () async {
      final signCalled = <String, dynamic>{};
      final confirmCalled = <String, dynamic>{};
      final cloudinaryHeaders = <String, String>{};

      final mockSupabase = MockSupabase((request) {
        if (request.url.path.contains('/rest/v1/visits')) {
          return jsonResponse(<Map<String, dynamic>>[
            {'id': visitId}
          ], 201);
        }

        if (request.url.path.contains('/functions/v1/visit-photos')) {
          final payload = jsonDecode(request.body) as Map<String, dynamic>;
          final action = payload['action'];
          if (action == 'sign') {
            signCalled.addAll(payload);
            return jsonResponse({
              'upload_url': 'https://api.cloudinary.com/v1_1/testcloud/image/upload',
              'api_key': 'mock_api_key',
              'params': {
                'public_id': 'visit-$visitId',
                'timestamp': '1700000000',
                'type': 'authenticated',
              },
              'signature': 'mock_sha1_signature',
            });
          } else if (action == 'confirm') {
            confirmCalled.addAll(payload);
            return jsonResponse({'status': 'attached'});
          }
        }

        return jsonResponse(null, 404);
      });

      final mockCloudinaryClient = MockClient((request) async {
        if (request.url.host.contains('cloudinary.com')) {
          cloudinaryHeaders.addAll(request.headers);
          return http.Response(
            jsonEncode({'public_id': 'visit-$visitId', 'bytes': 150000}),
            200,
          );
        }
        return http.Response('not found', 404);
      });

      final repository = SupabaseVisitRepository(
        mockSupabase.client,
        mockCloudinaryClient,
      );

      final result = await repository.recordVisit(
        sampleVisit(photoPath: '/mock/storage/captured_photo.jpg'),
      );

      expect(result.synced, isTrue);
      expect(result.photoPublicId, 'visit-$visitId');
      expect(result.photoAttachedAt, isNotNull);

      // Verify sign call
      expect(signCalled['action'], 'sign');
      expect(signCalled['visit_id'], visitId);

      // Verify confirm call
      expect(confirmCalled['action'], 'confirm');
      expect(confirmCalled['visit_id'], visitId);
    });

    test('retains visit row if photo upload fails and queues for retry', () async {
      final mockSupabase = MockSupabase((request) {
        if (request.url.path.contains('/rest/v1/visits')) {
          return jsonResponse(<Map<String, dynamic>>[], 201);
        }
        if (request.url.path.contains('/functions/v1/visit-photos')) {
          return jsonResponse({'error': 'visit_too_old'}, 409);
        }
        return jsonResponse(null, 404);
      });

      final repository = SupabaseVisitRepository(mockSupabase.client);
      final result = await repository.recordVisit(
        sampleVisit(photoPath: '/mock/photo.jpg'),
      );

      // Visit row was saved to Postgres, photo is queued for retry
      expect(result.synced, isTrue);
      expect(result.photoPublicId, isNull);
      final unsynced = await repository.getUnsyncedVisits();
      expect(unsynced.length, 1);
      expect(unsynced.first.id, visitId);
    });
  });

  group('SupabaseVisitRepository error translation', () {
    test('translates account_not_active to AccountBlockedException', () async {
      final mockSupabase = MockSupabase((request) {
        return jsonResponse(
          {'code': 'P0001', 'message': 'account_not_active'},
          400,
        );
      });

      final repository = SupabaseVisitRepository(mockSupabase.client);
      expect(
        () => repository.recordVisit(sampleVisit()),
        throwsA(isA<AccountBlockedException>()),
      );
    });

    test('translates visit_outside_session to ValidationException', () async {
      final mockSupabase = MockSupabase((request) {
        return jsonResponse(
          {'code': 'P0001', 'message': 'visit_outside_session'},
          400,
        );
      });

      final repository = SupabaseVisitRepository(mockSupabase.client);
      expect(
        () => repository.recordVisit(sampleVisit()),
        throwsA(isA<ValidationException>()),
      );
    });

    test('translates visit_limit to ValidationException', () async {
      final mockSupabase = MockSupabase((request) {
        return jsonResponse(
          {'code': 'P0001', 'message': 'visit_limit'},
          400,
        );
      });

      final repository = SupabaseVisitRepository(mockSupabase.client);
      expect(
        () => repository.recordVisit(sampleVisit()),
        throwsA(isA<ValidationException>()),
      );
    });

    test('offline network error queues visit locally with synced=false', () async {
      final mockSupabase = MockSupabase.offline();
      final repository = SupabaseVisitRepository(mockSupabase.client);

      final result = await repository.recordVisit(sampleVisit());
      expect(result.synced, isFalse);

      final queued = await repository.getUnsyncedVisits();
      expect(queued.length, 1);
      expect(queued.first.id, visitId);
    });
  });

  group('SupabaseVisitRepository.getVisitsForSession', () {
    test('queries visits for session ordered by captured_at ascending', () async {
      final mockSupabase = MockSupabase((request) {
        if (request.url.path.contains('/rest/v1/visits')) {
          expect(request.url.queryParameters['session_id'], 'eq.$sessionId');
          return jsonResponse(<Map<String, dynamic>>[
            {
              'id': visitId,
              'session_id': sessionId,
              'employee_id': 'user-1',
              'store_name': 'Shop A',
              'latitude': 19.99,
              'longitude': 73.78,
              'captured_at': '2026-10-18T04:00:00Z',
              'photo_public_id': 'visit-$visitId',
            }
          ]);
        }
        return jsonResponse(null, 404);
      });

      final repository = SupabaseVisitRepository(mockSupabase.client);
      final list = await repository.getVisitsForSession(sessionId);

      expect(list.length, 1);
      expect(list.first.storeName, 'Shop A');
      expect(list.first.hasRemotePhoto, isTrue);
    });
  });
}
