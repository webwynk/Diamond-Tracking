/// Utilities for evaluating duty operating windows and formatting time
/// strictly in the required `Asia/Kolkata` (IST, UTC+05:30) timezone per PRD BR-1, BR-2, BR-3.
abstract final class DutyTimeHelper {
  const DutyTimeHelper._();

  /// IST is UTC + 5 hours and 30 minutes.
  static const Duration istOffset = Duration(hours: 5, minutes: 30);

  /// 00:00 IST on the IST calendar day [wallDate] (only its year, month and day
  /// count; day 0 or 32 roll over as in [DateTime]), as a UTC instant. IST has
  /// no daylight saving, so a day is exactly 24 hours.
  ///
  /// The one place an IST day or month is turned into the UTC interval the
  /// server is asked for: the end of a period is the start of the day after it.
  static DateTime istDayStartUtc(DateTime wallDate) {
    return DateTime.utc(
      wallDate.year,
      wallDate.month,
      wallDate.day,
    ).subtract(istOffset);
  }

  /// Converts any [DateTime] into `Asia/Kolkata` (IST) wall clock time.
  static DateTime toIst(DateTime dateTime) {
    return dateTime.toUtc().add(istOffset);
  }

  /// Optional debug time override for deterministic testing across timezone boundaries.
  static DateTime? debugNow;

  /// Returns current time in `Asia/Kolkata` (IST).
  static DateTime get nowIst => toIst(debugNow ?? DateTime.now());

  /// Checks whether the provided [time] (or [nowIst]) is within the permitted
  /// 08:00 to 23:00 IST operating window (PRD BR-1).
  static bool isWithinDutyWindow([DateTime? time]) {
    final ist = time != null ? toIst(time) : nowIst;
    final hour = ist.hour;

    // Allowed hours: 8 through 22 inclusive (i.e. up to 22:59:59).
    // Exactly at 23:00 (11:00 PM), curfew closes all sessions (BR-2).
    return hour >= 8 && hour < 23;
  }

  /// Returns whether curfew is imminent (between 22:45 and 23:00 IST per PRD BR-3).
  static bool isCurfewWarningActive([DateTime? time]) {
    final ist = time != null ? toIst(time) : nowIst;
    return ist.hour == 22 && ist.minute >= 45;
  }

  /// Returns a user-friendly explanation when the duty window is disabled (Screen 08).
  static String getDutyDisabledReason([DateTime? time]) {
    final ist = time != null ? toIst(time) : nowIst;
    if (ist.hour < 8) {
      return 'Duty starts today at 8:00 AM';
    } else {
      return 'Duty ended for today. Resumes tomorrow at 8:00 AM';
    }
  }

  /// Formats an elapsed duration as "Xh Ym" (e.g. "8h 12m" or "0h 0m").
  static String formatElapsed(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    return '${hours}h ${minutes}m';
  }

  /// Formats a distance in kilometers to 1 decimal place (e.g. "47.3 km" or "0.0 km").
  static String formatDistanceKm(double km) {
    return km.toStringAsFixed(1);
  }

  /// Formats a [DateTime] into standard "DD MMM YYYY" (e.g. "11 Oct 2026").
  static String formatDate(DateTime dateTime) {
    final ist = toIst(dateTime);
    const months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final day = ist.day.toString().padLeft(2, '0');
    final month = months[ist.month - 1];
    final year = ist.year;
    return '$day $month $year';
  }

  /// Formats a time into "h:mm a" in IST (e.g. "8:04 AM").
  static String formatTime(DateTime dateTime) {
    final ist = toIst(dateTime);
    final hour = ist.hour % 12 == 0 ? 12 : ist.hour % 12;
    final minute = ist.minute.toString().padLeft(2, '0');
    final ampm = ist.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $ampm';
  }

  /// Formats a shift interval like "12 Oct 2026 · 8:04 AM to 4:28 PM".
  static String formatShiftInterval(DateTime start, DateTime? end) {
    final startDate = formatDate(start);
    final startTime = formatTime(start);
    final endTime = end != null ? formatTime(end) : formatTime(DateTime.now());
    return '$startDate · $startTime to $endTime';
  }

  /// Formats a date into "Weekday, DD Mon" (e.g. "Sat, 11 Oct", "Thu, 09 Oct").
  static String formatDayAndDate(DateTime dateTime) {
    final ist = toIst(dateTime);
    const weekdays = <String>['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final weekday = weekdays[ist.weekday - 1];
    final day = ist.day.toString().padLeft(2, '0');
    final month = months[ist.month - 1];
    return '$weekday, $day $month';
  }

  /// Formats a date into uppercase "MONTH YYYY" (e.g. "OCTOBER 2026").
  static String formatMonthAndYear(DateTime dateTime) {
    final ist = toIst(dateTime);
    const fullMonths = <String>[
      'JANUARY',
      'FEBRUARY',
      'MARCH',
      'APRIL',
      'MAY',
      'JUNE',
      'JULY',
      'AUGUST',
      'SEPTEMBER',
      'OCTOBER',
      'NOVEMBER',
      'DECEMBER',
    ];
    final month = fullMonths[ist.month - 1];
    final year = ist.year;
    return '$month $year';
  }

  /// Formats a concise time range (e.g. "8:02 AM–6:30 PM").
  static String formatTimeRange(DateTime start, DateTime? end) {
    final startStr = formatTime(start);
    if (end == null) return '$startStr–Active';
    final endStr = formatTime(end);
    return '$startStr–$endStr';
  }
}
