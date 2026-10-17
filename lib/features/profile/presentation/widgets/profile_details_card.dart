import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';

/// Card 1 — MY DETAILS showing phone, email, and joined date
/// with leading icons adhering strictly to Screen 13 design specifications.
class ProfileDetailsCard extends StatelessWidget {
  const ProfileDetailsCard({
    super.key,
    required this.phone,
    required this.email,
    required this.joinedDate,
  });

  final String phone;
  final String email;
  final String joinedDate;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.neutral200, width: 1),
      ),
      padding: const EdgeInsets.all(AppSpacing.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Overline Header
          Text(
            'MY DETAILS',
            style: AppTypography.overline.copyWith(
              color: AppColors.textSecondary,
              letterSpacing: 0.6,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.x1),

          // Row 1: Phone
          _buildDetailRow(
            icon: Icons.phone_outlined,
            label: 'Phone',
            value: phone,
            showDivider: true,
          ),

          // Row 2: Email
          _buildDetailRow(
            icon: Icons.mail_outline_rounded,
            label: 'Email',
            value: email,
            showDivider: true,
          ),

          // Row 3: Joined Date
          _buildDetailRow(
            icon: Icons.calendar_today_outlined,
            label: 'Joined',
            value: joinedDate,
            showDivider: false,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    required bool showDivider,
  }) {
    return Column(
      children: [
        SizedBox(
          height: 56,
          child: Row(
            children: [
              // 20 dp Leading Icon in 32x32 container
              SizedBox(
                width: 32,
                height: 32,
                child: Icon(icon, size: 20, color: AppColors.textDisabled),
              ),
              const SizedBox(width: AppSpacing.x3),

              // Column: Caption + Value
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
                    const SizedBox(height: 2),
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
            ],
          ),
        ),
        if (showDivider)
          const Divider(height: 1, thickness: 1, color: AppColors.neutral200),
      ],
    );
  }
}
