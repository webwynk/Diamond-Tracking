import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_typography.dart';
import 'app_button.dart';

/// Reusable empty state view matching Screen 28 and docs/03-DESIGN-SYSTEM.md section 10.
///
/// Features:
/// - 56 dp rounded container with subtle brand tint ([AppColors.primary50]).
/// - Vector icon with brand accent ([AppColors.primary600]).
/// - Headline in [AppTypography.title] ([AppColors.textPrimary]).
/// - Description in [AppTypography.caption] ([AppColors.textSecondary]).
/// - Optional primary or secondary action button.
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    required this.title,
    required this.description,
    required this.icon,
    super.key,
    this.actionLabel,
    this.onActionPressed,
    this.isActionOutlined = true,
  });

  /// No notifications.
  factory AppEmptyState.noNotifications() {
    return const AppEmptyState(
      icon: Icons.notifications_none_rounded,
      title: "You're all caught up",
      description: 'New alerts will appear here.',
    );
  }

  final String title;
  final String description;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onActionPressed;
  final bool isActionOutlined;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            // 56 dp rounded container with subtle brand tint
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: AppColors.primary50,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(icon, size: 28, color: AppColors.primary600),
              ),
            ),
            const SizedBox(height: AppSpacing.x4),
            Text(
              title,
              style: AppTypography.title.withColor(AppColors.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.x1),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 280),
              child: Text(
                description,
                style: AppTypography.caption.withColor(AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ),
            if (actionLabel != null && onActionPressed != null) ...<Widget>[
              const SizedBox(height: AppSpacing.x5),
              AppButton(
                label: actionLabel!,
                onPressed: onActionPressed,
                variant: isActionOutlined
                    ? AppButtonVariant.secondary
                    : AppButtonVariant.primary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
