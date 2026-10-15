import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_dimens.dart';
import '../../../../../core/theme/app_typography.dart';
import '../controllers/admin_employee_list_state.dart';

/// White card with Overline "CONTACT" and rows for Phone, Email, and Joined date.
class AdminEmployeeContactCard extends StatelessWidget {
  const AdminEmployeeContactCard({
    super.key,
    required this.employee,
    this.email = 'suresh.p@diamondagritech.in',
    this.joinedDate = '18 Feb 2026',
    this.onPhoneTap,
    this.onEmailTap,
  });

  final AdminEmployeeItem employee;
  final String email;
  final String joinedDate;
  final VoidCallback? onPhoneTap;
  final VoidCallback? onEmailTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border, width: 1.0),
      ),
      padding: const EdgeInsets.all(AppSpacing.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header Overline
          Text(
            'CONTACT',
            style: AppTypography.overline.copyWith(
              color: AppColors.textSecondary,
              letterSpacing: 1.0,
            ),
          ),

          const SizedBox(height: AppSpacing.x2),

          // Row 1: Phone
          _buildContactRow(
            key: const Key('row-contact-phone'),
            icon: Icons.call_rounded,
            label: 'Phone',
            value: employee.phoneNumber,
            showChevron: true,
            onTap: onPhoneTap ??
                () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Dialing ${employee.phoneNumber}...'),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
          ),

          const Divider(color: AppColors.border, height: 1),

          // Row 2: Email
          _buildContactRow(
            key: const Key('row-contact-email'),
            icon: Icons.mail_rounded,
            label: 'Email',
            value: email,
            showChevron: true,
            onTap: onEmailTap ??
                () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Opening email to $email...'),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
          ),

          const Divider(color: AppColors.border, height: 1),

          // Row 3: Joined Date
          _buildContactRow(
            key: const Key('row-contact-joined'),
            icon: Icons.calendar_today_rounded,
            label: 'Joined',
            value: joinedDate,
            showChevron: false,
          ),
        ],
      ),
    );
  }

  Widget _buildContactRow({
    required Key key,
    required IconData icon,
    required String label,
    required String value,
    required bool showChevron,
    VoidCallback? onTap,
  }) {
    return InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: SizedBox(
        height: 56,
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.textDisabled),
            const SizedBox(width: AppSpacing.x3),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    value,
                    style: AppTypography.body.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (showChevron)
              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: AppColors.neutral300,
              ),
          ],
        ),
      ),
    );
  }
}
