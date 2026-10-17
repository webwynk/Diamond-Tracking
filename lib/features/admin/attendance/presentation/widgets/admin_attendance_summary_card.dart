import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_dimens.dart';
import '../../../../../core/theme/app_typography.dart';
import '../controllers/admin_attendance_state.dart';

/// Monthly telemetry audit card with 2x3 metric grid for Screen 22.
class AdminAttendanceSummaryCard extends StatelessWidget {
  const AdminAttendanceSummaryCard({super.key, required this.metrics});

  final AdminMonthlyMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.x4,
        AppSpacing.x3,
        AppSpacing.x4,
        0,
      ),
      decoration: BoxDecoration(
        color: AppColors.primary50,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.primary100, width: 1),
      ),
      padding: const EdgeInsets.all(AppSpacing.x4),
      child: Column(
        children: <Widget>[
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Expanded(
                child: Row(
                  children: <Widget>[
                    const Icon(
                      Icons.analytics_outlined,
                      color: AppColors.primary600,
                      size: 18,
                    ),
                    const SizedBox(width: AppSpacing.x1 + 2),
                    Flexible(
                      child: Text(
                        'MONTHLY TELEMETRY AUDIT',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.overline.copyWith(
                          color: AppColors.primary700,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.x3),

          // 2x3 Metric Grid
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: AppSpacing.x2 + 2,
            crossAxisSpacing: AppSpacing.x2 + 2,
            childAspectRatio: 1.15,
            children: <Widget>[
              // Tile 1: Days worked
              _buildTile(
                value: '${metrics.daysWorked}',
                label: 'Days worked',
                valueColor: AppColors.primary600,
              ),

              // Tile 2: Total hours
              _buildTile(
                value: metrics.totalHoursText,
                label: 'Total hours',
                valueColor: AppColors.primary600,
              ),

              // Tile 3: Distance
              _buildTile(
                value: metrics.distanceKm,
                label: 'Distance',
                valueColor: AppColors.primary600,
              ),

              // Tile 4: Visits
              _buildTile(
                value: '${metrics.visitsCount}',
                label: 'Visits',
                valueColor: AppColors.primary600,
              ),

              // Tile 5: Auto-ended (with timer_off warning icon)
              _buildTile(
                value: '${metrics.autoEndedCount}',
                label: 'Auto-ended',
                valueColor: AppColors.warning,
                trailingIcon: Icons.timer_off_rounded,
                iconColor: AppColors.warning,
              ),

              // Tile 6: Flags (with verified badge)
              _buildTile(
                value: '${metrics.flagsCount}',
                label: 'Flags',
                valueColor: AppColors.neutral900,
                trailingIcon: Icons.verified_rounded,
                iconColor: AppColors.success,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTile({
    required String value,
    required String label,
    required Color valueColor,
    IconData? trailingIcon,
    Color? iconColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: AppColors.neutral200.withValues(alpha: 0.8),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.h3.copyWith(
                    color: valueColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (trailingIcon != null)
                Icon(trailingIcon, size: 16, color: iconColor),
            ],
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.caption.copyWith(color: AppColors.neutral500),
          ),
        ],
      ),
    );
  }
}
