import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../app_shimmer.dart';
import '../../app_skeletons.dart';

/// Section 3: Grouped Notification List Skeleton.
///
/// Matches Screen 30 (item 3): Grouped container with 4 rows of 76 dp
/// notification item placeholders separated by 1 dp dividers.
class NotificationListSkeleton extends StatelessWidget {
  const NotificationListSkeleton({super.key, this.itemCount = 4});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: Container(
        key: const Key('skeleton-notification-list'),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x05000000),
              blurRadius: 3,
              offset: Offset(0, 1),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: List.generate(itemCount, (index) {
            final isLast = index == itemCount - 1;
            // Varied title width for realistic content simulation
            final titleWidth = switch (index % 4) {
              0 => 180.0,
              1 => 160.0,
              2 => 190.0,
              _ => 170.0,
            };
            final subtitleWidth = switch (index % 4) {
              0 => 120.0,
              1 => 100.0,
              2 => 130.0,
              _ => 110.0,
            };

            return Container(
              height: 76,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4),
              decoration: BoxDecoration(
                border: isLast
                    ? null
                    : const Border(
                        bottom: BorderSide(
                          color: AppColors.neutral100,
                          width: 1,
                        ),
                      ),
              ),
              child: Row(
                children: <Widget>[
                  // 40x40 circle avatar placeholder
                  const AppShimmerBox.circle(size: 40),

                  const SizedBox(width: AppSpacing.x3),

                  // Middle text bars
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        AppShimmerBox(
                          width: titleWidth,
                          height: 14,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        const SizedBox(height: 6),
                        AppShimmerBox(
                          width: subtitleWidth,
                          height: 12,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: AppSpacing.x2),

                  // Right time/unread indicator placeholder
                  AppShimmerBox(
                    width: 36,
                    height: 12,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }
}
