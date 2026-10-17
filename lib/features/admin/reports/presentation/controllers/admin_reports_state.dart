import 'package:flutter/foundation.dart';

import '../../../../../domain/entities/report_data.dart';

/// The report tiles on Screen 26. The visit log is shown but not offered until
/// there is visit data to report on.
enum ReportType { dailyDetail, employeeSummary, teamSummary, visitLog }

extension ReportTypeX on ReportType {
  String get title => switch (this) {
    ReportType.dailyDetail => 'Daily detail',
    ReportType.employeeSummary => 'Employee summary',
    ReportType.teamSummary => 'Team summary',
    ReportType.visitLog => 'Visit log',
  };

  String get subtitle => switch (this) {
    ReportType.dailyDetail => 'Every duty of one day',
    ReportType.employeeSummary => 'One person, day by day',
    ReportType.teamSummary => 'Everyone, one row each',
    ReportType.visitLog => 'Coming soon',
  };

  bool get isAvailable => this != ReportType.visitLog;

  /// What the audit log records. Null for a report that cannot be built yet.
  ReportKind? get kind => switch (this) {
    ReportType.dailyDetail => ReportKind.dailyDetail,
    ReportType.employeeSummary => ReportKind.employeeSummary,
    ReportType.teamSummary => ReportKind.teamSummary,
    ReportType.visitLog => null,
  };

  /// Longest period the report covers, in days.
  int get maxDays => switch (this) {
    ReportType.dailyDetail => 1,
    ReportType.employeeSummary => 62,
    ReportType.teamSummary => 31,
    ReportType.visitLog => 0,
  };

  /// The period choices offered for this report.
  List<ReportPeriodPreset> get presets => switch (this) {
    ReportType.dailyDetail => const [
      ReportPeriodPreset.today,
      ReportPeriodPreset.yesterday,
      ReportPeriodPreset.pickDay,
    ],
    _ => const [
      ReportPeriodPreset.thisMonth,
      ReportPeriodPreset.lastMonth,
      ReportPeriodPreset.last7Days,
      ReportPeriodPreset.custom,
    ],
  };
}

/// The period choices on Screen 26.
enum ReportPeriodPreset {
  today('Today'),
  yesterday('Yesterday'),
  pickDay('Pick a day'),
  thisMonth('This month'),
  lastMonth('Last month'),
  last7Days('Last 7 days'),
  custom('Custom');

  const ReportPeriodPreset(this.label);

  final String label;

  /// Needs the admin to pick a date.
  bool get needsPicker =>
      this == ReportPeriodPreset.pickDay || this == ReportPeriodPreset.custom;
}

/// The person an employee summary is about.
@immutable
class ReportEmployeeChoice {
  const ReportEmployeeChoice({
    required this.id,
    required this.name,
    required this.code,
  });

  final String id;
  final String name;
  final String code;

  String get label => code.isEmpty ? name : '$name ($code)';

  @override
  bool operator ==(Object other) =>
      other is ReportEmployeeChoice && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Where generating a report has got to.
enum ReportPhase { idle, working, ready, failed }

/// A finished report: the PDF and what it is, kept in memory only.
@immutable
class GeneratedReport {
  const GeneratedReport({
    required this.bytes,
    required this.fileName,
    required this.truncated,
  });

  final Uint8List bytes;
  final String fileName;

  /// More records exist than one report holds, so the PDF is marked incomplete.
  final bool truncated;

  int get sizeBytes => bytes.length;

  /// "184 KB" or "1.2 MB".
  String get sizeLabel {
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).ceil()} KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// Immutable state for Screen 26 Reports (Admin): the admin's choices and the
/// progress and result of building the report.
@immutable
class AdminReportsState {
  const AdminReportsState({
    required this.from,
    required this.to,
    this.type = ReportType.dailyDetail,
    this.preset = ReportPeriodPreset.today,
    this.employee,
    this.phase = ReportPhase.idle,
    this.stage,
    this.result,
    this.errorMessage,
  });

  final ReportType type;
  final ReportPeriodPreset preset;

  /// First and last day, both included: IST calendar days (only year, month and
  /// day mean anything).
  final DateTime from;
  final DateTime to;

  /// Who an employee summary is about. Unused by the other reports.
  final ReportEmployeeChoice? employee;

  final ReportPhase phase;

  /// What is being done while [phase] is working ("Building the PDF...").
  final String? stage;
  final GeneratedReport? result;
  final String? errorMessage;

  bool get isWorking => phase == ReportPhase.working;

  /// Days in the period, both ends included.
  int get days =>
      DateTime.utc(
        to.year,
        to.month,
        to.day,
      ).difference(DateTime.utc(from.year, from.month, from.day)).inDays +
      1;

  /// Why the period cannot be used, or null when it can.
  String? get periodProblem {
    if (days < 1) return 'The end date is before the start date.';
    if (days > type.maxDays) {
      return switch (type) {
        ReportType.teamSummary =>
          'A team summary covers at most 31 days. Choose a shorter period.',
        ReportType.employeeSummary =>
          'An employee summary covers at most 62 days. Choose a shorter period.',
        _ => null,
      };
    }
    return null;
  }

  /// Why the report cannot be built yet, or null when it can.
  String? get blocker {
    if (!type.isAvailable) return 'This report is not available yet.';
    if (type == ReportType.employeeSummary && employee == null) {
      return 'Choose whose report to build.';
    }
    return periodProblem;
  }

  bool get canGenerate => blocker == null && !isWorking;

  AdminReportsState copyWith({
    ReportType? type,
    ReportPeriodPreset? preset,
    DateTime? from,
    DateTime? to,
    ReportEmployeeChoice? employee,
    bool clearEmployee = false,
    ReportPhase? phase,
    String? stage,
    GeneratedReport? result,
    String? errorMessage,
    bool clearResult = false,
    bool clearError = false,
  }) {
    return AdminReportsState(
      type: type ?? this.type,
      preset: preset ?? this.preset,
      from: from ?? this.from,
      to: to ?? this.to,
      employee: clearEmployee ? null : (employee ?? this.employee),
      phase: phase ?? this.phase,
      stage: phase == null ? (stage ?? this.stage) : stage,
      result: clearResult ? null : (result ?? this.result),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
