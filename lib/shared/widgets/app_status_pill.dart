import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_typography.dart';

/// Status pill strictly enforcing the design system rule:
/// **Status is colour PLUS a text label, never colour alone.**
///
/// Features:
/// - Fully rounded pill ([AppRadius.fullAll]).
/// - Status tint background.
/// - 8 dp circle dot matching the status colour.
/// - Text label in [AppTypography.label] using the status colour.
class AppStatusPill extends StatelessWidget {
  const AppStatusPill({required this.statusKey, super.key})
    : color = null,
      backgroundColor = null,
      customLabel = null;

  const AppStatusPill.custom({
    required Color this.color,
    required Color this.backgroundColor,
    required String label,
    super.key,
  }) : statusKey = null,
       customLabel = label;

  final String? statusKey;
  final String? customLabel;
  final Color? color;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final Color effectiveColor;
    final Color effectiveBg;
    final String effectiveLabel;

    if (statusKey != null) {
      effectiveColor =
          AppStatusColors.colours[statusKey] ?? AppColors.neutral700;
      effectiveBg =
          AppStatusColors.backgrounds[statusKey] ?? AppColors.neutral100;
      effectiveLabel = AppStatusColors.labels[statusKey] ?? statusKey!;
    } else {
      effectiveColor = color ?? AppColors.neutral700;
      effectiveBg = backgroundColor ?? AppColors.neutral100;
      effectiveLabel = customLabel ?? '';
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x2 + 2,
        vertical: AppSpacing.x1,
      ),
      decoration: BoxDecoration(
        color: effectiveBg,
        borderRadius: AppRadius.fullAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: effectiveColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppSpacing.x1 + 2),
          Text(
            effectiveLabel,
            style: AppTypography.label.withColor(effectiveColor),
          ),
        ],
      ),
    );
  }
}
