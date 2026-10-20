import 'dart:convert';
import 'dart:io';

import 'package:diamond_tracking/core/errors/app_exceptions.dart';
import 'package:diamond_tracking/core/services/visit_photo_vault.dart';
import 'package:diamond_tracking/data/local/drift_visit_queue_store.dart';
import 'package:diamond_tracking/data/local/tracking_database.dart';
import 'package:diamond_tracking/data/repositories/supabase_visit_repository.dart';
import 'package:diamond_tracking/domain/entities/visit_record.dart';
import 'package:diamond_tracking/domain/repositories/visit_queue_store.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/mock_supabase.dart';

/// A vault that keeps photos where they are, so tests can see which ones the
/// repository kept and which it let go.
class _FakeVault implements VisitPhotoVault {
  final List<String> discarded = <String>[];
  bool failToKeep = false;

  @override
  Future<String?> keep(String sourcePath, String visitId) async {
    if (failToKeep) throw const FileSystemException('No space left on device');
    if (!File(sourcePath).existsSync()) return null;
    return sourcePath;
  }

  @override
  Future<void> discard(String path) async => discarded.add(path);
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  const visitId = '11111111-2222-3333-4444-555555555555';
  const sessionId = 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee';
  const employeeId = 'user-1';

  late TrackingDatabase database;
  late VisitQueueStore queue;
  late _FakeVault vault;
  late Directory tempDir;
  late String photoPath;

  setUp(() {
    database = TrackingDatabase(NativeDatabase.memory());
    queue = DriftVisitQueueStore(database);
    vault = _FakeVault();
    tempDir = Directory.systemTemp.createTempSync('visit_photo_test');
    photoPath = '${tempDir.path}${Platform.pathSeparator}photo.jpg';
    File(photoPath).writeAsStringSync('REAL-PHOTO-BYTES');
  });

  tearDown(() async {
    await database.close();
    tempDir.deleteSync(recursive: true);
  });

  VisitRecord sampleVisit({String? photo}) => VisitRecord(
    id: visitId,
    sessionId: sessionId,
    employeeId: employeeId,
    storeName: 'Kisan Kendra',
    note: 'Delivered seeds sample',
    latitude: 19.9975,
    longitude: 73.7898,
    accuracy: 4.2,
    capturedAt: DateTime.parse('2026-10-18T04:00:00Z'),
    localPhotoPath: photo,
  );

  SupabaseVisitRepository repo(
    MockSupabase supabase, {
    http.Client? cloudinary,
    String Function()? signedIn,
  }) => SupabaseVisitRepository(
    queue,
    supabase.client,
    cloudinary,
    vault,
    signedIn ?? () => employeeId,
  );

  /// A server that takes the visit and signs, confirms and accepts the photo.
  MockSupabase healthyServer({List<String>? actions}) =>
      MockSupabase((request) {
        if (request.url.path.contains('/rest/v1/visits')) {
          return jsonResponse(<Map<String, dynamic>>[
            <String, dynamic>{'id': visitId},
          ], 201);
        }
        if (request.url.path.contains('/functions/v1/visit-photos')) {
          final payload = jsonDecode(request.body) as Map<String, dynamic>;
          actions?.add(payload['action'] as String);
          if (payload['action'] == 'sign') {
            return jsonResponse(<String, dynamic>{
              'upload_url':
                  'https://api.cloudinary.com/v1_1/testcloud/image/upload',
              'api_key': 'mock_api_key',
              'params': <String, dynamic>{
                'public_id': 'visit-$visitId',
                'timestamp': '1700000000',
                'type': 'authenticated',
              },
              'signature': 'mock_sha1_signature',
            });
          }
          return jsonResponse(<String, dynamic>{'status': 'attached'});
        }
        return jsonResponse(null, 404);
      });

  http.Client cloudinaryReplying(int status, {List<http.Request>? seen}) =>
      MockClient((request) async {
        seen?.add(request);
        return http.Response(
          jsonEncode(<String, dynamic>{'public_id': 'visit-$visitId'}),
          status,
        );
      });

