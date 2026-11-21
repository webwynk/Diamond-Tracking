import '../time/ist.dart';

/// The business rules agreed for duty and attendance, in one place.
///
/// These are pure functions with no I/O, so they are fully unit-tested. The
/// database enforces the same rules (Phase 2); the app uses these to show the
/// right button, warning or message before asking the server.
abstract final class DutyRules {
  const DutyRules._();

  /// Duty on is allowed from 05:00 ...
  static const int dutyOnStartMinute = 5 * 60;

  /// ... up to and including 08:30 IST.
  static const int dutyOnEndMinute = 8 * 60 + 30;

  /// Open duties are closed automatically at 23:00 IST.
  static const int autoDutyOffMinute = 23 * 60;

  /// The admin's "Allow duty on today" can be given and used until 21:00
  /// IST. Later, a duty would last under two hours before the 23:00 auto
  /// duty off: always short, and only a request for the admin (review L28).
  /// The database checks the same time (private.permit_cutoff_at).
  static const int dutyPermitEndMinute = 21 * 60;

  /// A day shorter than this needs an admin decision.
  static const Duration minimumDuty = Duration(hours: 10);

  /// Attendance can be requested for today and the 7 days before it.
  static const int attendanceRequestDaysBack = 7;

  /// Low-battery warnings, highest first. Each fires once per duty day.
  static const List<int> batteryWarningLevels = <int>[20, 15, 10];

  /// Whether duty on is allowed at [now].
  static bool canDutyOn(DateTime now) {
    final int minute = Ist.minuteOfDay(now);
    return minute >= dutyOnStartMinute && minute <= dutyOnEndMinute;
  }

  /// Whether an admin's permission for today can still start a duty at [now].
  static bool canUsePermitAt(DateTime now) =>
      Ist.minuteOfDay(now) < dutyPermitEndMinute;

  /// The automatic duty-off instant for a duty that started at [dutyOn].
  static DateTime autoDutyOffFor(DateTime dutyOn) {
    final DateTime day = Ist.dateOf(dutyOn);
    return Ist.instantAt(day.year, day.month, day.day, 23);
  }

  /// Whether a duty from [dutyOn] to [dutyOff] reached the 10-hour minimum.
  static bool meetsMinimum(DateTime dutyOn, DateTime dutyOff) =>
      dutyOff.difference(dutyOn) >= minimumDuty;

  /// Whether [day] (an IST date) can still get an attendance request at [now].
  /// Today counts, and so do the 7 days before it. Future days do not.
  static bool canRequestAttendanceFor(DateTime day, DateTime now) {
    final DateTime today = Ist.dateOf(now);
    final DateTime target = DateTime.utc(day.year, day.month, day.day);
    final int daysBack = today.difference(target).inDays;
    return daysBack >= 0 && daysBack <= attendanceRequestDaysBack;
  }

  /// The battery warning to show when the level drops to [level], or null.
  ///
  /// [alreadyShown] holds the levels already warned about today. If the level
  /// jumps past several thresholds at once (25% to 9%), only the lowest one is
  /// shown; the caller then marks every level in [thresholdsReached] as shown,
  /// so the higher ones do not pop up afterwards.
  static int? batteryWarningFor(int level, Set<int> alreadyShown) {
    for (final int threshold in batteryWarningLevels.reversed) {
      if (level <= threshold) {
        return alreadyShown.contains(threshold) ? null : threshold;
      }
    }
    return null;
  }

  /// Every warning level at or above [level].
  static Set<int> thresholdsReached(int level) => <int>{
    for (final int threshold in batteryWarningLevels)
      if (level <= threshold) threshold,
  };
}
