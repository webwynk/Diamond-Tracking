import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_dimens.dart';
import '../../../../../core/theme/app_typography.dart';
import 'admin_profile_section.dart';

/// Represents a single completed or active duty shift history record.
class EmployeeDutyLogRecord {
  const EmployeeDutyLogRecord({
    required this.id,
    required this.dateStr,
    required this.timeWindow,
    required this.durationStr,
    required this.distanceStr,
  });

  final String id;
  final String dateStr;
  final String timeWindow;
  final String durationStr;
  final String distanceStr;
}

/// Screen 18 "Recent duty": the latest days worked, each opening that day's
/// route, and "View all" for the attendance screen.
class AdminEmployeeRecentDutyCard extends StatelessWidget {
  const AdminEmployeeRecentDutyCard({
    super.key,
    this.logs = const <EmployeeDutyLogRecord>[],
    this.emptyText = 'No duty recorded this month.',
    this.onViewAll,
    this.onLogSelected,
  });

  final List<EmployeeDutyLogRecord> logs;

  /// Said when there is nothing to list: "no duty", "loading" or "could not
  /// load" are different things and must not look the same.
  final String emptyText;
  final VoidCallback? onViewAll;
  final ValueChanged<EmployeeDutyLogRecord>? onLogSelected;

  @override
  Widget build(BuildContext context) {
    return AdminProfileSection(
      title: 'Recent duty',
      trailing: AdminProfileSectionLink(
        key: const Key('btn-recent-duty-view-all'),
        label: 'View all',
        onPressed: onViewAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (logs.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.x3),
              child: Text(
                emptyText,
                key: const Key('text-recent-duty-empty'),
                style: AppTypography.body.withColor(AppColors.textSecondary),
              ),
            ),
          for (var i = 0; i < logs.length; i++) ...<Widget>[
            if (i > 0) const Divider(color: AppColors.border, height: 1),
            _DutyRow(log: logs[i], onTap: () => onLogSelected?.call(logs[i])),
          ],
        ],
      ),
    );
  }
}

class _DutyRow extends StatelessWidget {
  const _DutyRow({required this.log, required this.onTap});

  static const double _badge = 40;

  final EmployeeDutyLogRecord log;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: Key('row-recent-duty-${log.id}'),
      onTap: onTap,
      borderRadius: AppRadius.mdAll,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSizes.listRowMinHeight),
        child: Row(
          children: <Widget>[
            Container(
              width: _badge,
              height: _badge,
              decoration: const BoxDecoration(
                color: AppColors.primary50,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.event_note_rounded,
                size: AppSizes.iconDense,
                color: AppColors.primary600,
              ),
            ),
            const SizedBox(width: AppSpacing.x3),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    log.dateStr,
                    style: AppTypography.body.semiBold.withColor(
                      AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    log.timeWindow,
                    style: AppTypography.caption.withColor(
                      AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.x2),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Text(
                  log.durationStr,
                  style: AppTypography.body.tabular.semiBold.withColor(
                    AppColors.textPrimary,
                  ),
                ),
                Text(
                  log.distanceStr,
                  style: AppTypography.caption.tabular.withColor(
                    AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: AppSizes.iconDense,
              color: AppColors.neutral400,
            ),
          ],
        ),
      ),
    );
  }
}
