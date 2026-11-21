import 'package:flutter/material.dart';

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
  const AppStatusPill.custom({
    required this.color,
    required this.backgroundColor,
    required this.label,
    super.key,
  });

  final String label;
  final Color color;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x2 + 2,
        vertical: AppSpacing.x1,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: AppRadius.fullAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: AppSpacing.x1 + 2),
          Text(label, style: AppTypography.label.withColor(color)),
        ],
      ),
    );
  }
}
