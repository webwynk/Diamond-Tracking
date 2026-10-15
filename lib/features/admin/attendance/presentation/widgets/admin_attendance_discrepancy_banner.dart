import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_dimens.dart';
import '../../../../../core/theme/app_typography.dart';

/// Micro-alert discrepancy warning banner for Screen 22.
class AdminAttendanceDiscrepancyBanner extends StatelessWidget {
  const AdminAttendanceDiscrepancyBanner({
    super.key,
    required this.message,
    required this.onReview,
  });

  final String message;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.x4,
        AppSpacing.x3,
        AppSpacing.x4,
        0,
      ),
      decoration: BoxDecoration(
        color: AppColors.warningBg,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
          color: AppColors.warning.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x3,
        vertical: AppSpacing.x2,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          // Warning Icon + Discrepancy Note
          Expanded(
            child: Row(
              children: <Widget>[
                const Icon(
                  Icons.info_outline_rounded,
                  color: AppColors.warning,
                  size: 18,
                ),
                const SizedBox(width: AppSpacing.x2),
                Expanded(
                  child: Text(
                    message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.label.copyWith(
                      color: AppColors.neutral900,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.x2),

          // "Review" Action Button
          GestureDetector(
            key: const Key('btn-discrepancy-review'),
            onTap: onReview,
            child: Text(
              'Review',
              style: AppTypography.caption.copyWith(
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
