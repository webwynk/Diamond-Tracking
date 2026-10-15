import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_dimens.dart';
import '../../../../../core/theme/app_typography.dart';

/// Full-width 48 dp outlined danger button: "Block employee".
class AdminEmployeeBlockActionButton extends StatelessWidget {
  const AdminEmployeeBlockActionButton({
    super.key,
    required this.onBlockPressed,
  });

  final VoidCallback onBlockPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      width: double.infinity,
      child: OutlinedButton.icon(
        key: const Key('btn-employee-block-action'),
        onPressed: onBlockPressed,
        icon: const Icon(
          Icons.block_rounded,
          color: AppColors.error,
          size: 20,
        ),
        label: Text(
          'Block employee',
          style: AppTypography.label.copyWith(
            color: AppColors.error,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.error,
          side: const BorderSide(color: AppColors.error, width: 1.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
    );
  }
}
