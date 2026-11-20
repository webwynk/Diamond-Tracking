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

  test('a refused batch is dropped, not retried forever', () async {
    queue.addPoint(1, 'old', point(0));
    up.reject = true;
    final DrainResult r = await queue.drain(up);
    expect(r.dropped, 1);
    expect(queue.isEmpty, isTrue);
  });

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

  test('a line cut short by a crash is skipped', () async {
    queue.addPoint(1, 'p', point(0));
    File('${dir.path}/q/open.jsonl')
        .writeAsStringSync('{"t": "2026-11', mode: FileMode.append);
    expect(queue.pendingCount, 1);
    await queue.drain(up);
    expect(up.pointCount, 1);
  });
}
