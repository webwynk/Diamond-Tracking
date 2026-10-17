import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_dimens.dart';
import '../../../../../core/theme/app_typography.dart';
import '../../../../../domain/entities/user_profile.dart';

/// Card 3: ROLE (Selectable 72 dp side-by-side tiles for Employee and Admin)
class AdminEmployeeRoleCard extends StatelessWidget {
  const AdminEmployeeRoleCard({
    super.key,
    required this.selectedRole,
    required this.onRoleChanged,
  });

  final UserRole selectedRole;
  final ValueChanged<UserRole> onRoleChanged;

  @override
  Widget build(BuildContext context) {
    final isEmployeeSelected = selectedRole == UserRole.employee;
    final isAdminSelected = selectedRole == UserRole.admin;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: AppColors.neutral200),
      ),
      padding: const EdgeInsets.all(AppSpacing.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Header row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              const Text('ROLE', style: AppTypography.overline),
              Text(
                'Permissions tier',
                style: AppTypography.caption.copyWith(
                  color: AppColors.neutral500,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.x3),

          // Side-by-side Role Tiles
          Row(
            children: <Widget>[
              // Tile 1: Employee
              Expanded(
                child: _RoleTile(
                  key: const Key('admin-role-employee-tile'),
                  isSelected: isEmployeeSelected,
                  title: 'Employee',
                  subtitle: 'Field Officer',
                  icon: Icons.person_rounded,
                  onTap: () => onRoleChanged(UserRole.employee),
                ),
              ),
              const SizedBox(width: AppSpacing.x3),

              // Tile 2: Admin
              Expanded(
                child: _RoleTile(
                  key: const Key('admin-role-admin-tile'),
                  isSelected: isAdminSelected,
                  title: 'Admin',
                  subtitle: 'Supervisor',
                  icon: Icons.admin_panel_settings_outlined,
                  onTap: () => onRoleChanged(UserRole.admin),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RoleTile extends StatelessWidget {
  const _RoleTile({
    super.key,
    required this.isSelected,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final bool isSelected;
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.mdAll,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 72,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary50 : AppColors.surface,
          borderRadius: AppRadius.mdAll,
          border: Border.all(
            color: isSelected ? AppColors.primary600 : AppColors.neutral300,
            width: isSelected ? 2.0 : 1.0,
          ),
        ),
        child: Row(
          children: <Widget>[
            // Icon container
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary100 : AppColors.neutral100,
                borderRadius: AppRadius.smAll,
              ),
              child: Icon(
                icon,
                size: 20,
                color: isSelected ? AppColors.primary600 : AppColors.neutral500,
              ),
            ),
            const SizedBox(width: 8),

            // Text column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(
                    title,
                    style: AppTypography.label.copyWith(
                      color: isSelected
                          ? AppColors.primary600
                          : AppColors.neutral700,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    subtitle,
                    style: AppTypography.caption.copyWith(
                      color: isSelected
                          ? AppColors.neutral600
                          : AppColors.neutral400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Indicator
            if (isSelected)
              const Icon(
                Icons.check_circle_rounded,
                size: 18,
                color: AppColors.primary600,
              )
            else
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.neutral300),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
