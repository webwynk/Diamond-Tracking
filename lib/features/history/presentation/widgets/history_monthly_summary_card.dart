import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';
import '../controllers/duty_history_state.dart';

/// Monthly / Period Summary card styled with #E8F3F8 background and 4 stat blocks
/// adhering strictly to Screen 12 design specifications.
class HistoryMonthlySummaryCard extends StatelessWidget {
  const HistoryMonthlySummaryCard({super.key, required this.summary});

  final DutyHistorySummary summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.x4),
      padding: const EdgeInsets.all(AppSpacing.x4),
      decoration: BoxDecoration(
        color: AppColors.primary50,
        borderRadius: AppRadius.lgAll,
        border: Border.all(
          color: AppColors.primary100.withValues(alpha: 0.8),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Period Label (e.g., "OCTOBER 2026")
          Text(
            summary.periodLabel,
            style: AppTypography.overline.copyWith(
              color: AppColors.textSecondary,
              letterSpacing: 0.6,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.x3),

          // 4-column Stat Blocks Row
          Row(
            children: [
              // Stat 1: Days
              Expanded(
                child: _buildStatBlock(
                  value: summary.totalDays.toString(),
                  label: 'Days',
                ),
              ),
              // Stat 2: Hours
              Expanded(
                child: _buildStatBlock(
                  value: summary.totalHours,
                  label: 'Hours',
                  tight: true,
                ),
              ),
              // Stat 3: Distance km
              Expanded(
                child: _buildStatBlock(
                  value: summary.totalKm.toStringAsFixed(1),
                  label: 'km',
                ),
              ),
              // Stat 4: Visits
              Expanded(
                child: _buildStatBlock(
                  value: summary.totalVisits.toString(),
                  label: 'Visits',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatBlock({
    required String value,
    required String label,
    bool tight = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: TextStyle(
              fontSize: 24,
              height: 1.25,
              fontWeight: FontWeight.w700,
              letterSpacing: tight ? -0.5 : 0,
              color: AppColors.primary600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
