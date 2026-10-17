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
    state = state.copyWith(selectedStatuses: updated);
  }

  void setDutyToday(DutyTodayFilter filter) {
    if (state.selectedDutyToday == filter) {
      state = state.copyWith(clearDutyToday: true);
    } else {
      state = state.copyWith(selectedDutyToday: filter);
    }
  }

  void setDatePreset(FilterDatePreset preset) {
    state = state.copyWith(selectedDateRange: preset);
  }

  void setSortOption(EmployeeSortOption option) {
    state = state.copyWith(selectedSort: option);
  }

  void clearAll() {
    state = state.copyWith(
      selectedStatuses: const <EmployeeFilterStatus>{},
      clearDutyToday: true,
      selectedDateRange: FilterDatePreset.today,
      selectedSort: EmployeeSortOption.nameAsc,
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
