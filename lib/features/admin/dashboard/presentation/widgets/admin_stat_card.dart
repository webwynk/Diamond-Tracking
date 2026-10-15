import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_dimens.dart';
import '../../../../../core/theme/app_typography.dart';

/// Single telemetry statistic card in the 2x2 grid answering "Who is working right now?"
class AdminStatCard extends StatelessWidget {
  const AdminStatCard({
    super.key,
    required this.value,
    required this.label,
    required this.icon,
    required this.badgeColor,
    required this.iconColor,
    this.borderColor = AppColors.neutral200,
    this.backgroundColor = AppColors.surface,
    this.labelColor = AppColors.textSecondary,
    this.showPingDot = false,
    this.pingColor,
    this.trailingIcon,
    this.onTap,
  });

  final String value;
  final String label;
  final IconData icon;
  final Color badgeColor;
  final Color iconColor;
  final Color borderColor;
  final Color backgroundColor;
  final Color labelColor;
  final bool showPingDot;
  final Color? pingColor;
  final IconData? trailingIcon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.lgAll,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.x4),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: AppRadius.lgAll,
            border: Border.all(color: borderColor, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Top Row: Badge Icon + Trailing Indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: badgeColor,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      icon,
                      size: 18,
                      color: iconColor,
                    ),
                  ),
                  if (showPingDot && pingColor != null)
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: pingColor,
                        shape: BoxShape.circle,
                      ),
                    )
                  else if (trailingIcon != null)
                    Icon(
                      trailingIcon,
                      size: 16,
                      color: AppColors.textDisabled,
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.x3),

              // Bottom Section: Value + Label
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      value,
                      style: const TextStyle(
                        fontSize: 32,
                        height: 1.1,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.5,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: AppTypography.overline.copyWith(
                      color: labelColor,
                      letterSpacing: 0.8,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
