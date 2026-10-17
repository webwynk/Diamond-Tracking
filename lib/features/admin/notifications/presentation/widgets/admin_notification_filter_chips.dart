import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_dimens.dart';
import '../../../../../core/theme/app_typography.dart';
import '../controllers/admin_notification_state.dart';

/// Horizontally scrolling 32 dp category filter chips bar for Screen 21.
class AdminNotificationFilterChips extends StatelessWidget {
  const AdminNotificationFilterChips({
    super.key,
    required this.selectedFilter,
    required this.unreadCount,
    required this.onSelectFilter,
  });

  final AdminNotificationFilter selectedFilter;
  final int unreadCount;
  final ValueChanged<AdminNotificationFilter> onSelectFilter;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(
          bottom: BorderSide(color: AppColors.neutral200, width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.x2),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4),
        child: Row(
          children: <Widget>[
            // 1. Unread [Count]
            _buildChip(
              key: const Key('filter-chip-unread'),
              filter: AdminNotificationFilter.unread,
              label: 'Unread',
              countBadge: unreadCount > 0 ? '$unreadCount' : null,
            ),
            const SizedBox(width: AppSpacing.x2),

            // 2. All
            _buildChip(
              key: const Key('filter-chip-all'),
              filter: AdminNotificationFilter.all,
              label: 'All',
            ),
            const SizedBox(width: AppSpacing.x2),

            // 3. Duty
            _buildChip(
              key: const Key('filter-chip-duty'),
              filter: AdminNotificationFilter.duty,
              label: 'Duty',
            ),
            const SizedBox(width: AppSpacing.x2),

            // 4. Alerts
            _buildChip(
              key: const Key('filter-chip-alerts'),
              filter: AdminNotificationFilter.alerts,
              label: 'Alerts',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip({
    required Key key,
    required AdminNotificationFilter filter,
    required String label,
    String? countBadge,
  }) {
    final isSelected = selectedFilter == filter;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: key,
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: () => onSelectFilter(filter),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x3),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary600 : AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: isSelected ? AppColors.primary600 : AppColors.neutral300,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                label,
                style: AppTypography.label.copyWith(
                  color: isSelected ? AppColors.neutral0 : AppColors.neutral500,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
              if (countBadge != null) ...[
                const SizedBox(width: AppSpacing.x1 + 2),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.25)
                        : AppColors.neutral200,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text(
                    countBadge,
                    style: TextStyle(
                      fontFamily: AppTypography.fontFamily,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? AppColors.neutral0
                          : AppColors.neutral700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
