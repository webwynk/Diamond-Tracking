import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_dimens.dart';
import '../../../../../core/theme/app_typography.dart';

/// Two equal 48 dp action buttons side by side: "Track live" (filled) and "Route view" (outlined).
class AdminEmployeeQuickActions extends StatelessWidget {
  const AdminEmployeeQuickActions({
    super.key,
    this.onTrackLive,
    this.onRouteView,
  });

  final VoidCallback? onTrackLive;
  final VoidCallback? onRouteView;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // 1. Track Live Button (Filled #016893)
        Expanded(
          child: SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              key: const Key('btn-quick-track-live'),
              onPressed: onTrackLive,
              icon: const Icon(Icons.location_on_rounded, size: 20),
              label: Text(
                'Track live',
                style: AppTypography.label.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary600,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
            ),
          ),
        ),

        const SizedBox(width: AppSpacing.x3),

        // 2. Route View Button (Outlined #016893)
        Expanded(
          child: SizedBox(
            height: 48,
            child: OutlinedButton.icon(
              key: const Key('btn-quick-route-view'),
              onPressed: onRouteView,
              icon: const Icon(Icons.history_rounded, size: 20),
              label: Text(
                'Route view',
                style: AppTypography.label.copyWith(
                  color: AppColors.primary600,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary600,
                side: const BorderSide(color: AppColors.primary600, width: 1.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
