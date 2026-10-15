import 'package:flutter/foundation.dart';

/// Status classification for an individual day on the admin attendance log.
enum AdminDailyStatusType {
  normal,
  autoEnded,
  multiSession,
  absent,
}

/// Filter mode for the daily attendance cards stream.
enum AdminAttendanceFilter {
  allDays,
  autoEnded,
  withFlags,
  absent,
}

/// A single duty session slice within a day.
@immutable
class AdminDailySession {
  const AdminDailySession({
    required this.start,
    required this.end,
  });

  final String start;
  final String end;

  String get timeRange => '$start – $end';
}

/// Domain entity representing one calendar day's duty and attendance record.
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
  });

  final String id;
  final String dayNumber;
  final String dayOfWeek;
  final AdminDailyStatusType statusType;
  final List<AdminDailySession> sessions;
  final String statsText;
  final String? alertNote;
  final bool hasChevron;
  final bool hasFlag;

  bool get isAbsent => statusType == AdminDailyStatusType.absent;
  bool get isAutoEnded => statusType == AdminDailyStatusType.autoEnded;
  bool get isMultiSession => statusType == AdminDailyStatusType.multiSession;
}

/// Cumulative monthly telemetry audit metrics.
@immutable
class AdminMonthlyMetrics {
  const AdminMonthlyMetrics({
    required this.daysWorked,
    required this.totalHoursText,
    required this.distanceKm,
    required this.visitsCount,
    required this.autoEndedCount,
    required this.flagsCount,
    required this.payableHoursText,
    required this.payableAmountText,
  });

  final int daysWorked;
  final String totalHoursText;
  final String distanceKm;
  final int visitsCount;
  final int autoEndedCount;
  final int flagsCount;
  final String payableHoursText;
  final String payableAmountText;
}

/// State representation for Screen 22 (Duty History & Attendance — Admin).
@immutable
class AdminAttendanceState {
  const AdminAttendanceState({
    required this.employeeName,
    required this.employeeCode,
    required this.roleSubtitle,
    required this.selectedMonth,
    required this.metrics,
    required this.dailyLogs,
    this.selectedFilter = AdminAttendanceFilter.allDays,
    this.isMonthApproved = false,
    this.hasDiscrepancy = true,
  });

  final String employeeName;
  final String employeeCode;
  final String roleSubtitle;
  final String selectedMonth;
  final AdminMonthlyMetrics metrics;
  final List<AdminDailyAttendanceItem> dailyLogs;
  final AdminAttendanceFilter selectedFilter;
  final bool isMonthApproved;
  final bool hasDiscrepancy;

  String get employeeInitials {
    final parts = employeeName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts[0].isEmpty) return 'EM';
    if (parts.length == 1) {
      return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    }
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }

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
    String? employeeName,
    String? employeeCode,
    String? roleSubtitle,
    String? selectedMonth,
    AdminMonthlyMetrics? metrics,
    List<AdminDailyAttendanceItem>? dailyLogs,
    AdminAttendanceFilter? selectedFilter,
    bool? isMonthApproved,
    bool? hasDiscrepancy,
  }) {
    return AdminAttendanceState(
      employeeName: employeeName ?? this.employeeName,
      employeeCode: employeeCode ?? this.employeeCode,
      roleSubtitle: roleSubtitle ?? this.roleSubtitle,
      selectedMonth: selectedMonth ?? this.selectedMonth,
      metrics: metrics ?? this.metrics,
      dailyLogs: dailyLogs ?? this.dailyLogs,
      selectedFilter: selectedFilter ?? this.selectedFilter,
      isMonthApproved: isMonthApproved ?? this.isMonthApproved,
      hasDiscrepancy: hasDiscrepancy ?? this.hasDiscrepancy,
    );
  }
}
