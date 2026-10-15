import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_dimens.dart';
import '../../../../../core/theme/app_typography.dart';

/// 56 dp App Bar for Screen 26 Reports (Admin).
class AdminReportsTopBar extends StatelessWidget implements PreferredSizeWidget {
  const AdminReportsTopBar({
    super.key,
    required this.isReady,
    this.onBack,
    this.onViewHistory,
    this.onCloseReadyView,
  });

  final bool isReady;
  final VoidCallback? onBack;
  final VoidCallback? onViewHistory;
  final VoidCallback? onCloseReadyView;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('admin-reports-top-bar'),
      height: 56,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.neutral200, width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4),
      child: SafeArea(
        bottom: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            // Leading + Title
            Row(
              children: <Widget>[
                if (onBack != null && !isReady) ...[
                  IconButton(
                    key: const Key('btn-reports-back'),
                    onPressed: onBack,
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: AppColors.neutral700,
                      size: 22,
                    ),
                    splashRadius: 20,
                    tooltip: 'Back',
                  ),
                  const SizedBox(width: AppSpacing.x1),
                ],
                Text(
                  'Reports',
                  style: AppTypography.h3.copyWith(
                    color: AppColors.neutral900,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),

            // Trailing Action Button
            if (!isReady)
              IconButton(
                key: const Key('btn-reports-history'),
                onPressed: onViewHistory ??
                    () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Opening previous reports history...'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                icon: const Icon(
                  Icons.history_rounded,
                  color: AppColors.neutral600,
                  size: 22,
                ),
                splashRadius: 20,
                tooltip: 'Report history',
              )
            else
              IconButton(
                key: const Key('btn-reports-close'),
                onPressed: onCloseReadyView,
                icon: const Icon(
                  Icons.close_rounded,
                  color: AppColors.neutral600,
                  size: 22,
                ),
                splashRadius: 20,
                tooltip: 'Close export view',
              ),
          ],
        ),
      ),
    );
  }
}
