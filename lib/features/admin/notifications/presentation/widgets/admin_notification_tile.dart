import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_dimens.dart';
import '../../../../../core/theme/app_typography.dart';
import '../controllers/admin_notification_state.dart';

/// 76 dp notification row for Screen 21.
///
/// If unread:
/// - Light brand tint background (#E8F3F8)
/// - 4 dp brand primary (#016893) vertical bar on left edge
/// - SemiBold 14px title
/// - Category-colored dot indicator under timestamp
///
/// If read:
/// - White background (#FFFFFF)
/// - No left vertical bar
/// - Regular 14px title
class AdminNotificationTile extends StatelessWidget {
  const AdminNotificationTile({
    super.key,
    required this.item,
    required this.onTap,
  });

  final AdminNotificationItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: item.isUnread ? AppColors.primary50 : AppColors.surface,
      child: InkWell(
        key: Key('notif-tile-${item.id}'),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 76),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: AppColors.neutral200, width: 1),
            ),
          ),
          child: Stack(
            children: <Widget>[
              // Unread 4 dp vertical bar on the left edge
              if (item.isUnread)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 4,
                    color: AppColors.primary600,
                  ),
                ),

              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.x4,
                  vertical: AppSpacing.x3,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    // Left 40x40 circular tinted icon badge
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: item.badgeColor,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        item.icon,
                        color: item.iconColor,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.x4),

                    // Center: Title + Subtitle
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.body.copyWith(
                              color: AppColors.neutral900,
                              fontWeight: item.isUnread
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.caption.copyWith(
                              color: AppColors.neutral500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.x3),

                    // Right: Timestamp + Unread Dot
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        Text(
                          item.timestamp,
                          style: AppTypography.caption.copyWith(
                            color: AppColors.neutral400,
                            fontFeatures: const <FontFeature>[
                              FontFeature.tabularFigures(),
                            ],
                          ),
                        ),
                        if (item.isUnread) ...[
                          const SizedBox(height: AppSpacing.x1),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: item.iconColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
