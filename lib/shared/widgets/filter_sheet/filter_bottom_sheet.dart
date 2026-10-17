import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import 'controllers/filter_sheet_controller.dart';
import 'controllers/filter_sheet_state.dart';
import 'widgets/filter_date_range_section.dart';
import 'widgets/filter_duty_chips.dart';
import 'widgets/filter_sheet_header.dart';
import 'widgets/filter_sort_radio_group.dart';
import 'widgets/filter_status_chips.dart';

/// Screen 27: Filter Bottom Sheet modal component.
///
/// Provides reusable multi-criteria filtering across employee status,
/// duty state, date ranges, and sorting.
class FilterBottomSheet extends ConsumerStatefulWidget {
  const FilterBottomSheet({super.key, this.initialState});

  final FilterSheetState? initialState;

  /// Helper method to present the modal sheet.
  static Future<FilterSheetState?> show(
    BuildContext context, {
    FilterSheetState? initialState,
  }) {
    return showModalBottomSheet<FilterSheetState>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x660F172A),
      builder: (BuildContext ctx) =>
          FilterBottomSheet(initialState: initialState),
    );
  }

  @override
  ConsumerState<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends ConsumerState<FilterBottomSheet> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialState != null) {
        ref
            .read(filterSheetControllerProvider.notifier)
            .initialize(widget.initialState);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(filterSheetControllerProvider);
    final notifier = ref.read(filterSheetControllerProvider.notifier);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.85;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.xlTop,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // Header with Drag Handle & "Clear all"
          FilterSheetHeader(onClearAll: notifier.clearAll),

          // Scrollable filter criteria
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.x4,
                vertical: AppSpacing.x4,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  FilterStatusChips(
                    selectedStatuses: state.selectedStatuses,
                    onStatusToggled: notifier.toggleStatus,
                  ),
                  const SizedBox(height: AppSpacing.x6),
                  FilterDutyChips(
                    selectedDutyToday: state.selectedDutyToday,
                    onDutyToggled: notifier.setDutyToday,
                  ),
                  const SizedBox(height: AppSpacing.x6),
                  FilterDateRangeSection(
                    selectedPreset: state.selectedDateRange,
                    dateText: state.selectedDateText,
                    onPresetSelected: notifier.setDatePreset,
                  ),
                  const SizedBox(height: AppSpacing.x6),
                  FilterSortRadioGroup(
                    selectedSort: state.selectedSort,
                    onSortSelected: notifier.setSortOption,
                  ),
                  const SizedBox(height: AppSpacing.x6),
                ],
              ),
            ),
          ),

          // Pinned bottom action bar
          Container(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.x4,
              AppSpacing.x4,
              AppSpacing.x4,
              bottomInset > 0 ? bottomInset + 8 : AppSpacing.x6,
            ),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(
                top: BorderSide(color: AppColors.neutral200, width: 1),
              ),
            ),
            child: Row(
              children: <Widget>[
                // Reset Button
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      key: const Key('btn-filters-reset'),
                      onPressed: notifier.reset,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.neutral300),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                        ),
                      ),
                      child: Text(
                        'Reset',
                        style: AppTypography.label.copyWith(
                          color: AppColors.neutral700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.x3),

                // Apply / Show Results Button
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      key: const Key('btn-filters-apply'),
                      onPressed: () {
                        Navigator.of(context).pop(state);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary600,
                        foregroundColor: AppColors.surface,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                        ),
                      ),
                      child: Text(
                        'Apply filters',
                        style: AppTypography.label.copyWith(
                          color: AppColors.surface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
