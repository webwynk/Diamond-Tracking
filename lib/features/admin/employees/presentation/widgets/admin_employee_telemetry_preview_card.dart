import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_dimens.dart';
import '../../../../../core/theme/app_typography.dart';

/// Screen 19: Telemetry diagnostic preview card showing auto-provision readiness.
class AdminEmployeeTelemetryPreviewCard extends StatelessWidget {
  const AdminEmployeeTelemetryPreviewCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: AppColors.neutral200),
      ),
      padding: const EdgeInsets.all(AppSpacing.x3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Expanded(
            child: Row(
              children: <Widget>[
                const Icon(
                  Icons.my_location_rounded,
                  size: 20,
                  color: AppColors.primary600,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Auto-Provision GPS Sync',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.neutral900,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        '15-SECOND HEARTBEAT ACTIVE',
                        style: AppTypography.overline,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: const BoxDecoration(
              color: AppColors.successBg,
              borderRadius: AppRadius.smAll,
            ),
            child: Text(
              'READY',
              style: AppTypography.overline.copyWith(
                color: AppColors.success,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
