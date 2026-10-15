import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_dimens.dart';
import '../../../../../core/theme/app_typography.dart';

/// Floating inset app bar for Screen 23 Route View (Admin).
class AdminRouteFloatingAppBar extends StatelessWidget {
  const AdminRouteFloatingAppBar({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onBack,
    required this.onShare,
  });

  final String title;
  final String subtitle;
  final VoidCallback onBack;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.x4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.neutral200, width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          // Back Chevron
          IconButton(
            key: const Key('btn-route-back'),
            onPressed: onBack,
            icon: const Icon(
              Icons.chevron_left_rounded,
              color: AppColors.primary600,
              size: 26,
            ),
            splashRadius: 20,
            tooltip: 'Go back',
          ),

          // Center Title + Subtitle
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.title.copyWith(
                    color: AppColors.neutral900,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.neutral500,
                  ),
                ),
              ],
            ),
          ),

          // Share Action Button
          IconButton(
            key: const Key('btn-route-share'),
            onPressed: onShare,
            icon: const Icon(
              Icons.share_outlined,
              color: AppColors.neutral600,
              size: 20,
            ),
            splashRadius: 20,
            tooltip: 'Share telemetry',
          ),
        ],
      ),
    );
  }
}
