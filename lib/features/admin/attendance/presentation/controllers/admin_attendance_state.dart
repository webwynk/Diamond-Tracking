import 'package:flutter/foundation.dart';

import '../../../../../core/utils/date_labels.dart';
import '../../../../../core/utils/duty_time_helper.dart';
import '../../../../../domain/entities/attendance_month.dart';

/// Status classification for an individual day on the admin attendance log.
enum AdminDailyStatusType { normal, autoEnded, multiSession, absent }

/// Filter mode for the daily attendance cards stream.
enum AdminAttendanceFilter { allDays, autoEnded, withFlags, absent }

/// Where the load of the selected month stands.
enum AttendanceLoad { loading, loaded, failed }

/// A single duty session slice within a day, already worded (IST).
@immutable
class AdminDailySession {
  const AdminDailySession({required this.start, required this.end});

  final String start;

  /// "now" while the session is still open.
  final String end;

  String get timeRange => '$start – $end';
}

/// One calendar day's duty and attendance record, worded for its card.
@immutable
class AdminDailyAttendanceItem {
  const AdminDailyAttendanceItem({
    required this.id,
    required this.dayNumber,
    required this.dayOfWeek,
    required this.statusType,
    required this.sessions,
    this.statsText = '',
    this.alertNote,
    this.hasChevron = true,
    this.hasFlag = false,
    this.isInProgress = false,
    this.dateLabel = '',
    this.durationText = '',
    this.distanceText = '',
  });

  /// `yyyy-MM-dd`, which the route view opens on.
  final String id;
  final String dayNumber;
  final String dayOfWeek;
  final AdminDailyStatusType statusType;
  final List<AdminDailySession> sessions;
  final String statsText;
  final String? alertNote;
  final bool hasChevron;
  final bool hasFlag;

  /// A session is still running: the hours are "so far", never final.
  final bool isInProgress;

  /// "Sat, 17 Oct".
  final String dateLabel;

  /// "7h 26m", or "2h 5m so far" while a session is running.
  final String durationText;

  /// "12.3 km", or "— km" when the server could not give it.
  final String distanceText;

  bool get isAbsent => statusType == AdminDailyStatusType.absent;
  bool get isAutoEnded => statusType == AdminDailyStatusType.autoEnded;
  bool get isMultiSession => statusType == AdminDailyStatusType.multiSession;

  /// Words one [AttendanceDay] for its card.
  factory AdminDailyAttendanceItem.fromDay(AttendanceDay day) {
    // The date is already an IST calendar day: never convert it again.
    final weekday = DateLabels.shortDate(day.date).split(',').first; // "Sat"
    if (day.isAbsent) {
      return AdminDailyAttendanceItem(
        id: day.id,
        dayNumber: '${day.date.day}',
        dayOfWeek: weekday,
        statusType: AdminDailyStatusType.absent,
        sessions: const <AdminDailySession>[],
        statsText: DateLabels.longDate(day.date),
        hasChevron: false,
      );
    }

    final km = day.distanceKm;
    final duration =
        '${DutyTimeHelper.formatElapsed(day.duration)}'
        '${day.hasOpenSession ? ' so far' : ''}';
    final distance = km == null
        ? '— km'
        : '${DutyTimeHelper.formatDistanceKm(km)} km';
    final stats = <String>[
      duration,
      distance,
      '${day.visitsCount} ${day.visitsCount == 1 ? 'visit' : 'visits'}',
    ];
    final notes = <String>[
      if (day.endedAutomatically) 'Duty ended automatically',
      if (day.hasFlag)
        '${day.flaggedPoints} flagged '
            '${day.flaggedPoints == 1 ? 'point' : 'points'}',
    ];

    return AdminDailyAttendanceItem(
      id: day.id,
      dayNumber: '${day.date.day}',
      dayOfWeek: weekday,
      statusType: day.endedAutomatically
          ? AdminDailyStatusType.autoEnded
          : day.sessions.length > 1
          ? AdminDailyStatusType.multiSession
          : AdminDailyStatusType.normal,
      sessions: [
        for (final s in day.sessions)
          AdminDailySession(
            start: DutyTimeHelper.formatTime(s.startedAt),
            end: s.endedAt == null
                ? 'now'
                : DutyTimeHelper.formatTime(s.endedAt!),
          ),
      ],
      statsText: stats.join(' · '),
      alertNote: notes.isEmpty ? null : notes.join(' · '),
      hasFlag: day.hasFlag,
      isInProgress: day.hasOpenSession,
      dateLabel: DateLabels.shortDate(day.date),
      durationText: duration,
      distanceText: distance,
    );
  }
}

