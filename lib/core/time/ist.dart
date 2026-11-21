/// India Standard Time helpers.
///
/// India has one time zone, UTC+05:30, with no daylight saving, so a fixed
/// offset is exact. Business rules (the 5:00 to 8:30 AM duty window, the
/// 11:00 PM automatic duty off, "which day is today") are always judged in
/// IST, whatever time zone the phone is set to.
///
/// An IST wall-clock time is represented as a UTC [DateTime] whose fields read
/// as IST (for example 05:00 IST is `DateTime.utc(y, m, d, 5)`). This avoids
/// the phone's own time zone ever leaking into a calculation.
library;

abstract final class Ist {
  const Ist._();

  static const Duration offset = Duration(hours: 5, minutes: 30);

  /// The IST wall-clock reading of an instant.
  static DateTime wallClock(DateTime instant) => instant.toUtc().add(offset);

  /// The instant at a given IST wall-clock time.
  static DateTime instantAt(
    int year,
    int month,
    int day, [
    int hour = 0,
    int minute = 0,
  ]) => DateTime.utc(year, month, day, hour, minute).subtract(offset);

  /// The IST calendar date of an instant, as a UTC midnight date.
  static DateTime dateOf(DateTime instant) {
    final DateTime wall = wallClock(instant);
    return DateTime.utc(wall.year, wall.month, wall.day);
  }

  /// Minutes since IST midnight for an instant (0 to 1439).
  static int minuteOfDay(DateTime instant) {
    final DateTime wall = wallClock(instant);
    return wall.hour * 60 + wall.minute;
  }
}

/// A calendar date as the database writes it, for example "2026-11-20"
/// (L53: the one copy used by every repository).
String isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';
