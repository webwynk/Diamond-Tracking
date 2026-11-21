import 'package:diamond_tracking/features/duty/domain/duty_day.dart';
import 'package:diamond_tracking/features/routes/domain/history_month.dart';
import 'package:flutter_test/flutter_test.dart';

DutyDay _day(int id, DateTime date, DayStatus status) =>
    DutyDay(id: id, userId: 'u', day: date, status: status);

void main() {
  final DateTime today = DateTime.utc(2026, 11, 21);
  final DateTime earliest = today.subtract(const Duration(days: 90));
  final List<DutyDay> all = <DutyDay>[
    _day(1, DateTime.utc(2026, 11, 3), DayStatus.present),
    _day(2, DateTime.utc(2026, 11, 4), DayStatus.present),
    _day(3, DateTime.utc(2026, 11, 5), DayStatus.halfDay),
    _day(4, DateTime.utc(2026, 11, 6), DayStatus.leave),
    _day(5, DateTime.utc(2026, 10, 30), DayStatus.present),
  ];

  test('Days counted is present plus half of each half day, no leave', () {
    final HistoryMonth m = HistoryMonth.of(
      DateTime.utc(2026, 11),
      all,
      today: today,
      earliest: earliest,
    );
    expect(m.daysCounted, 2.5);
    expect(formatDaysCounted(m.daysCounted), '2.5');
    expect(m.count(DayStatus.leave), 1);
    expect(m.days.first.id, 4, reason: 'newest first');
    expect(m.days.any((DutyDay d) => d.id == 5), isFalse);
  });

  test('the current month stops at today; every day counts', () {
    final HistoryMonth m = HistoryMonth.of(
      DateTime.utc(2026, 11),
      all,
      today: today,
      earliest: earliest,
    );
    expect(m.calendarDays, 21);
  });

  test('months run newest first across the 90 days', () {
    final List<DateTime> months = HistoryMonth.monthsBetween(earliest, today);
    expect(months.first, DateTime.utc(2026, 11));
    expect(months.last, DateTime.utc(2026, 8));
  });

  test('a whole number shows without a decimal', () {
    expect(formatDaysCounted(16), '16');
  });
}
