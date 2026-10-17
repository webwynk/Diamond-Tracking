import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_dimens.dart';
import '../../../../../core/theme/app_typography.dart';

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

/// Screen 18 "Recent duty" Card: Section header with "View all" CTA and the session history rows.
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
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border, width: 1.0),
      ),
      padding: const EdgeInsets.all(AppSpacing.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Header: Title "Recent duty" & "View all" Action
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent duty',
                style: AppTypography.title.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              InkWell(
                key: const Key('btn-recent-duty-view-all'),
                onTap: onViewAll,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  child: Text(
                    'View all',
                    style: AppTypography.label.copyWith(
                      color: AppColors.primary600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.x1),

          // 2. Shift rows, or an honest empty message
          if (logs.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.x4),
              child: Text(
                emptyText,
                key: const Key('text-recent-duty-empty'),
                style: AppTypography.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          for (int i = 0; i < logs.length; i++) ...[
            if (i > 0) const Divider(color: AppColors.border, height: 1),
            _buildDutyRow(logs[i]),
          ],
        ],
      ),
    );
  }

  Widget _buildDutyRow(EmployeeDutyLogRecord log) {
    return InkWell(
      key: Key('row-recent-duty-${log.id}'),
      onTap: () => onLogSelected?.call(log),
      child: SizedBox(
        height: 64,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Left: Date & Time Window
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  log.dateStr,
                  style: AppTypography.body.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  log.timeWindow,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),

            // Right: Duration & Distance Covered
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  log.durationStr,
                  style: AppTypography.body.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  log.distanceStr,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
