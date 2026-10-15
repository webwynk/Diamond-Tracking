import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';

/// Card 2 — THIS MONTH: 2x2 grid of stat blocks adhering to Screen 13 specifications.
class ProfileMonthStatsGrid extends StatelessWidget {
  const ProfileMonthStatsGrid({
    super.key,
    required this.monthLabel,
    required this.daysWorked,
    required this.hoursWorked,
    required this.distanceKm,
    required this.visitsCount,
  });

  final String monthLabel;
  final int daysWorked;
  final String hoursWorked;
  final double distanceKm;
  final int visitsCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.neutral200, width: 1),
      ),
      padding: const EdgeInsets.all(AppSpacing.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'THIS MONTH',
                style: AppTypography.overline.copyWith(
                  color: AppColors.textSecondary,
                  letterSpacing: 0.6,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                monthLabel,
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.x3),

          // 2x2 Stat Grid (using Rows & Columns to avoid nested grid constraints)
          Column(
            children: [
              // Row 1: Days worked & Hours
              Row(
                children: [
                  Expanded(
                    child: _buildStatCell(
                      value: daysWorked.toString(),
                      label: 'Days worked',
                      icon: Icons.event_available_rounded,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.x3),
                  Expanded(
                    child: _buildStatCell(
                      value: hoursWorked,
                      label: 'Hours',
                      icon: Icons.schedule_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.x3),

              // Row 2: Distance & Visits
              Row(
                children: [
                  Expanded(
                    child: _buildStatCell(
                      value: '${distanceKm.toStringAsFixed(1)} km',
                      label: 'Distance',
                      icon: Icons.two_wheeler_rounded,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.x3),
                  Expanded(
                    child: _buildStatCell(
                      value: visitsCount.toString(),
                      label: 'Visits',
                      icon: Icons.agriculture_rounded,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCell({
    required String value,
    required String label,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.x3 + 2),
      decoration: BoxDecoration(
        color: AppColors.neutral50,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: AppColors.neutral200, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                icon,
                size: 18,
                color: AppColors.textSecondary.withValues(alpha: 0.6),
              ),
            ],
          ),
          const SizedBox(height: 6),
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
