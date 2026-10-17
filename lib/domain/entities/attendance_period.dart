import 'package:flutter/foundation.dart';

import '../../core/utils/duty_time_helper.dart';
import 'admin_duty_session.dart';

/// One IST calendar day of an employee's attendance.
@immutable
class AttendanceDay {
  const AttendanceDay({
    required this.date,
    required this.sessions,
    required this.duration,
    required this.distanceKm,
    required this.visitsCount,
    required this.flaggedPoints,
  });

  /// The IST day (midnight; only year, month and day mean anything).
  final DateTime date;

  /// Sessions that started on this day, oldest first. Empty means absent.
  final List<AdminDutySession> sessions;
  final Duration duration;

  /// Null when the server could not give the distance of a session that is
  /// still open. Never guessed.
  final double? distanceKm;
  final int visitsCount;

  /// Mock-flagged points over the day's sessions.
  final int flaggedPoints;

  bool get isAbsent => sessions.isEmpty;
  bool get hasOpenSession => sessions.any((s) => s.isOpen);
  bool get endedAutomatically => sessions.any((s) => s.endedAutomatically);
  bool get hasFlag => flaggedPoints > 0;

  /// `yyyy-MM-dd`, which the route view reads to open on this day.
  String get id =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

/// The period's totals, all summed from the same session rows the days show.
@immutable
class AttendanceSummary {
  const AttendanceSummary({
    required this.daysWorked,
    required this.totalDuration,
    required this.distanceKm,
    required this.visitsCount,
    required this.autoEndedDays,
    required this.flaggedPoints,
    required this.absentDays,
  });

  /// Days with at least one session.
  final int daysWorked;
  final Duration totalDuration;

  /// Null if any day's distance is unknown: a total that leaves a day out
  /// would not reconcile with the rows, so it is not shown.
  final double? distanceKm;
  final int visitsCount;

  /// Days on which a session was ended automatically at 23:00 IST.
  final int autoEndedDays;
  final int flaggedPoints;

  /// Days with no duty, from the employee's first day up to yesterday.
  final int absentDays;
}

/// One employee's attendance over a run of IST days: every day with duty, the
/// days without, and the totals.
///
/// Built from the session rows alone, so the totals can be reconciled by adding
/// up what is on the screen or in a report. The attendance screen (a month) and
/// the reports (any period) use this one builder, so they cannot disagree. A
/// session belongs to the IST day it started on (the 08:00-23:00 duty window
/// means a session never crosses midnight).
@immutable
class AttendancePeriod {
  const AttendancePeriod({
    required this.from,
    required this.to,
    required this.days,
    required this.summary,
  });

  /// First and last day of the period, both included (IST calendar days).
  final DateTime from;
  final DateTime to;

  /// Days with duty, and absent days, newest first.
  final List<AttendanceDay> days;
  final AttendanceSummary summary;

  /// Builds the period from [sessions].
  ///
  /// [serverNow] decides what "today" is and how long an open session has run.
  /// An absent day is a past day with no duty, on or after the employee's
  /// first day ([employeeCreatedAt]); today and later days are never absent,
  /// because the day is not over. There is no holiday or weekly-off calendar,
  /// so every such day counts.
  factory AttendancePeriod.build({
    required DateTime from,
    required DateTime to,
    required List<AdminDutySession> sessions,
    required DateTime serverNow,
    DateTime? employeeCreatedAt,
  }) {
    final first = DateTime(from.year, from.month, from.day);
    final last = DateTime(to.year, to.month, to.day);

    final byDay = <DateTime, List<AdminDutySession>>{};
    for (final session in sessions) {
      final ist = DutyTimeHelper.toIst(session.startedAt);
      final day = DateTime(ist.year, ist.month, ist.day);
      if (day.isBefore(first) || day.isAfter(last)) continue;
      byDay.putIfAbsent(day, () => <AdminDutySession>[]).add(session);
    }

    final days = <AttendanceDay>[];
    for (final entry in byDay.entries) {
      final daySessions = [...entry.value]
        ..sort((a, b) => a.startedAt.compareTo(b.startedAt));
      var duration = Duration.zero;
      double? distance = 0;
      var visits = 0;
      var flagged = 0;
      for (final session in daySessions) {
        duration += session.durationAt(serverNow);
        visits += session.visitsCount;
        flagged += session.mockPointsCount;
        final km = session.distanceKm;
        distance = (distance == null || km == null) ? null : distance + km;
      }
      days.add(
        AttendanceDay(
          date: entry.key,
          sessions: daySessions,
          duration: duration,
          distanceKm: distance,
          visitsCount: visits,
          flaggedPoints: flagged,
        ),
      );
    }

    // Absent days: past days, from the employee's first day, with no duty.
    final serverIst = DutyTimeHelper.toIst(serverNow);
    final yesterday = DateTime(
      serverIst.year,
      serverIst.month,
      serverIst.day - 1,
    );
    var counting = first;
    if (employeeCreatedAt != null) {
      final created = DutyTimeHelper.toIst(employeeCreatedAt);
      final createdDay = DateTime(created.year, created.month, created.day);
      if (createdDay.isAfter(counting)) counting = createdDay;
    }
    final until = yesterday.isBefore(last) ? yesterday : last;
    for (
      var day = counting;
      !day.isAfter(until);
      day = DateTime(day.year, day.month, day.day + 1)
    ) {
      if (byDay.containsKey(day)) continue;
      days.add(
        AttendanceDay(
          date: day,
          sessions: const <AdminDutySession>[],
          duration: Duration.zero,
          distanceKm: 0,
          visitsCount: 0,
          flaggedPoints: 0,
        ),
      );
    }

    days.sort((a, b) => b.date.compareTo(a.date));

    final worked = days.where((d) => !d.isAbsent).toList();
    double? distance = 0;
    for (final day in worked) {
      final km = day.distanceKm;
      distance = (distance == null || km == null) ? null : distance + km;
    }

    return AttendancePeriod(
      from: first,
      to: last,
      days: days,
      summary: AttendanceSummary(
        daysWorked: worked.length,
        totalDuration: worked.fold(
          Duration.zero,
          (total, day) => total + day.duration,
        ),
        distanceKm: distance,
        visitsCount: worked.fold(0, (total, day) => total + day.visitsCount),
        autoEndedDays: worked.where((d) => d.endedAutomatically).length,
        flaggedPoints: worked.fold(
          0,
          (total, day) => total + day.flaggedPoints,
        ),
        absentDays: days.length - worked.length,
      ),
    );
  }
}
