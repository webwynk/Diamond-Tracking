import 'dart:io';

import 'package:diamond_tracking/features/tracking/application/tracker_control.dart';
import 'package:diamond_tracking/features/tracking/data/tracker_files.dart';
import 'package:diamond_tracking/features/tracking/domain/tracking_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // 7:00 AM IST duty on; 11:00 PM IST is 17:30 UTC.
  final DateTime dutyOn = DateTime.utc(2026, 11, 20, 1, 30);
  final DateTime autoOff = DateTime.utc(2026, 11, 20, 17, 30);
  late Directory dir;
  late TrackerFiles files;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('unsent_work_test');
    files = TrackerFiles(dir)
      ..writeSession(
        TrackingSession(
          dayId: 7,
          pass: 'pass7',
          dutyOnAt: dutyOn,
          autoOffAt: autoOff,
        ),
      );
  });
  tearDown(() => dir.deleteSync(recursive: true));

  test('logout waits during duty by the trusted clock (L47)', () {
    // 6:00 PM IST by the server, even if the phone says 11:30 PM.
    expect(unsentWorkIn(files, DateTime.utc(2026, 11, 20, 12, 30)), isTrue);
  });

  test('after 11:00 PM by the trusted clock, logout is allowed', () {
    // 11:30 PM IST by the server, even if the phone says 6:00 PM.
    expect(unsentWorkIn(files, DateTime.utc(2026, 11, 20, 18)), isFalse);
  });
}
