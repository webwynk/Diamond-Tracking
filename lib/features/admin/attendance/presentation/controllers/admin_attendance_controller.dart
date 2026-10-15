import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'admin_attendance_state.dart';

/// Provider exposing the administrative attendance and payroll audit controller.
final adminAttendanceControllerProvider =
    NotifierProvider<AdminAttendanceNotifier, AdminAttendanceState>(
  AdminAttendanceNotifier.new,
);

/// Riverpod 3 Notifier managing monthly attendance records, filtering, and payroll approvals.
class AdminAttendanceNotifier extends Notifier<AdminAttendanceState> {
  @override
  AdminAttendanceState build() {
    return AdminAttendanceState(
      employeeName: 'Suresh Patel',
      employeeCode: 'DA-022',
      roleSubtitle: 'Agronomist · Nashik Central Beat',
      selectedMonth: 'October 2026',
      metrics: const AdminMonthlyMetrics(
        daysWorked: 12,
        totalHoursText: '96h 40m',
        distanceKm: '578.3 km',
        visitsCount: 54,
        autoEndedCount: 1,
        flagsCount: 0,
        payableHoursText: '96h 40m',
        payableAmountText: '₹14,500 Base',
      ),
      dailyLogs: _buildDefaultDailyLogs(),
      selectedFilter: AdminAttendanceFilter.allDays,
      isMonthApproved: false,
      hasDiscrepancy: true,
    );
  }

  void setFilter(AdminAttendanceFilter filter) {
    state = state.copyWith(selectedFilter: filter);
  }

  void previousMonth() {
    if (state.selectedMonth == 'October 2026') {
      state = state.copyWith(selectedMonth: 'September 2026');
    } else if (state.selectedMonth == 'September 2026') {
      state = state.copyWith(selectedMonth: 'August 2026');
    }
  }

  void nextMonth() {
    if (state.selectedMonth == 'August 2026') {
      state = state.copyWith(selectedMonth: 'September 2026');
    } else if (state.selectedMonth == 'September 2026') {
      state = state.copyWith(selectedMonth: 'October 2026');
    }
  }

  void approveMonth() {
    state = state.copyWith(
      isMonthApproved: true,
      hasDiscrepancy: false,
    );
  }

  void adjustPayableHours({
    required String hours,
    required String amount,
  }) {
    state = state.copyWith(
      metrics: AdminMonthlyMetrics(
        daysWorked: state.metrics.daysWorked,
        totalHoursText: state.metrics.totalHoursText,
        distanceKm: state.metrics.distanceKm,
        visitsCount: state.metrics.visitsCount,
        autoEndedCount: state.metrics.autoEndedCount,
        flagsCount: state.metrics.flagsCount,
        payableHoursText: hours,
        payableAmountText: amount,
      ),
    );
  }

  void resolveDiscrepancy() {
    state = state.copyWith(hasDiscrepancy: false);
  }

  List<AdminDailyAttendanceItem> _buildDefaultDailyLogs() {
    return const <AdminDailyAttendanceItem>[
      // Day 1: 11 / Sat — Normal complete
      AdminDailyAttendanceItem(
        id: 'day-11',
        dayNumber: '11',
        dayOfWeek: 'Sat',
        statusType: AdminDailyStatusType.normal,
        sessions: [
          AdminDailySession(start: '8:04 AM', end: '6:12 PM'),
        ],
        statsText: '8h 08m · 47.3 km · 5 visits',
        hasChevron: true,
      ),

      // Day 2: 10 / Fri — Auto-ended Discrepancy
      AdminDailyAttendanceItem(
        id: 'day-10',
        dayNumber: '10',
        dayOfWeek: 'Fri',
        statusType: AdminDailyStatusType.autoEnded,
        sessions: [
          AdminDailySession(start: '8:00 AM', end: '11:00 PM'),
        ],
        statsText: '15h 00m · 96.4 km · 9 visits',
        alertNote: 'Exceeded shift threshold (14h cap applied)',
        hasChevron: true,
        hasFlag: true,
      ),

      // Day 3: 09 / Thu — Two duty sessions in one day
      AdminDailyAttendanceItem(
        id: 'day-09',
        dayNumber: '09',
        dayOfWeek: 'Thu',
        statusType: AdminDailyStatusType.multiSession,
        sessions: [
          AdminDailySession(start: '8:02 AM', end: '1:10 PM'),
          AdminDailySession(start: '2:30 PM', end: '6:40 PM'),
        ],
        statsText: 'Cumulative: 9h 18m · 54.2 km · 6 visits',
        hasChevron: true,
      ),

      // Day 4: 08 / Wed — Absent / Weekly Off
      AdminDailyAttendanceItem(
        id: 'day-08',
        dayNumber: '08',
        dayOfWeek: 'Wed',
        statusType: AdminDailyStatusType.absent,
        sessions: [],
        statsText: 'Scheduled weekly rest / Non-operational',
        hasChevron: false,
      ),

      // Day 5: 07 / Tue — Normal complete
      AdminDailyAttendanceItem(
        id: 'day-07',
        dayNumber: '07',
        dayOfWeek: 'Tue',
        statusType: AdminDailyStatusType.normal,
        sessions: [
          AdminDailySession(start: '8:15 AM', end: '5:45 PM'),
        ],
        statsText: '9h 30m · 51.0 km · 6 visits',
        hasChevron: true,
      ),
    ];
  }
}
