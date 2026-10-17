import 'package:flutter/foundation.dart';

import 'admin_duty_session.dart';
import 'attendance_period.dart';

export 'attendance_period.dart' show AttendanceDay, AttendanceSummary;

/// One employee's calendar month: an [AttendancePeriod] from the 1st to the
/// last day.
@immutable
class AttendanceMonth {
  const AttendanceMonth({
    required this.month,
    required this.days,
    required this.summary,
  });

  /// First day of the month (IST).
  final DateTime month;

  /// Days with duty, and absent days, newest first.
  final List<AttendanceDay> days;
  final AttendanceSummary summary;

  /// Builds the month from [sessions].
  ///
  /// [serverNow] decides what "today" is and how long an open session has run.
  /// An absent day is a past day with no duty, on or after the employee's
  /// first day ([employeeCreatedAt]); today and later days are never absent,
  /// because the day is not over. There is no holiday or weekly-off calendar,
  /// so every such day counts.
  factory AttendanceMonth.build({
    required DateTime month,
    required List<AdminDutySession> sessions,
    required DateTime serverNow,
    DateTime? employeeCreatedAt,
  }) {
    final first = DateTime(month.year, month.month);
    final period = AttendancePeriod.build(
      from: first,
      to: DateTime(month.year, month.month + 1, 0),
      sessions: sessions,
      serverNow: serverNow,
      employeeCreatedAt: employeeCreatedAt,
    );
    return AttendanceMonth(
      month: first,
      days: period.days,
      summary: period.summary,
    );
  }
}
