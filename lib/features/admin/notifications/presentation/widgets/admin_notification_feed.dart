import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_dimens.dart';
import '../../../../../core/theme/app_typography.dart';
import '../controllers/admin_notification_state.dart';
import 'admin_notification_tile.dart';

/// Notification Feed Stream containing notification tiles, sticky cadence headers, and audit footer.
class AdminNotificationFeed extends StatelessWidget {
  const AdminNotificationFeed({
    super.key,
    required this.items,
    required this.onTapItem,
  });

  final List<AdminNotificationItem> items;
  final ValueChanged<String> onTapItem;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.x6,
          vertical: AppSpacing.x12,
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: AppColors.neutral100,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_off_outlined,
                color: AppColors.neutral400,
                size: 28,
              ),
            ),
            const SizedBox(height: AppSpacing.x4),
            Text(
              'No notifications in this filter',
              style: AppTypography.title.copyWith(
                color: AppColors.neutral900,
              ),
            ),
            const SizedBox(height: AppSpacing.x1),
            Text(
              'Operational events and alerts matching your filter will appear here.',
              textAlign: TextAlign.center,
              style: AppTypography.body.copyWith(
                color: AppColors.neutral500,
              ),
            ),
          ],
        ),
      );
    }

    // Split into today and earlier today items
    final todayItems = items.where((i) => !i.isEarlierToday).toList();
    final earlierItems = items.where((i) => i.isEarlierToday).toList();

    return Column(
      children: <Widget>[
        // Today Items
        ...todayItems.map(
          (item) => AdminNotificationTile(
            item: item,
            onTap: () => onTapItem(item.id),
          ),
        ),

        // Sticky Date Cadence Header (between today and earlier today)
        if (earlierItems.isNotEmpty) ...[
          Container(
            height: 32,
            width: double.infinity,
            decoration: const BoxDecoration(
              color: AppColors.neutral50,
              border: Border(
                top: BorderSide(color: AppColors.neutral200, width: 1),
                bottom: BorderSide(color: AppColors.neutral200, width: 1),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  'EARLIER TODAY',
                  style: AppTypography.overline.copyWith(
                    color: AppColors.neutral500,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  'Archived Synced',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.neutral500,
                  ),
                ),
              ],
            ),
          ),

          // Earlier Today Items
          ...earlierItems.map(
            (item) => AdminNotificationTile(
              item: item,
              onTap: () => onTapItem(item.id),
            ),
          ),
        ],

        // Operational Footer: End of Event Log
        Padding(
          padding: const EdgeInsets.all(AppSpacing.x6),
          child: Column(
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: AppColors.neutral100,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.verified_rounded,
                  color: AppColors.neutral500,
                  size: 22,
                ),
              ),
              const SizedBox(height: AppSpacing.x2),
              Text(
                'END OF EVENT LOG',
                style: AppTypography.label.copyWith(
                  color: AppColors.neutral900,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: AppSpacing.x1),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 280),
                child: Text(
                  'Synchronized with Central Agricultural Hub. All field logs retained for 90 days.',
                  textAlign: TextAlign.center,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.neutral500,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.x4),
            ],
          ),
        ),
      ],
    );
  }
}
