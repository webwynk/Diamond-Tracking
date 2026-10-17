import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_labels.dart';

/// Employee status options for Screen 27 (Filter Bottom Sheet).
enum EmployeeFilterStatus { onDuty, checkNeeded, offDuty, stale, blocked }

extension EmployeeFilterStatusX on EmployeeFilterStatus {
  String get label => switch (this) {
    EmployeeFilterStatus.onDuty => 'On duty',
    EmployeeFilterStatus.checkNeeded => 'Check needed',
    EmployeeFilterStatus.offDuty => 'Off duty',
    EmployeeFilterStatus.stale => 'Stale',
    EmployeeFilterStatus.blocked => 'Blocked',
  };

  Color get dotColor => switch (this) {
    EmployeeFilterStatus.onDuty => AppColors.statusActive,
    EmployeeFilterStatus.checkNeeded => AppColors.statusStale,
    EmployeeFilterStatus.offDuty => AppColors.statusOff,
    EmployeeFilterStatus.stale => AppColors.statusStale,
    EmployeeFilterStatus.blocked => AppColors.statusBlocked,
  };
}

/// Duty today options in Screen 27.
enum DutyTodayFilter { workedToday, notStarted, autoEnded }

extension DutyTodayFilterX on DutyTodayFilter {
  String get label => switch (this) {
    DutyTodayFilter.workedToday => 'Worked today',
    DutyTodayFilter.notStarted => 'Not started',
    DutyTodayFilter.autoEnded => 'Auto-ended',
  };
}

/// Quick date presets in Screen 27.
enum FilterDatePreset { today, yesterday, last7Days, thisMonth }

extension FilterDatePresetX on FilterDatePreset {
  String get label => switch (this) {
    FilterDatePreset.today => 'Today',
    FilterDatePreset.yesterday => 'Yesterday',
    FilterDatePreset.last7Days => 'Last 7 days',
    FilterDatePreset.thisMonth => 'This month',
  };

  /// The range this preset covers, as display text, for a given "today".
  String dateText(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    return switch (this) {
      FilterDatePreset.today => DateLabels.dayMonthYear(today),
      FilterDatePreset.yesterday => DateLabels.dayMonthYear(
        today.subtract(const Duration(days: 1)),
      ),
      FilterDatePreset.last7Days =>
        '${DateLabels.dayMonthYear(today.subtract(const Duration(days: 6)))} – ${DateLabels.dayMonthYear(today)}',
      FilterDatePreset.thisMonth =>
        '${DateLabels.dayMonthYear(DateTime(now.year, now.month))} – ${DateLabels.dayMonthYear(today)}',
    };
  }
}

/// Sorting options in Screen 27.
enum EmployeeSortOption { nameAsc, employeeId, lastActive, distanceToday }

extension EmployeeSortOptionX on EmployeeSortOption {
  String get label => switch (this) {
    EmployeeSortOption.nameAsc => 'Name (A–Z)',
    EmployeeSortOption.employeeId => 'Employee ID',
    EmployeeSortOption.lastActive => 'Last active',
    EmployeeSortOption.distanceToday => 'Distance today',
  };
}

/// Immutable state for Screen 27 Filter Bottom Sheet.
@immutable
class FilterSheetState {
  const FilterSheetState({
    this.selectedStatuses = const <EmployeeFilterStatus>{},
    this.selectedDutyToday,
    this.selectedDateRange = FilterDatePreset.today,
    this.selectedSort = EmployeeSortOption.nameAsc,
  });

  final Set<EmployeeFilterStatus> selectedStatuses;
  final DutyTodayFilter? selectedDutyToday;
  final FilterDatePreset selectedDateRange;
  final EmployeeSortOption selectedSort;

  /// Display text for the chosen date preset, from the clock.
  String get selectedDateText => selectedDateRange.dateText(DateTime.now());

  bool get hasActiveFilters =>
      selectedStatuses.isNotEmpty ||
      selectedDutyToday != null ||
      selectedDateRange != FilterDatePreset.today ||
      selectedSort != EmployeeSortOption.nameAsc;

  FilterSheetState copyWith({
    Set<EmployeeFilterStatus>? selectedStatuses,
    DutyTodayFilter? selectedDutyToday,
    bool clearDutyToday = false,
    FilterDatePreset? selectedDateRange,
    EmployeeSortOption? selectedSort,
  }) {
    return FilterSheetState(
      selectedStatuses: selectedStatuses ?? this.selectedStatuses,
      selectedDutyToday: clearDutyToday
          ? null
          : (selectedDutyToday ?? this.selectedDutyToday),
      selectedDateRange: selectedDateRange ?? this.selectedDateRange,
      selectedSort: selectedSort ?? this.selectedSort,
    );
  }
}
