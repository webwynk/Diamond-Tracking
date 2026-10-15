import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_typography.dart';

/// Branded placeholder for map loading states.
///
/// Matches Screen 30 (item 5) and docs/03-DESIGN-SYSTEM.md section 7:
/// Maps are explicitly forbidden from using a shimmer skeleton.
/// Instead, they show this 180 dp rounded-16 branded container.
class AppMapPlaceholder extends StatelessWidget {
  const AppMapPlaceholder({
    super.key,
    this.height = 180,
    this.message = 'Loading map…',
  });

  final double height;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.primary50,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: AppColors.primary100, width: 1),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            const Icon(
              Icons.location_on_outlined,
              size: AppSizes.iconMarker,
              color: AppColors.neutral400,
            ),
            const SizedBox(height: AppSpacing.x2),
            Text(
              message,
              style: AppTypography.caption.withColor(AppColors.neutral400),
            ),
          ],
        ),
      ),
    );
  }
}
