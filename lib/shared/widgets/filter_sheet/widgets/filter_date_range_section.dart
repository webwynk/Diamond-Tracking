import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';
import '../controllers/filter_sheet_state.dart';

/// Date range quick chips and preview field for Screen 27 (Filter Bottom Sheet).
class FilterDateRangeSection extends StatelessWidget {
  const FilterDateRangeSection({
    super.key,
    required this.selectedPreset,
    required this.dateText,
    required this.onPresetSelected,
  });

  final FilterDatePreset selectedPreset;
  final String dateText;
  final ValueChanged<FilterDatePreset> onPresetSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          'DATE RANGE',
          style: AppTypography.overline.copyWith(
            color: AppColors.neutral600,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: AppSpacing.x2),

        // Quick date presets row
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: FilterDatePreset.values.map((preset) {
              final isSelected = selectedPreset == preset;
              return Padding(
                padding: const EdgeInsets.only(right: AppSpacing.x2),
                child: InkWell(
                  key: Key('chip-date-${preset.name}'),
                  onTap: () => onPresetSelected(preset),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    height: 32,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary600
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.full),
                      border: isSelected
                          ? null
                          : Border.all(color: AppColors.neutral300),
                    ),
                    child: Text(
                      preset.label,
                      style: AppTypography.label.copyWith(
                        color: isSelected
                            ? AppColors.surface
                            : AppColors.neutral600,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: AppSpacing.x3),

        // Read-only date preview container
        Container(
          key: const Key('field-filter-date-preview'),
          height: 48,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4),
          decoration: BoxDecoration(
            color: AppColors.neutral50,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.neutral300),
          ),
          child: Row(
            children: <Widget>[
              const Icon(
                Icons.calendar_today_outlined,
                size: 20,
                color: AppColors.neutral500,
              ),
              const SizedBox(width: AppSpacing.x3),
              Text(
                dateText,
                style: AppTypography.body.copyWith(
                  color: AppColors.neutral900,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
