import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';
import '../controllers/duty_history_state.dart';

/// Single duty day card adhering strictly to Screen 12 design specifications.
class DutyHistoryCard extends StatelessWidget {
  const DutyHistoryCard({
    super.key,
    required this.item,
    this.onTap,
  });

  final DutyHistoryItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isNoDuty = item.isNoDuty;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.lgAll,
        child: Container(
          constraints: const BoxConstraints(minHeight: 88),
          padding: const EdgeInsets.all(AppSpacing.x4),
          decoration: BoxDecoration(
            color: isNoDuty ? AppColors.neutral50 : AppColors.surface,
            borderRadius: AppRadius.lgAll,
            border: Border.all(
              color: AppColors.neutral200,
              width: 1,
            ),
            boxShadow: isNoDuty
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Row: Date title + Status Chip
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    item.dateTitle,
                    style: AppTypography.title.copyWith(
                      color: isNoDuty
                          ? AppColors.textSecondary
                          : AppColors.textPrimary,
                    ),
                  ),
                  _buildStatusChip(),
                ],
              ),
              const SizedBox(height: AppSpacing.x2),

              // Divider Line
              Container(
                height: 1,
                color: isNoDuty ? AppColors.neutral200 : AppColors.neutral100,
              ),
              const SizedBox(height: AppSpacing.x2),

              // Second Row: 4 Inline Stats
              Row(
                children: [
                  Expanded(
                    child: _buildInlineStat(
                      label: 'Duty time',
                      value: item.dutyTimeStr,
                      isNoDuty: isNoDuty,
                    ),
                  ),
                  Expanded(
                    child: _buildInlineStat(
                      label: 'Duration',
                      value: item.durationStr,
                      isNoDuty: isNoDuty,
                    ),
                  ),
                  Expanded(
                    child: _buildInlineStat(
                      label: 'Distance',
                      value: item.distanceStr,
                      isNoDuty: isNoDuty,
                    ),
                  ),
                  Expanded(
                    child: _buildInlineStat(
                      label: 'Recorded',
                      value: item.visitsStr,
                      isNoDuty: isNoDuty,
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

  Widget _buildStatusChip() {
    switch (item.chipType) {
      case DutyHistoryChipType.none:
        return const SizedBox.shrink();

      case DutyHistoryChipType.autoEnded:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: const BoxDecoration(
            color: AppColors.warningBg,
            borderRadius: AppRadius.fullAll,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.schedule_rounded,
                size: 14,
                color: AppColors.warningText,
              ),
              const SizedBox(width: 4),
              Text(
                'Auto-ended',
                style: AppTypography.label.copyWith(
                  color: AppColors.warningText,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );

      case DutyHistoryChipType.flagged:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: const BoxDecoration(
            color: AppColors.errorBg,
            borderRadius: AppRadius.fullAll,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                size: 14,
                color: AppColors.error,
              ),
              const SizedBox(width: 4),
              Text(
                '${item.flagCount} flags',
                style: AppTypography.label.copyWith(
                  color: AppColors.error,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );

      case DutyHistoryChipType.noDuty:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: const BoxDecoration(
            color: AppColors.neutral200,
            borderRadius: AppRadius.fullAll,
          ),
          child: Text(
            'No duty',
            style: AppTypography.label.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        );
    }
  }

  Widget _buildInlineStat({
    required String label,
    required String value,
    required bool isNoDuty,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            height: 14 / 11,
            color: isNoDuty ? AppColors.textDisabled : AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              height: 20 / 14,
              fontWeight: isNoDuty ? FontWeight.w500 : FontWeight.w600,
              color: isNoDuty ? AppColors.textDisabled : AppColors.textPrimary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}
