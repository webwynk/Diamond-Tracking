import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_dimens.dart';
import '../../../../../core/theme/app_typography.dart';

/// Full-width 48 dp outlined button: "Reset PIN".
class AdminEmployeeResetPinButton extends StatelessWidget {
  const AdminEmployeeResetPinButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      width: double.infinity,
      child: OutlinedButton.icon(
        key: const Key('btn-employee-reset-pin'),
        onPressed: onPressed,
        icon: const Icon(
          Icons.lock_reset_rounded,
          color: AppColors.primary600,
          size: 20,
        ),
        label: Text(
          'Reset PIN',
          style: AppTypography.label.copyWith(
            color: AppColors.primary600,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary600,
          side: const BorderSide(color: AppColors.primary600, width: 1.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
    );
  }
}