  group('recordVisit without a photo', () {
    test(
      'sends only granted columns and leaves nothing on the phone',
      () async {
        late http.Request insertRequest;
        final server = MockSupabase((request) {
          insertRequest = request;
          return jsonResponse(<Map<String, dynamic>>[], 201);
        });

        final result = await repo(server).recordVisit(sampleVisit());

        expect(result.synced, isTrue);
        expect(result.id, visitId);
        final body = jsonDecode(insertRequest.body) as Map<String, dynamic>;
        expect(body['id'], visitId);
        expect(body['session_id'], sessionId);
        expect(body['store_name'], 'Kisan Kendra');
        expect(body['note'], 'Delivered seeds sample');
        expect(body['latitude'], 19.9975);
        expect(body['longitude'], 73.7898);
        expect(body.containsKey('employee_id'), isFalse);
        expect(await queue.all(), isEmpty);
      },
    );

    test('a duplicate id (23505) counts as sent', () async {
      final server = MockSupabase(
        (request) => jsonResponse(<String, dynamic>{
          'code': '23505',
          'message': 'duplicate key value violates unique constraint',
        }, 409),
      );

      final result = await repo(server).recordVisit(sampleVisit());

      expect(result.synced, isTrue);
      expect(await queue.all(), isEmpty);
    });
  });

  group('recordVisit with a photo', () {
    test('signs, uploads the real file, confirms, then forgets it', () async {
      final actions = <String>[];
      final cloudinaryRequests = <http.Request>[];

      final result = await repo(
        healthyServer(actions: actions),
        cloudinary: cloudinaryReplying(200, seen: cloudinaryRequests),
      ).recordVisit(sampleVisit(photo: photoPath));

      expect(result.synced, isTrue);
      expect(actions, <String>['sign', 'confirm']);
      expect(cloudinaryRequests, hasLength(1));
      expect(cloudinaryRequests.single.body, contains('REAL-PHOTO-BYTES'));
      expect(await queue.all(), isEmpty);
      expect(vault.discarded, <String>[photoPath]);
    });

    test(
      'a photo the server refuses for good is dropped, the visit stays',
      () async {
        final server = MockSupabase((request) {
          if (request.url.path.contains('/rest/v1/visits')) {
            return jsonResponse(<Map<String, dynamic>>[], 201);
          }
          return jsonResponse(<String, dynamic>{'error': 'visit_too_old'}, 409);
        });

        final result = await repo(
          server,
        ).recordVisit(sampleVisit(photo: photoPath));

        expect(result.synced, isTrue);
        expect(await queue.all(), isEmpty);
        expect(vault.discarded, <String>[photoPath]);
      },
    );

    test(
      'a Cloudinary 4xx drops the photo; a 5xx keeps it for a retry',
      () async {
        await repo(
          healthyServer(),
          cloudinary: cloudinaryReplying(400),
        ).recordVisit(sampleVisit(photo: photoPath));
        expect(await queue.all(), isEmpty);

        final later = sampleVisit(
          photo: photoPath,
        ).copyWith(id: 'second-visit');
        final result = await repo(
          healthyServer(),
          cloudinary: cloudinaryReplying(503),
        ).recordVisit(later);

        expect(result.synced, isTrue, reason: 'the row is on the server');
        final waiting = await queue.all();
        expect(waiting, hasLength(1));
        expect(waiting.single.rowSent, isTrue);
        expect(waiting.single.visit.localPhotoPath, photoPath);
      },
    );

    test(
      'a photo file that is gone is never replaced by fake content',
      () async {
        final cloudinaryRequests = <http.Request>[];
        final missing = '${tempDir.path}${Platform.pathSeparator}gone.jpg';

        final result = await repo(
          healthyServer(),
          cloudinary: cloudinaryReplying(200, seen: cloudinaryRequests),
        ).recordVisit(sampleVisit(photo: missing));

        expect(result.synced, isTrue);
        expect(cloudinaryRequests, isEmpty);
        expect(await queue.all(), isEmpty);
      },
    );

    test(
      'a photo that disappears while waiting is dropped, not faked',
      () async {
        final cloudinaryRequests = <http.Request>[];
        await repo(
          MockSupabase.offline(),
        ).recordVisit(sampleVisit(photo: photoPath));
        File(photoPath).deleteSync();

        await repo(
          healthyServer(),
          cloudinary: cloudinaryReplying(200, seen: cloudinaryRequests),
        ).syncPendingVisits();

        expect(cloudinaryRequests, isEmpty);
        expect(await queue.all(), isEmpty);
      },
    );
  });

