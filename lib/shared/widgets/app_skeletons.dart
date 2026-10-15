import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import 'app_card.dart';
import 'app_shimmer.dart';

/// Atomic placeholder bar/box for skeleton loaders.
class AppShimmerBox extends StatelessWidget {
  const AppShimmerBox({
    required this.width,
    required this.height,
    super.key,
    this.borderRadius = AppRadius.smAll,
  });

  const AppShimmerBox.circle({required double size, super.key})
    : width = size,
      height = size,
      borderRadius = AppRadius.fullAll;

  final double width;
  final double height;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.neutral100,
        borderRadius: borderRadius,
      ),
    );
  }
}

/// Skeleton loader for lists (e.g. employee list rows).
///
/// Matches Screen 30 (item 1):
/// 5 cards, radius 12, with a 44 dp avatar circle, two text bars, and a status pill.
class AppListSkeleton extends StatelessWidget {
  const AppListSkeleton({super.key, this.itemCount = 5});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: AppSpacing.screen,
        itemCount: itemCount,
        separatorBuilder: (BuildContext context, int index) =>
            const SizedBox(height: 10),
        itemBuilder: (BuildContext context, int index) {
          return const AppCard(
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.x4,
              vertical: AppSpacing.x3,
            ),
            child: Row(
              children: <Widget>[
                AppShimmerBox.circle(size: 44),
                SizedBox(width: AppSpacing.x3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      AppShimmerBox(width: 140, height: 18),
                      SizedBox(height: 6),
                      AppShimmerBox(width: 90, height: 12),
                    ],
                  ),
                ),
                AppShimmerBox(
                  width: 72,
                  height: 24,
                  borderRadius: AppRadius.fullAll,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Skeleton loader for stat card rows.
///
/// Matches Screen 30 (item 2):
/// Three equal white cards, radius 12, each containing category, metric, and unit bars.
class AppStatRowSkeleton extends StatelessWidget {
  const AppStatRowSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: Row(
        children: <Widget>[
          Expanded(child: _buildCard()),
          const SizedBox(width: AppSpacing.x3),
          Expanded(child: _buildCard()),
          const SizedBox(width: AppSpacing.x3),
          Expanded(child: _buildCard()),
        ],
      ),
    );
  }

  Widget _buildCard() {
    return const AppCard(
      padding: EdgeInsets.all(AppSpacing.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          AppShimmerBox(width: 48, height: 11),
          SizedBox(height: AppSpacing.x2),
          AppShimmerBox(width: 72, height: 32),
          SizedBox(height: AppSpacing.x2),
          AppShimmerBox(width: 28, height: 12),
        ],
      ),
    );
  }
}
