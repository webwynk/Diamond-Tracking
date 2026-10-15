import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_typography.dart';

/// Standard form text field for Diamond Agritech.
///
/// Features:
/// - Label sits strictly **above** the field (Design System Rule 85).
/// - 48 dp minimum touch and control height ([AppSizes.controlHeight]).
/// - 12 dp border radius ([AppRadius.mdAll]).
/// - DM Sans typography throughout.
/// - Inline error state with warning icon and helper text beneath.
class AppTextField extends StatelessWidget {
  const AppTextField({
    required this.label,
    super.key,
    this.controller,
    this.hintText,
    this.helperText,
    this.errorText,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.prefixIcon,
    this.suffixIcon,
    this.onChanged,
    this.onSubmitted,
    this.validator,
    this.enabled = true,
    this.readOnly = false,
    this.onTap,
    this.autofocus = false,
    this.maxLines = 1,
    this.minLines,
    this.focusNode,
  });

  final String label;
  final TextEditingController? controller;
  final String? hintText;
  final String? helperText;
  final String? errorText;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FormFieldValidator<String>? validator;
  final bool enabled;
  final bool readOnly;
  final VoidCallback? onTap;
  final bool autofocus;
  final int maxLines;
  final int? minLines;
  final FocusNode? focusNode;

  bool get _hasError => errorText != null && errorText!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // Label strictly above the field
        Text(
          label,
          style: AppTypography.label.withColor(
            enabled ? AppColors.textSecondary : AppColors.textDisabled,
          ),
        ),
        const SizedBox(height: AppSpacing.x2),
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          enabled: enabled,
          readOnly: readOnly,
          onTap: onTap,
          autofocus: autofocus,
          maxLines: maxLines,
          minLines: minLines,
          onChanged: onChanged,
          onFieldSubmitted: onSubmitted,
          validator: validator,
          style: AppTypography.bodyLarge.withColor(
            enabled ? AppColors.textPrimary : AppColors.textDisabled,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: AppTypography.body.withColor(AppColors.textDisabled),
            prefixIcon: prefixIcon,
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: enabled ? AppColors.surface : AppColors.neutral50,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.x4,
              vertical: AppSpacing.x3,
            ),
            border: const OutlineInputBorder(
              borderRadius: AppRadius.mdAll,
              borderSide: BorderSide(color: AppColors.neutral300, width: 1),
            ),
            enabledBorder: const OutlineInputBorder(
              borderRadius: AppRadius.mdAll,
              borderSide: BorderSide(color: AppColors.neutral300, width: 1),
            ),
            focusedBorder: const OutlineInputBorder(
              borderRadius: AppRadius.mdAll,
              borderSide: BorderSide(color: AppColors.primary600, width: 2),
            ),
            disabledBorder: const OutlineInputBorder(
              borderRadius: AppRadius.mdAll,
              borderSide: BorderSide(color: AppColors.neutral200, width: 1),
            ),
            errorBorder: const OutlineInputBorder(
              borderRadius: AppRadius.mdAll,
              borderSide: BorderSide(color: AppColors.error, width: 1.5),
            ),
            focusedErrorBorder: const OutlineInputBorder(
              borderRadius: AppRadius.mdAll,
              borderSide: BorderSide(color: AppColors.error, width: 2),
            ),
            errorText: null, // Custom error display below field
          ),
        ),
        if (_hasError) ...<Widget>[
          const SizedBox(height: AppSpacing.x1),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              const Icon(
                Icons.error_outline_rounded,
                size: 14,
                color: AppColors.error,
              ),
              const SizedBox(width: AppSpacing.x1),
              Expanded(
                child: Text(
                  errorText!,
                  style: AppTypography.caption.withColor(AppColors.error),
                ),
              ),
            ],
          ),
        ] else if (helperText != null && helperText!.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.x1),
          Text(
            helperText!,
            style: AppTypography.caption.withColor(AppColors.textSecondary),
          ),
        ],
      ],
    );
  }
}
