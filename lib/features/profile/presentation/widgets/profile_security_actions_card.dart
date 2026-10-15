import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';

/// Card 3 — Actions / Settings: Change PIN and Privacy & Tracking rows.
class ProfileSecurityActionsCard extends StatelessWidget {
  const ProfileSecurityActionsCard({
    super.key,
    required this.onChangePin,
    required this.onPrivacyAndTracking,
  });

  final VoidCallback onChangePin;
  final VoidCallback onPrivacyAndTracking;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.neutral200, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Row 1: Change PIN
          Material(
            color: Colors.transparent,
            child: InkWell(
              key: const Key('btn-change-pin-row'),
              onTap: onChangePin,
              child: Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4),
                child: Row(
                  children: [
                    const Icon(
                      Icons.lock_outline_rounded,
                      size: 20,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: AppSpacing.x3),
                    Expanded(
                      child: Text(
                        'Change PIN',
                        style: AppTypography.body.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Text(
                      '••••',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textDisabled,
                        letterSpacing: 2.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: AppColors.neutral300,
                    ),
                  ],
                ),
              ),
            ),
          ),

          const Divider(height: 1, thickness: 1, color: AppColors.neutral200),

          // Row 2: Privacy and Tracking
          Material(
            color: Colors.transparent,
            child: InkWell(
              key: const Key('btn-privacy-tracking-row'),
              onTap: onPrivacyAndTracking,
              child: Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4),
                child: Row(
                  children: [
                    const Icon(
                      Icons.shield_outlined,
                      size: 20,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: AppSpacing.x3),
                    Expanded(
                      child: Text(
                        'Privacy and tracking',
                        style: AppTypography.body.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: const BoxDecoration(
                        color: AppColors.successBg,
                        borderRadius: AppRadius.fullAll,
                      ),
                      child: Text(
                        'Active',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.success,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: AppColors.neutral300,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
