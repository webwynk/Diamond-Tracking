import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';

/// Pattern 2: Sync Pending Banner.
///
/// Indicates telemetry points or visits queued on the device awaiting network sync.
class SyncPendingBanner extends StatelessWidget {
  const SyncPendingBanner({super.key, this.pointCount = 18, this.onDetails});

  final int pointCount;
  final VoidCallback? onDetails;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('banner-sync-pending'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x4,
        vertical: AppSpacing.x3,
      ),
      decoration: BoxDecoration(
        color: AppColors.warningBg,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Expanded(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(
                  Icons.upload_rounded,
                  size: 20,
                  color: AppColors.warning,
                ),
                const SizedBox(width: AppSpacing.x2),
                Flexible(
                  child: Text(
                    '$pointCount points waiting to sync',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.body.copyWith(
                      color: AppColors.neutral900,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.x2),
          TextButton(
            key: const Key('btn-sync-details'),
            onPressed: onDetails,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'Details',
              style: AppTypography.label.copyWith(
                color: AppColors.primary600,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
