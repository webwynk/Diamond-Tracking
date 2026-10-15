import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_dimens.dart';
import '../../../../../core/theme/app_typography.dart';

/// Screen 15 Top Header Bar adhering strictly to the enterprise design reference.
class AdminMapTopBar extends StatelessWidget implements PreferredSizeWidget {
  const AdminMapTopBar({
    super.key,
    this.onSearchPressed,
    this.onNotificationsPressed,
    this.onProfilePressed,
  });

  final VoidCallback? onSearchPressed;
  final VoidCallback? onNotificationsPressed;
  final VoidCallback? onProfilePressed;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      color: AppColors.primary600,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: Agriculture Icon + Title Group
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.agriculture_rounded,
                  color: AppColors.neutral0,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.x3),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'DIAMOND AGRITECH',
                    style: AppTypography.overline.copyWith(
                      color: AppColors.neutral0.withValues(alpha: 0.75),
                      letterSpacing: 1.2,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Live Map Telemetry',
                    style: AppTypography.title.copyWith(
                      color: AppColors.neutral0,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Right: Action Icons (Search, Notifications with Badge, Admin Avatar)
          Row(
            children: [
              IconButton(
                key: const Key('btn-telemetry-search-action'),
                icon: const Icon(
                  Icons.search_rounded,
                  color: AppColors.neutral0,
                  size: 22,
                ),
                tooltip: 'Search telemetry',
                onPressed: onSearchPressed,
              ),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    key: const Key('btn-telemetry-notifications-action'),
                    icon: const Icon(
                      Icons.notifications_none_rounded,
                      color: AppColors.neutral0,
                      size: 22,
                    ),
                    tooltip: 'Telemetry alerts',
                    onPressed: onNotificationsPressed,
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.error,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: AppSpacing.x1),
              InkWell(
                onTap: onProfilePressed,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.primary500,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.person_rounded,
                    size: 18,
                    color: AppColors.neutral0,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
