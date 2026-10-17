import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/errors/app_exceptions.dart';
import '../../../../../data/repositories/supabase_employee_repository.dart';
import '../../../../../domain/entities/live_position.dart';
import '../../../../../domain/repositories/employee_repository.dart';
import 'admin_employee_list_state.dart';

/// Provider exposing the employee repository.
final employeeRepositoryProvider = Provider<EmployeeRepository>((ref) {
  return SupabaseEmployeeRepository();
});

/// Provider exposing the administrative employee roster controller.
final adminEmployeeListControllerProvider =
    NotifierProvider<AdminEmployeeListNotifier, AdminEmployeeListState>(
      AdminEmployeeListNotifier.new,
    );

/// Riverpod 3 Notifier managing roster filtering, search queries, and status filters.
class AdminEmployeeListNotifier extends Notifier<AdminEmployeeListState> {
  /// What the live feed last said about everyone on duty (employee id to
  /// status), or null before it has said anything reliable. Kept so a reload of
  /// the roster does not bring back the older, one-off picture.
  Map<String, LiveStatus>? _live;

  @override
  AdminEmployeeListState build() {
    return const AdminEmployeeListState(
      selectedFilter: AdminEmployeeFilter.active,
      searchQuery: '',
      filterActiveOnly: true,
      filterTuneBadgeCount: 1,
    );
  }

  /// Loads the roster from the server. A failure is kept in
  /// [AdminEmployeeListState.errorMessage] so the screen can offer a retry;
  /// it is never shown as an empty team.
  Future<void> loadEmployees({bool force = false}) async {
    if (state.isLoading) return;
    if (!force && state.hasLoaded) return;

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final items = await ref.read(employeeRepositoryProvider).getEmployees();
      state = state.copyWith(
        employees: _withLive(items),
        isLoading: false,
        hasLoaded: true,
      );
    } on AppException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Could not load the team. Please try again.',
      );
    }
  }

  /// Shows who is on duty as the live feed says it now, the same people and the
  /// same wording as the live map: someone on duty is "On duty", "No update" or
  /// "Check needed" (a flagged position); everyone else, not blocked, is off
  /// duty. The roster only records who was on duty when it was read.
  ///
  /// Call it only when the live feed has loaded: an unknown feed must never
  /// turn everyone "off duty".
  void applyLiveStatuses(Map<String, LiveStatus> live) {
    _live = live;
    if (!state.hasLoaded) return;
    final updated = _withLive(state.employees);
    final changed = !_sameStatuses(state.employees, updated);
    if (changed) state = state.copyWith(employees: updated);
  }

  List<AdminEmployeeItem> _withLive(List<AdminEmployeeItem> items) {
    final live = _live;
    if (live == null) return items;
    return [
      for (final employee in items)
        if (!employee.isActive ||
            employee.status == AdminEmployeeStatus.blocked)
          employee
        else
          _liveItem(employee, live[employee.id]),
    ];
  }

  AdminEmployeeItem _liveItem(AdminEmployeeItem employee, LiveStatus? live) {
    final status = switch (live) {
      null => AdminEmployeeStatus.offDuty,
      LiveStatus.active => AdminEmployeeStatus.onDuty,
      LiveStatus.stale => AdminEmployeeStatus.stale,
      LiveStatus.suspect => AdminEmployeeStatus.needsCheck,
    };
    final flagged = live == LiveStatus.suspect;
    if (status == employee.status && flagged == employee.hasFlags) {
      return employee;
    }
    return employee.copyWith(status: status, hasFlags: flagged);
  }

  bool _sameStatuses(List<AdminEmployeeItem> a, List<AdminEmployeeItem> b) {
    for (var i = 0; i < a.length; i++) {
      if (!identical(a[i], b[i])) return false;
    }
    return true;
  }

  void setFilter(AdminEmployeeFilter filter) {
    state = state.copyWith(selectedFilter: filter);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void clearSearch() {
    state = state.copyWith(searchQuery: '');
  }

  void removeActiveOnlyFilter() {
    state = state.copyWith(filterActiveOnly: false);
  }

  void clearAllFilters() {
    state = state.copyWith(
      selectedFilter: AdminEmployeeFilter.active,
      searchQuery: '',
      filterActiveOnly: false,
    );
  }

  void addEmployee(AdminEmployeeItem employee) {
    state = state.copyWith(
      employees: <AdminEmployeeItem>[employee, ...state.employees],
    );
  }

  /// Applies server-confirmed edits (name, phone, email). Duty status and
  /// block state are kept from the roster, since an edit does not change them.
  void updateEmployee(AdminEmployeeItem updated) {
    state = state.copyWith(
      employees: state.employees.map((e) {
        if (e.id != updated.id) return e;
        return AdminEmployeeItem(
          id: e.id,
          name: updated.name,
          employeeCode: e.employeeCode,
          phoneNumber: updated.phoneNumber,
          status: e.status,
          isActive: e.isActive,
          hasFlags: e.hasFlags,
          dutyStartTime: e.dutyStartTime,
          distanceTodayKm: e.distanceTodayKm,
          locationName: e.locationName,
          email: updated.email,
          role: e.role,
        );
      }).toList(),
    );
  }

  /// Blocks [employeeId] on the server first; the roster changes only once the
  /// server confirms. Throws the repository's `AppException` on failure so the
  /// caller can show it.
  Future<void> blockEmployee({
    required String employeeId,
    required String reason,
  }) async {
    await ref
        .read(employeeRepositoryProvider)
        .blockEmployee(id: employeeId, reason: reason);
    state = state.copyWith(
      employees: state.employees.map((e) {
        if (e.id != employeeId) return e;
        return AdminEmployeeItem(
          id: e.id,
          name: e.name,
          employeeCode: e.employeeCode,
          phoneNumber: e.phoneNumber,
          status: AdminEmployeeStatus.blocked,
          isActive: false,
          distanceTodayKm: e.distanceTodayKm,
          locationName: 'Blocked ($reason)',
          email: e.email,
          role: e.role,
        );
      }).toList(),
    );
  }

  /// Restores [employeeId] on the server first, then in the roster.
  Future<void> unblockEmployee({required String employeeId}) async {
    await ref.read(employeeRepositoryProvider).unblockEmployee(id: employeeId);
    state = state.copyWith(
      employees: state.employees.map((e) {
        if (e.id != employeeId) return e;
        return AdminEmployeeItem(
          id: e.id,
          name: e.name,
          employeeCode: e.employeeCode,
          phoneNumber: e.phoneNumber,
          status: AdminEmployeeStatus.offDuty,
          distanceTodayKm: e.distanceTodayKm,
          email: e.email,
          role: e.role,
        );
      }).toList(),
    );
  }
}
