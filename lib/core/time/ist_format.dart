import 'package:intl/intl.dart';

import 'ist.dart';

/// How times and durations are written in the app, always in India time.
abstract final class IstFormat {
  const IstFormat._();

  static final DateFormat _time = DateFormat('h:mm a');
  static final DateFormat _date = DateFormat('d MMM yyyy');
  static final DateFormat _shortDate = DateFormat('d MMM');
  static final DateFormat _dayDate = DateFormat('EEEE, d MMM');

  /// "7:05 AM".
  static String time(DateTime instant) => _time.format(Ist.wallClock(instant));

  /// "20 Nov 2026" for an IST date (a UTC midnight date).
  static String date(DateTime istDate) => _date.format(istDate);

  /// "20 Nov", the IST day of an instant.
  static String shortDate(DateTime instant) =>
      _shortDate.format(Ist.wallClock(instant));

  /// "Saturday, 21 Nov", the IST day of an instant.
  static String dayDate(DateTime instant) =>
      _dayDate.format(Ist.wallClock(instant));

  /// "9 h 05 min", "45 min".
  static String duration(Duration d) {
    final int minutes = d.isNegative ? 0 : d.inMinutes;
    final int h = minutes ~/ 60;
    final int m = minutes % 60;
    if (h == 0) return '$m min';
    return '$h h ${m.toString().padLeft(2, '0')} min';
  }
}
