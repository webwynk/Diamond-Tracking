import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_typography.dart';

/// Helper to display standard snackbars matching docs/03-DESIGN-SYSTEM.md.
///
/// Features:
/// - Floating dark surface ([AppColors.snackbarSurface] / #1E293B).
/// - 12 dp border radius ([AppRadius.mdAll]).
/// - DM Sans typography with WCAG AA compliant action colour ([AppColors.snackbarAction]).
abstract final class AppSnackbar {
  const AppSnackbar._();

  static void show(
    BuildContext context, {
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 4),
  }) {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: AppTypography.body.withColor(AppColors.neutral0),
        ),
        backgroundColor: AppColors.snackbarSurface,
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
        duration: duration,
        action: actionLabel != null && onAction != null
            ? SnackBarAction(
                label: actionLabel,
                textColor: AppColors.snackbarAction,
                onPressed: onAction,
              )
            : null,
      ),
    );
  }
}
