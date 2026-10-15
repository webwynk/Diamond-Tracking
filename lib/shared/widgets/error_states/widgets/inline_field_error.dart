import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';

/// Pattern 4: Inline Field Error.
///
/// Standardized text field validation error pattern showing 1.5 dp error border,
/// trailing error icon, and warning icon caption.
class InlineFieldError extends StatelessWidget {
  const InlineFieldError({
    super.key,
    this.label = 'Employee Identifier',
    this.value = 'DA-022',
    this.errorMessage = 'This employee ID is already in use.',
  });

  final String label;
  final String value;
  final String errorMessage;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('field-inline-error'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          label,
          style: AppTypography.label.copyWith(
            color: AppColors.neutral900,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: 48,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: AppColors.error,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                value,
                style: AppTypography.bodyLarge.copyWith(
                  color: AppColors.neutral900,
                ),
              ),
              const Icon(
                Icons.error_outline_rounded,
                size: 20,
                color: AppColors.error,
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: <Widget>[
            const Icon(
              Icons.warning_amber_rounded,
              size: 14,
              color: AppColors.error,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                errorMessage,
                style: AppTypography.caption.copyWith(
                  color: AppColors.error,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
