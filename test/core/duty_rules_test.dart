import 'package:diamond_tracking/core/rules/duty_rules.dart';
import 'package:diamond_tracking/core/time/ist.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime ist(int h, int m, {int day = 20}) =>
    Ist.instantAt(2026, 11, day, h, m);

void main() {
  group('duty on window 05:00 to 08:30 IST', () {
    test(
      'closed before 05:00',
      () => expect(DutyRules.canDutyOn(ist(4, 59)), isFalse),
    );
    test('open at 05:00', () => expect(DutyRules.canDutyOn(ist(5, 0)), isTrue));
    test(
      'open at 08:30',
      () => expect(DutyRules.canDutyOn(ist(8, 30)), isTrue),
    );
    test(
      'closed at 08:31',
      () => expect(DutyRules.canDutyOn(ist(8, 31)), isFalse),
    );
    test(
      'closed in the evening',
      () => expect(DutyRules.canDutyOn(ist(18, 0)), isFalse),
    );
  });

  test('auto duty off is 23:00 IST on the duty day', () {
    expect(DutyRules.autoDutyOffFor(ist(5, 10)), ist(23, 0));
  });

  group('10 hour minimum', () {
    test('9h59 is short', () {
      expect(DutyRules.meetsMinimum(ist(7, 0), ist(16, 59)), isFalse);
    });
    test('exactly 10h is enough', () {
      expect(DutyRules.meetsMinimum(ist(7, 0), ist(17, 0)), isTrue);
    });
  });

  group('attendance request: today and 7 days back', () {
    final DateTime now = ist(10, 0);
    test('today', () {
      expect(
        DutyRules.canRequestAttendanceFor(DateTime.utc(2026, 11, 20), now),
        isTrue,
      );
    });
    test('7 days ago', () {
      expect(
        DutyRules.canRequestAttendanceFor(DateTime.utc(2026, 11, 13), now),
        isTrue,
      );
    });
    test('8 days ago', () {
      expect(
        DutyRules.canRequestAttendanceFor(DateTime.utc(2026, 11, 12), now),
        isFalse,
      );
    });
    test('tomorrow', () {
      expect(
        DutyRules.canRequestAttendanceFor(DateTime.utc(2026, 11, 21), now),
        isFalse,
      );
    });
    test('just after midnight IST counts the new day', () {
      // 00:10 IST on 21 Nov is still 20 Nov in UTC.
      final DateTime earlyMorning = ist(0, 10, day: 21);
      expect(
        DutyRules.canRequestAttendanceFor(
          DateTime.utc(2026, 11, 13),
          earlyMorning,
        ),
        isFalse,
      );
      expect(
        DutyRules.canRequestAttendanceFor(
          DateTime.utc(2026, 11, 14),
          earlyMorning,
        ),
        isTrue,
      );
    });
  });

  group('battery warnings at 20, 15, 10', () {
    test(
      'none above 20',
      () => expect(DutyRules.batteryWarningFor(21, <int>{}), isNull),
    );
    test(
      '20 at 20',
      () => expect(DutyRules.batteryWarningFor(20, <int>{}), 20),
    );
    test(
      'not twice',
      () => expect(DutyRules.batteryWarningFor(19, <int>{20}), isNull),
    );
    test(
      '15 next',
      () => expect(DutyRules.batteryWarningFor(15, <int>{20}), 15),
    );
    test('a big drop shows only the lowest', () {
      expect(DutyRules.batteryWarningFor(9, <int>{}), 10);
      expect(DutyRules.thresholdsReached(9), <int>{20, 15, 10});
    });
  });
}
