import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_typography.dart';

/// Button visual variants matching docs/03-DESIGN-SYSTEM.md section 11.
enum AppButtonVariant {
  /// primary-600 fill, white text, 48 dp tall. The main action.
  primary,

  /// primary-600 outline and text, transparent fill. Alternative action.
  secondary,

  /// Text only, primary-600. Low-emphasis action.
  tertiary,

  /// error fill, white text. Dangerous actions like blocking or deleting.
  destructive,
}

/// Standard button for Diamond Agritech.
///
/// Features:
/// - 48 dp standard height ([AppSizes.controlHeight]).
/// - 12 dp border radius ([AppRadius.mdAll]).
/// - DM Sans 13 dp Medium text ([AppTypography.label]).
/// - Inline spinner and disabled state when [isLoading] is true.
/// - Tooltip explaining disabled state if [disabledReason] is provided.
/// - Minimum 48 dp touch target.
class AppButton extends StatelessWidget {
  const AppButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.variant = AppButtonVariant.primary,
    this.isLoading = false,
    this.loadingLabel,
    this.icon,
    this.isFullWidth = false,
    this.disabledReason,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final bool isLoading;
  final String? loadingLabel;
  final Widget? icon;
  final bool isFullWidth;
  final String? disabledReason;

  bool get _isEnabled => onPressed != null && !isLoading;

  @override
  Widget build(BuildContext context) {
    Widget button;

    switch (variant) {
      case AppButtonVariant.primary:
        button = _buildPrimary();
      case AppButtonVariant.secondary:
        button = _buildSecondary();
      case AppButtonVariant.tertiary:
        button = _buildTertiary();
      case AppButtonVariant.destructive:
        button = _buildDestructive();
    }

    if (isFullWidth) {
      button = SizedBox(width: double.infinity, child: button);
    }

    if (!_isEnabled && disabledReason != null && disabledReason!.isNotEmpty) {
      button = Tooltip(message: disabledReason!, child: button);
    }

    return button;
  }

  Widget _buildContent(Color textColor, Color spinnerColor) {
    if (isLoading) {
      return Row(
        mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(spinnerColor),
            ),
          ),
          const SizedBox(width: AppSpacing.x2),
          Text(
            loadingLabel ?? label,
            style: AppTypography.label.withColor(textColor),
          ),
        ],
      );
    }

    if (icon != null) {
      return Row(
        mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          icon!,
          const SizedBox(width: AppSpacing.x2),
          Text(label, style: AppTypography.label.withColor(textColor)),
        ],
      );
    }

    return Text(
      label,
      style: AppTypography.label.withColor(textColor),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildPrimary() {
    return ElevatedButton(
      onPressed: _isEnabled ? onPressed : null,
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(
          AppSizes.minTouchTarget,
          AppSizes.controlHeight,
        ),
        backgroundColor: AppColors.primary600,
        foregroundColor: AppColors.neutral0,
        disabledBackgroundColor: AppColors.primary300,
        disabledForegroundColor: AppColors.neutral400,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4),
      ),
      child: _buildContent(
        _isEnabled ? AppColors.neutral0 : AppColors.neutral400,
        AppColors.neutral0,
      ),
    );
  }

  Widget _buildSecondary() {
    return OutlinedButton(
      onPressed: _isEnabled ? onPressed : null,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(
          AppSizes.minTouchTarget,
          AppSizes.controlHeight,
        ),
        foregroundColor: AppColors.primary600,
        disabledForegroundColor: AppColors.neutral400,
        side: BorderSide(
          color: _isEnabled ? AppColors.primary600 : AppColors.neutral300,
          width: 1,
        ),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4),
      ),
      child: _buildContent(
        _isEnabled ? AppColors.primary600 : AppColors.neutral400,
        AppColors.primary600,
      ),
    );
  }

  Widget _buildTertiary() {
    return TextButton(
      onPressed: _isEnabled ? onPressed : null,
      style: TextButton.styleFrom(
        minimumSize: const Size(
          AppSizes.minTouchTarget,
          AppSizes.controlHeight,
        ),
        foregroundColor: AppColors.primary600,
        disabledForegroundColor: AppColors.neutral400,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4),
      ),
      child: _buildContent(
        _isEnabled ? AppColors.primary600 : AppColors.neutral400,
        AppColors.primary600,
      ),
    );
  }

  Widget _buildDestructive() {
    return ElevatedButton(
      onPressed: _isEnabled ? onPressed : null,
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(
          AppSizes.minTouchTarget,
          AppSizes.controlHeight,
        ),
        backgroundColor: AppColors.error,
        foregroundColor: AppColors.neutral0,
        disabledBackgroundColor: AppColors.errorBg,
        disabledForegroundColor: AppColors.neutral400,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4),
      ),
      child: _buildContent(
        _isEnabled ? AppColors.neutral0 : AppColors.neutral400,
        AppColors.neutral0,
      ),
    );
  }
}

/// Icon-only button strictly enforcing the 48 × 48 dp minimum touch target
/// and accessibility label requirement.
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    super.key,
    this.color,
    this.backgroundColor,
  });

  final Widget icon;
  final VoidCallback? onPressed;
  final String tooltip;
  final Color? color;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: icon,
      onPressed: onPressed,
      tooltip: tooltip,
      iconSize: AppSizes.icon,
      color: color ?? AppColors.neutral700,
      disabledColor: AppColors.neutral400,
      style: IconButton.styleFrom(
        minimumSize: const Size(
          AppSizes.minTouchTarget,
          AppSizes.minTouchTarget,
        ),
        backgroundColor: backgroundColor,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
      ),
    );
  }
}
