import 'dart:io';

import 'package:diamond_tracking/features/tracking/data/tracker_files.dart';
import 'package:diamond_tracking/features/tracking/domain/phone_off.dart';
import 'package:diamond_tracking/features/tracking/domain/track_break.dart';
import 'package:diamond_tracking/features/tracking/domain/track_fix.dart';
import 'package:diamond_tracking/features/tracking/domain/tracker_status.dart';
import 'package:diamond_tracking/features/tracking/domain/tracking_session.dart';
import 'package:diamond_tracking/features/tracking/engine/tracker_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_uploader.dart';

class FakeSystem implements SystemInfo {
  Duration up = const Duration(hours: 5);
  String? boot = 'boot-a';

  @override
  Duration uptime() => up;

  @override
  String? bootId() => boot;
}

void main() {
  // 7:00 AM IST duty on; 11:00 PM IST is 17:30 UTC.
  final DateTime dutyOn = DateTime.utc(2026, 11, 20, 1, 30);
  final DateTime autoOff = DateTime.utc(2026, 11, 20, 17, 30);
  final TrackingSession session = TrackingSession(
    dayId: 7,
    pass: 'pass7',
    dutyOnAt: dutyOn,
    autoOffAt: autoOff,
  );

  late Directory dir;
  late TrackerFiles files;
  late FakeUploader up;
  late FakeSystem system;
  late DateTime now;
  late List<int> warnings;
  late TrackerEngine engine;

  TrackerEngine newEngine() => TrackerEngine(
    files: files,
    uploader: up,
    now: () => now,
    system: system,
    onBatteryWarning: warnings.add,
  );

  setUp(() {
    dir = Directory.systemTemp.createTempSync('engine_test');
    files = TrackerFiles(dir);
    up = FakeUploader();
    system = FakeSystem();
    now = dutyOn.add(const Duration(minutes: 1));
    warnings = <int>[];
    files.writeSession(session);
    engine = newEngine();
  });
  tearDown(() => dir.deleteSync(recursive: true));

  TrackFix fixAt(DateTime t, double northM) => TrackFix(
    time: t,
    latitude: 22.5 + northM / 111195,
    longitude: 88.3,
    accuracyM: 8,
  );

  test('records, uploads, and keeps tracking during the duty', () async {
    expect(await engine.start(), TrackerMode.tracking);
    engine.onFix(fixAt(now, 0));
    now = now.add(const Duration(minutes: 1));
    engine.onFix(fixAt(now, 100));
    expect(await engine.tick(batteryLevel: 80), TrackerMode.tracking);
    expect(up.pointCount, 2);
    expect(up.pointCalls.first.first['la'], 22500000);
    expect(engine.pendingCount, 0);
    expect(files.readState().heartbeat?.at, now);
  });

  test('a wrong phone clock does not move the points', () async {
    await engine.start();
    // The phone stamps the fix with its own (wrong) clock.
    engine.onFix(fixAt(now.add(const Duration(hours: 2)), 0));
    await engine.tick();
    expect(up.pointCalls.single.single['t'], now.toIso8601String());
  });

  test(
    'a fix with the right satellite time is not moved twice (L43)',
    () async {
      await engine.start();
      // The fix already carries the right time; whatever the phone's own clock
      // says, the point keeps the trusted time.
      engine.onFix(fixAt(now, 0));
      await engine.tick();
      expect(up.pointCalls.single.single['t'], now.toIso8601String());
    },
  );

  test('offline: points wait on the phone, then go up', () async {
    await engine.start();
    up.offline = true;
    engine.onFix(fixAt(now, 0));
    expect(await engine.tick(), TrackerMode.tracking);
    expect(engine.isOffline, isTrue);
    expect(engine.pendingCount, 1);
    up.offline = false;
    now = now.add(const Duration(minutes: 1));
    await engine.tick();
    expect(up.pointCount, 1);
    expect(engine.isOffline, isFalse);
  });

  test(
    'a password reset: points are kept, then sent with the new pass',
    () async {
      await engine.start();
      up.reject = true;
      engine.onFix(fixAt(now, 0));
      await engine.tick();
      expect(engine.pendingCount, 1);
      expect(files.readState().refusedPass, 'pass7');

      // Not asked again with the same pass.
      final int calls = up.pointCalls.length;
      now = now.add(const Duration(minutes: 1));
      engine.onFix(fixAt(now, 50));
      await engine.tick();
      expect(engine.pendingCount, 2);
      expect(up.pointCalls.length, calls);

      // The app got a new pass.
      up.reject = false;
      files.writeSession(
        TrackingSession(
          dayId: 7,
          pass: 'pass7b',
          dutyOnAt: dutyOn,
          autoOffAt: autoOff,
        ),
      );
      now = now.add(const Duration(minutes: 1));
      await engine.tick();
      expect(up.pointCount, 2);
      expect(up.passes.toSet(), <String>{'pass7b'});
      expect(engine.pendingCount, 0);
      expect(files.readState().refusedPass, isNull);
    },
  );

  test(
    'refused points are held after the duty, and the tracker stops (L13)',
    () async {
      await engine.start();
      up.reject = true;
      engine.onFix(fixAt(now, 0));
      await engine.tick();
      expect(engine.pendingCount, 1);
      now = autoOff.add(const Duration(minutes: 1));
      expect(await engine.tick(), TrackerMode.stop);
      expect(engine.pendingCount, 0);
      expect(files.queue.heldCount, 1);
    },
  );

  test('a fix from a fake-location app is sent with the fake mark', () async {
    await engine.start();
    engine.onFix(fixAt(now, 0));
    now = now.add(const Duration(minutes: 1));
    engine.onFix(
      TrackFix(
        time: now,
        latitude: 22.5 + 500 / 111195,
        longitude: 88.3,
        accuracyM: 8,
        mocked: true,
      ),
    );
    await engine.tick();
    final List<Map<String, Object?>> sent = <Map<String, Object?>>[
      for (final List<Map<String, Object?>> c in up.pointCalls) ...c,
    ];
    expect(sent, hasLength(2));
    expect(sent[0].containsKey('m'), isFalse);
    expect(sent[1]['m'], isTrue);
  });

  test('after a phone restart the off time is recorded', () async {
    files.writeState(
      TrackerState(
        heartbeat: Heartbeat(
          dayId: 7,
          at: now,
          uptime: const Duration(hours: 5),
          bootId: 'boot-a',
        ),
      ),
    );
    final DateTime offAt = now;
    now = now.add(const Duration(hours: 1));
    system
      ..up = const Duration(minutes: 3)
      ..boot = 'boot-b';
    expect(await newEngine().start(), TrackerMode.tracking);
    expect(
      up.breaks.single,
      TrackBreak(
        from: offAt,
        to: now.subtract(const Duration(minutes: 3)),
        kind: TrackBreakKind.phoneOff,
      ),
    );
  });

  test('stops recording at 11 PM, sends what is left, then stops', () async {
    await engine.start();
    engine.onFix(fixAt(now, 0));
    up.offline = true;
    now = autoOff;
    engine.onFix(fixAt(now, 500));
    expect(await engine.tick(), TrackerMode.finishing);
    up.offline = false;
    expect(await engine.tick(), TrackerMode.stop);
    expect(up.pointCount, 1, reason: 'the 11 PM fix is outside the duty');
  });

  test('a phone restart after 11 PM still records the off time', () async {
    files.writeState(
      TrackerState(
        heartbeat: Heartbeat(
          dayId: 7,
          at: autoOff.subtract(const Duration(hours: 1)),
          uptime: const Duration(hours: 5),
          bootId: 'boot-a',
        ),
      ),
    );
    now = autoOff.add(const Duration(hours: 8));
    system
      ..up = const Duration(minutes: 2)
      ..boot = 'boot-b';
    expect(await newEngine().start(), TrackerMode.stop);
    expect(up.breaks.single.kind, TrackBreakKind.phoneOff);
  });

  test('duty off online: send the rest, then stop', () async {
    await engine.start();
    engine.onFix(fixAt(now, 0));
    files.writeSession(session.withDutyOff(now, confirmed: true));
    expect(await engine.tick(), TrackerMode.stop);
    expect(up.pointCount, 1);
    expect(up.dutyOffs, isEmpty);
  });

  test('duty off offline: the tracker sends it when online', () async {
    await engine.start();
    final DateTime offAt = now;
    files.writeSession(session.withDutyOff(offAt, confirmed: false));
    up.offline = true;
    expect(await engine.tick(), TrackerMode.finishing);
    up.offline = false;
    expect(await engine.tick(), TrackerMode.stop);
    expect(up.dutyOffs, <DateTime>[offAt]);
    expect(await engine.tick(), TrackerMode.stop);
    expect(up.dutyOffs, hasLength(1), reason: 'sent once');
  });

  test('ignores fixes after duty off', () async {
    await engine.start();
    files.writeSession(session.withDutyOff(now, confirmed: true));
    await engine.tick();
    engine.onFix(fixAt(now.add(const Duration(minutes: 1)), 0));
    expect(engine.pendingCount, 0);
  });

  test('battery warnings once each, lowest when it drops fast', () async {
    await engine.start();
    await engine.tick(batteryLevel: 21);
    await engine.tick(batteryLevel: 20);
    await engine.tick(batteryLevel: 19);
    await engine.tick(batteryLevel: 9);
    await engine.tick(batteryLevel: 14);
    expect(warnings, <int>[20, 10]);
    // Remembered across a service restart.
    await newEngine().tick(batteryLevel: 8);
    expect(warnings, <int>[20, 10]);
  });

  group('GPS watchdog and reasons', () {
    /// Ticks once a minute for [minutes] minutes; returns the minutes at
    /// which the engine asked for a GPS restart.
    Future<List<int>> tickFor(int minutes) async {
      final List<int> restarts = <int>[];
      for (int i = 1; i <= minutes; i++) {
        now = now.add(const Duration(minutes: 1));
        await engine.tick();
        if (engine.takeGpsRestart()) restarts.add(i);
      }
      return restarts;
    }

    test('silent GPS: restarted every 5 min, the reason is sent', () async {
      await engine.start();
      final DateTime lastFix = now;
      engine.onFix(fixAt(now, 0));
      expect(await tickFor(20), <int>[5, 10, 15, 20]);
      engine.onFix(fixAt(now, 0));
      await engine.tick();
      expect(up.breaks, <TrackBreak>[
        TrackBreak(from: lastFix, to: now, kind: TrackBreakKind.gpsSilent),
      ]);
      expect(await tickFor(4), isEmpty, reason: 'positions came back');
    });

    test('a short silence restarts GPS but needs no reason', () async {
      await engine.start();
      engine.onFix(fixAt(now, 0));
      expect(await tickFor(8), <int>[5]);
      engine.onFix(fixAt(now, 0));
      await engine.tick();
      expect(up.breaks, isEmpty);
    });

    test('no fix at all since the tracker started is silence too', () async {
      await engine.start();
      expect(await tickFor(6), <int>[5]);
    });

    test('a frozen tracker is reported as tracking stopped', () async {
      await engine.start();
      engine.onFix(fixAt(now, 0));
      await tickFor(1);
      final DateTime frozenAt = now;
      now = now.add(const Duration(minutes: 25));
      system.up += const Duration(minutes: 25);
      await engine.tick();
      expect(up.breaks.single.kind, TrackBreakKind.trackingStopped);
      expect(up.breaks.single.from, frozenAt);
      expect(engine.takeGpsRestart(), isFalse, reason: 'silence starts again');
      engine.onFix(fixAt(now, 0));
      await engine.tick();
      expect(up.breaks, hasLength(1), reason: 'no GPS-silent note on top');
    });

    test('a clock correction is not a freeze', () async {
      await engine.start();
      engine.onFix(fixAt(now, 0));
      await tickFor(1);
      // The server time moved the clock 25 minutes; the phone's uptime
      // moved one minute.
      now = now.add(const Duration(minutes: 25));
      system.up += const Duration(minutes: 1);
      await engine.tick();
      expect(up.breaks, isEmpty);
    });

    test('location off: the time it was off is the reason', () async {
      await engine.start();
      engine.onFix(fixAt(now, 0));
      await tickFor(1);
      final DateTime offAt = now;
      engine.onProblem(TrackerProblem.locationOff);
      expect(await tickFor(30), isEmpty, reason: 'no restart while off');
      engine.onProblem(null);
      await engine.tick();
      expect(up.breaks, <TrackBreak>[
        TrackBreak(from: offAt, to: now, kind: TrackBreakKind.locationOff),
      ]);
      expect(await tickFor(4), isEmpty, reason: 'silence measured from now');
    });

    test('permission taken during silence: counted from the silence', () async {
      await engine.start();
      final DateTime lastFix = now;
      engine.onFix(fixAt(now, 0));
      await tickFor(6);
      engine.onProblem(TrackerProblem.permissionOff);
      await tickFor(20);
      engine.onProblem(null);
      await engine.tick();
      expect(up.breaks.single.kind, TrackBreakKind.permissionOff);
      expect(up.breaks.single.from, lastFix);
    });

    test('a reason still open at duty off ends at duty off', () async {
      await engine.start();
      engine.onFix(fixAt(now, 0));
      await tickFor(1);
      final DateTime offAt = now;
      engine.onProblem(TrackerProblem.locationOff);
      now = autoOff.add(const Duration(minutes: 2));
      // Tick each minute would be the real case; a jump is enough here.
      expect(await engine.tick(), TrackerMode.stop);
      expect(
        up.breaks.last,
        TrackBreak(from: offAt, to: autoOff, kind: TrackBreakKind.locationOff),
      );
    });
  });

  test('no session: nothing to do', () async {
    files.deleteSession();
    expect(await newEngine().start(), TrackerMode.stop);
  });
}
