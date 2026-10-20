import 'package:diamond_tracking/core/errors/app_exceptions.dart';
import 'package:diamond_tracking/core/services/tracker_engine.dart';
import 'package:diamond_tracking/core/services/tracking_uploader.dart';
import 'package:diamond_tracking/data/local/drift_tracking_queue_store.dart';
import 'package:diamond_tracking/data/local/tracking_database.dart';
import 'package:diamond_tracking/domain/entities/location_point.dart';
import 'package:diamond_tracking/domain/repositories/tracking_queue_store.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_duty.dart';

/// 10:00 IST on 17 Oct 2026.
final DateTime _tenAm = DateTime.utc(2026, 10, 17, 4, 30);

TrackerFix _fix({
  double lat = 20.0,
  double lon = 73.0,
  double? speed,
  bool mock = false,
  double accuracy = 5,
}) => TrackerFix(
  latitude: lat,
  longitude: lon,
  accuracy: accuracy,
  speed: speed,
  isMock: mock,
);

ActiveTrackingSession _session({
  DateTime? startedAt,
  Duration offset = Duration.zero,
}) => ActiveTrackingSession(
  sessionId: 's1',
  employeeId: 'e1',
  startedAt: startedAt ?? _tenAm,
  clockOffset: offset,
);

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late TrackingDatabase database;
  late DriftTrackingQueueStore store;
  late FakeUploader uploader;
  late DateTime deviceNow;
  late List<LocationPoint> reported;
  late List<TrackerStopReason> stops;
  late List<TrackerNotice> notices;
  late bool sessionStillOpen;
  late Exception? openCheckFails;
  late int? battery;
  late TrackerEngine engine;

  setUp(() {
    database = TrackingDatabase(NativeDatabase.memory());
    store = DriftTrackingQueueStore(database);
    uploader = FakeUploader();
    deviceNow = _tenAm;
    reported = [];
    stops = [];
    notices = [];
    sessionStillOpen = true;
    openCheckFails = null;
    battery = 80;
    engine = TrackerEngine(
      queue: store,
      uploader: uploader,
      isSessionOpen: (_) async {
        if (openCheckFails != null) throw openCheckFails!;
        return sessionStillOpen;
      },
      onPoint: reported.add,
      onStopped: stops.add,
      onNotice: notices.add,
      now: () => deviceNow,
      batteryLevel: () async => battery,
    );
  });

  tearDown(() => database.close());

  group('waiting for a good first fix', () {
    setUp(() async => engine.start(_session()));

    test(
      'a weak fix right after start is skipped; a good one is recorded',
      () async {
        await engine.handleFix(_fix(accuracy: 400));
        await engine.handleFix(_fix(accuracy: 120));
        expect(reported, isEmpty);
        expect(await store.pendingPointCount(), 0);

        deviceNow = deviceNow.add(const Duration(seconds: 6));
        await engine.handleFix(_fix(accuracy: 12));

        expect(reported, hasLength(1));
        expect(reported.single.accuracy, 12);
      },
    );

    test('50 m counts as good; just over it does not', () async {
      await engine.handleFix(_fix(accuracy: 50.1));
      expect(reported, isEmpty);

      await engine.handleFix(_fix(accuracy: 50));
      expect(reported, hasLength(1));
    });

    test('after 30 seconds a weak fix is recorded anyway', () async {
      await engine.handleFix(_fix(accuracy: 300));
      expect(reported, isEmpty);

      deviceNow = deviceNow.add(const Duration(seconds: 29));
      await engine.handleFix(_fix(accuracy: 300));
      expect(reported, isEmpty, reason: 'still inside the 30 seconds');

      deviceNow = deviceNow.add(const Duration(seconds: 1));
      await engine.handleFix(_fix(accuracy: 300));
      expect(reported, hasLength(1), reason: 'tracking never waits for ever');
      expect(reported.single.accuracy, 300);
    });

    test('a fake location is recorded at once, never skipped', () async {
      await engine.handleFix(_fix(accuracy: 400, mock: true));

      expect(reported, hasLength(1));
      expect(reported.single.isMock, isTrue);
    });

    test(
      'once a point is recorded, weak fixes follow the normal rules',
      () async {
        await engine.handleFix(_fix(accuracy: 10));
        expect(reported, hasLength(1));

        // Moving: the next point is due after 25 s, weak or not.
        deviceNow = deviceNow.add(const Duration(seconds: 26));
        await engine.handleFix(_fix(lat: 20.001, accuracy: 300, speed: 5));

        expect(reported, hasLength(2));
        expect(reported.last.accuracy, 300);
      },
    );

    test(
      'starting again (a system restart) waits for a good fix again',
      () async {
        await engine.handleFix(_fix(accuracy: 10));
        expect(reported, hasLength(1));
        engine.stop();

        deviceNow = deviceNow.add(const Duration(minutes: 10));
        await engine.start(_session());
        await engine.handleFix(_fix(accuracy: 300));
        expect(
          reported,
          hasLength(1),
          reason: 'weak fix skipped after restart',
        );

        await engine.handleFix(_fix(accuracy: 20));
        expect(reported, hasLength(2));
      },
    );

    test('a phone clock that is wrong does not stretch the wait', () async {
      engine.stop();
      // The server is 2 hours ahead of the phone.
      await engine.start(_session(offset: const Duration(hours: 2)));

      await engine.handleFix(_fix(accuracy: 300));
      expect(reported, isEmpty);

      deviceNow = deviceNow.add(const Duration(seconds: 31));
      await engine.handleFix(_fix(accuracy: 300));
      expect(reported, hasLength(1));
    });
  });

  group('starting and resuming', () {
    test('tracks the session it is given', () async {
      expect(await engine.start(_session()), isTrue);
      expect(engine.isTracking, isTrue);
      expect(engine.session?.sessionId, 's1');
    });

    test(
      'with nothing given and nothing stored there is nothing to track',
      () async {
        expect(await engine.start(), isFalse);
        expect(engine.isTracking, isFalse);
      },
    );

    test('after a system restart it resumes TODAY\'s stored session', () async {
      await store.saveActiveSession(_session());
      deviceNow = _tenAm.add(const Duration(hours: 5)); // 15:00 IST

      expect(await engine.start(), isTrue);
      expect(engine.session?.sessionId, 's1');
    });

    test('it never resumes an earlier day\'s session; it is cleared', () async {
      await store.saveActiveSession(
        _session(startedAt: _tenAm.subtract(const Duration(days: 1))),
      );

      expect(await engine.start(), isFalse);
      expect(await store.activeSession(), isNull);
    });

    test('it never resumes after the 23:00 IST curfew', () async {
      await store.saveActiveSession(_session());
      deviceNow = DateTime.utc(2026, 10, 17, 17, 31); // 23:01 IST

      expect(await engine.start(), isFalse);
      expect(await store.activeSession(), isNull);
    });

    test(
      'the clock offset is applied: a phone running slow still follows the server',
      () async {
        // Phone says 17:00 IST (11:30 UTC) but the server is 7 hours ahead of
        // that, at 00:00 IST the next day: duty is over, so nothing resumes.
        await store.saveActiveSession(
          _session(offset: const Duration(hours: 7)),
        );
        deviceNow = DateTime.utc(2026, 10, 17, 11, 30);

        expect(await engine.start(), isFalse);
      },
    );
  });

  group('recording points', () {
    setUp(() async => engine.start(_session()));

    test('a point is saved to the phone first, then reported', () async {
      await engine.handleFix(_fix(lat: 20.5, lon: 73.5, speed: 3));

      final saved = await store.nextBatch();
      expect(saved, hasLength(1));
      expect(reported.single.id, saved.single.id);
      expect(saved.single.sessionId, 's1');
      expect(saved.single.latitude, 20.5);
      expect(saved.single.batteryLevel, 80);
    });

    test('its time is the server\'s time, not the raw phone clock', () async {
      engine.stop();
      await engine.start(_session(offset: const Duration(minutes: 10)));

      await engine.handleFix(_fix());

      expect(
        (await store.nextBatch()).single.recordedAt,
        _tenAm.add(const Duration(minutes: 10)),
      );
    });

    test(
      'a mock-location point is recorded and flagged, never dropped',
      () async {
        await engine.handleFix(_fix(mock: true));

        expect((await store.nextBatch()).single.isMock, isTrue);
        expect(stops, isEmpty, reason: 'fake GPS never ends duty (BR-9)');
      },
    );

    test('a failing battery reading does not lose the point', () async {
      engine = TrackerEngine(
        queue: store,
        uploader: uploader,
        isSessionOpen: (_) async => true,
        onPoint: reported.add,
        onStopped: stops.add,
        now: () => deviceNow,
        batteryLevel: () async => throw Exception('no battery info'),
      );
      await engine.start(_session());

      await engine.handleFix(_fix());

      expect((await store.nextBatch()).single.batteryLevel, isNull);
    });

    test('while moving, about every 25 seconds', () async {
      await engine.handleFix(_fix(speed: 2));
      deviceNow = deviceNow.add(const Duration(seconds: 10));
      await engine.handleFix(_fix(speed: 2));
      expect(await store.pendingPointCount(), 1, reason: 'too soon');

      deviceNow = deviceNow.add(const Duration(seconds: 15));
      await engine.handleFix(_fix(speed: 2));
      expect(await store.pendingPointCount(), 2);
    });

    test('standing still, only every 3 minutes', () async {
      await engine.handleFix(_fix(speed: 0));
      deviceNow = deviceNow.add(const Duration(seconds: 60));
      await engine.handleFix(_fix(speed: 0));
      deviceNow = deviceNow.add(const Duration(seconds: 100));
      await engine.handleFix(_fix(speed: 0));
      expect(await store.pendingPointCount(), 1);

      deviceNow = deviceNow.add(const Duration(seconds: 25));
      await engine.handleFix(_fix(speed: 0));
      expect(await store.pendingPointCount(), 2, reason: '3 minutes passed');
    });

    test(
      'moving 25 m or more counts as moving even with no speed reading',
      () async {
        await engine.handleFix(_fix(lat: 20.0));
        deviceNow = deviceNow.add(const Duration(seconds: 30));
        await engine.handleFix(_fix(lat: 20.0003)); // about 33 m north

        expect(await store.pendingPointCount(), 2);
      },
    );

    test('nothing is recorded once stopped', () async {
      engine.stop();

      await engine.handleFix(_fix());

      expect(await store.pendingPointCount(), 0);
      expect(reported, isEmpty);
    });
  });

  group('stopping by itself', () {
    setUp(() async {
      await store.saveActiveSession(_session());
      await engine.start();
    });

    test('at 23:00 IST, even if the server cannot be reached', () async {
      deviceNow = DateTime.utc(2026, 10, 17, 17, 30); // 23:00 IST

      await engine.tick();

      expect(stops, [TrackerStopReason.curfew]);
      expect(engine.isTracking, isFalse);
      expect(await store.activeSession(), isNull);

      await engine.handleFix(_fix());
      expect(await store.pendingPointCount(), 0);
    });

    test('before 23:00 it keeps going', () async {
      deviceNow = DateTime.utc(2026, 10, 17, 17, 29); // 22:59 IST

      await engine.tick();

      expect(stops, isEmpty);
      expect(engine.isTracking, isTrue);
    });

    test(
      'when the server refused points AND confirms the session is closed',
      () async {
        uploader.lastOutcome = const UploadOutcome(refusedSessionIds: {'s1'});
        sessionStillOpen = false;

        await engine.tick();

        expect(stops, [TrackerStopReason.sessionClosedByServer]);
        expect(await store.activeSession(), isNull);
      },
    );

    test(
      'a refusal alone is not enough (a wrong phone clock can cause one)',
      () async {
        uploader.lastOutcome = const UploadOutcome(refusedSessionIds: {'s1'});
        sessionStillOpen = true;

        await engine.tick();

        expect(stops, isEmpty);
        expect(engine.isTracking, isTrue);
      },
    );

    test('if the server cannot be asked, tracking continues', () async {
      uploader.lastOutcome = const UploadOutcome(refusedSessionIds: {'s1'});
      openCheckFails = Exception('offline');

      await engine.tick();

      expect(stops, isEmpty);
      expect(engine.isTracking, isTrue);
    });

    test(
      'an expired sign-in is reported once per streak, not every check',
      () async {
        uploader.lastOutcome = const UploadOutcome(
          queueEmpty: false,
          failure: UnauthorizedRoleException(),
        );

        await engine.tick();
        await engine.tick();
        expect(notices, [TrackerNotice.needsSignIn]);
        expect(engine.isTracking, isTrue, reason: 'points keep being recorded');

        uploader.lastOutcome = const UploadOutcome();
        await engine.tick();
        uploader.lastOutcome = const UploadOutcome(
          queueEmpty: false,
          failure: UnauthorizedRoleException(),
        );
        await engine.tick();

        expect(notices, hasLength(2), reason: 'a new streak is reported again');
      },
    );

    test('a refusal about some other session is ignored', () async {
      uploader.lastOutcome = const UploadOutcome(refusedSessionIds: {'old'});
      sessionStillOpen = false;

      await engine.tick();

      expect(stops, isEmpty);
    });
  });
}
