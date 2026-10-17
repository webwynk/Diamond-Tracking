import 'dart:async';
import 'dart:math';

import 'package:diamond_tracking/core/errors/app_exceptions.dart';
import 'package:diamond_tracking/core/services/tracking_uploader.dart';
import 'package:diamond_tracking/data/local/drift_tracking_queue_store.dart';
import 'package:diamond_tracking/data/local/tracking_database.dart';
import 'package:diamond_tracking/domain/entities/location_point.dart';
import 'package:diamond_tracking/domain/entities/point_ingest_result.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_duty.dart';

final DateTime _base = DateTime.utc(2026, 10, 17, 4, 30);

LocationPoint _point(String id, int seconds, {String session = 's1'}) =>
    LocationPoint(
      id: id,
      sessionId: session,
      latitude: 20.0,
      longitude: 73.0,
      accuracy: 5,
      recordedAt: _base.add(Duration(seconds: seconds)),
    );

/// Waits (briefly, in real time) until [condition] holds.
Future<void> _until(bool Function() condition) async {
  for (var i = 0; i < 400 && !condition(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  expect(condition(), isTrue, reason: 'timed out waiting');
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('BackoffPolicy', () {
    final policy = BackoffPolicy(random: Random(1));

    test('starts near 15 s and roughly doubles', () {
      for (var i = 0; i < 50; i++) {
        expect(
          policy.delayAfter(1).inMilliseconds,
          inInclusiveRange(12000, 18000),
        );
        expect(
          policy.delayAfter(2).inMilliseconds,
          inInclusiveRange(24000, 36000),
        );
        expect(
          policy.delayAfter(3).inMilliseconds,
          inInclusiveRange(48000, 72000),
        );
      }
    });

    test('never waits more than 10 minutes, however many failures', () {
      for (final failures in [6, 7, 10, 50, 1000]) {
        expect(
          policy.delayAfter(failures),
          lessThanOrEqualTo(BackoffPolicy.maximum),
        );
      }
      expect(policy.delayAfter(1000), BackoffPolicy.maximum);
    });

    test('is randomised so phones do not retry in lockstep', () {
      final delays = {for (var i = 0; i < 20; i++) policy.delayAfter(4)};
      expect(delays.length, greaterThan(1));
    });
  });

  group('TrackingUploader', () {
    late TrackingDatabase database;
    late DriftTrackingQueueStore store;
    late FakeDutyRepository server;
    late TrackingUploader uploader;

    setUp(() {
      database = TrackingDatabase(NativeDatabase.memory());
      store = DriftTrackingQueueStore(database);
      server = FakeDutyRepository();
      uploader = TrackingUploader(queue: store, ingestor: server);
    });

    tearDown(() async {
      uploader.stop();
      await database.close();
    });

    Future<void> enqueue(int count, {String prefix = 'p'}) async {
      for (var i = 0; i < count; i++) {
        await store.enqueuePoint(_point('$prefix$i', i));
      }
    }

    test('an empty queue makes no request', () async {
      final outcome = await uploader.uploadPending();

      expect(outcome.queueEmpty, isTrue);
      expect(outcome.failed, isFalse);
      expect(server.ingestedBatches, isEmpty);
    });

    test('confirmed points (new or already there) leave the phone', () async {
      await enqueue(3);
      server.ingestHandler = (points) async =>
          PointIngestResult(confirmedIds: {for (final p in points) p.id});

      final outcome = await uploader.uploadPending();

      expect(outcome.confirmed, 3);
      expect(outcome.queueEmpty, isTrue);
      expect(await store.pendingPointCount(), 0);
    });

    test('sends oldest first, 100 at a time', () async {
      await enqueue(250);

      final outcome = await uploader.uploadPending();

      expect(server.ingestedBatches.map((b) => b.length), [100, 100, 50]);
      expect(server.ingestedBatches.first.first.id, 'p0');
      expect(server.ingestedBatches.last.last.id, 'p249');
      expect(outcome.confirmed, 250);
      expect(await store.pendingPointCount(), 0);
    });

    test(
      'no internet: every point stays, the failure is counted, and it recovers',
      () async {
        await enqueue(3);
        server.ingestHandler = (_) async => throw const NetworkException();

        final first = await uploader.uploadPending();
        final second = await uploader.uploadPending();

        expect(first.failed, isTrue);
        expect(first.failure, isA<NetworkException>());
        expect(first.queueEmpty, isFalse);
        expect(second.failed, isTrue);
        expect(uploader.consecutiveFailures, 2);
        expect(await store.pendingPointCount(), 3);

        server.ingestHandler = null;
        final third = await uploader.uploadPending();

        expect(third.failed, isFalse);
        expect(uploader.consecutiveFailures, 0);
        expect(await store.pendingPointCount(), 0);
      },
    );

    test(
      'a signed-out session asks the employee to sign in and loses nothing',
      () async {
        await enqueue(2);
        server.ingestHandler = (_) async =>
            throw const UnauthorizedRoleException();

        final outcome = await uploader.uploadPending();

        expect(outcome.needsSignIn, isTrue);
        expect(await store.pendingPointCount(), 2);
      },
    );

    test(
      'rejected points are discarded and counted; the rest still go',
      () async {
        await store.enqueuePoint(_point('bad', 0));
        await store.enqueuePoint(_point('good', 1));
        server.ingestHandler = (points) async => const PointIngestResult(
          confirmedIds: {'good'},
          rejected: {'bad': 'invalid_point'},
        );

        final outcome = await uploader.uploadPending();

        expect(outcome.confirmed, 1);
        expect(outcome.rejected, 1);
        expect(await store.pendingPointCount(), 0);
        expect(await store.rejectedPointsCount(), 1);
        expect(outcome.refusedSessionIds, isEmpty);
      },
    );

    test(
      'a refused session is reported so the tracker can stop for it',
      () async {
        await store.enqueuePoint(_point('late', 0, session: 'closed-one'));
        await store.enqueuePoint(_point('other', 1, session: 'open-one'));
        server.ingestHandler = (points) async => const PointIngestResult(
          confirmedIds: {'other'},
          rejected: {'late': 'point_outside_session'},
        );

        final outcome = await uploader.uploadPending();

        expect(outcome.refusedSessionIds, {'closed-one'});
      },
    );

    test(
      'a point the server did not mention is kept, and the pass stops',
      () async {
        await store.enqueuePoint(_point('a', 0));
        await store.enqueuePoint(_point('b', 1));
        server.ingestHandler = (points) async =>
            const PointIngestResult(confirmedIds: {'a'});

        final outcome = await uploader.uploadPending();

        expect(outcome.failed, isTrue);
        expect((await store.nextBatch()).map((p) => p.id), ['b']);
      },
    );

    test(
      'an answer that settles nothing is a failure, not an endless loop',
      () async {
        await enqueue(2);
        server.ingestHandler = (_) async => const PointIngestResult();

        final outcome = await uploader.uploadPending();

        expect(outcome.failed, isTrue);
        expect(server.ingestedBatches, hasLength(1));
        expect(await store.pendingPointCount(), 2);
      },
    );

    test('overlapping calls share one pass', () async {
      await enqueue(2);
      final gate = Completer<void>();
      server.ingestHandler = (points) async {
        await gate.future;
        return PointIngestResult(confirmedIds: {for (final p in points) p.id});
      };

      final first = uploader.uploadPending();
      final second = uploader.uploadPending();
      gate.complete();
      await Future.wait([first, second]);

      expect(server.ingestedBatches, hasLength(1));
    });

    test('flush gives up waiting after its timeout', () async {
      await enqueue(1);
      final neverAnswers = Completer<PointIngestResult>();
      server.ingestHandler = (_) => neverAnswers.future;

      final outcome = await uploader.flush(
        timeout: const Duration(milliseconds: 30),
      );

      expect(outcome.failed, isTrue);
      expect(outcome.queueEmpty, isFalse);
      expect(await store.pendingPointCount(), 1);
    });
  });

  group('TrackingUploader background loop', () {
    late TrackingDatabase database;
    late DriftTrackingQueueStore store;
    late FakeDutyRepository server;
    late List<Duration> waits;
    late List<Completer<void>> delays;
    late TrackingUploader uploader;

    setUp(() {
      database = TrackingDatabase(NativeDatabase.memory());
      store = DriftTrackingQueueStore(database);
      server = FakeDutyRepository();
      waits = [];
      delays = [];
      uploader = TrackingUploader(
        queue: store,
        ingestor: server,
        backoff: BackoffPolicy(random: Random(7)),
        delay: (duration) {
          waits.add(duration);
          final gate = Completer<void>();
          delays.add(gate);
          return gate.future;
        },
      );
    });

    tearDown(() async {
      uploader.stop();
      await database.close();
    });

    test(
      'uploads, waits a minute, then uploads what arrived meanwhile',
      () async {
        await store.enqueuePoint(_point('p1', 0));

        uploader.start();
        await _until(() => waits.length == 1);
        expect(waits.single, const Duration(seconds: 60));
        expect(await store.pendingPointCount(), 0);

        await store.enqueuePoint(_point('p2', 60));
        delays.first.complete();
        await _until(() => waits.length == 2);

        expect(server.ingestedBatches.map((b) => b.single.id), ['p1', 'p2']);
        expect(await store.pendingPointCount(), 0);
      },
    );

    test(
      'after a failure it waits longer (backoff), and a clean pass returns to a minute',
      () async {
        await store.enqueuePoint(_point('p1', 0));
        server.ingestHandler = (_) async => throw const NetworkException();

        uploader.start();
        await _until(() => waits.length == 1);
        expect(waits.first.inMilliseconds, inInclusiveRange(12000, 18000));

        server.ingestHandler = null;
        delays.first.complete();
        await _until(() => waits.length == 2);

        expect(waits.last, const Duration(seconds: 60));
        expect(await store.pendingPointCount(), 0);
      },
    );

    test('start twice runs one loop, and stop ends it', () async {
      uploader
        ..start()
        ..start();
      await _until(() => waits.isNotEmpty);
      expect(waits, hasLength(1));
      expect(uploader.isRunning, isTrue);

      uploader.stop();
      await store.enqueuePoint(_point('p1', 0));
      for (final gate in delays) {
        if (!gate.isCompleted) gate.complete();
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(uploader.isRunning, isFalse);
      expect(
        server.ingestedBatches,
        isEmpty,
        reason: 'a stopped loop sends nothing',
      );
      expect(await store.pendingPointCount(), 1);
    });
  });
}
