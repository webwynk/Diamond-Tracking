import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';

/// Top Hero Header block adhering strictly to Screen 13 design specifications:
/// - Height: 140+ dp
/// - Background: Brand Primary #016893
/// - Bottom corners: Radius 24 dp
/// - Centered 72 dp circular white avatar with SemiBold initials
/// - Employee name and 15%-opacity code badge
class ProfileHeaderHero extends StatelessWidget {
  const ProfileHeaderHero({
    super.key,
    required this.fullName,
    required this.employeeCode,
    required this.initials,
    this.isOnDuty = false,
    this.onBack,
  });

  final String fullName;
  final String employeeCode;
  final String initials;
  final bool isOnDuty;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.primary600,
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(AppRadius.xl),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.only(
            left: AppSpacing.x4,
            right: AppSpacing.x4,
            top: AppSpacing.x2,
            bottom: AppSpacing.x8,
          ),
          child: Column(
            children: [
              // Top Bar: Back Button (Left) & Duty Status Pill (Right)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Back Button
                  IconButton(
                    key: const Key('profile-back-btn'),
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: AppColors.neutral0,
                    ),
                    onPressed: () {
                      if (onBack != null) {
                        onBack!();
                      } else if (Navigator.of(context).canPop()) {
                        Navigator.of(context).pop();
                      }
                    },
                    tooltip: 'Back',
                  ),

                  // Duty Status Badge Pill
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: AppRadius.fullAll,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: isOnDuty
                                ? AppColors.success
                                : AppColors.neutral400,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isOnDuty ? 'ACTIVE DUTY' : 'OFF DUTY',
                          style: AppTypography.overline.copyWith(
                            color: AppColors.neutral0,
                            letterSpacing: 0.8,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.x1),

              // Centered Avatar (72x72 dp)
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.25),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      initials,
                      style: AppTypography.h2.copyWith(
                        color: AppColors.primary600,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  // Small Verified Check Badge
                  Positioned(
                    bottom: -2,
                    right: -2,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.primary600,
                          width: 2,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.check_rounded,
                        size: 13,
                        color: AppColors.neutral0,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.x3),

              // Name Heading
              Text(
                fullName,
                style: AppTypography.h3.copyWith(
                  color: AppColors.neutral0,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.x2),

              // Employee Code Badge Pill
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: AppRadius.fullAll,
                ),
                child: Text(
                  employeeCode,
                  style: AppTypography.label.copyWith(
                    color: AppColors.neutral0,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
