import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_dimens.dart';
import '../../../../../core/theme/app_typography.dart';

/// One section of the employee profile (Screen 18): a white card with a title
/// row and an optional action on the right ("View all", a month picker).
///
/// Every profile section uses it, so the cards share one padding, radius,
/// border and title style and cannot drift apart.
class AdminProfileSection extends StatelessWidget {
  const AdminProfileSection({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget child;

  /// Shown at the right of the title row.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.x4,
        AppSpacing.x2,
        AppSpacing.x4,
        AppSpacing.x4,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AppSizes.minTouchTarget,
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      title,
                      style: AppTypography.title.withColor(
                        AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.x1),
          child,
        ],
      ),
    );
  }
}

/// The "View all" link of a section title row, with a full touch target.
class AdminProfileSectionLink extends StatelessWidget {
  const AdminProfileSectionLink({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary600,
        minimumSize: const Size(
          AppSizes.minTouchTarget,
          AppSizes.minTouchTarget,
        ),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x2),
      ),
      child: Text(
        label,
        style: AppTypography.label.withColor(AppColors.primary600),
      ),
    );
  }
}

/// A small status chip: grey when there is nothing to worry about, tinted when
/// there is. Always an icon plus words, never colour alone.
class AdminProfileStatusChip extends StatelessWidget {
  const AdminProfileStatusChip({
    super.key,
    required this.icon,
    required this.label,
    this.background = AppColors.neutral100,
    this.foreground = AppColors.neutral600,
  });

  final IconData icon;
  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x3,
        vertical: AppSpacing.x1,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppRadius.fullAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: AppSizes.iconDense, color: foreground),
          const SizedBox(width: AppSpacing.x1),
          Flexible(
            child: Text(
              label,
              style: AppTypography.label.withColor(foreground),
            ),
          ),
        ],
      ),
    );
  }
}
