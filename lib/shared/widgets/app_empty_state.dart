import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_typography.dart';
import 'app_button.dart';

/// Reusable empty state view matching Screen 28 and docs/03-DESIGN-SYSTEM.md section 10.
///
/// Features:
/// - 56 dp rounded container with subtle brand tint ([AppColors.primary50]).
/// - Vector icon with brand accent ([AppColors.primary600]).
/// - Headline in [AppTypography.title] ([AppColors.textPrimary]).
/// - Description in [AppTypography.caption] ([AppColors.textSecondary]).
/// - Optional primary or secondary action button.
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    required this.title,
    required this.description,
    required this.icon,
    super.key,
    this.actionLabel,
    this.onActionPressed,
    this.isActionOutlined = true,
  });

  /// Preset 1: No employees yet.
  factory AppEmptyState.noEmployees({VoidCallback? onAddEmployee}) {
    return AppEmptyState(
      icon: Icons.people_outline_rounded,
      title: 'No employees yet',
      description: 'Add your first team member.',
      actionLabel: onAddEmployee != null ? 'Add employee' : null,
      onActionPressed: onAddEmployee,
      isActionOutlined: false, // Primary button per design
    );
  }

  /// Preset 2: Nobody on duty.
  factory AppEmptyState.nobodyOnDuty({VoidCallback? onViewTeam}) {
    return AppEmptyState(
      icon: Icons.location_off_outlined,
      title: 'No one is on duty',
      description: 'Nobody has started duty today.',
      actionLabel: onViewTeam != null ? 'View team' : null,
      onActionPressed: onViewTeam,
      isActionOutlined: true,
    );
  }

  /// Preset 3: No notifications.
  factory AppEmptyState.noNotifications() {
    return const AppEmptyState(
      icon: Icons.notifications_none_rounded,
      title: "You're all caught up",
      description: 'New alerts will appear here.',
    );
  }

  /// Preset 4: Filtered to nothing.
  factory AppEmptyState.filteredToNothing({VoidCallback? onClearFilters}) {
    return AppEmptyState(
      icon: Icons.filter_alt_off_outlined,
      title: 'No results for these filters',
      description: 'Try removing one or more filters.',
      actionLabel: onClearFilters != null ? 'Clear filters' : null,
      onActionPressed: onClearFilters,
      isActionOutlined: true,
    );
  }

  /// Preset 5: Search found nothing.
  factory AppEmptyState.searchNotFound({
    required String query,
    VoidCallback? onClearSearch,
  }) {
    return AppEmptyState(
      icon: Icons.search_off_rounded,
      title: 'No matches found',
      description: "Nothing matches '$query'.",
      actionLabel: onClearSearch != null ? 'Clear search' : null,
      onActionPressed: onClearSearch,
      isActionOutlined: true,
    );
  }

  /// Preset 6: No route on this date.
  factory AppEmptyState.noRoute({VoidCallback? onPickDate, String? dateLabel}) {
    return AppEmptyState(
      icon: Icons.alt_route_rounded,
      title: 'No location recorded',
      description: dateLabel != null
          ? 'No duty points recorded for $dateLabel.'
          : 'No location recorded on this date.',
      actionLabel: onPickDate != null ? 'Pick another date' : null,
      onActionPressed: onPickDate,
      isActionOutlined: true,
    );
  }

  /// Preset 7: Route expired (older than 30 days).
  factory AppEmptyState.routeExpired({VoidCallback? onViewSummary}) {
    return AppEmptyState(
      icon: Icons.history_toggle_off_rounded,
      title: 'Route older than 30 days',
      description:
          'Detailed routes are kept for 30 days. Totals are still available.',
      actionLabel: onViewSummary != null ? 'View summary' : null,
      onActionPressed: onViewSummary,
      isActionOutlined: true,
    );
  }

  final String title;
  final String description;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onActionPressed;
  final bool isActionOutlined;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            // 56 dp rounded container with subtle brand tint
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: AppColors.primary50,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(icon, size: 28, color: AppColors.primary600),
              ),
            ),
            const SizedBox(height: AppSpacing.x4),
            Text(
              title,
              style: AppTypography.title.withColor(AppColors.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.x1),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 280),
              child: Text(
                description,
                style: AppTypography.caption.withColor(AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ),
            if (actionLabel != null && onActionPressed != null) ...<Widget>[
              const SizedBox(height: AppSpacing.x5),
              AppButton(
                label: actionLabel!,
                onPressed: onActionPressed,
                variant: isActionOutlined
                    ? AppButtonVariant.secondary
                    : AppButtonVariant.primary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
