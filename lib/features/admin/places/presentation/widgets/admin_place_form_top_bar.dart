import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_dimens.dart';
import '../../../../../core/theme/app_typography.dart';

/// Floating inset app bar for Screen 25 Create / Edit Place (Admin).
class AdminPlaceFormTopBar extends StatelessWidget {
  const AdminPlaceFormTopBar({
    super.key,
    required this.title,
    required this.onClose,
    required this.onSave,
  });

  final String title;
  final VoidCallback onClose;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('admin-place-form-top-bar'),
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
          // Close Icon Button
          IconButton(
            key: const Key('btn-place-form-close'),
            onPressed: onClose,
            icon: const Icon(
              Icons.close_rounded,
              color: AppColors.neutral600,
              size: 20,
            ),
            splashRadius: 20,
            tooltip: 'Cancel and close',
          ),

          // Center Title
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.title.copyWith(
                color: AppColors.neutral900,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          // Save Action Button
          TextButton(
            key: const Key('btn-place-form-save'),
            onPressed: onSave,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              minimumSize: const Size(0, 36),
            ),
            child: Text(
              'Save',
              style: AppTypography.label.copyWith(
                color: AppColors.primary600,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
