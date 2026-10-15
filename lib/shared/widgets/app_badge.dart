import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_typography.dart';

/// Small numeric or status counter badge for Diamond Agritech.
///
/// Used on filter buttons, notification icons, and filter chips.
class AppBadge extends StatelessWidget {
  const AppBadge({
    required this.label,
    super.key,
    this.backgroundColor = AppColors.primary600,
    this.textColor = AppColors.neutral0,
  });

  factory AppBadge.count(
    int count, {
    Color backgroundColor = AppColors.primary600,
    Color textColor = AppColors.neutral0,
  }) {
    return AppBadge(
      label: count > 99 ? '99+' : count.toString(),
      backgroundColor: backgroundColor,
      textColor: textColor,
    );
  }

  final String label;
  final Color backgroundColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: AppRadius.fullAll,
      ),
      child: Center(
        child: Text(
          label,
          style: AppTypography.overline.tabular.withColor(textColor),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
