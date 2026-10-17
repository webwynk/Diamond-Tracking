import 'package:diamond_tracking/core/utils/duty_time_helper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(
    'istDayStartUtc: an IST day as the UTC instant the server is asked for',
    () {
      test('is 18:30 UTC the evening before', () {
        expect(
          DutyTimeHelper.istDayStartUtc(DateTime(2026, 10, 17)),
          DateTime.utc(2026, 10, 16, 18, 30),
        );
      });

      test('ignores the time of day on the date it is given', () {
        expect(
          DutyTimeHelper.istDayStartUtc(DateTime(2026, 10, 17, 23, 59, 59)),
          DutyTimeHelper.istDayStartUtc(DateTime(2026, 10, 17)),
        );
      });

      test(
        'a month is the first day of it, and its end the first of the next',
        () {
          expect(
            DutyTimeHelper.istDayStartUtc(DateTime(2026, 10)),
            DateTime.utc(2026, 9, 30, 18, 30),
          );
          expect(
            DutyTimeHelper.istDayStartUtc(DateTime(2026, 11)),
            DateTime.utc(2026, 10, 31, 18, 30),
          );
        },
      );

      test('rolls over month and year ends the way DateTime does', () {
        expect(
          DutyTimeHelper.istDayStartUtc(DateTime(2026, 12, 32)),
          DateTime.utc(2026, 12, 31, 18, 30),
        );
        expect(
          DutyTimeHelper.istDayStartUtc(DateTime(2026, 13)),
          DateTime.utc(2026, 12, 31, 18, 30),
        );
      });

      test('the day before the first is the last of the month before', () {
        expect(
          DutyTimeHelper.istDayStartUtc(DateTime(2026, 10, 0)),
          DateTime.utc(2026, 9, 29, 18, 30),
        );
      });

      test('two following days are exactly 24 hours apart', () {
        final first = DutyTimeHelper.istDayStartUtc(DateTime(2026, 3, 28));
        final next = DutyTimeHelper.istDayStartUtc(DateTime(2026, 3, 29));

        expect(next.difference(first), const Duration(hours: 24));
      });

      test('is a UTC instant', () {
        expect(
          DutyTimeHelper.istDayStartUtc(DateTime(2026, 10, 17)).isUtc,
          isTrue,
        );
      });
    },
  );
}
