import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_dimens.dart';
import '../../../../../core/theme/app_typography.dart';

/// A row of four shortcuts on the admin Home: Live map, Team, Reports and Add
/// employee. Each opens a screen that already exists.
class AdminQuickActions extends StatelessWidget {
  const AdminQuickActions({
    super.key,
    required this.onLiveMap,
    required this.onTeam,
    required this.onReports,
    required this.onAddEmployee,
  });

  final VoidCallback onLiveMap;
  final VoidCallback onTeam;
  final VoidCallback onReports;
  final VoidCallback onAddEmployee;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _Action(
          key: const Key('quick-live-map'),
          icon: Icons.map_rounded,
          label: 'Live map',
          onTap: onLiveMap,
        ),
        _Action(
          key: const Key('quick-team'),
          icon: Icons.groups_rounded,
          label: 'Team',
          onTap: onTeam,
        ),
        _Action(
          key: const Key('quick-reports'),
          icon: Icons.bar_chart_rounded,
          label: 'Reports',
          onTap: onReports,
        ),
        _Action(
          key: const Key('quick-add-employee'),
          icon: Icons.person_add_alt_1_rounded,
          label: 'Add employee',
          onTap: onAddEmployee,
        ),
      ],
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.lgAll,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AppSizes.minTouchTarget,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.x1),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.primary50,
                      borderRadius: AppRadius.lgAll,
                      border: Border.all(color: AppColors.primary100),
                    ),
                    alignment: Alignment.center,
                    child: Icon(icon, size: 24, color: AppColors.primary600),
                  ),
                  const SizedBox(height: AppSpacing.x2),
                  Text(
                    label,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
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
