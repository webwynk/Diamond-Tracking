import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_dimens.dart';
import '../../../../../core/theme/app_typography.dart';
import '../../../../../core/utils/date_labels.dart';

/// Screen 18 "THIS MONTH" Telemetry Card: Month dropdown, 2x2 metric grid, and diagnostic footnotes.
class AdminEmployeeMonthlyStatsCard extends StatelessWidget {
  const AdminEmployeeMonthlyStatsCard({
    super.key,
    this.monthName,
    this.daysWorked = 0,
    this.hoursWorked = '0h 00m',
    this.distanceKm = '0.0 km',
    this.visitsCount = 0,
    this.autoEndedDays = 0,
    this.locationFlags = 0,
    this.isAvailable = true,
    this.onMonthSelect,
  });

  /// Month shown on the chip. Defaults to the current month.
  final String? monthName;
  final int daysWorked;
  final String hoursWorked;
  final String distanceKm;
  final int visitsCount;
  final int autoEndedDays;
  final int locationFlags;

  /// False while the month is loading or could not be loaded: the figures show
  /// a dash instead of a made-up zero.
  final bool isAvailable;
  final VoidCallback? onMonthSelect;

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
          // 1. Header: Overline "THIS MONTH" & Month Selector Chip
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'THIS MONTH',
                style: AppTypography.overline.copyWith(
                  color: AppColors.textSecondary,
                  letterSpacing: 1.0,
                ),
              ),
              InkWell(
                key: const Key('btn-employee-select-month'),
                onTap: onMonthSelect,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(color: AppColors.neutral300, width: 1.0),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        monthName ?? DateLabels.monthName(DateTime.now()),
                        style: AppTypography.label.copyWith(
                          color: AppColors.neutral600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.expand_more_rounded,
                        size: 16,
                        color: AppColors.neutral600,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.x3),

          // 2. 2x2 Telemetry Metric Grid
          Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildMetricBlock(
                      key: const Key('metric-days-worked'),
                      value: isAvailable ? '$daysWorked' : '–',
                      label: 'Days worked',
                    ),
                  ),
                  const SizedBox(width: AppSpacing.x3),
                  Expanded(
                    child: _buildMetricBlock(
                      key: const Key('metric-hours-worked'),
                      value: isAvailable ? hoursWorked : '–',
                      label: 'Hours',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.x3),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricBlock(
                      key: const Key('metric-distance-km'),
                      value: isAvailable ? distanceKm : '–',
                      label: 'Distance',
                    ),
                  ),
                  const SizedBox(width: AppSpacing.x3),
                  Expanded(
                    child: _buildMetricBlock(
                      key: const Key('metric-visits-count'),
                      value: isAvailable ? '$visitsCount' : '–',
                      label: 'Visits',
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.x3),

          // 3. Metric Diagnostics Footnote
          Container(
            padding: const EdgeInsets.only(top: AppSpacing.x3),
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: AppColors.border, width: 1.0),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Auto-ended days
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.warning,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isAvailable
                          ? '$autoEndedDays ${autoEndedDays == 1 ? 'day' : 'days'} auto-ended'
                          : 'auto-ended days: –',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),

                // Location flags
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.error,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isAvailable
                          ? '$locationFlags location ${locationFlags == 1 ? 'flag' : 'flags'}'
                          : 'location flags: –',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricBlock({
    required Key key,
    required String value,
    required String label,
  }) {
    return Container(
      key: key,
      padding: const EdgeInsets.all(AppSpacing.x3),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.border, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'DMSans',
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
              fontFeatures: [FontFeature.tabularFigures()],
              height: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