  group('saving on the phone first', () {
    test('offline: the visit and its photo wait on the phone', () async {
      final result = await repo(
        MockSupabase.offline(),
      ).recordVisit(sampleVisit(photo: photoPath));

      expect(result.synced, isFalse);
      final waiting = await queue.all();
      expect(waiting, hasLength(1));
      expect(waiting.single.rowSent, isFalse);
      expect(waiting.single.visit.localPhotoPath, photoPath);
      expect(vault.discarded, isEmpty);
    });

    test(
      'a server error leaves the visit waiting instead of losing it',
      () async {
        final server = MockSupabase((request) => jsonResponse(null, 500));

        final result = await repo(server).recordVisit(sampleVisit());

        expect(result.synced, isFalse);
        expect(await queue.all(), hasLength(1));
      },
    );

    test('when the phone cannot keep the photo the employee is told', () async {
      vault.failToKeep = true;

      await expectLater(
        repo(healthyServer()).recordVisit(sampleVisit(photo: photoPath)),
        throwsA(isA<ServerException>()),
      );
      expect(await queue.all(), isEmpty);
    });

    test('a visit waiting offline is sent later, exactly once', () async {
      await repo(
        MockSupabase.offline(),
      ).recordVisit(sampleVisit(photo: photoPath));

      final server = healthyServer();
      final online = repo(server, cloudinary: cloudinaryReplying(200));
      await online.syncPendingVisits();
      await online.syncPendingVisits();

      expect(await queue.all(), isEmpty);
      final inserts = server.requests.where(
        (r) => r.url.path.contains('/rest/v1/visits'),
      );
      expect(inserts, hasLength(1));
    });

    test("only the signed-in employee's visits are sent", () async {
      await repo(MockSupabase.offline()).recordVisit(sampleVisit());
      final server = healthyServer();

      await repo(server, signedIn: () => 'someone-else').syncPendingVisits();

      expect(server.requests, isEmpty);
      expect(await queue.all(), hasLength(1));
    });

    test('a failure that may pass ends the pass; the next goes on', () async {
      final second = sampleVisit().copyWith(id: 'second-visit');
      final offline = repo(MockSupabase.offline());
      await offline.recordVisit(sampleVisit());
      await offline.recordVisit(second);

      final down = MockSupabase((request) => jsonResponse(null, 503));
      await repo(down).syncPendingVisits();
      expect(down.requests, hasLength(1), reason: 'stops at the first failure');
      expect(await queue.all(), hasLength(2));

      await repo(healthyServer()).syncPendingVisits();
      expect(await queue.all(), isEmpty);
    });

    test('a visit refused for good is dropped and the rest go on', () async {
      final second = sampleVisit().copyWith(id: 'second-visit');
      final offline = repo(MockSupabase.offline());
      await offline.recordVisit(sampleVisit());
      await offline.recordVisit(second);

      var calls = 0;
      final server = MockSupabase((request) {
        calls++;
        return calls == 1
            ? jsonResponse(<String, dynamic>{
                'code': 'P0001',
                'message': 'visit_outside_session',
              }, 400)
            : jsonResponse(<Map<String, dynamic>>[], 201);
      });
      await repo(server).syncPendingVisits();

      expect(await queue.all(), isEmpty);
      expect(calls, 2);
    });
  });

  group('refusals reach the employee', () {
    final cases = <String, Matcher>{
      'account_not_active': isA<AccountBlockedException>(),
      'visit_outside_session': isA<ValidationException>(),
      'visit_limit': isA<ValidationException>(),
    };
    for (final entry in cases.entries) {
      test('${entry.key} is thrown and nothing is left waiting', () async {
        final server = MockSupabase(
          (request) => jsonResponse(<String, dynamic>{
            'code': 'P0001',
            'message': entry.key,
          }, 400),
        );

        await expectLater(
          repo(server).recordVisit(sampleVisit(photo: photoPath)),
          throwsA(entry.value),
        );
        expect(await queue.all(), isEmpty);
        expect(vault.discarded, <String>[photoPath]);
      });
    }
  });
}
