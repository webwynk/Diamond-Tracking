import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../app_skeletons.dart';

/// Screen 30 — Skeleton Loaders System Reference Page.
///
/// Complete catalog of progressive shimmer patterns and geometry-matched
/// loading placeholders across field workflows.
class SkeletonLoadersReferencePage extends StatefulWidget {
  const SkeletonLoadersReferencePage({
    super.key,
    this.isPaginationSpinning = true,
  });

  final bool isPaginationSpinning;

  @override
  State<SkeletonLoadersReferencePage> createState() =>
      _SkeletonLoadersReferencePageState();
}

class _SkeletonLoadersReferencePageState
    extends State<SkeletonLoadersReferencePage> {
  int _activeNavIndex = 3; // 3 = Specs (active by default per design)

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.neutral50,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: AppBar(
          backgroundColor: AppColors.surface,
          elevation: 1,
          shadowColor: const Color(0x0A000000),
          automaticallyImplyLeading: false,
          title: Row(
            children: <Widget>[
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  color: AppColors.primary600,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: AppSpacing.x2),
              Text(
                'SYSTEM REFERENCE',
                style: AppTypography.title.copyWith(
                  color: AppColors.neutral900,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          actions: <Widget>[
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.x4),
              child: Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: AppColors.primary600,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person,
                  size: 18,
                  color: AppColors.surface,
                ),
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.x4,
          vertical: AppSpacing.x6,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // 1. Specification Sheet Header Section
                _buildSheetHeader(),

                const SizedBox(height: AppSpacing.x6),

                // 2. Section 1: EMPLOYEE LIST
                _buildSectionHeader(
                  title: 'EMPLOYEE LIST',
                  subtitle: '5 Instances • 80px Row',
                ),
                const AppListSkeleton(itemCount: 5),

                const SizedBox(height: AppSpacing.x6),

                // 3. Section 2: STAT CARD ROW
                _buildSectionHeader(
                  title: 'STAT CARD ROW',
                  subtitle: '3 Metric Columns',
                ),
                const AppStatRowSkeleton(),

                const SizedBox(height: AppSpacing.x6),

                // 4. Section 3: NOTIFICATION LIST
                _buildSectionHeader(
                  title: 'NOTIFICATION LIST',
                  subtitle: 'Grouped Container',
                ),
                const NotificationListSkeleton(itemCount: 4),

                const SizedBox(height: AppSpacing.x6),

                // 5. Section 4: DUTY HISTORY
                _buildSectionHeader(
                  title: 'DUTY HISTORY',
                  subtitle: '3 Event Log Cards',
                ),
                const DutyHistorySkeleton(itemCount: 3),

                const SizedBox(height: AppSpacing.x6),

                // 6. Section 5: MAP PLACEHOLDER
                _buildSectionHeader(
                  title: 'MAP PLACEHOLDER',
                  subtitle: 'Telemetry Exception',
                  isSubtitleBrand: true,
                ),
                const EnhancedMapPlaceholder(),

                const SizedBox(height: AppSpacing.x6),

                // 7. Section 6: NEXT-PAGE LOADER
                _buildSectionHeader(
                  title: 'NEXT-PAGE LOADER',
                  subtitle: 'Scroll Anchor',
                ),
                PaginationLoaderCard(
                  isSpinning: widget.isPaginationSpinning,
                ),

                const SizedBox(height: AppSpacing.x10),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildSheetHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // Overline with Interactive Shimmer Badge
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Expanded(
              child: Text(
                'SPECIFICATION SHEET 30 • DIAMOND AGRITECH',
                style: AppTypography.overline.copyWith(
                  color: AppColors.primary600,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w600,
                  fontSize: 10,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: AppSpacing.x2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary50,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: 6,
                    height: 6,
                    color: AppColors.primary600,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'INTERACTIVE SHIMMER',
                    style: AppTypography.overline.copyWith(
                      color: AppColors.primary600,
                      fontWeight: FontWeight.w700,
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 6),

        Text(
          'Skeleton Loaders',
          style: AppTypography.h2.copyWith(
            color: AppColors.neutral900,
            fontWeight: FontWeight.w600,
          ),
        ),

        const SizedBox(height: 4),

        Text(
          'Progressive shimmer patterns and geometry-matched loading placeholders across field workflows.',
          style: AppTypography.body.copyWith(
            color: AppColors.neutral600,
            height: 1.4,
          ),
        ),

        const SizedBox(height: AppSpacing.x4),

        const Divider(
          height: 1,
          thickness: 1,
          color: AppColors.neutral200,
        ),
      ],
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
    bool isSubtitleBrand = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.x2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(
            title,
            style: AppTypography.overline.copyWith(
              color: AppColors.neutral400,
              letterSpacing: 0.5,
              fontWeight: FontWeight.w600,
              fontSize: 10,
            ),
          ),
          Text(
            subtitle,
            style: AppTypography.caption.copyWith(
              color: isSubtitleBrand
                  ? AppColors.primary600
                  : AppColors.neutral500,
              fontWeight:
                  isSubtitleBrand ? FontWeight.w600 : FontWeight.w400,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    final navItems = <(IconData, String)>[
      (Icons.dashboard_outlined, 'Overview'),
      (Icons.sensors_outlined, 'Telemetry'),
      (Icons.alt_route_outlined, 'Routes'),
      (Icons.widgets_outlined, 'Specs'),
    ];

    return Container(
      height: 64,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.neutral200, width: 1),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: navItems.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final isActive = _activeNavIndex == index;

          return Expanded(
            child: InkWell(
              onTap: () => setState(() => _activeNavIndex = index),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(
                    item.$1,
                    size: 22,
                    color:
                        isActive ? AppColors.primary600 : AppColors.neutral500,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.$2.toUpperCase(),
                    style: AppTypography.overline.copyWith(
                      color: isActive
                          ? AppColors.primary600
                          : AppColors.neutral500,
                      fontWeight:
                          isActive ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 9,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
