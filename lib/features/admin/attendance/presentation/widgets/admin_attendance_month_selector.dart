import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_dimens.dart';
import '../../../../../core/theme/app_typography.dart';

/// 48 dp pinned month switcher bar for Screen 22.
class AdminAttendanceMonthSelector extends StatelessWidget {
  const AdminAttendanceMonthSelector({
    super.key,
    required this.selectedMonth,
    required this.onPreviousMonth,
    required this.onNextMonth,
  });

  final String selectedMonth;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.neutral200, width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          // Previous Month Button
          IconButton(
            key: const Key('btn-prev-month'),
            icon: const Icon(
              Icons.chevron_left_rounded,
              color: AppColors.primary600,
              size: 24,
            ),
            onPressed: onPreviousMonth,
            tooltip: 'Previous Month',
          ),

          // Current Month Center Display
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(
                  Icons.calendar_month_rounded,
                  color: AppColors.primary600,
                  size: 18,
                ),
                const SizedBox(width: AppSpacing.x2),
                Text(
                  selectedMonth,
                  style: AppTypography.title.copyWith(
                    color: AppColors.neutral900,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          // Next Month Button
          IconButton(
            key: const Key('btn-next-month'),
            icon: const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.primary600,
              size: 24,
            ),
            onPressed: onNextMonth,
            tooltip: 'Next Month',
          ),
        ],
      ),
    );
  }
}
