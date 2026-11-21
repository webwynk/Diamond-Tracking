import 'package:diamond_tracking/core/time/ist.dart';
import 'package:diamond_tracking/core/time/ist_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('IST is UTC+05:30 whatever the phone zone is', () {
    final DateTime instant = DateTime.utc(
      2026,
      11,
      19,
      23,
      45,
    ); // 05:15 IST next day
    final DateTime wall = Ist.wallClock(instant);
    expect(wall, DateTime.utc(2026, 11, 20, 5, 15));
    expect(Ist.dateOf(instant), DateTime.utc(2026, 11, 20));
    expect(Ist.minuteOfDay(instant), 5 * 60 + 15);
  });

  test('instantAt is the inverse of wallClock', () {
    final DateTime instant = Ist.instantAt(2026, 11, 20, 23);
    expect(instant, DateTime.utc(2026, 11, 20, 17, 30));
    expect(Ist.wallClock(instant), DateTime.utc(2026, 11, 20, 23));
  });

  test('a local DateTime is read by its instant, not its fields', () {
    final DateTime local = DateTime.utc(2026, 1, 1, 0, 0).toLocal();
    expect(Ist.minuteOfDay(local), 5 * 60 + 30);
  });

  test('dayDate is the weekday and date in India', () {
    // 20 Nov 2026, 11:00 PM UTC is already Saturday 21 Nov in India.
    expect(
      IstFormat.dayDate(DateTime.utc(2026, 11, 20, 23)),
      'Saturday, 21 Nov',
    );
  });
}
