import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_dimens.dart';
import '../../../../../core/theme/app_typography.dart';

/// Telemetry RTK sync micro-banner for Screen 24 Places List (Admin).
class AdminPlacesTelemetryBanner extends StatelessWidget {
  const AdminPlacesTelemetryBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.x4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary50,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          // Left: Icon + Label
          Expanded(
            child: Row(
              children: <Widget>[
                const Icon(
                  Icons.satellite_alt_rounded,
                  color: AppColors.primary600,
                  size: 15,
                ),
                const SizedBox(width: AppSpacing.x1 + 2),
                Flexible(
                  child: Text(
                    'POLYGON GEOFENCE GRID · RTK SYNCED',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.overline.copyWith(
                      color: AppColors.primary700,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.x2),

          // Right: Accuracy Status
          Text(
            'accuracy ±1.8m',
            style: AppTypography.caption.copyWith(
              color: AppColors.neutral500,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
