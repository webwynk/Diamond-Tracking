import 'dart:io';

import 'package:diamond_tracking/features/tracking/data/point_queue.dart';
import 'package:diamond_tracking/features/tracking/domain/track_break.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_uploader.dart';

void main() {
  late Directory dir;
  late PointQueue queue;
  late FakeUploader up;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('queue_test');
    queue = PointQueue(Directory('${dir.path}/q'));
    up = FakeUploader();
  });
  tearDown(() => dir.deleteSync(recursive: true));

  Map<String, Object?> point(int i) => <String, Object?>{
    't': DateTime.utc(2026, 11, 20, 2, i).toIso8601String(),
    'la': 22500000 + i,
    'lo': 88300000,
    'a': 8,
  };

  test('queues points and breaks, uploads them, then is empty', () async {
    queue.addPoint(1, 'pass1', point(0));
    queue.addPoint(1, 'pass1', point(1));
    queue.addBreak(
      1,
      'pass1',
      TrackBreak(
        from: DateTime.utc(2026, 11, 20, 3),
        to: DateTime.utc(2026, 11, 20, 4),
        kind: TrackBreakKind.phoneOff,
      ),
    );
    expect(queue.pendingCount, 3);

    final DrainResult r = await queue.drain(up);
    expect(r.sent, 3);
    expect(up.pointCount, 2);
    expect(up.breaks.single.kind, TrackBreakKind.phoneOff);
    expect(queue.pendingCount, 0);
  });

  test('keeps everything when offline, sends it later', () async {
    queue.addPoint(1, 'pass1', point(0));
    up.offline = true;
    final DrainResult r = await queue.drain(up);
    expect(r.failed, isTrue);
    queue.addPoint(1, 'pass1', point(1));
    expect(queue.pendingCount, 2);

    up.offline = false;
    await queue.drain(up);
    expect(up.pointCount, 2);
    expect(queue.isEmpty, isTrue);
  });

  test('a new day or pass starts a new batch with its own pass', () async {
    queue.addPoint(1, 'pass1', point(0));
    queue.addPoint(2, 'pass2', point(1));
    await queue.drain(up);
    expect(up.passes, <String>['pass1', 'pass2']);
  });

  test(
    'a batch refused for its pass waits 2 days, then is dropped (L13)',
    () async {
      queue.addPoint(1, 'old', point(0));
      up.reject = true;
      DrainResult r = await queue.drain(up);
      expect(r.waiting, 1);
      expect(r.dropped, 0);
      // Held, not counted as waiting work (the tracker can stop, and logging
      // out is not blocked).
      expect(queue.pendingCount, 0);
      expect(queue.heldCount, 1);

      // Two days later it is no longer worth keeping.
      r = await queue.drain(
        up,
        now: () => DateTime.now().add(const Duration(days: 2, minutes: 1)),
      );
      expect(r.dropped, 1);
      expect(queue.heldCount, 0);
    },
  );

  test('a waiting batch goes up once the pass works again (L13)', () async {
    queue.addPoint(1, 'old', point(0));
    up.reject = true;
    await queue.drain(up);
    // Signed in again on the same phone: the same pass is accepted.
    up.reject = false;
    final DrainResult r = await queue.drain(up);
    expect(r.sent, 1);
    expect(up.passes, <String>['old']);
    expect(queue.isEmpty, isTrue);
    expect(queue.heldCount, 0);
  });

  test('a waiting batch does not hold up the others (L13)', () async {
    queue.addPoint(1, 'old', point(0));
    queue.addPoint(2, 'good', point(1));
    up.rejectPass = 'old';
    final DrainResult r = await queue.drain(up);
    expect(r.waiting, 1);
    expect(r.sent, 1);
    expect(up.passes, <String>['good']);
    expect(queue.heldCount, 1);
  });

  test('a batch refused for another reason is dropped at once', () async {
    queue.addPoint(1, 'p', point(0));
    up.rejectReason = 'duty_not_found';
    final DrainResult r = await queue.drain(up);
    expect(r.dropped, 1);
    expect(queue.isEmpty, isTrue);
  });

  test('points of the running duty wait when the pass is refused', () async {
    queue.addPoint(1, 'old', point(0));
    up.reject = true;
    final DrainResult r = await queue.drain(
      up,
      passFor: (int day) => day == 1 ? 'old' : null,
      keepOnRefusedPass: true,
    );
    expect(r.passRefused, isTrue);
    expect(r.dropped, 0);
    expect(queue.pendingCount, 1);
  });

  test('kept points go up with the new pass', () async {
    queue.addPoint(1, 'old', point(0));
    up.reject = true;
    await queue.drain(
      up,
      passFor: (int day) => day == 1 ? 'old' : null,
      keepOnRefusedPass: true,
    );
    up.reject = false;
    final DrainResult r = await queue.drain(
      up,
      passFor: (int day) => day == 1 ? 'new' : null,
      keepOnRefusedPass: true,
    );
    expect(r.sent, 1);
    expect(up.passes, <String>['new']);
    expect(queue.isEmpty, isTrue);
  });

  test(
    'a refused batch of another day waits without stopping the drain',
    () async {
      queue.addPoint(1, 'old', point(0));
      up.reject = true;
      final DrainResult r = await queue.drain(
        up,
        passFor: (int day) => day == 2 ? 'x' : null,
        keepOnRefusedPass: true,
      );
      expect(r.waiting, 1);
      expect(r.dropped, 0);
      expect(r.passRefused, isFalse);
    },
  );

  test('big backlogs go in chunks the server accepts', () async {
    for (int i = 0; i < 950; i++) {
      queue.addPoint(1, 'p', point(i % 600));
    }
    await queue.drain(up);
    expect(up.pointCalls.map((List<Map<String, Object?>> c) => c.length), <int>[
      400,
      400,
      150,
    ]);
  });

  test('the count stays right as batches come and go (L46)', () async {
    final PointQueue other = PointQueue(Directory('${dir.path}/q'));
    up.offline = true;
    for (int i = 0; i < 5; i++) {
      queue.addPoint(1, 'pass1', point(i));
      await queue.drain(up); // offline: seals a batch, sends nothing
    }
    queue.addPoint(1, 'pass1', point(5)); // still in the open file
    expect(queue.pendingCount, 6);
    // Another reader of the same folder (the app beside the tracker).
    expect(other.pendingCount, 6);

    up.offline = false;
    await queue.drain(up);
    expect(queue.pendingCount, 0);
    expect(other.pendingCount, 0);

    queue.addPoint(1, 'pass1', point(6));
    expect(other.pendingCount, 1);
    queue.clear();
    expect(queue.pendingCount, 0);
  });

  test('a line cut short by a crash is skipped', () async {
    queue.addPoint(1, 'p', point(0));
    File('${dir.path}/q/open.jsonl')
        .writeAsStringSync('{"t": "2026-11', mode: FileMode.append);
    expect(queue.pendingCount, 1);
    await queue.drain(up);
    expect(up.pointCount, 1);
  });
}
