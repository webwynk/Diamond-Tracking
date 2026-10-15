import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';
import '../controllers/filter_sheet_state.dart';

/// Multi-select status chips for Screen 27 (Filter Bottom Sheet).
class FilterStatusChips extends StatelessWidget {
  const FilterStatusChips({
    super.key,
    required this.selectedStatuses,
    required this.onStatusToggled,
  });

  final Set<EmployeeFilterStatus> selectedStatuses;
  final ValueChanged<EmployeeFilterStatus> onStatusToggled;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          'STATUS',
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
          children: EmployeeFilterStatus.values.map((status) {
            final isSelected = selectedStatuses.contains(status);
            return _FilterStatusChip(
              key: Key('chip-status-${status.name}'),
              status: status,
              isSelected: isSelected,
              onTap: () => onStatusToggled(status),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _FilterStatusChip extends StatelessWidget {
  const _FilterStatusChip({
    super.key,
    required this.status,
    required this.isSelected,
    required this.onTap,
  });

  final EmployeeFilterStatus status;
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
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: status.dotColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              status.label,
              style: AppTypography.label.copyWith(
                color: isSelected ? AppColors.primary600 : AppColors.neutral600,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
            if (isSelected) ...<Widget>[
              const SizedBox(width: 4),
              const Icon(
                Icons.check,
                size: 16,
                color: AppColors.primary600,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
