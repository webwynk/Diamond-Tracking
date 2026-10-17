import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';
import '../controllers/duty_history_state.dart';

/// Horizontally scrolling row of 32 dp capsule filter chips adhering to
/// Screen 12 design specifications.
class HistoryFilterChipsBar extends StatelessWidget {
  const HistoryFilterChipsBar({
    super.key,
    required this.selectedFilter,
    required this.onFilterSelected,
  });

  final DutyHistoryFilter selectedFilter;
  final ValueChanged<DutyHistoryFilter> onFilterSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x4,
        vertical: AppSpacing.x3,
      ),
      child: Row(
        children: [
          for (final filter in DutyHistoryFilter.values)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.x2),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  key: Key('filter-chip-${filter.name}'),
                  onTap: () => onFilterSelected(filter),
                  borderRadius: AppRadius.fullAll,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    height: 32,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.x4,
                    ),
                    decoration: BoxDecoration(
                      color: filter == selectedFilter
                          ? AppColors.primary600
                          : AppColors.surface,
                      borderRadius: AppRadius.fullAll,
                      border: Border.all(
                        color: filter == selectedFilter
                            ? AppColors.primary600
                            : AppColors.neutral300,
                        width: 1,
                      ),
                      boxShadow: filter == selectedFilter
                          ? [
                              BoxShadow(
                                color: AppColors.primary600.withValues(
                                  alpha: 0.15,
                                ),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      filter.label,
                      style: AppTypography.label.copyWith(
                        color: filter == selectedFilter
                            ? AppColors.neutral0
                            : AppColors.neutral600,
                        fontWeight: filter == selectedFilter
                            ? FontWeight.w600
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
