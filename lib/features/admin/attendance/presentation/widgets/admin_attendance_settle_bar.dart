import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_dimens.dart';
import '../../../../../core/theme/app_typography.dart';

/// Sticky bottom payroll settlement bar for Screen 22.
class AdminAttendanceSettleBar extends StatelessWidget {
  const AdminAttendanceSettleBar({
    super.key,
    required this.payableHours,
    required this.payableAmount,
    required this.isApproved,
    required this.onAdjust,
    required this.onApprove,
  });

  final String payableHours;
  final String payableAmount;
  final bool isApproved;
  final VoidCallback onAdjust;
  final VoidCallback onApprove;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.neutral200, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x4,
        vertical: 10,
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            // Left: Payable Hours & Amount
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    'PAYABLE HOURS',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.overline.copyWith(
                      color: AppColors.neutral500,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[
                      Text(
                        payableHours,
                        style: AppTypography.title.copyWith(
                          color: AppColors.primary600,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '($payableAmount)',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.neutral500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.x2),

            // Right: Adjust + Approve Actions
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                // Adjust Button
                OutlinedButton.icon(
                  key: const Key('btn-attendance-adjust'),
                  onPressed: onAdjust,
                  icon: const Icon(
                    Icons.edit_calendar_outlined,
                    size: 16,
                    color: AppColors.primary600,
                  ),
                  label: Text(
                    'Adjust',
                    style: AppTypography.label.copyWith(
                      color: AppColors.primary600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary600,
                    side: const BorderSide(color: AppColors.neutral300, width: 1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    minimumSize: const Size(0, 38),
                  ),
                ),
                const SizedBox(width: AppSpacing.x2),

                // Approve Month Button
                ElevatedButton.icon(
                  key: const Key('btn-attendance-approve'),
                  onPressed: isApproved ? null : onApprove,
                  icon: Icon(
                    isApproved ? Icons.check_circle_rounded : Icons.done_all_rounded,
                    size: 16,
                    color: AppColors.neutral0,
                  ),
                  label: Text(
                    isApproved ? 'Approved' : 'Approve Month',
                    style: AppTypography.label.copyWith(
                      color: AppColors.neutral0,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isApproved
                        ? AppColors.success
                        : AppColors.primary600,
                    disabledBackgroundColor: AppColors.success,
                    disabledForegroundColor: AppColors.neutral0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    minimumSize: const Size(0, 38),
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
