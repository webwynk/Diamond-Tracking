import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_dimens.dart';
import '../../../../../core/theme/app_typography.dart';

/// Top app bar for Screen 24 Places List (Admin).
class AdminPlacesTopBar extends StatelessWidget implements PreferredSizeWidget {
  const AdminPlacesTopBar({
    super.key,
    required this.activePlacesCount,
    required this.onTuneFilter,
    required this.onExportCoordinates,
    this.onBack,
  });

  final int activePlacesCount;
  final VoidCallback onTuneFilter;
  final VoidCallback onExportCoordinates;
  final VoidCallback? onBack;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: preferredSize.height,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.neutral200, width: 1),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              // Left: Title + Active Badge Pill
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (onBack != null) ...[
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded),
                      color: AppColors.neutral900,
                      onPressed: onBack,
                      splashRadius: 20,
                    ),
                    const SizedBox(width: AppSpacing.x1),
                  ],
                  Text(
                    'Places',
                    style: AppTypography.h3.copyWith(
                      color: AppColors.neutral900,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.x2),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary50,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Text(
                      '$activePlacesCount ACTIVE',
                      style: AppTypography.overline.copyWith(
                        color: AppColors.primary700,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),

              // Right: Tune/Filter + Export Actions
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  IconButton(
                    key: const Key('btn-places-filter'),
                    onPressed: onTuneFilter,
                    icon: const Icon(
                      Icons.tune_rounded,
                      color: AppColors.neutral600,
                      size: 22,
                    ),
                    splashRadius: 20,
                    tooltip: 'Geofence satellite calibration',
                  ),
                  IconButton(
                    key: const Key('btn-places-export'),
                    onPressed: onExportCoordinates,
                    icon: const Icon(
                      Icons.download_rounded,
                      color: AppColors.neutral600,
                      size: 22,
                    ),
                    splashRadius: 20,
                    tooltip: 'Export perimeter coordinates',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
