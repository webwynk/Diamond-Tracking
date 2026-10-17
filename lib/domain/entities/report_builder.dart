import '../../core/utils/duty_time_helper.dart';
import 'attendance_period.dart';
import 'report_data.dart';

/// Turns what the server holds ([ReportSource]) into the three reports.
///
/// Every number comes from [AttendancePeriod] (the builder behind the
/// attendance screen) or from adding up the same session rows, so a report and
/// the screen cannot disagree. Pure: no clock, no network.
abstract final class ReportBuilder {
  const ReportBuilder._();

  /// Stands in for a session whose owner is not in the roster.
  static const ReportEmployee _unknown = ReportEmployee(
    id: '',
    name: 'Unknown employee',
    code: '',
  );

  /// Every duty session that started on [day], and who was absent.
  ///
  /// Absent means an active employee, already on the team that day, with no
  /// session. It is only known once the day is over (today is never absent).
  static DailyDetailReport daily(ReportSource source, {required DateTime day}) {
    final date = DateTime(day.year, day.month, day.day);
    final byId = {for (final e in source.employees) e.id: e};

    final rows = <DailyDetailRow>[];
    for (final session in source.sessions) {
      if (_istDay(session.startedAt) != date) continue;
      rows.add(
        DailyDetailRow(
          employee: byId[session.employeeId] ?? _unknown,
          session: session,
        ),
      );
    }
    rows.sort((a, b) {
      final byName = a.employee.name.toLowerCase().compareTo(
        b.employee.name.toLowerCase(),
      );
      if (byName != 0) return byName;
      final byCode = a.employee.code.compareTo(b.employee.code);
      if (byCode != 0) return byCode;
      return a.session.startedAt.compareTo(b.session.startedAt);
    });

    final today = _istDay(source.serverNow);
    final absentKnown = date.isBefore(today);
    final present = {for (final r in rows) r.employee.id};
    final absent = absentKnown
        ? (source.employees
              .where(
                (e) =>
                    e.isActive &&
                    !present.contains(e.id) &&
                    !_startedAfter(e, date),
              )
              .toList()
            ..sort(
              (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
            ))
        : const <ReportEmployee>[];

    var duration = Duration.zero;
    double? distance = 0;
    var visits = 0;
    var flagged = 0;
    var auto = 0;
    var open = 0;
    for (final row in rows) {
      final session = row.session;
      duration += session.durationAt(source.serverNow);
      visits += session.visitsCount;
      flagged += session.mockPointsCount;
      if (session.endedAutomatically) auto++;
      if (session.isOpen) open++;
      distance = _add(distance, session.distanceKm);
    }

    return DailyDetailReport(
      from: date,
      serverNow: source.serverNow,
      truncated: source.truncated,
      rows: rows,
      absent: absent,
      absentKnown: absentKnown,
      employeesOnDuty: present.length,
      totalDuration: duration,
      distanceKm: distance,
      visits: visits,
      flaggedPoints: flagged,
      autoEnded: auto,
      inProgress: open,
    );
  }

  /// One employee, day by day, over [from]..[to] (both included).
  static EmployeeSummaryReport employee(
    ReportSource source, {
    required ReportEmployee employee,
    required DateTime from,
    required DateTime to,
  }) {
    final period = _period(source, employee, from, to);
    return EmployeeSummaryReport(
      from: period.from,
      to: period.to,
      serverNow: source.serverNow,
      truncated: source.truncated,
      employee: employee,
      period: period,
    );
  }

  /// Everyone over [from]..[to]: a row each, and the totals.
  ///
  /// Included: active employees, and blocked ones only if they worked in the
  /// period. Absent days are only counted for active employees (the date an
  /// account was blocked is not recorded), and the totals follow the rows.
  static TeamSummaryReport team(
    ReportSource source, {
    required DateTime from,
    required DateTime to,
  }) {
    final rows = <TeamSummaryRow>[];
    for (final employee in source.employees) {
      final period = _period(source, employee, from, to);
      if (!employee.isActive && period.summary.daysWorked == 0) continue;
      rows.add(TeamSummaryRow(employee: employee, summary: period.summary));
    }
    rows.sort((a, b) {
      final byName = a.employee.name.toLowerCase().compareTo(
        b.employee.name.toLowerCase(),
      );
      return byName != 0 ? byName : a.employee.code.compareTo(b.employee.code);
    });

    var worked = 0;
    var duration = Duration.zero;
    double? distance = 0;
    var visits = 0;
    var auto = 0;
    var flagged = 0;
    var absent = 0;
    for (final row in rows) {
      final s = row.summary;
      worked += s.daysWorked;
      duration += s.totalDuration;
      distance = _add(distance, s.distanceKm);
      visits += s.visitsCount;
      auto += s.autoEndedDays;
      flagged += s.flaggedPoints;
      absent += s.absentDays;
    }

    return TeamSummaryReport(
      from: DateTime(from.year, from.month, from.day),
      to: DateTime(to.year, to.month, to.day),
      serverNow: source.serverNow,
      truncated: source.truncated,
      rows: rows,
      totals: AttendanceSummary(
        daysWorked: worked,
        totalDuration: duration,
        distanceKm: distance,
        visitsCount: visits,
        autoEndedDays: auto,
        flaggedPoints: flagged,
        absentDays: absent,
      ),
    );
  }

  /// One employee's period, from the sessions that are theirs. Absent days are
  /// left out for a blocked account (see [team]).
  static AttendancePeriod _period(
    ReportSource source,
    ReportEmployee employee,
    DateTime from,
    DateTime to,
  ) {
    final mine = source.sessions
        .where((s) => s.employeeId == employee.id)
        .toList();
    final period = AttendancePeriod.build(
      from: from,
      to: to,
      sessions: mine,
      serverNow: source.serverNow,
      employeeCreatedAt: employee.createdAt,
    );
    if (employee.isActive) return period;
    final worked = period.days.where((d) => !d.isAbsent).toList();
    return AttendancePeriod(
      from: period.from,
      to: period.to,
      days: worked,
      summary: AttendanceSummary(
        daysWorked: period.summary.daysWorked,
        totalDuration: period.summary.totalDuration,
        distanceKm: period.summary.distanceKm,
        visitsCount: period.summary.visitsCount,
        autoEndedDays: period.summary.autoEndedDays,
        flaggedPoints: period.summary.flaggedPoints,
        absentDays: 0,
      ),
    );
  }

  static DateTime _istDay(DateTime utc) {
    final ist = DutyTimeHelper.toIst(utc);
    return DateTime(ist.year, ist.month, ist.day);
  }

  /// True when the employee's first day is after [day].
  static bool _startedAfter(ReportEmployee employee, DateTime day) {
    final created = employee.createdAt;
    return created != null && _istDay(created).isAfter(day);
  }

  /// A running total that turns null (unknown) as soon as a part is unknown.
  static double? _add(double? total, double? part) =>
      (total == null || part == null) ? null : total + part;
}
