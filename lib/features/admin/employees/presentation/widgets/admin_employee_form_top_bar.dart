import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_typography.dart';

/// Screen 19 Top App Bar with back/close, title, and conditional save action.
class AdminEmployeeFormTopBar extends StatelessWidget implements PreferredSizeWidget {
  const AdminEmployeeFormTopBar({
    super.key,
    required this.isEditMode,
    required this.isValid,
    required this.isSaving,
    required this.onClose,
    required this.onSave,
  });

  final bool isEditMode;
  final bool isValid;
  final bool isSaving;
  final VoidCallback onClose;
  final VoidCallback onSave;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.neutral200),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: <Widget>[
          // Close / X button
          IconButton(
            key: const Key('admin-employee-form-close-btn'),
            icon: const Icon(
              Icons.close_rounded,
              color: AppColors.neutral600,
              size: 22,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            onPressed: onClose,
            tooltip: 'Close',
          ),
          const SizedBox(width: 8),

          // Title
          Expanded(
            child: Text(
              isEditMode ? 'Edit employee' : 'Add employee',
              style: AppTypography.h3.copyWith(
                color: AppColors.neutral900,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          // Header Save button
          TextButton(
            key: const Key('admin-employee-form-header-save-btn'),
            onPressed: isValid && !isSaving ? onSave : null,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: const Size(48, 36),
            ),
            child: Text(
              'Save',
              style: AppTypography.label.copyWith(
                color: isValid && !isSaving
                    ? AppColors.primary600
                    : AppColors.neutral400,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
