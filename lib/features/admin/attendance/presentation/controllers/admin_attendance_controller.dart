import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/errors/app_exceptions.dart';
import '../../../../../core/utils/duty_time_helper.dart';
import '../../../../../core/utils/phone_clock.dart';
import '../../../../../data/repositories/supabase_attendance_repository.dart';
import '../../../../../domain/entities/attendance_month.dart';
import '../../../../../domain/repositories/attendance_repository.dart';
import 'admin_attendance_state.dart';

/// Provider exposing the source of attendance records.
final attendanceRepositoryProvider = Provider<AttendanceRepository>((ref) {
  return SupabaseAttendanceRepository();
});

/// Provider for Screen 22, one per employee. Auto-disposed with the screen.
final adminAttendanceControllerProvider = NotifierProvider.autoDispose
    .family<AdminAttendanceNotifier, AdminAttendanceState, String>(
      AdminAttendanceNotifier.new,
    );

/// Loads one employee's month of attendance and filters it.
///
/// Every figure is added up from the month's session rows (docs/01 F7), the
/// same rows and the same arithmetic as the route view. Months are IST months.
/// A load overtaken by a newer one (the admin tapping through months) is
/// dropped. Nothing is invented: until the load finishes the screen shows
/// loading, and a failure is an error with Retry, never an empty month.
class AdminAttendanceNotifier extends Notifier<AdminAttendanceState> {
  AdminAttendanceNotifier(this.employeeId);

  final String employeeId;

  /// How far back the month picker goes before the employee's first day is
  /// known (it is known after the first load).
  static const int historyMonths = 24;

  int _request = 0;
  bool _stopped = false;

  DateTime _currentMonthIst() {
    final ist = DutyTimeHelper.toIst(ref.read(phoneClockProvider)());
    return DateTime(ist.year, ist.month);
  }

  @override
  AdminAttendanceState build() {
    ref.onDispose(() => _stopped = true);
    Future<void>.microtask(_load);
    return AdminAttendanceState(month: _currentMonthIst());
  }

  void setFilter(AdminAttendanceFilter filter) {
    state = state.copyWith(selectedFilter: filter);
  }

  /// Loads the month again (after a failure, or to see a fresher "so far").
  Future<void> reload() => _load();

  void previousMonth() {
    final current = _currentMonthIst();
    final earliest = DateTime(current.year, current.month - historyMonths);
    final previous = DateTime(state.month.year, state.month.month - 1);
    if (previous.isBefore(earliest)) return;
    final first = state.firstMonth;
    if (first != null && previous.isBefore(first)) return;
    _select(previous);
  }

  /// Moves forward one month, never past the current month.
  void nextMonth() {
    final next = DateTime(state.month.year, state.month.month + 1);
    if (next.isAfter(_currentMonthIst())) return;
    _select(next);
  }

  void _select(DateTime month) {
    state = AdminAttendanceState(
      month: month,
      selectedFilter: state.selectedFilter,
      firstMonth: state.firstMonth,
    );
    _load();
  }

  Future<void> _load() async {
    if (_stopped) return;
    final ticket = ++_request;
    final month = state.month;
    state = state.copyWith(load: AttendanceLoad.loading, clearError: true);

    // The IST month as a UTC interval (IST has no daylight saving).
    final startUtc = DutyTimeHelper.istDayStartUtc(
      DateTime(month.year, month.month),
    );
    final endUtc = DutyTimeHelper.istDayStartUtc(
      DateTime(month.year, month.month + 1),
    );

    try {
      final source = await ref
          .read(attendanceRepositoryProvider)
          .fetchMonth(
            employeeId: employeeId,
            monthStartUtc: startUtc,
            monthEndUtc: endUtc,
          );
      if (ticket != _request || _stopped) return;

      final built = AttendanceMonth.build(
        month: month,
        sessions: source.sessions,
        serverNow: source.serverNow,
        employeeCreatedAt: source.employeeCreatedAt,
      );
      final created = source.employeeCreatedAt;
      final createdIst = created == null ? null : DutyTimeHelper.toIst(created);
      state = state.copyWith(
        load: AttendanceLoad.loaded,
        metrics: AdminMonthlyMetrics.fromSummary(built.summary),
        dailyLogs: [
          for (final day in built.days) AdminDailyAttendanceItem.fromDay(day),
        ],
        truncated: source.truncated,
        firstMonth: createdIst == null
            ? null
            : DateTime(createdIst.year, createdIst.month),
      );
    } on AppException catch (e) {
      if (ticket != _request || _stopped) return;
      state = state.copyWith(
        load: AttendanceLoad.failed,
        errorMessage: e.message,
      );
    } catch (e, st) {
      if (ticket != _request || _stopped) return;
      debugPrint('AdminAttendance: could not load: $e\n$st');
      state = state.copyWith(
        load: AttendanceLoad.failed,
        errorMessage: 'Could not load the attendance. Please try again.',
      );
    }
  }
}
