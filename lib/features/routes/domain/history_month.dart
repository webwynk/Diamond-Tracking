import '../../duty/domain/duty_day.dart';

/// A full day: 10 hours or more on duty. The admin's review usually marks it
/// Present; shorter days usually Half day.
const Duration fullDay = Duration(hours: 10);

/// One month of the History tab (design v2): the days in it, the counts by
/// status, and "Days counted" (Present + half of each Half day; leave is
/// not counted, owner's decision 2026-11-21).
class HistoryMonth {
  HistoryMonth._({
    required this.month,
    required this.from,
    required this.to,
    required this.days,
  });

  /// The month of [month] (any day in it), cut to the [earliest] and
  /// [today] IST dates. [all] are the person's days, any order.
  factory HistoryMonth.of(
    DateTime month,
    List<DutyDay> all, {
    required DateTime today,
    required DateTime earliest,
  }) {
    final DateTime first = DateTime.utc(month.year, month.month);
    final DateTime last = DateTime.utc(month.year, month.month + 1, 0);
    final DateTime from = first.isBefore(earliest) ? earliest : first;
    final DateTime to = last.isAfter(today) ? today : last;
    final List<DutyDay> days =
        all
            .where((DutyDay d) => !d.day.isBefore(from) && !d.day.isAfter(to))
            .toList()
          ..sort((DutyDay a, DutyDay b) => b.day.compareTo(a.day));
    return HistoryMonth._(month: first, from: from, to: to, days: days);
  }

  /// The first of the month.
  final DateTime month;

  /// The dates shown, inclusive: the whole month, or less at either end.
  final DateTime from;
  final DateTime to;

  /// Newest first.
  final List<DutyDay> days;

  /// Calendar days in [from]..[to]: every day counts, Sundays too.
  int get calendarDays => to.difference(from).inDays + 1;

  int count(DayStatus status) =>
      days.where((DutyDay d) => d.status == status).length;

  /// Present days plus half of each Half day ("16.5").
  double get daysCounted =>
      count(DayStatus.present) + count(DayStatus.halfDay) / 2;

  /// The months a window from [earliest] to [today] touches, newest first.
  static List<DateTime> monthsBetween(DateTime earliest, DateTime today) {
    final List<DateTime> months = <DateTime>[];
    DateTime m = DateTime.utc(today.year, today.month);
    final DateTime stop = DateTime.utc(earliest.year, earliest.month);
    while (!m.isBefore(stop)) {
      months.add(m);
      m = DateTime.utc(m.year, m.month - 1);
    }
    return months;
  }
}

/// "16.5", "16".
String formatDaysCounted(double days) =>
    days == days.roundToDouble() ? days.toInt().toString() : days.toString();

/// Time on duty for a day: the running time while on duty, otherwise the
/// worked minutes. Null when there was no duty.
Duration? dutyLength(DutyDay day, DateTime now) {
  final DateTime? on = day.dutyOnAt;
  if (on == null) return null;
  if (day.status == DayStatus.onDuty) return now.difference(on);
  final int? minutes = day.workedMinutes;
  if (minutes != null) return Duration(minutes: minutes);
  final DateTime? off = day.dutyOffAt;
  return off?.difference(on);
}
