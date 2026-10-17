/// English month and weekday names for display labels.
///
/// Display only. Nothing here decides duty windows or curfews, which are always
/// judged on the server.
abstract final class DateLabels {
  const DateLabels._();

  static const List<String> _weekdays = <String>[
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  static const List<String> _months = <String>[
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  /// "October" for any date in October.
  static String monthName(DateTime date) => _months[date.month - 1];

  /// "Monday, 12 October 2026".
  static String longDate(DateTime date) {
    return '${_weekdays[date.weekday - 1]}, ${date.day} '
        '${monthName(date)} ${date.year}';
  }

  static const List<String> _weekdaysShort = <String>[
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  /// "Sat, 11 Oct".
  static String shortDate(DateTime date) {
    return '${_weekdaysShort[date.weekday - 1]}, ${date.day} '
        '${monthName(date).substring(0, 3)}';
  }

  /// "05 Oct 2026".
  static String dayMonthYear(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    return '$day ${monthName(date).substring(0, 3)} ${date.year}';
  }
}
