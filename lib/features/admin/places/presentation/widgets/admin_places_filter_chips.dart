import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_dimens.dart';
import '../../../../../core/theme/app_typography.dart';
import '../controllers/admin_places_state.dart';

/// Horizontally scrolling category chip bar for Screen 24 Places List (Admin).
class AdminPlacesFilterChips extends StatelessWidget {
  const AdminPlacesFilterChips({
    super.key,
    required this.selectedCategory,
    required this.onSelectCategory,
  });

  final AdminPlaceCategory selectedCategory;
  final ValueChanged<AdminPlaceCategory> onSelectCategory;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4),
        child: Row(
          children: <Widget>[
            // Chip 1: All 38
            _buildChip(
              key: const Key('chip-place-all'),
              label: 'All',
              countText: '38',
              category: AdminPlaceCategory.all,
            ),
            const SizedBox(width: AppSpacing.x2),

            // Chip 2: Farms 24
            _buildChip(
              key: const Key('chip-place-farms'),
              label: 'Farms',
              countText: '24',
              category: AdminPlaceCategory.farms,
              icon: Icons.eco_rounded,
              iconColor: AppColors.success,
            ),
            const SizedBox(width: AppSpacing.x2),

            // Chip 3: Dealers 9
            _buildChip(
              key: const Key('chip-place-dealers'),
              label: 'Dealers',
              countText: '9',
              category: AdminPlaceCategory.dealers,
              icon: Icons.storefront_rounded,
              iconColor: AppColors.info,
            ),
            const SizedBox(width: AppSpacing.x2),

            // Chip 4: Offices 2
            _buildChip(
              key: const Key('chip-place-offices'),
              label: 'Offices',
              countText: '2',
              category: AdminPlaceCategory.offices,
              icon: Icons.corporate_fare_rounded,
              iconColor: AppColors.primary600,
            ),
            const SizedBox(width: AppSpacing.x2),

            // Chip 5: Warehouses 3
            _buildChip(
              key: const Key('chip-place-warehouses'),
              label: 'Warehouses',
              countText: '3',
              category: AdminPlaceCategory.warehouses,
              icon: Icons.warehouse_rounded,
              iconColor: AppColors.warning,
            ),
            const SizedBox(width: AppSpacing.x2),

            // Chip 6: Inactive 4
            _buildChip(
              key: const Key('chip-place-inactive'),
              label: 'Inactive',
              countText: '4',
              category: AdminPlaceCategory.inactive,
              icon: Icons.do_not_disturb_on_outlined,
              iconColor: AppColors.neutral400,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip({
    required Key key,
    required String label,
    required String countText,
    required AdminPlaceCategory category,
    IconData? icon,
    Color? iconColor,
  }) {
    final isSelected = selectedCategory == category;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: key,
        onTap: () => onSelectCategory(category),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary600 : AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(
              color: isSelected ? AppColors.primary600 : AppColors.neutral300,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 16,
                  color: isSelected ? AppColors.neutral0 : iconColor,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: AppTypography.label.copyWith(
                  color: isSelected ? AppColors.neutral0 : AppColors.neutral900,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                countText,
                style: AppTypography.caption.copyWith(
                  color: isSelected
                      ? AppColors.neutral0.withValues(alpha: 0.85)
                      : AppColors.neutral500,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
