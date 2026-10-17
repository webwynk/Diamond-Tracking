import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_dimens.dart';
import '../../../../../core/theme/app_typography.dart';

/// Pinned 48 dp search bar for Screen 24 Places List (Admin).
class AdminPlacesSearchBar extends StatelessWidget {
  const AdminPlacesSearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.x4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.neutral300, width: 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x3),
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.search_rounded,
            color: AppColors.neutral400,
            size: 22,
          ),
          const SizedBox(width: AppSpacing.x2),
          Expanded(
            child: TextField(
              key: const Key('input-places-search'),
              controller: controller,
              onChanged: onChanged,
              style: AppTypography.body.copyWith(color: AppColors.neutral900),
              decoration: InputDecoration(
                hintText: 'Search places (name, taluka, radius)...',
                hintStyle: AppTypography.body.copyWith(
                  color: AppColors.neutral400,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (controller.text.isNotEmpty)
            GestureDetector(
              key: const Key('btn-clear-places-search'),
              onTap: onClear,
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(
                  Icons.close_rounded,
                  color: AppColors.neutral400,
                  size: 18,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
