import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_dimens.dart';
import '../../../../../core/theme/app_typography.dart';

/// The profile's action bar: a white card floating over the edge of the hero,
/// with four equal tiles. "Track live" is the one primary action (filled);
/// the others are tonal. Each whole tile is the touch target.
class AdminEmployeeQuickActions extends StatelessWidget {
  const AdminEmployeeQuickActions({
    super.key,
    this.onTrackLive,
    this.onRouteView,
    this.onAttendance,
    this.onVisits,
  });

  final VoidCallback? onTrackLive;
  final VoidCallback? onRouteView;
  final VoidCallback? onAttendance;
  final VoidCallback? onVisits;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: AppColors.border),
        boxShadow: AppElevation.raised,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x1,
        vertical: AppSpacing.x2,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _ActionTile(
            key: const Key('btn-quick-track-live'),
            icon: Icons.my_location_rounded,
            label: 'Track live',
            primary: true,
            onTap: onTrackLive,
          ),
          _ActionTile(
            key: const Key('btn-quick-route-view'),
            icon: Icons.route_rounded,
            label: 'Route view',
            onTap: onRouteView,
          ),
          _ActionTile(
            key: const Key('btn-quick-attendance'),
            icon: Icons.event_available_rounded,
            label: 'Attendance',
            onTap: onAttendance,
          ),
          _ActionTile(
            key: const Key('btn-quick-visits'),
            icon: Icons.storefront_rounded,
            label: 'Visits',
            onTap: onVisits,
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  static const double _circle = 44;

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.mdAll,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AppSizes.listRowMinHeight,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.x1,
                vertical: AppSpacing.x2,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: _circle,
                    height: _circle,
                    decoration: BoxDecoration(
                      color: primary
                          ? AppColors.primary600
                          : AppColors.primary50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      size: AppSizes.icon,
                      color: primary
                          ? AppColors.neutral0
                          : AppColors.primary600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.x2),
                  Text(
                    label,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.label.withColor(AppColors.neutral700),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
