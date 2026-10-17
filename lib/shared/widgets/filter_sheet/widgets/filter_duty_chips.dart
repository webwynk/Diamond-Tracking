import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';
import '../controllers/filter_sheet_state.dart';

/// Duty today filter chips for Screen 27 (Filter Bottom Sheet).
class FilterDutyChips extends StatelessWidget {
  const FilterDutyChips({
    super.key,
    required this.selectedDutyToday,
    required this.onDutyToggled,
  });

  final DutyTodayFilter? selectedDutyToday;
  final ValueChanged<DutyTodayFilter> onDutyToggled;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          'DUTY TODAY',
          style: AppTypography.overline.copyWith(
            color: AppColors.neutral600,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: AppSpacing.x2),
        Wrap(
          spacing: AppSpacing.x2,
          runSpacing: AppSpacing.x2,
          children: DutyTodayFilter.values.map((duty) {
            final isSelected = selectedDutyToday == duty;
            return _FilterDutyChip(
              key: Key('chip-duty-${duty.name}'),
              duty: duty,
              isSelected: isSelected,
              onTap: () => onDutyToggled(duty),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _FilterDutyChip extends StatelessWidget {
  const _FilterDutyChip({
    super.key,
    required this.duty,
    required this.isSelected,
    required this.onTap,
  });

  final DutyTodayFilter duty;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.full),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary50 : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(
            color: isSelected ? AppColors.primary600 : AppColors.neutral300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              duty.label,
              style: AppTypography.label.copyWith(
                color: isSelected ? AppColors.primary600 : AppColors.neutral600,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
            if (isSelected) ...<Widget>[
              const SizedBox(width: 4),
              const Icon(Icons.check, size: 16, color: AppColors.primary600),
            ],
          ],
        ),
      ),
    );
  }
}
