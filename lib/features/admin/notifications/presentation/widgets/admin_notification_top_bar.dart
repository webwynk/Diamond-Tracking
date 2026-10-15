import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_dimens.dart';
import '../../../../../core/theme/app_typography.dart';

/// 56 dp white top app bar for Screen 21 (Notification Centre — Admin).
///
/// Features:
/// - Brand primary back chevron button
/// - Title "Notifications" with dynamic red unread counter badge pill
/// - "Mark all read" interactive text button
class AdminNotificationTopBar extends StatelessWidget implements PreferredSizeWidget {
  const AdminNotificationTopBar({
    super.key,
    required this.unreadCount,
    required this.onBack,
    required this.onMarkAllRead,
  });

  final int unreadCount;
  final VoidCallback onBack;
  final VoidCallback onMarkAllRead;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.neutral200, width: 1),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              // Left Group: Back Button + Title + Counter Pill
              Expanded(
                child: Row(
                  children: <Widget>[
                    IconButton(
                      key: const Key('btn-notif-back'),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                      icon: const Icon(
                        Icons.arrow_back_rounded,
                        color: AppColors.primary600,
                        size: 24,
                      ),
                      onPressed: onBack,
                      tooltip: 'Back',
                    ),
                    const SizedBox(width: AppSpacing.x1),
                    Flexible(
                      child: Text(
                        'Notifications',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.h3.copyWith(
                          color: AppColors.neutral900,
                        ),
                      ),
                    ),
                    if (unreadCount > 0) ...[
                      const SizedBox(width: AppSpacing.x2),
                      Container(
                        key: const Key('badge-unread-count-pill'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.x2,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          borderRadius: BorderRadius.circular(AppRadius.full),
                        ),
                        child: Text(
                          '$unreadCount',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.neutral0,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Right Action: Mark all read
              TextButton(
                key: const Key('btn-mark-all-read'),
                onPressed: unreadCount > 0 ? onMarkAllRead : null,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary600,
                  disabledForegroundColor: AppColors.neutral400,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x2),
                ),
                child: Text(
                  'Mark all read',
                  style: AppTypography.label.copyWith(
                    color: unreadCount > 0
                        ? AppColors.primary600
                        : AppColors.neutral400,
                    fontWeight: FontWeight.w600,
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