/// The month's totals, worded for the summary card.
@immutable
class AdminMonthlyMetrics {
  const AdminMonthlyMetrics({
    this.daysWorked = 0,
    this.totalHoursText = '0h 0m',
    this.distanceKm = '0.0 km',
    this.visitsCount = 0,
    this.autoEndedCount = 0,
    this.flagsCount = 0,
  });

  final int daysWorked;
  final String totalHoursText;

  /// "—" when a distance the server could not give would make it wrong.
  final String distanceKm;
  final int visitsCount;
  final int autoEndedCount;
  final int flagsCount;

  factory AdminMonthlyMetrics.fromSummary(AttendanceSummary summary) {
    final km = summary.distanceKm;
    return AdminMonthlyMetrics(
      daysWorked: summary.daysWorked,
      totalHoursText: DutyTimeHelper.formatElapsed(summary.totalDuration),
      distanceKm: km == null
          ? '—'
          : '${DutyTimeHelper.formatDistanceKm(km)} km',
      visitsCount: summary.visitsCount,
      autoEndedCount: summary.autoEndedDays,
      flagsCount: summary.flaggedPoints,
    );
  }
}

/// State of Screen 22 (Duty History & Attendance — Admin) for one employee.
@immutable
class AdminAttendanceState {
  const AdminAttendanceState({
    required this.month,
    this.load = AttendanceLoad.loading,
    this.errorMessage,
    this.metrics = const AdminMonthlyMetrics(),
    this.dailyLogs = const <AdminDailyAttendanceItem>[],
    this.selectedFilter = AdminAttendanceFilter.allDays,
    this.truncated = false,
    this.firstMonth,
  });

  /// First day of the month being viewed (IST).
  final DateTime month;
  final AttendanceLoad load;
  final String? errorMessage;
  final AdminMonthlyMetrics metrics;
  final List<AdminDailyAttendanceItem> dailyLogs;
  final AdminAttendanceFilter selectedFilter;

  /// More sessions exist than could be read for the month.
  final bool truncated;

  /// The month of the employee's first day, once known: nothing exists before.
  final DateTime? firstMonth;

  /// "October 2026".
  String get selectedMonth => '${DateLabels.monthName(month)} ${month.year}';

  bool get isLoaded => load == AttendanceLoad.loaded;

  /// Days with no duty, from the employee's first day up to yesterday.
  int get absentCount => dailyLogs.where((l) => l.isAbsent).length;

  int get autoEndedLogCount => dailyLogs.where((l) => l.isAutoEnded).length;

  /// Days with a flagged point.
  int get flaggedLogCount => dailyLogs.where((l) => l.hasFlag).length;

  /// Filtered subset of daily attendance cards.
  List<AdminDailyAttendanceItem> get filteredDailyLogs {
    switch (selectedFilter) {
      case AdminAttendanceFilter.allDays:
        return dailyLogs;
      case AdminAttendanceFilter.autoEnded:
        return dailyLogs.where((l) => l.isAutoEnded).toList();
      case AdminAttendanceFilter.withFlags:
        return dailyLogs.where((l) => l.hasFlag).toList();
      case AdminAttendanceFilter.absent:
        return dailyLogs.where((l) => l.isAbsent).toList();
    }
  }

  AdminAttendanceState copyWith({
    DateTime? month,
    AttendanceLoad? load,
    String? errorMessage,
    bool clearError = false,
    AdminMonthlyMetrics? metrics,
    List<AdminDailyAttendanceItem>? dailyLogs,
    AdminAttendanceFilter? selectedFilter,
    bool? truncated,
    DateTime? firstMonth,
  }) {
    return AdminAttendanceState(
      month: month ?? this.month,
      load: load ?? this.load,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      metrics: metrics ?? this.metrics,
      dailyLogs: dailyLogs ?? this.dailyLogs,
      selectedFilter: selectedFilter ?? this.selectedFilter,
      truncated: truncated ?? this.truncated,
      firstMonth: firstMonth ?? this.firstMonth,
    );
  }
}
