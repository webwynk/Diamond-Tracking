import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_dimens.dart';
import '../../../../../core/theme/app_typography.dart';
import '../controllers/admin_employee_list_state.dart';

/// Pinned search bar, horizontal filter chips, and active-filter modifier strip.
class AdminEmployeeSearchFilterBar extends StatelessWidget {
  const AdminEmployeeSearchFilterBar({
    super.key,
    required this.selectedFilter,
    required this.searchQuery,
    required this.filterActiveOnly,
    required this.filteredCount,
    required this.totalCount,
    required this.activeCount,
    required this.onDutyCount,
    required this.offDutyCount,
    required this.blockedCount,
    required this.hasFlagsCount,
    required this.onFilterSelected,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onRemoveActiveOnly,
    required this.onClearAll,
  });

  final AdminEmployeeFilter selectedFilter;
  final String searchQuery;
  final bool filterActiveOnly;
  final int filteredCount;
  final int totalCount;
  final int activeCount;
  final int onDutyCount;
  final int offDutyCount;
  final int blockedCount;
  final int hasFlagsCount;

  final ValueChanged<AdminEmployeeFilter> onFilterSelected;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final VoidCallback onRemoveActiveOnly;
  final VoidCallback onClearAll;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x4,
        vertical: AppSpacing.x3,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Search Bar (48dp height, 12dp radius, 1px #CBD5E1 border)
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.neutral300, width: 1.0),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                const Icon(
                  Icons.search_rounded,
                  color: AppColors.textDisabled,
                  size: 22,
                ),
                const SizedBox(width: AppSpacing.x2),
                Expanded(
                  child: TextField(
                    key: const Key('input-employee-search'),
                    controller: TextEditingController.fromValue(
                      TextEditingValue(
                        text: searchQuery,
                        selection: TextSelection.collapsed(
                          offset: searchQuery.length,
                        ),
                      ),
                    ),
                    onChanged: onSearchChanged,
                    style: AppTypography.bodyLarge.copyWith(
                      color: AppColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search field officers',
                      hintStyle: AppTypography.bodyLarge.copyWith(
                        color: AppColors.textDisabled,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                if (searchQuery.isNotEmpty)
                  GestureDetector(
                    key: const Key('btn-employee-search-clear'),
                    onTap: onClearSearch,
                    child: const Icon(
                      Icons.cancel_rounded,
                      color: AppColors.textDisabled,
                      size: 18,
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.x2),

          // 2. Horizontal Filter Chips (32dp tall)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildChip(
                  key: const Key('chip-employee-filter-active'),
                  filter: AdminEmployeeFilter.active,
                  label: 'Active $activeCount',
                ),
                const SizedBox(width: AppSpacing.x2),
                _buildChip(
                  key: const Key('chip-employee-filter-onduty'),
                  filter: AdminEmployeeFilter.onDuty,
                  label: 'On duty $onDutyCount',
                ),
                const SizedBox(width: AppSpacing.x2),
                _buildChip(
                  key: const Key('chip-employee-filter-offduty'),
                  filter: AdminEmployeeFilter.offDuty,
                  label: 'Off duty $offDutyCount',
                ),
                const SizedBox(width: AppSpacing.x2),
                _buildChip(
                  key: const Key('chip-employee-filter-blocked'),
                  filter: AdminEmployeeFilter.blocked,
                  label: 'Blocked $blockedCount',
                ),
                const SizedBox(width: AppSpacing.x2),
                _buildChip(
                  key: const Key('chip-employee-filter-flags'),
                  filter: AdminEmployeeFilter.hasFlags,
                  label: 'Has flags $hasFlagsCount',
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.x2),

          // 3. Active-Filter Modifier Row & Showing Counter
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (filterActiveOnly) ...[
                    Container(
                      key: const Key('pill-employee-active-only'),
                      height: 28,
                      padding: const EdgeInsets.only(left: 10, right: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary50,
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Active only',
                            style: AppTypography.label.copyWith(
                              color: AppColors.primary600,
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 2),
                          GestureDetector(
                            key: const Key('btn-remove-active-only'),
                            onTap: onRemoveActiveOnly,
                            child: const Padding(
                              padding: EdgeInsets.all(2.0),
                              child: Icon(
                                Icons.close_rounded,
                                size: 14,
                                color: AppColors.primary600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.x2),
                  ],
                  GestureDetector(
                    key: const Key('btn-employee-clear-all'),
                    onTap: onClearAll,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      child: Text(
                        'Clear all',
                        style: AppTypography.label.copyWith(
                          color: AppColors.primary600,
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              // Showing Counter
              Text(
                'Showing $filteredCount of $totalCount',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChip({
    required Key key,
    required AdminEmployeeFilter filter,
    required String label,
  }) {
    final isSelected = selectedFilter == filter;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: key,
        borderRadius: BorderRadius.circular(AppRadius.full),
        onTap: () => onFilterSelected(filter),
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary600 : AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.full),
            border: Border.all(
              color: isSelected ? AppColors.primary600 : AppColors.neutral300,
              width: 1.0,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: AppTypography.label.copyWith(
              color: isSelected ? Colors.white : AppColors.neutral600,
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}
