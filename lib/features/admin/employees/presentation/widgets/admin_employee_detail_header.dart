import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_dimens.dart';
import '../../../../../core/theme/app_typography.dart';
import '../controllers/admin_employee_list_state.dart';

/// Screen 18 Header: 170+ dp tall #016893 container with rounded bottom corners,
/// white back button, overflow menu, 80 dp circular avatar, name, code pill, and live duty pill.
class AdminEmployeeDetailHeader extends StatelessWidget {
  const AdminEmployeeDetailHeader({
    super.key,
    required this.employee,
    this.onBack,
    this.onMoreOptions,
  });

  final AdminEmployeeItem employee;
  final VoidCallback? onBack;
  final VoidCallback? onMoreOptions;

  @override
  Widget build(BuildContext context) {
    final isBlocked = employee.status == AdminEmployeeStatus.blocked;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.primary600,
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(AppRadius.xl),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.x4,
        AppSpacing.x2,
        AppSpacing.x4,
        AppSpacing.x8, // Room for 24dp overlap from body
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // 1. Top Action Icons Bar (48x48 dp touch targets)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  key: const Key('btn-employee-detail-back'),
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                  onPressed: onBack ?? () => Navigator.of(context).maybePop(),
                ),
                IconButton(
                  key: const Key('btn-employee-detail-overflow'),
                  icon: const Icon(
                    Icons.more_vert_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                  onPressed:
                      onMoreOptions ??
                      () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Options for ${employee.name}'),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      },
                ),
              ],
            ),

            // 2. 80 dp Circular Avatar
            Container(
              key: const Key('avatar-employee-detail'),
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                  width: 2.0,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x20000000),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                employee.initials,
                style: AppTypography.display.copyWith(
                  color: isBlocked
                      ? AppColors.textSecondary
                      : AppColors.primary600,
                  fontWeight: FontWeight.w600,
                  fontSize: 28,
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.x3),

            // 3. Employee Full Name
            Text(
              employee.name,
              style: const TextStyle(
                fontFamily: 'DMSans',
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                height: 1.2,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: AppSpacing.x2),

            // 4. Status Chips & Identifiers Row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Employee Code Pill (15% white fill)
                Container(
                  key: const Key('pill-employee-code'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Text(
                    employee.employeeCode,
                    style: AppTypography.label.copyWith(
                      color: Colors.white,
                      fontSize: 13,
                    ),
                  ),
                ),

                const SizedBox(width: AppSpacing.x2),

                // Live Duty Status Pill
                _buildDutyStatusPill(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDutyStatusPill() {
    Color bg;
    Color? dotColor;
    Color textColor;
    String label;

    switch (employee.status) {
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
        label = 'No update 5 min';
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
      key: const Key('pill-employee-duty-status'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dotColor != null) ...[
            Container(
              width: 6,
              height: 6,
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
