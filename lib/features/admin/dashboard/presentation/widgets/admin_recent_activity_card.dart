import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_dimens.dart';
import '../../../../../core/theme/app_typography.dart';
import '../../../../../domain/entities/admin_activity_event.dart';
import '../../../../../shared/widgets/app_empty_state.dart';
import '../controllers/admin_dashboard_state.dart';

/// Card 4 — Recent activity: the latest real duty and account events from the
/// server (Screen 14).
class AdminRecentActivityCard extends StatelessWidget {
  const AdminRecentActivityCard({
    super.key,
    required this.activities,
    this.isLoading = false,
    this.errorMessage,
    this.onRetry,
    this.onSeeAll,
  });

  final List<AdminActivityItem> activities;

  /// First load in progress: shown instead of "No activity yet".
  final bool isLoading;

  /// The first load failed: shown with a Retry instead of "No activity yet".
  final String? errorMessage;
  final VoidCallback? onRetry;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: AppColors.neutral200, width: 1),
        boxShadow: AppElevation.card,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Header Row
          Container(
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.x4,
              vertical: AppSpacing.x2,
            ),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppColors.neutral200, width: 1),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: const BoxDecoration(
                          color: AppColors.neutral100,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.history_rounded,
                          size: 16,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.x2),
                      Flexible(
                        child: Text(
                          'Recent activity',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.title.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.x2),
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
          if (isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.x6),
              child: Center(
                child: SizedBox(
                  key: Key('activity-loading'),
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              ),
            )
          else if (errorMessage != null)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.x4),
              child: Column(
                key: const Key('activity-error'),
                children: [
                  Text(
                    errorMessage!,
                    textAlign: TextAlign.center,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  TextButton(
                    key: const Key('btn-activity-retry'),
                    onPressed: onRetry,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          else if (activities.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.x6),
              child: AppEmptyState(
                icon: Icons.history_rounded,
                title: 'No activity yet',
                description: 'Duty starts and ends will appear here.',
              ),
            )
          else
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

    switch (item.kind) {
      case AdminActivityKind.dutyStarted:
        badgeBg = AppColors.successBg;
        iconColor = AppColors.success;
        icon = Icons.login_rounded;
        break;

      case AdminActivityKind.dutyEnded:
        badgeBg = AppColors.neutral100;
        iconColor = AppColors.neutral600;
        icon = Icons.logout_rounded;
        break;

      case AdminActivityKind.dutyAutoEnded:
        badgeBg = AppColors.warningBg;
        iconColor = AppColors.warning;
        icon = Icons.schedule_rounded;
        rowBg = AppColors.warningBg.withValues(alpha: 0.12);
        subtitleColor = AppColors.warningText;
        break;

      case AdminActivityKind.employeeCreated:
        badgeBg = AppColors.primary50;
        iconColor = AppColors.primary600;
        icon = Icons.person_add_alt_1_rounded;
        break;

      case AdminActivityKind.employeeBlocked:
        badgeBg = AppColors.errorBg;
        iconColor = AppColors.error;
        icon = Icons.block_rounded;
        rowBg = AppColors.errorBg.withValues(alpha: 0.12);
        subtitleColor = AppColors.error;
        break;

      case AdminActivityKind.employeeUnblocked:
        badgeBg = AppColors.successBg;
        iconColor = AppColors.success;
        icon = Icons.lock_open_rounded;
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
            decoration: BoxDecoration(color: badgeBg, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Icon(icon, size: 20, color: iconColor),
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
                  style: AppTypography.caption.copyWith(color: subtitleColor),
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
