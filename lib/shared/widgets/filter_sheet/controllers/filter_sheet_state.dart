import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Employee status options for Screen 27 (Filter Bottom Sheet).
enum EmployeeFilterStatus {
  onDuty,
  checkNeeded,
  offDuty,
  stale,
  blocked,
}

extension EmployeeFilterStatusX on EmployeeFilterStatus {
  String get label => switch (this) {
        EmployeeFilterStatus.onDuty => 'On duty 112',
        EmployeeFilterStatus.checkNeeded => 'Check needed 3',
        EmployeeFilterStatus.offDuty => 'Off duty 31',
        EmployeeFilterStatus.stale => 'Stale 4',
        EmployeeFilterStatus.blocked => 'Blocked 2',
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
enum DutyTodayFilter {
  workedToday,
  notStarted,
  autoEnded,
}

extension DutyTodayFilterX on DutyTodayFilter {
  String get label => switch (this) {
        DutyTodayFilter.workedToday => 'Worked today',
        DutyTodayFilter.notStarted => 'Not started',
        DutyTodayFilter.autoEnded => 'Auto-ended',
      };
}

/// Quick date presets in Screen 27.
enum FilterDatePreset {
  today,
  yesterday,
  last7Days,
  thisMonth,
}

extension FilterDatePresetX on FilterDatePreset {
  String get label => switch (this) {
        FilterDatePreset.today => 'Today',
        FilterDatePreset.yesterday => 'Yesterday',
        FilterDatePreset.last7Days => 'Last 7 days',
        FilterDatePreset.thisMonth => 'This month',
      };

  String get defaultDateText => switch (this) {
        FilterDatePreset.today => '12 Oct 2026',
        FilterDatePreset.yesterday => '11 Oct 2026',
        FilterDatePreset.last7Days => '05 Oct 2026 – 12 Oct 2026',
        FilterDatePreset.thisMonth => '01 Oct 2026 – 12 Oct 2026',
      };
}

/// Sorting options in Screen 27.
enum EmployeeSortOption {
  nameAsc,
  employeeId,
  lastActive,
  distanceToday,
}

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
    this.selectedStatuses = const <EmployeeFilterStatus>{
      EmployeeFilterStatus.onDuty,
      EmployeeFilterStatus.checkNeeded,
    },
    this.selectedDutyToday = DutyTodayFilter.workedToday,
    this.selectedDateRange = FilterDatePreset.today,
    this.selectedDateText = '12 Oct 2026',
    this.selectedSort = EmployeeSortOption.nameAsc,
    this.matchingResultsCount = 115,
  });

  final Set<EmployeeFilterStatus> selectedStatuses;
  final DutyTodayFilter? selectedDutyToday;
  final FilterDatePreset selectedDateRange;
  final String selectedDateText;
  final EmployeeSortOption selectedSort;
  final int matchingResultsCount;

  String get resultsButtonLabel => 'Show $matchingResultsCount results';

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
    String? selectedDateText,
    EmployeeSortOption? selectedSort,
    int? matchingResultsCount,
  }) {
    return FilterSheetState(
      selectedStatuses: selectedStatuses ?? this.selectedStatuses,
      selectedDutyToday:
          clearDutyToday ? null : (selectedDutyToday ?? this.selectedDutyToday),
      selectedDateRange: selectedDateRange ?? this.selectedDateRange,
      selectedDateText: selectedDateText ?? this.selectedDateText,
      selectedSort: selectedSort ?? this.selectedSort,
      matchingResultsCount: matchingResultsCount ?? this.matchingResultsCount,
    );
  }
}
