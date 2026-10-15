import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_dimens.dart';
import '../../../../../core/theme/app_typography.dart';
import '../controllers/admin_employee_list_state.dart';

/// 80 dp employee roster card displaying monogram avatar, identity, status pill, and chevron.
class AdminEmployeeCard extends StatelessWidget {
  const AdminEmployeeCard({
    super.key,
    required this.employee,
    required this.onTap,
  });

  final AdminEmployeeItem employee;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isBlocked = employee.status == AdminEmployeeStatus.blocked;

    return Container(
      constraints: const BoxConstraints(minHeight: 80),
      decoration: BoxDecoration(
        color: isBlocked ? AppColors.background : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: AppColors.border,
          width: 1.0,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: Key('card-employee-${employee.id}'),
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.x4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Left: Avatar + Identity Metadata
                Expanded(
                  child: Row(
                    children: [
                      // 44dp Circular Monogram Avatar
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: isBlocked
                              ? AppColors.border
                              : AppColors.primary50,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          employee.initials,
                          style: AppTypography.title.copyWith(
                            color: isBlocked
                                ? AppColors.textSecondary
                                : AppColors.primary600,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ),

                      const SizedBox(width: AppSpacing.x3),

                      // Identity Column
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              employee.name,
                              style: AppTypography.title.copyWith(
                                color: isBlocked
                                    ? AppColors.textPrimary.withValues(alpha: 0.7)
                                    : AppColors.textPrimary,
                                fontWeight: FontWeight.w600,
                                decoration: isBlocked
                                    ? TextDecoration.lineThrough
                                    : null,
                                decorationColor: AppColors.textDisabled,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${employee.employeeCode} · ${employee.phoneNumber}',
                              style: AppTypography.caption.copyWith(
                                color: isBlocked
                                    ? AppColors.textDisabled
                                    : AppColors.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: AppSpacing.x2),

                // Right: Status Pill & Chevron
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildStatusPill(employee.status),
                    const SizedBox(width: AppSpacing.x2),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.neutral300,
                      size: 20,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusPill(AdminEmployeeStatus status) {
    Color bg;
    Color? dotColor;
    Color textColor;
    String label;

    switch (status) {
      case AdminEmployeeStatus.onDuty:
        bg = AppColors.successBg;
        dotColor = const Color(0xFF15803D);
        textColor = const Color(0xFF15803D);
        label = 'On duty';
        break;
      case AdminEmployeeStatus.needsCheck:
        bg = AppColors.errorBg;
        dotColor = AppColors.error;
        textColor = AppColors.error;
        label = 'Check needed';
        break;
      case AdminEmployeeStatus.stale:
        bg = AppColors.warningBg;
        dotColor = const Color(0xFF92400E);
        textColor = const Color(0xFF92400E);
        label = 'No update';
        break;
      case AdminEmployeeStatus.offDuty:
        bg = const Color(0xFFF1F5F9);
        dotColor = AppColors.textSecondary;
        textColor = AppColors.textSecondary;
        label = 'Off duty';
        break;
      case AdminEmployeeStatus.blocked:
        bg = const Color(0xFF1E293B);
        dotColor = null;
        textColor = Colors.white;
        label = 'Blocked';
        break;
    }

    return Container(
      key: Key('badge-employee-status-${employee.id}'),
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (dotColor != null) ...[
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: AppTypography.label.copyWith(
              color: textColor,
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
