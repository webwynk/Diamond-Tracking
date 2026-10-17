import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_dimens.dart';
import '../../../../../core/theme/app_typography.dart';
import '../controllers/admin_live_map_state.dart';

/// Horizontally scrollable status filter chips bar for the live map.
///
/// Only people on duty have a position, so there are no off-duty or blocked
/// chips: the Team list shows those.
class AdminMapFilterChipsBar extends StatelessWidget {
  const AdminMapFilterChipsBar({
    super.key,
    required this.selectedFilter,
    required this.onFilterSelected,
    required this.totalCount,
    required this.onDutyCount,
    required this.staleCount,
    required this.needsCheckCount,
  });

  final AdminMapFilter selectedFilter;
  final ValueChanged<AdminMapFilter> onFilterSelected;
  final int totalCount;
  final int onDutyCount;
  final int staleCount;
  final int needsCheckCount;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4),
        child: Row(
          children: [
            _buildChip(filter: AdminMapFilter.all, label: 'All $totalCount'),
            const SizedBox(width: AppSpacing.x2),
            _buildChip(
              filter: AdminMapFilter.onDuty,
              label: 'On duty $onDutyCount',
              dotColor: AppColors.statusActive,
            ),
            const SizedBox(width: AppSpacing.x2),
            _buildChip(
              filter: AdminMapFilter.stale,
              label: 'Stale $staleCount',
              dotColor: AppColors.statusStale,
            ),
            const SizedBox(width: AppSpacing.x2),
            _buildChip(
              filter: AdminMapFilter.needsCheck,
              label: 'Check $needsCheckCount',
              dotColor: AppColors.statusSuspect,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip({
    required AdminMapFilter filter,
    required String label,
    Color? dotColor,
  }) {
    final isSelected = selectedFilter == filter;

    return InkWell(
      key: Key('chip-admin-map-${filter.name}'),
      onTap: () => onFilterSelected(filter),
      borderRadius: AppRadius.fullAll,
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary600 : AppColors.surface,
          borderRadius: AppRadius.fullAll,
          border: Border.all(
            color: isSelected ? AppColors.primary600 : AppColors.neutral300,
            width: 1,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x08000000),
              blurRadius: 4,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (dotColor != null) ...[
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: AppTypography.label.copyWith(
                color: isSelected ? AppColors.neutral0 : AppColors.textPrimary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
