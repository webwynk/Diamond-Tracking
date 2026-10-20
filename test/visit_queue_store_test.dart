import 'dart:io';

import 'package:diamond_tracking/data/local/drift_tracking_queue_store.dart';
import 'package:diamond_tracking/data/local/drift_visit_queue_store.dart';
import 'package:diamond_tracking/data/local/tracking_database.dart';
import 'package:diamond_tracking/domain/entities/location_point.dart';
import 'package:diamond_tracking/domain/entities/visit_record.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

VisitRecord _visit(
  String id, {
  int minute = 0,
  String employeeId = 'emp-1',
  String? photo,
}) => VisitRecord(
  id: id,
  sessionId: 'session-1',
  employeeId: employeeId,
  storeName: 'Kisan Kendra',
  note: 'Seeds delivered',
  latitude: 19.9975,
  longitude: 73.7898,
  accuracy: 4.5,
  capturedAt: DateTime.utc(2026, 10, 18, 4, minute),
  localPhotoPath: photo,
);

void main() {
  // The restart tests open the same file twice on purpose, after closing the
  // first connection: drift's warning about multiple instances does not apply.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('DriftVisitQueueStore', () {
    late TrackingDatabase database;
    late DriftVisitQueueStore store;

    setUp(() {
      database = TrackingDatabase(NativeDatabase.memory());
      store = DriftVisitQueueStore(database);
    });

    tearDown(() => database.close());

    test('keeps every field of a visit', () async {
      await store.enqueue(_visit('v1', photo: '/photos/v1.jpg'));

      final waiting = await store.all();

      expect(waiting, hasLength(1));
      final saved = waiting.single;
      expect(saved.rowSent, isFalse);
      expect(saved.visit.id, 'v1');
      expect(saved.visit.sessionId, 'session-1');
      expect(saved.visit.employeeId, 'emp-1');
      expect(saved.visit.storeName, 'Kisan Kendra');
      expect(saved.visit.note, 'Seeds delivered');
      expect(saved.visit.latitude, 19.9975);
      expect(saved.visit.longitude, 73.7898);
      expect(saved.visit.accuracy, 4.5);
      expect(saved.visit.capturedAt, DateTime.utc(2026, 10, 18, 4));
      expect(saved.visit.localPhotoPath, '/photos/v1.jpg');
    });

    test(
      'a visit with no store name, note, accuracy or photo is fine',
      () async {
        await store.enqueue(
          VisitRecord(
            id: 'bare',
            sessionId: 'session-1',
            employeeId: 'emp-1',
            latitude: 1,
            longitude: 2,
            capturedAt: DateTime.utc(2026, 10, 18, 4),
          ),
        );

        final saved = (await store.all()).single;

        expect(saved.visit.storeName, isNull);
        expect(saved.visit.note, isNull);
        expect(saved.visit.accuracy, isNull);
        expect(saved.visit.localPhotoPath, isNull);
      },
    );

    test('returns the oldest visit first', () async {
      await store.enqueue(_visit('late', minute: 30));
      await store.enqueue(_visit('early', minute: 5));
      await store.enqueue(_visit('middle', minute: 20));

      final ids = (await store.all()).map((p) => p.visit.id);

      expect(ids, <String>['early', 'middle', 'late']);
    });

    test('saving the same id again keeps the first entry', () async {
      await store.enqueue(_visit('v1', photo: '/photos/first.jpg'));
      await store.enqueue(_visit('v1', photo: '/photos/second.jpg'));

      final waiting = await store.all();

      expect(waiting, hasLength(1));
      expect(waiting.single.visit.localPhotoPath, '/photos/first.jpg');
    });

    test('pendingFor lists only that employee', () async {
      await store.enqueue(_visit('mine'));
      await store.enqueue(_visit('theirs', employeeId: 'emp-2'));

      final mine = await store.pendingFor('emp-1');

      expect(mine.map((p) => p.visit.id), <String>['mine']);
    });

    test('markRowSent is remembered, remove forgets the visit', () async {
      await store.enqueue(_visit('v1'));

      await store.markRowSent('v1');
      expect((await store.all()).single.rowSent, isTrue);

      await store.remove('v1');
      expect(await store.all(), isEmpty);
    });
  });

  group('across a restart', () {
    late Directory dir;
    late File file;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('visit_queue_test');
      file = File('${dir.path}${Platform.pathSeparator}tracking.sqlite');
    });

    tearDown(() => dir.deleteSync(recursive: true));

    test('a waiting visit is still there when the app starts again', () async {
      final first = TrackingDatabase(NativeDatabase(file));
      await DriftVisitQueueStore(first).enqueue(_visit('v1', photo: '/p.jpg'));
      await DriftVisitQueueStore(first).markRowSent('v1');
      await first.close();

      final second = TrackingDatabase(NativeDatabase(file));
      addTearDown(second.close);
      final waiting = await DriftVisitQueueStore(second).all();

      expect(waiting, hasLength(1));
      expect(waiting.single.visit.id, 'v1');
      expect(waiting.single.rowSent, isTrue);
      expect(waiting.single.visit.localPhotoPath, '/p.jpg');
    });

    test(
      'a phone on database version 1 upgrades without losing GPS points',
      () async {
        final oldPhone = TrackingDatabase(NativeDatabase(file));
        await DriftTrackingQueueStore(oldPhone).enqueuePoint(
          LocationPoint(
            id: 'p1',
            sessionId: 's1',
            latitude: 20,
            longitude: 73,
            accuracy: 5,
            recordedAt: DateTime.utc(2026, 10, 17, 4, 30),
          ),
        );
        // Make it look like the file an earlier app version left behind.
        await oldPhone.customStatement('DROP TABLE pending_visits');
        await oldPhone.customStatement('PRAGMA user_version = 1');
        await oldPhone.close();

        final upgraded = TrackingDatabase(NativeDatabase(file));
        addTearDown(upgraded.close);
        final points = await DriftTrackingQueueStore(upgraded).nextBatch();
        await DriftVisitQueueStore(upgraded).enqueue(_visit('v1'));

        expect(points.map((p) => p.id), <String>['p1']);
        expect(await DriftVisitQueueStore(upgraded).all(), hasLength(1));
      },
    );
  });
}
