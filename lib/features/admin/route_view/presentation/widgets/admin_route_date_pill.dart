import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_dimens.dart';
import '../../../../../core/theme/app_typography.dart';

/// Floating date selector pill for Screen 23 Route View (Admin).
class AdminRouteDatePill extends StatelessWidget {
  const AdminRouteDatePill({
    super.key,
    required this.selectedDateText,
    required this.onPreviousDate,
    required this.onNextDate,
  });

  final String selectedDateText;
  final VoidCallback onPreviousDate;
  final VoidCallback onNextDate;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: AppColors.neutral200, width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // Previous Date Chevron
          InkWell(
            key: const Key('btn-route-prev-date'),
            onTap: onPreviousDate,
            borderRadius: BorderRadius.circular(AppRadius.full),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(
                Icons.chevron_left_rounded,
                color: AppColors.primary600,
                size: 20,
              ),
            ),
          ),

          // Date Label
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x2),
            child: Text(
              selectedDateText,
              style: AppTypography.label.copyWith(
                color: AppColors.neutral900,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          // Next Date Chevron
          InkWell(
            key: const Key('btn-route-next-date'),
            onTap: onNextDate,
            borderRadius: BorderRadius.circular(AppRadius.full),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(
                Icons.chevron_right_rounded,
                color: AppColors.primary600,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
