import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_dimens.dart';
import '../../../../../core/theme/app_typography.dart';
import '../controllers/admin_live_map_state.dart';

/// Horizontally scrollable status filter chips bar for Screen 15.
class AdminMapFilterChipsBar extends StatelessWidget {
  const AdminMapFilterChipsBar({
    super.key,
    required this.selectedFilter,
    required this.onFilterSelected,
    this.totalCount = 143,
    this.onDutyCount = 112,
    this.staleCount = 4,
    this.needsCheckCount = 3,
    this.offDutyCount = 31,
    this.blockedCount = 2,
  });

  final AdminMapFilter selectedFilter;
  final ValueChanged<AdminMapFilter> onFilterSelected;
  final int totalCount;
  final int onDutyCount;
  final int staleCount;
  final int needsCheckCount;
  final int offDutyCount;
  final int blockedCount;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4),
        child: Row(
          children: [
            _buildChip(
              filter: AdminMapFilter.all,
              label: 'All $totalCount',
            ),
            const SizedBox(width: AppSpacing.x2),
            _buildChip(
              filter: AdminMapFilter.onDuty,
              label: 'On duty $onDutyCount',
              dotColor: AppColors.success,
            ),
            const SizedBox(width: AppSpacing.x2),
            _buildChip(
              filter: AdminMapFilter.stale,
              label: 'Stale $staleCount',
              dotColor: AppColors.warning,
            ),
            const SizedBox(width: AppSpacing.x2),
            _buildChip(
              filter: AdminMapFilter.needsCheck,
              label: 'Check $needsCheckCount',
              dotColor: AppColors.error,
            ),
            const SizedBox(width: AppSpacing.x2),
            _buildChip(
              filter: AdminMapFilter.offDuty,
              label: 'Off $offDutyCount',
              dotColor: AppColors.neutral400,
            ),
            const SizedBox(width: AppSpacing.x2),
            _buildChip(
              filter: AdminMapFilter.blocked,
              label: 'Blocked $blockedCount',
              dotColor: const Color(0xFF1E293B),
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
