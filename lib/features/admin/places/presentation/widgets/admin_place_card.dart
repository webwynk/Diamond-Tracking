import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_dimens.dart';
import '../../../../../core/theme/app_typography.dart';
import '../controllers/admin_places_state.dart';

/// Individual place / geofence facility card for Screen 24 Places List (Admin).
class AdminPlaceCard extends StatelessWidget {
  const AdminPlaceCard({super.key, required this.place, required this.onTap});

  final AdminPlaceItem place;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (badgeBg, iconColor, iconData) = _getBadgeStyle(place);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: place.isActive ? AppColors.surface : AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.neutral200, width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: Key('place-card-${place.id}'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.x4),
            child: Row(
              children: <Widget>[
                // 1. 44x44 Tinted Icon Badge
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  alignment: Alignment.center,
                  child: Icon(iconData, size: 24, color: iconColor),
                ),
                const SizedBox(width: AppSpacing.x3),

                // 2. Middle Content Column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      // Row A: Place Name + Tag Pill
                      Row(
                        children: <Widget>[
                          Flexible(
                            child: Text(
                              place.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.title.copyWith(
                                color: place.isActive
                                    ? AppColors.neutral900
                                    : AppColors.neutral600,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.x1 + 2),
                          _buildTagPill(place),
                        ],
                      ),
                      const SizedBox(height: 2),

                      // Row B: Radius & Location
                      Text(
                        place.radiusAndLocation,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.caption.copyWith(
                          color: place.isActive
                              ? AppColors.neutral500
                              : AppColors.neutral400,
                        ),
                      ),
                      const SizedBox(height: 4),

                      // Row C: Visits count this month
                      Row(
                        children: <Widget>[
                          if (place.isActive) ...[
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: AppColors.primary600,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                          ],
                          Flexible(
                            child: Text(
                              place.visitsText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.caption.copyWith(
                                color: place.isActive
                                    ? AppColors.primary600
                                    : AppColors.neutral400,
                                fontWeight: place.isActive
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.x2),

                // 3. Right Chevron
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.neutral300,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTagPill(AdminPlaceItem place) {
    if (!place.isActive) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: AppColors.neutral200,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Text(
          'Inactive',
          style: AppTypography.caption.copyWith(
            color: AppColors.neutral600,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    final (pillBg, pillTextColor) = switch (place.category) {
      AdminPlaceCategory.farms => (AppColors.successBg, AppColors.success),
      AdminPlaceCategory.dealers => (AppColors.infoBg, AppColors.info),
      AdminPlaceCategory.offices => (AppColors.primary50, AppColors.primary700),
      AdminPlaceCategory.warehouses => (AppColors.warningBg, AppColors.warning),
      _ => (AppColors.neutral100, AppColors.neutral600),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: pillBg,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        place.badgeTag,
        style: AppTypography.overline.copyWith(
          color: pillTextColor,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  (Color, Color, IconData) _getBadgeStyle(AdminPlaceItem place) {
    if (!place.isActive) {
      return (AppColors.neutral100, AppColors.neutral400, Icons.eco_outlined);
    }

    return switch (place.category) {
      AdminPlaceCategory.farms => (
        AppColors.successBg,
        AppColors.success,
        Icons.eco_rounded,
      ),
      AdminPlaceCategory.dealers => (
        AppColors.infoBg,
        AppColors.info,
        Icons.storefront_rounded,
      ),
      AdminPlaceCategory.offices => (
        AppColors.primary50,
        AppColors.primary600,
        Icons.corporate_fare_rounded,
      ),
      AdminPlaceCategory.warehouses => (
        AppColors.warningBg,
        AppColors.warning,
        Icons.warehouse_rounded,
      ),
      _ => (AppColors.neutral100, AppColors.neutral600, Icons.place_rounded),
    };
  }
}
