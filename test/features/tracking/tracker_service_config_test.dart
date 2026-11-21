import 'package:diamond_tracking/features/tracking/service/tracker_service_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the clock is read every minute until the first read works (L44)', () {
    for (int tick = 1; tick <= 5; tick++) {
      expect(TrackerServiceConfig.clockSyncDue(tick, synced: false), isTrue);
    }
  });

  test('once read, the clock is read again every 30 minutes', () {
    expect(TrackerServiceConfig.clockSyncDue(1, synced: true), isFalse);
    expect(TrackerServiceConfig.clockSyncDue(29, synced: true), isFalse);
    expect(TrackerServiceConfig.clockSyncDue(30, synced: true), isTrue);
    expect(TrackerServiceConfig.clockSyncDue(60, synced: true), isTrue);
  });
}
