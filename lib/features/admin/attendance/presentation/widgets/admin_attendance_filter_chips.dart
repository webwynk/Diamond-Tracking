import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_dimens.dart';
import '../../../../../core/theme/app_typography.dart';
import '../controllers/admin_attendance_state.dart';

/// Horizontally scrolling 32 dp filter chips bar for Screen 22.
class AdminAttendanceFilterChips extends StatelessWidget {
  const AdminAttendanceFilterChips({
    super.key,
    required this.selectedFilter,
    required this.onSelectFilter,
    required this.totalDaysCount,
    required this.autoEndedCount,
    required this.flagsCount,
    required this.absentCount,
  });

  final AdminAttendanceFilter selectedFilter;
  final ValueChanged<AdminAttendanceFilter> onSelectFilter;
  final int totalDaysCount;
  final int autoEndedCount;
  final int flagsCount;
  final int absentCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.x3),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4),
        child: Row(
          children: <Widget>[
            // 1. All days
            _buildChip(
              key: const Key('attendance-filter-all'),
              filter: AdminAttendanceFilter.allDays,
              label: 'All days',
              badgeCount: '$totalDaysCount',
            ),
            const SizedBox(width: AppSpacing.x2),

            // 2. Auto-ended
            _buildChip(
              key: const Key('attendance-filter-auto-ended'),
              filter: AdminAttendanceFilter.autoEnded,
              label: 'Auto-ended',
              badgeCount: '$autoEndedCount',
              indicatorColor: AppColors.warning,
            ),
            const SizedBox(width: AppSpacing.x2),

            // 3. With flags
            _buildChip(
              key: const Key('attendance-filter-flags'),
              filter: AdminAttendanceFilter.withFlags,
              label: 'With flags',
              badgeCount: '$flagsCount',
            ),
            const SizedBox(width: AppSpacing.x2),

            // 4. Absent
            _buildChip(
              key: const Key('attendance-filter-absent'),
              filter: AdminAttendanceFilter.absent,
              label: 'Absent',
              badgeCount: '$absentCount',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip({
    required Key key,
    required AdminAttendanceFilter filter,
    required String label,
    required String badgeCount,
    Color? indicatorColor,
  }) {
    final isSelected = selectedFilter == filter;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: key,
        borderRadius: BorderRadius.circular(AppRadius.full),
        onTap: () => onSelectFilter(filter),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary600 : AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.full),
            border: Border.all(
              color: isSelected ? AppColors.primary600 : AppColors.neutral300,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (indicatorColor != null) ...[
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: indicatorColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: AppTypography.label.copyWith(
                  color: isSelected ? AppColors.neutral0 : AppColors.neutral500,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.25)
                      : (indicatorColor != null
                            ? AppColors.warningBg
                            : AppColors.neutral100),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Text(
                  badgeCount,
                  style: TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isSelected
                        ? AppColors.neutral0
                        : (indicatorColor != null
                              ? AppColors.neutral900
                              : AppColors.neutral700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
