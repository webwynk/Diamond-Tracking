import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../app_shimmer.dart';
import '../../app_skeletons.dart';

/// Section 4: Duty History Skeleton.
///
/// Matches Screen 30 (item 4): 3 event log cards (88 dp height) matching
/// MyDutyHistoryCard layout with rounded icon boxes and metric bars.
class DutyHistorySkeleton extends StatelessWidget {
  const DutyHistorySkeleton({super.key, this.itemCount = 3});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: Column(
        key: const Key('skeleton-duty-history'),
        children: List.generate(itemCount, (index) {
          final titleWidth = switch (index % 3) {
            0 => 150.0,
            1 => 135.0,
            _ => 160.0,
          };
          final subtitleWidth = switch (index % 3) {
            0 => 200.0,
            1 => 180.0,
            _ => 210.0,
          };

          return Container(
            height: 88,
            margin: EdgeInsets.only(bottom: index == itemCount - 1 ? 0 : 10),
            padding: const EdgeInsets.all(AppSpacing.x4),
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
            child: Row(
              children: <Widget>[
                // 44x44 dp 12-radius icon box placeholder
                AppShimmerBox(
                  width: 44,
                  height: 44,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),

                const SizedBox(width: AppSpacing.x3),

                // Middle date and metric bars
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      AppShimmerBox(
                        width: titleWidth,
                        height: 18,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      const SizedBox(height: 8),
                      AppShimmerBox(
                        width: subtitleWidth,
                        height: 12,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}
