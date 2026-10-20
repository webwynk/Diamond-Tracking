import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_typography.dart';
import 'app_button.dart';

/// Full-screen or section failure view matching Screen 29 (item 5)
/// and docs/03-DESIGN-SYSTEM.md section 10.
///
/// Features:
/// - 64 dp circular error badge ([AppColors.errorBg]).
/// - Error icon ([AppColors.error]).
/// - Headline in [AppTypography.title].
/// - Explanation in [AppTypography.caption].
/// - Primary retry action.
class AppErrorView extends StatelessWidget {
  const AppErrorView({
    required this.onRetry,
    super.key,
    this.title = "Couldn't load this",
    this.message = 'Check your connection and try again.',
    this.icon = Icons.cloud_off_rounded,
  });

  final String title;
  final String message;
  final IconData icon;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: AppColors.errorBg,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(icon, size: 32, color: AppColors.error),
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
                message,
                style: AppTypography.caption.withColor(AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: AppSpacing.x5),
            AppButton(
              label: 'Retry',
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}
