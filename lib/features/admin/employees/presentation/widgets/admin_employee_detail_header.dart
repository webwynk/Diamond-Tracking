import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_dimens.dart';
import '../../../../../core/theme/app_typography.dart';
import '../controllers/admin_employee_list_state.dart';

/// Screen 18 identity hero: brand blue with rounded bottom corners, back and
/// edit buttons, the avatar, the name, the employee code and the duty status.
///
/// Leaves room at the bottom for the action bar, which floats over its edge.
class AdminEmployeeDetailHeader extends StatelessWidget {
  const AdminEmployeeDetailHeader({
    super.key,
    required this.employee,
    this.onBack,
    this.onEdit,
  });

  /// How far the action bar below overlaps this hero.
  static const double overlap = AppSpacing.x8;

  static const double _avatarSize = 72;

  final AdminEmployeeItem employee;
  final VoidCallback? onBack;
  final VoidCallback? onEdit;

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
        AppSpacing.x2,
        0,
        AppSpacing.x2,
        overlap + AppSpacing.x5,
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                IconButton(
                  key: const Key('btn-employee-detail-back'),
                  tooltip: 'Back',
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: AppColors.neutral0,
                    size: AppSizes.icon,
                  ),
                  onPressed: onBack ?? () => Navigator.of(context).maybePop(),
                ),
                IconButton(
                  key: const Key('btn-employee-detail-edit'),
                  tooltip: 'Edit employee',
                  icon: const Icon(
                    Icons.edit_outlined,
                    color: AppColors.neutral0,
                    size: AppSizes.icon,
                  ),
                  onPressed: onEdit,
                ),
              ],
            ),
            Container(
              key: const Key('avatar-employee-detail'),
              width: _avatarSize,
              height: _avatarSize,
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.primary400,
                  width: AppSpacing.x1,
                  strokeAlign: BorderSide.strokeAlignOutside,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                employee.initials,
                style: AppTypography.h2.withColor(
                  isBlocked ? AppColors.textSecondary : AppColors.primary600,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.x4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4),
              child: Text(
                employee.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AppTypography.h2.withColor(AppColors.neutral0),
              ),
            ),
            const SizedBox(height: AppSpacing.x2),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: AppSpacing.x2,
              runSpacing: AppSpacing.x2,
              children: <Widget>[
                Container(
                  key: const Key('pill-employee-code'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.x3,
                    vertical: AppSpacing.x1,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.neutral0.withValues(alpha: 0.16),
                    borderRadius: AppRadius.fullAll,
                  ),
                  child: Text(
                    employee.employeeCode,
                    style: AppTypography.label.tabular.withColor(
                      AppColors.neutral0,
                    ),
                  ),
                ),
                _StatusChip(employee: employee),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The duty status: a white chip with the status colour as a dot and the
/// status in words, so it reads on the blue hero and without colour.
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.employee});

  final AdminEmployeeItem employee;

  @override
  Widget build(BuildContext context) {
    final (Color dot, String label) = switch (employee.status) {
      AdminEmployeeStatus.onDuty => (
        AppColors.statusActive,
        employee.dutyStartTime == null
            ? 'On duty'
            : 'On duty · since ${employee.dutyStartTime}',
      ),
      AdminEmployeeStatus.needsCheck => (
        AppColors.statusSuspect,
        'Check needed',
      ),
      AdminEmployeeStatus.stale => (AppColors.statusStale, 'No update 5 min'),
      AdminEmployeeStatus.offDuty => (AppColors.statusOff, 'Off duty'),
      AdminEmployeeStatus.blocked => (AppColors.statusBlocked, 'Blocked'),
    };

    return Container(
      key: const Key('pill-employee-duty-status'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x3,
        vertical: AppSpacing.x1,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.fullAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: AppSpacing.x2,
            height: AppSpacing.x2,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: AppSpacing.x2),
          Flexible(
            child: Text(
              label,
              style: AppTypography.label.withColor(AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
