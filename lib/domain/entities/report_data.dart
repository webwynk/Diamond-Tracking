import 'package:flutter/foundation.dart';

import 'admin_duty_session.dart';
import 'attendance_period.dart';

/// The reports an admin can export. The visit and geofence logs wait for visit
/// and place data.
enum ReportKind {
  dailyDetail('daily_detail'),
  employeeSummary('employee_summary'),
  teamSummary('team_summary');

  const ReportKind(this.wire);

  /// The value written to the audit log.
  final String wire;
}

/// An employee as a report needs to know them.
@immutable
class ReportEmployee {
  const ReportEmployee({
    required this.id,
    required this.name,
    required this.code,
    this.createdAt,
    this.isActive = true,
  });

  final String id;
  final String name;
  final String code;

  /// When the profile was created (UTC): days before it are not absences.
  final DateTime? createdAt;
  final bool isActive;

  /// Reads one `profiles` row. Null when it cannot be an employee.
  static ReportEmployee? tryParse(Map<String, dynamic> json) {
    final id = json['id'];
    if (id is! String) return null;
    final name = json['full_name'];
    final code = json['employee_code'];
    final created = json['created_at'];
    return ReportEmployee(
      id: id,
      name: name is String && name.trim().isNotEmpty ? name : 'Employee',
      code: code is String ? code : '',
      createdAt: created is String ? DateTime.tryParse(created)?.toUtc() : null,
      isActive: json['status'] != 'blocked',
    );
  }
}

/// What the server holds for a report: the sessions of the period (with whose
/// they are), the employees, and the server's clock.
@immutable
class ReportSource {
  const ReportSource({
    required this.sessions,
    required this.employees,
    required this.serverNow,
    this.truncated = false,
  });

  final List<AdminDutySession> sessions;
  final List<ReportEmployee> employees;

  /// The server's clock when this was read (UTC): "today", "hours so far" and
  /// the report's "generated at" all come from it.
  final DateTime serverNow;

  /// More sessions exist than the safety cap allows to be read.
  final bool truncated;
}

/// Common to every report.
@immutable
sealed class ReportData {
  const ReportData({
    required this.from,
    required this.to,
    required this.serverNow,
    required this.truncated,
  });

  /// First and last day, both included (IST calendar days).
  final DateTime from;
  final DateTime to;

  /// The server's clock when the data was read (UTC).
  final DateTime serverNow;
  final bool truncated;
}

/// One duty session of the day, with whose it is.
@immutable
class DailyDetailRow {
  const DailyDetailRow({required this.employee, required this.session});

  final ReportEmployee employee;
  final AdminDutySession session;
}

/// One day, every duty session of every employee (or of one).
@immutable
class DailyDetailReport extends ReportData {
  const DailyDetailReport({
    required super.from,
    required super.serverNow,
    required super.truncated,
    required this.rows,
    required this.absent,
    required this.absentKnown,
    required this.employeesOnDuty,
    required this.totalDuration,
    required this.distanceKm,
    required this.visits,
    required this.flaggedPoints,
    required this.autoEnded,
    required this.inProgress,
  }) : super(to: from);

  final List<DailyDetailRow> rows;

  /// Active employees with no duty that day. Only known once the day is over.
  final List<ReportEmployee> absent;
  final bool absentKnown;
  final int employeesOnDuty;
  final Duration totalDuration;

  /// Null when a session's distance is unknown (never a smaller total).
  final double? distanceKm;
  final int visits;
  final int flaggedPoints;
  final int autoEnded;
  final int inProgress;
}

/// One employee over a period, day by day.
@immutable
class EmployeeSummaryReport extends ReportData {
  const EmployeeSummaryReport({
    required super.from,
    required super.to,
    required super.serverNow,
    required super.truncated,
    required this.employee,
    required this.period,
  });

  final ReportEmployee employee;
  final AttendancePeriod period;
}

/// One employee's totals over the period, as a row of the team summary.
@immutable
class TeamSummaryRow {
  const TeamSummaryRow({required this.employee, required this.summary});

  final ReportEmployee employee;
  final AttendanceSummary summary;
}

/// Everyone over a period: one row each, and the totals.
@immutable
class TeamSummaryReport extends ReportData {
  const TeamSummaryReport({
    required super.from,
    required super.to,
    required super.serverNow,
    required super.truncated,
    required this.rows,
    required this.totals,
  });

  final List<TeamSummaryRow> rows;
  final AttendanceSummary totals;
}
