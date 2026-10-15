import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'filter_sheet_state.dart';

/// Riverpod 3 Notifier managing Filter Bottom Sheet state.
class FilterSheetNotifier extends Notifier<FilterSheetState> {
  @override
  FilterSheetState build() {
    return const FilterSheetState();
  }

  void initialize(FilterSheetState? initialState) {
    if (initialState != null) {
      state = initialState;
    }
  }

  void toggleStatus(EmployeeFilterStatus status) {
    final updated = Set<EmployeeFilterStatus>.from(state.selectedStatuses);
    if (updated.contains(status)) {
      updated.remove(status);
    } else {
      updated.add(status);
    }
    // Calculate dynamic matching results count (simulation: e.g. base 112 for onDuty, +3 for checkNeeded, etc.)
    var count = 0;
    if (updated.contains(EmployeeFilterStatus.onDuty)) count += 112;
    if (updated.contains(EmployeeFilterStatus.checkNeeded)) count += 3;
    if (updated.contains(EmployeeFilterStatus.offDuty)) count += 31;
    if (updated.contains(EmployeeFilterStatus.stale)) count += 4;
    if (updated.contains(EmployeeFilterStatus.blocked)) count += 2;
    if (updated.isEmpty) count = 143;

    state = state.copyWith(
      selectedStatuses: updated,
      matchingResultsCount: count,
    );
  }

  void setDutyToday(DutyTodayFilter filter) {
    if (state.selectedDutyToday == filter) {
      state = state.copyWith(clearDutyToday: true);
    } else {
      state = state.copyWith(selectedDutyToday: filter);
    }
  }

  void setDatePreset(FilterDatePreset preset) {
    state = state.copyWith(
      selectedDateRange: preset,
      selectedDateText: preset.defaultDateText,
    );
  }

  void setSortOption(EmployeeSortOption option) {
    state = state.copyWith(selectedSort: option);
  }

  void clearAll() {
    state = state.copyWith(
      selectedStatuses: const <EmployeeFilterStatus>{},
      clearDutyToday: true,
      selectedDateRange: FilterDatePreset.today,
      selectedDateText: FilterDatePreset.today.defaultDateText,
      selectedSort: EmployeeSortOption.nameAsc,
      matchingResultsCount: 143,
    );
  }

  void reset() {
    state = const FilterSheetState();
  }
}

/// Provider for Filter Bottom Sheet state notifier.
final filterSheetControllerProvider =
    NotifierProvider<FilterSheetNotifier, FilterSheetState>(
  FilterSheetNotifier.new,
);
