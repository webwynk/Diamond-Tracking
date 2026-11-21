import 'package:diamond_tracking/features/tracking/domain/tracker_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a status survives the trip from the service to the app', () {
    final TrackerStatus status = TrackerStatus(
      pendingPoints: 214,
      offline: true,
      problem: TrackerProblem.locationOff,
      problemSince: DateTime.utc(2026, 11, 21, 5, 35),
    );
    expect(TrackerStatus.fromMessage(status.toMessage()), status);
  });

  test('a status without a problem has no time', () {
    final TrackerStatus? read = TrackerStatus.fromMessage(<String, Object>{
      'status': true,
      'pending': 3,
      'offline': false,
      'since': 1,
    });
    expect(read, const TrackerStatus(pendingPoints: 3));
  });

  test('other messages are not a status', () {
    expect(TrackerStatus.fromMessage('stopped'), isNull);
    expect(TrackerStatus.fromMessage(<String, Object>{'battery': 15}), isNull);
  });

  test('bad values are read safely', () {
    final TrackerStatus? read = TrackerStatus.fromMessage(<String, Object>{
      'status': true,
      'pending': -4,
      'problem': 'unknown',
    });
    expect(read, const TrackerStatus());
  });
}
