import 'dart:io';

import 'package:diamond_tracking/data/local/drift_tracking_queue_store.dart';
import 'package:diamond_tracking/data/local/tracking_database.dart';
import 'package:diamond_tracking/domain/entities/location_point.dart';
import 'package:diamond_tracking/domain/repositories/tracking_queue_store.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

final DateTime _base = DateTime.utc(2026, 10, 17, 4, 30);

LocationPoint _point(String id, {int seconds = 0, String session = 's1'}) =>
    LocationPoint(
      id: id,
      sessionId: session,
      latitude: 20.0 + seconds / 100000,
      longitude: 73.0,
      accuracy: 5,
      recordedAt: _base.add(Duration(seconds: seconds)),
    );

void main() {
  // Each test opens its own in-memory database, and the restart test opens the
  // same file twice on purpose (after closing the first): drift's warning about
  // multiple instances does not apply.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late TrackingDatabase database;
  late DriftTrackingQueueStore store;

  setUp(() {
    database = TrackingDatabase(NativeDatabase.memory());
    store = DriftTrackingQueueStore(database);
  });

  tearDown(() => database.close());

  group('points', () {
    test('are returned oldest first, with every field intact', () async {
      final detailed = LocationPoint(
        id: 'full',
        sessionId: 's1',
        latitude: 20.123456,
        longitude: 73.654321,
        accuracy: 7.5,
        speed: 4.2,
        heading: 181.5,
        altitude: 552.25,
        batteryLevel: 63,
        isMock: true,
        recordedAt: DateTime.utc(2026, 10, 17, 4, 31, 2, 345),
      );
      await store.enqueuePoint(_point('later', seconds: 120));
      await store.enqueuePoint(detailed);
      await store.enqueuePoint(_point('first', seconds: 0));

      final batch = await store.nextBatch();

      expect(batch.map((p) => p.id), <String>['first', 'full', 'later']);
      final back = batch[1];
      expect(back, detailed);
      expect(back.speed, 4.2);
      expect(back.heading, 181.5);
      expect(back.altitude, 552.25);
      expect(back.batteryLevel, 63);
      expect(back.isMock, isTrue);
      expect(back.recordedAt.isUtc, isTrue);
      expect(back.recordedAt.millisecond, 345, reason: 'milliseconds are kept');
    });

    test('missing optional readings stay missing, not zero', () async {
      await store.enqueuePoint(_point('p'));

      final back = (await store.nextBatch()).single;

      expect(back.speed, isNull);
      expect(back.heading, isNull);
      expect(back.altitude, isNull);
      expect(back.batteryLevel, isNull);
      expect(back.isMock, isFalse);
    });

    test('the same id twice is stored once', () async {
      await store.enqueuePoint(_point('p', seconds: 1));
      await store.enqueuePoint(_point('p', seconds: 1));

      expect(await store.pendingPointCount(), 1);
    });

    test('nextBatch honours the limit', () async {
      for (var i = 0; i < 5; i++) {
        await store.enqueuePoint(_point('p$i', seconds: i));
      }

      expect((await store.nextBatch(limit: 2)).map((p) => p.id), ['p0', 'p1']);
      expect(await store.pendingPointCount(), 5);
    });

    test('only confirmed points leave the phone', () async {
      for (var i = 0; i < 4; i++) {
        await store.enqueuePoint(_point('p$i', seconds: i));
      }

      await store.removeConfirmedPoints(['p0', 'p2', 'unknown']);

      expect((await store.nextBatch()).map((p) => p.id), ['p1', 'p3']);
    });

    test('rejected points are removed and counted', () async {
      for (var i = 0; i < 4; i++) {
        await store.enqueuePoint(_point('p$i', seconds: i));
      }

      await store.discardRejectedPoints(['p0', 'p1']);
      await store.discardRejectedPoints(['p2', 'not-there']);

      expect(await store.pendingPointCount(), 1);
      expect(await store.rejectedPointsCount(), 3);
    });
  });

  group('limits', () {
    test(
      'over the cap, the oldest are thinned and the newest survive',
      () async {
        const cap = TrackingQueueStore.maxQueuedPoints;
        for (var i = 0; i <= cap; i++) {
          await store.enqueuePoint(_point('p$i', seconds: i));
        }

        final count = await store.pendingPointCount();
        final ids = (await store.nextBatch(limit: cap + 10)).map((p) => p.id);

        expect(count, lessThanOrEqualTo(cap));
        expect(count, greaterThan(cap * 0.7), reason: 'thinning, not wiping');
        expect(ids.first, 'p0', reason: 'the start of the route is kept');
        expect(ids.last, 'p$cap', reason: 'the newest point is never lost');
        expect(ids, contains('p2999'));
        expect(
          ids.where((id) => id == 'p1' || id == 'p3'),
          isEmpty,
          reason: 'every other old point is removed',
        );
      },
    );

    test('points older than 30 days are purged, newer ones kept', () async {
      final now = DateTime.utc(2026, 10, 17, 12);
      await store.enqueuePoint(
        LocationPoint(
          id: 'old',
          sessionId: 's1',
          latitude: 20,
          longitude: 73,
          accuracy: 5,
          recordedAt: now.subtract(const Duration(days: 31)),
        ),
      );
      await store.enqueuePoint(
        LocationPoint(
          id: 'recent',
          sessionId: 's1',
          latitude: 20,
          longitude: 73,
          accuracy: 5,
          recordedAt: now.subtract(const Duration(days: 29)),
        ),
      );

      final removed = await store.purgeExpiredPoints(now);

      expect(removed, 1);
      expect((await store.nextBatch()).map((p) => p.id), ['recent']);
    });
  });

  group('session and pending duty-off', () {
    test('the active session is saved, replaced whole, and cleared', () async {
      expect(await store.activeSession(), isNull);

      await store.saveActiveSession(
        ActiveTrackingSession(
          sessionId: 'a',
          employeeId: 'e1',
          startedAt: _base,
        ),
      );
      await store.saveActiveSession(
        ActiveTrackingSession(
          sessionId: 'b',
          employeeId: 'e1',
          startedAt: _base.add(const Duration(hours: 1)),
        ),
      );

      final active = await store.activeSession();
      expect(active?.sessionId, 'b');
      expect(active?.startedAt, _base.add(const Duration(hours: 1)));
      expect(active?.startedAt.isUtc, isTrue);

      await store.clearActiveSession();
      expect(await store.activeSession(), isNull);
    });

    test('a pending duty-off keeps the phone time, reason and note', () async {
      expect(await store.pendingEnd(), isNull);

      await store.savePendingEnd(
        PendingSessionEnd(
          sessionId: 's1',
          endedAt: DateTime.utc(2026, 10, 17, 13, 0, 5, 250),
          reason: 'normal',
          notes: 'No signal',
        ),
      );

      final pending = await store.pendingEnd();
      expect(pending?.sessionId, 's1');
      expect(pending?.endedAt, DateTime.utc(2026, 10, 17, 13, 0, 5, 250));
      expect(pending?.reason, 'normal');
      expect(pending?.notes, 'No signal');

      await store.clearPendingEnd();
      expect(await store.pendingEnd(), isNull);
    });
  });

  test('wipeAll (sign-out) removes everything personal', () async {
    await store.enqueuePoint(_point('p'));
    await store.discardRejectedPoints(['p']);
    await store.enqueuePoint(_point('q'));
    await store.saveActiveSession(
      ActiveTrackingSession(sessionId: 'a', employeeId: 'e1', startedAt: _base),
    );
    await store.savePendingEnd(
      PendingSessionEnd(sessionId: 'a', endedAt: _base, reason: 'normal'),
    );

    await store.wipeAll();

    expect(await store.pendingPointCount(), 0);
    expect(await store.rejectedPointsCount(), 0);
    expect(await store.activeSession(), isNull);
    expect(await store.pendingEnd(), isNull);
  });

  test('data survives the app being closed and opened again', () async {
    final directory = await Directory.systemTemp.createTemp('tracking_queue_');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/tracking.sqlite');

    final first = TrackingDatabase(NativeDatabase(file));
    final firstStore = DriftTrackingQueueStore(first);
    await firstStore.enqueuePoint(_point('kept', seconds: 5));
    await firstStore.saveActiveSession(
      ActiveTrackingSession(
        sessionId: 's1',
        employeeId: 'e1',
        startedAt: _base,
      ),
    );
    await firstStore.savePendingEnd(
      PendingSessionEnd(sessionId: 's1', endedAt: _base, reason: 'normal'),
    );
    await first.close();

    final second = TrackingDatabase(NativeDatabase(file));
    addTearDown(second.close);
    final secondStore = DriftTrackingQueueStore(second);

    expect((await secondStore.nextBatch()).single.id, 'kept');
    expect((await secondStore.activeSession())?.sessionId, 's1');
    expect((await secondStore.pendingEnd())?.sessionId, 's1');
  });
}
