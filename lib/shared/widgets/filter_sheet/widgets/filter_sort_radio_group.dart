import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../controllers/filter_sheet_state.dart';

/// Single-select radio group for sorting options in Screen 27.
class FilterSortRadioGroup extends StatelessWidget {
  const FilterSortRadioGroup({
    super.key,
    required this.selectedSort,
    required this.onSortSelected,
  });

  final EmployeeSortOption selectedSort;
  final ValueChanged<EmployeeSortOption> onSortSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          'SORT BY',
          style: AppTypography.overline.copyWith(
            color: AppColors.neutral600,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        ...EmployeeSortOption.values.asMap().entries.map((entry) {
          final index = entry.key;
          final option = entry.value;
          final isSelected = selectedSort == option;
          final isLast = index == EmployeeSortOption.values.length - 1;

          return InkWell(
            key: Key('radio-sort-${option.name}'),
            onTap: () => onSortSelected(option),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                border: isLast
                    ? null
                    : const Border(
                        bottom: BorderSide(
                          color: AppColors.neutral100,
                          width: 1,
                        ),
                      ),
              ),
              child: Row(
                children: <Widget>[
                  // Custom 20x20 radio button indicator
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary600
                            : AppColors.neutral300,
                        width: isSelected ? 2 : 1.5,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: isSelected
                        ? Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.primary600,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    option.label,
                    style: AppTypography.body.copyWith(
                      color: AppColors.neutral900,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}
