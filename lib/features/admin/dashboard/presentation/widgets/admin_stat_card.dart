import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_dimens.dart';
import '../../../../../core/theme/app_typography.dart';

/// A compact status tile on the admin Home (Off duty, No update, Needs check).
///
/// A tinted icon badge, the count in tabular figures and a short label. The
/// tiles that need attention get their own semantic border and a dot when the
/// count is above zero, so they read as something to look at.
class AdminStatCard extends StatelessWidget {
  const AdminStatCard({
    super.key,
    required this.value,
    this.valueKey,
    required this.label,
    required this.icon,
    required this.badgeColor,
    required this.iconColor,
    this.borderColor = AppColors.neutral200,
    this.backgroundColor = AppColors.surface,
    this.labelColor = AppColors.textSecondary,
    this.subtitle,
    this.subtitleKey,
    this.showPingDot = false,
    this.pingColor,
    this.onTap,
  });

  final String value;
  final Key? valueKey;
  final String label;
  final String? subtitle;
  final Key? subtitleKey;
  final IconData icon;
  final Color badgeColor;
  final Color iconColor;
  final Color borderColor;
  final Color backgroundColor;
  final Color labelColor;
  final bool showPingDot;
  final Color? pingColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.lgAll,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.x3),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: AppRadius.lgAll,
            border: Border.all(color: borderColor, width: 1),
            boxShadow: AppElevation.raised,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: badgeColor,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Icon(icon, size: 16, color: iconColor),
                  ),
                  if (showPingDot && pingColor != null)
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: pingColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.x2),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: <Widget>[
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        value,
                        key: valueKey,
                        style: AppTypography.h1.copyWith(
                          fontFeatures: const <FontFeature>[
                            FontFeature.tabularFigures(),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (subtitle != null) ...<Widget>[
                    const SizedBox(width: AppSpacing.x1 + 2),
                    Flexible(
                      child: Text(
                        subtitle!,
                        key: subtitleKey,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.x1),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.overline.copyWith(
                  color: labelColor,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
