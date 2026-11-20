import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_typography.dart';

/// An error or success note above a form's button.
class FormMessage extends StatelessWidget {
  const FormMessage.error(this.text, {super.key}) : isError = true;
  const FormMessage.success(this.text, {super.key}) : isError = false;

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final Color fg = isError ? AppColors.errorText : AppColors.success;
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.x3),
        decoration: BoxDecoration(
          color: isError ? AppColors.errorBg : AppColors.successBg,
          borderRadius: AppRadius.mdAll,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(
              isError
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_rounded,
              color: fg,
              size: AppSizes.iconDense,
            ),
            const SizedBox(width: AppSpacing.x2),
            Expanded(
              child: Text(text, style: AppTypography.body.copyWith(color: fg)),
            ),
          ],
        ),
      ),
    );
  }
}
