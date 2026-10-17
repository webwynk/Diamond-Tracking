import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_dimens.dart';
import '../../../../../core/theme/app_typography.dart';

/// Card 1: EMPLOYEE DETAILS (Full name, Phone number, Email)
class AdminEmployeeDetailsCard extends StatelessWidget {
  const AdminEmployeeDetailsCard({
    super.key,
    required this.nameController,
    required this.phoneController,
    required this.emailController,
    required this.onNameChanged,
    required this.onPhoneChanged,
    required this.onEmailChanged,
  });

  final TextEditingController nameController;
  final TextEditingController phoneController;
  final TextEditingController emailController;
  final ValueChanged<String> onNameChanged;
  final ValueChanged<String> onPhoneChanged;
  final ValueChanged<String> onEmailChanged;

  @override
  Widget build(BuildContext context) {
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
          // Overline Header
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text('EMPLOYEE DETAILS', style: AppTypography.overline),
              Icon(Icons.badge_outlined, size: 16, color: AppColors.neutral400),
            ],
          ),
          const SizedBox(height: AppSpacing.x4),

          // Field 1: Full name
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Full name',
                style: AppTypography.label.copyWith(
                  color: AppColors.neutral500,
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                height: 48,
                child: TextField(
                  key: const Key('admin-employee-name-field'),
                  controller: nameController,
                  onChanged: onNameChanged,
                  style: AppTypography.bodyLarge.copyWith(
                    color: AppColors.neutral900,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Enter full name',
                    hintStyle: AppTypography.bodyLarge.copyWith(
                      color: AppColors.neutral400,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    filled: true,
                    fillColor: AppColors.surface,
                    enabledBorder: const OutlineInputBorder(
                      borderRadius: AppRadius.mdAll,
                      borderSide: BorderSide(color: AppColors.neutral300),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderRadius: AppRadius.mdAll,
                      borderSide: BorderSide(
                        color: AppColors.primary600,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.x4),

          // Field 2: Phone number
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Phone number',
                style: AppTypography.label.copyWith(
                  color: AppColors.neutral500,
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                height: 48,
                child: TextField(
                  key: const Key('admin-employee-phone-field'),
                  controller: phoneController,
                  onChanged: onPhoneChanged,
                  keyboardType: TextInputType.phone,
                  style: AppTypography.bodyLarge.copyWith(
                    color: AppColors.neutral900,
                  ),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(
                      Icons.call_outlined,
                      size: 18,
                      color: AppColors.neutral400,
                    ),
                    hintText: '+91 00000 00000',
                    hintStyle: AppTypography.bodyLarge.copyWith(
                      color: AppColors.neutral400,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    filled: true,
                    fillColor: AppColors.surface,
                    enabledBorder: const OutlineInputBorder(
                      borderRadius: AppRadius.mdAll,
                      borderSide: BorderSide(color: AppColors.neutral300),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderRadius: AppRadius.mdAll,
                      borderSide: BorderSide(
                        color: AppColors.primary600,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Used for SMS dispatch and field verification',
                style: AppTypography.caption.copyWith(
                  color: AppColors.neutral400,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.x4),

          // Field 3: Email
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Email',
                style: AppTypography.label.copyWith(
                  color: AppColors.neutral500,
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                height: 48,
                child: TextField(
                  key: const Key('admin-employee-email-field'),
                  controller: emailController,
                  onChanged: onEmailChanged,
                  keyboardType: TextInputType.emailAddress,
                  style: AppTypography.bodyLarge.copyWith(
                    color: AppColors.neutral900,
                  ),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(
                      Icons.mail_outline_rounded,
                      size: 18,
                      color: AppColors.neutral400,
                    ),
                    hintText: 'name@diamondagritech.in',
                    hintStyle: AppTypography.bodyLarge.copyWith(
                      color: AppColors.neutral400,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    filled: true,
                    fillColor: AppColors.surface,
                    enabledBorder: const OutlineInputBorder(
                      borderRadius: AppRadius.mdAll,
                      borderSide: BorderSide(color: AppColors.neutral300),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderRadius: AppRadius.mdAll,
                      borderSide: BorderSide(
                        color: AppColors.primary600,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Official company domain required',
                style: AppTypography.caption.copyWith(
                  color: AppColors.neutral400,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
