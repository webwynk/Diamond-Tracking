import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_typography.dart';

/// Contextual and telemetry banners matching Screen 29 and docs/03-DESIGN-SYSTEM.md.
///
/// Features:
/// - Offline reassurance banner (info tint, non-error, no retry).
/// - Sync pending banner (stale warning tint with action).
/// - Blocking GPS/permission banner (suspect error tint with settings action).
/// - Reconnecting realtime banner (thin subtle amber strip).
class AppBanner extends StatelessWidget {
  const AppBanner({
    required this.title,
    required this.icon,
    required this.backgroundColor,
    required this.iconColor,
    super.key,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.isActionPill = false,
  });

  /// Offline reassurance banner.
  ///
  /// RULE (Design System 10): Offline is never an error for the employee.
  /// It is a reassuring info banner because work is safely queued.
  factory AppBanner.offline() {
    return const AppBanner(
      icon: Icons.cloud_off_rounded,
      backgroundColor: AppColors.infoBg,
      iconColor: AppColors.info,
      title: 'No internet connection',
      subtitle: 'Your work is saved and will sync automatically.',
    );
  }

  /// Sync pending banner.
  factory AppBanner.syncPending({
    required int pointCount,
    VoidCallback? onDetails,
  }) {
    return AppBanner(
      icon: Icons.upload_rounded,
      backgroundColor: AppColors.warningBg,
      iconColor: AppColors.warning,
      title: '$pointCount points waiting to sync',
      actionLabel: onDetails != null ? 'Details' : null,
      onAction: onDetails,
      isActionPill: false,
    );
  }

  /// GPS turned off (blocking action required).
  factory AppBanner.gpsOff({required VoidCallback onOpenSettings}) {
    return AppBanner(
      icon: Icons.location_off_rounded,
      backgroundColor: AppColors.errorBg,
      iconColor: AppColors.error,
      title: 'Location is turned off',
      subtitle: 'Turn on location to start duty.',
      actionLabel: 'Open settings',
      onAction: onOpenSettings,
      isActionPill: true,
    );
  }

  /// Realtime connection dropping / reconnecting banner.
  factory AppBanner.reconnecting() {
    return const AppBanner(
      icon: Icons.sync_rounded,
      backgroundColor: AppColors.warningBg,
      iconColor: AppColors.warning,
      title: 'Reconnecting…',
    );
  }

  final String title;
  final String? subtitle;
  final IconData icon;
  final Color backgroundColor;
  final Color iconColor;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool isActionPill;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x4,
        vertical: AppSpacing.x3,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: AppRadius.mdAll,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Icon(icon, size: AppSizes.icon, color: iconColor),
          const SizedBox(width: AppSpacing.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  title,
                  style: AppTypography.body
                      .withColor(AppColors.textPrimary)
                      .copyWith(fontWeight: FontWeight.w600),
                ),
                if (subtitle != null) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: AppTypography.caption.withColor(
                      AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (actionLabel != null && onAction != null) ...<Widget>[
            const SizedBox(width: AppSpacing.x2),
            if (isActionPill)
              ElevatedButton(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(0, 36),
                  backgroundColor: AppColors.error,
                  foregroundColor: AppColors.neutral0,
                  elevation: 0,
                  shape: const RoundedRectangleBorder(
                    borderRadius: AppRadius.fullAll,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.x3,
                  ),
                ),
                child: Text(
                  actionLabel!,
                  style: AppTypography.label.withColor(AppColors.neutral0),
                ),
              )
            else
              TextButton(
                onPressed: onAction,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  actionLabel!,
                  style: AppTypography.label.withColor(AppColors.primary600),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
