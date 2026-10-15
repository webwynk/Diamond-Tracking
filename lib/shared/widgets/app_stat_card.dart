import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_typography.dart';
import 'app_card.dart';

/// Stat card matching docs/03-DESIGN-SYSTEM.md section 11.
///
/// Features:
/// - Label in [AppTypography.overline] uppercase.
/// - Value in [AppTypography.display] with tabular figures ([FontFeature.tabularFigures()]).
/// - Unit in [AppTypography.label].
/// - Optional trend / subtitle in [AppTypography.caption].
class AppStatCard extends StatelessWidget {
  const AppStatCard({
    required this.title,
    required this.value,
    super.key,
    this.unit,
    this.trend,
    this.trendColor,
    this.onTap,
  });

  final String title;
  final String value;
  final String? unit;
  final String? trend;
  final Color? trendColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.x4),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            title.toUpperCase(),
            style: AppTypography.overline.withColor(AppColors.textSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.x1),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Text(
                value,
                style: AppTypography.display.tabular.withColor(
                  AppColors.textPrimary,
                ),
              ),
              if (unit != null && unit!.isNotEmpty) ...<Widget>[
                const SizedBox(width: AppSpacing.x1),
                Text(
                  unit!,
                  style: AppTypography.label.withColor(AppColors.textSecondary),
                ),
              ],
            ],
          ),
          if (trend != null && trend!.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.x1),
            Text(
              trend!,
              style: AppTypography.caption.withColor(
                trendColor ?? AppColors.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}
