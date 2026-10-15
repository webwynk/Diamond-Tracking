import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_dimens.dart';
import '../../../../../core/theme/app_typography.dart';
import '../controllers/admin_dashboard_state.dart';

/// Card 4 — Recent Activity feed displaying real-time field operations events
/// adhering strictly to Screen 14 design specifications.
class AdminRecentActivityCard extends StatelessWidget {
  const AdminRecentActivityCard({
    super.key,
    required this.activities,
    this.onSeeAll,
  });

  final List<AdminActivityItem> activities;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.neutral200, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Header Row
          Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppColors.neutral200, width: 1),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.history_rounded,
                      size: 20,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: AppSpacing.x2),
                    Text(
                      'Recent activity',
                      style: AppTypography.title.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                TextButton(
                  key: const Key('btn-see-all-activities'),
                  onPressed: onSeeAll,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.x2,
                      vertical: AppSpacing.x1,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'See all',
                    style: AppTypography.label.copyWith(
                      color: AppColors.primary600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // List Rows
          Column(
            children: [
              for (int i = 0; i < activities.length; i++) ...[
                _buildActivityRow(activities[i]),
                if (i < activities.length - 1)
                  const Divider(
                    height: 1,
                    thickness: 1,
                    color: AppColors.neutral200,
                  ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActivityRow(AdminActivityItem item) {
    Color badgeBg;
    Color iconColor;
    IconData icon;
    Color? rowBg;
    Color subtitleColor = AppColors.textSecondary;

    switch (item.type) {
      case AdminActivityType.dutyStarted:
        badgeBg = AppColors.successBg;
        iconColor = AppColors.success;
        icon = Icons.login_rounded;
        break;

      case AdminActivityType.locationFlagged:
        badgeBg = AppColors.errorBg;
        iconColor = AppColors.error;
        icon = Icons.error_outline_rounded;
        rowBg = AppColors.errorBg.withValues(alpha: 0.12);
        subtitleColor = AppColors.error;
        break;

      case AdminActivityType.reachedFarm:
        badgeBg = AppColors.primary50;
        iconColor = AppColors.primary600;
        icon = Icons.location_on_rounded;
        break;

      case AdminActivityType.noUpdate:
        badgeBg = AppColors.warningBg;
        iconColor = AppColors.warning;
        icon = Icons.schedule_rounded;
        rowBg = AppColors.warningBg.withValues(alpha: 0.12);
        subtitleColor = AppColors.warningText;
        break;
    }

    return Container(
      color: rowBg ?? Colors.transparent,
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4),
      child: Row(
        children: [
          // 36 dp Circular Tinted Badge
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: badgeBg,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: 20,
              color: iconColor,
            ),
          ),
          const SizedBox(width: AppSpacing.x3),

          // Title & Subtitle
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: AppTypography.body.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  item.subtitle,
                  style: AppTypography.caption.copyWith(
                    color: subtitleColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.x2),

          // Right-aligned Time
          Text(
            item.timeAgo,
            style: AppTypography.caption.copyWith(
              color: AppColors.textDisabled,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
