import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_dimens.dart';
import '../../../../../core/theme/app_typography.dart';

/// Card 2: LOGIN (Employee ID with Available chip, Initial PIN with Regen button)
class AdminEmployeeLoginCard extends StatelessWidget {
  const AdminEmployeeLoginCard({
    super.key,
    required this.employeeIdController,
    required this.pinController,
    required this.isEmployeeCodeAvailable,
    required this.onEmployeeIdChanged,
    required this.onPinChanged,
    required this.onRegeneratePin,
  });

  final TextEditingController employeeIdController;
  final TextEditingController pinController;
  final bool isEmployeeCodeAvailable;
  final ValueChanged<String> onEmployeeIdChanged;
  final ValueChanged<String> onPinChanged;
  final VoidCallback onRegeneratePin;

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
              Text(
                'LOGIN',
                style: AppTypography.overline,
              ),
              Icon(
                Icons.vpn_key_outlined,
                size: 16,
                color: AppColors.neutral400,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.x4),

          // Field 1: Employee ID
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Employee ID',
                style: AppTypography.label.copyWith(
                  color: AppColors.neutral500,
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                height: 48,
                child: TextField(
                  key: const Key('admin-employee-id-field'),
                  controller: employeeIdController,
                  onChanged: onEmployeeIdChanged,
                  textCapitalization: TextCapitalization.characters,
                  style: AppTypography.bodyLarge.copyWith(
                    color: AppColors.neutral900,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    hintText: 'DA-XXX',
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
                    suffixIcon: isEmployeeCodeAvailable
                        ? Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: const BoxDecoration(
                                    color: AppColors.successBg,
                                    borderRadius: AppRadius.smAll,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      const Icon(
                                        Icons.check_circle_rounded,
                                        size: 14,
                                        color: AppColors.success,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Available',
                                        style: AppTypography.caption.copyWith(
                                          color: AppColors.success,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          )
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Cannot be changed later.',
                style: AppTypography.caption.copyWith(
                  color: AppColors.neutral400,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.x4),

          // Field 2: Initial PIN
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Initial PIN',
                style: AppTypography.label.copyWith(
                  color: AppColors.neutral500,
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                height: 48,
                child: TextField(
                  key: const Key('admin-employee-pin-field'),
                  controller: pinController,
                  onChanged: onPinChanged,
                  obscureText: true,
                  maxLength: 6,
                  keyboardType: TextInputType.number,
                  style: AppTypography.bodyLarge.copyWith(
                    color: AppColors.neutral900,
                    letterSpacing: 4.0,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    prefixIcon: const Icon(
                      Icons.lock_outline_rounded,
                      size: 18,
                      color: AppColors.neutral400,
                    ),
                    hintText: '••••••',
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
                    suffixIcon: InkWell(
                      key: const Key('admin-employee-pin-regen-btn'),
                      onTap: onRegeneratePin,
                      borderRadius: AppRadius.mdAll,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            const Icon(
                              Icons.casino_outlined,
                              size: 18,
                              color: AppColors.primary600,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Regen',
                              style: AppTypography.caption.copyWith(
                                color: AppColors.primary600,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'The employee must change this at first login.',
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
