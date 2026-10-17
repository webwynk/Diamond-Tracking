import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_dimens.dart';
import '../../../../../core/theme/app_typography.dart';

/// Screen 19: Informational notice strip explaining permissions on first login.
class AdminEmployeeInfoStrip extends StatelessWidget {
  const AdminEmployeeInfoStrip({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.infoBg,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: AppColors.infoBg),
      ),
      padding: const EdgeInsets.all(AppSpacing.x3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.info_rounded, size: 20, color: AppColors.info),
          const SizedBox(width: AppSpacing.x3),
          Expanded(
            child: Text(
              'The employee will be asked to allow location access and background tracking at first login.',
              style: AppTypography.body.copyWith(
                color: AppColors.neutral900,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
