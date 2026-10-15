import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import 'controllers/duty_history_controller.dart';
import 'controllers/duty_history_state.dart';
import 'widgets/duty_history_card.dart';
import 'widgets/history_filter_chips_bar.dart';
import 'widgets/history_monthly_summary_card.dart';

/// Screen 12 — My Duty History (Employee)
///
/// Provides employees with transparent access to past shift records,
/// monthly statistics, status badges (Auto-ended, Flagged, No duty),
/// and period filtering.
class MyDutyHistoryPage extends ConsumerWidget {
  const MyDutyHistoryPage({
    super.key,
    this.onNavigateToDuty,
    this.onNavigateToMap,
  });

  final VoidCallback? onNavigateToDuty;
  final VoidCallback? onNavigateToMap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyState = ref.watch(dutyHistoryControllerProvider);
    final historyNotifier = ref.read(dutyHistoryControllerProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(
              bottom: BorderSide(color: AppColors.neutral200, width: 1),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x2),
              child: Row(
                children: [
                  // Back Chevron
                  IconButton(
                    key: const Key('history-back-btn'),
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 20,
                      color: AppColors.primary600,
                    ),
                    onPressed: () {
                      if (Navigator.of(context).canPop()) {
                        Navigator.of(context).pop();
                      } else if (onNavigateToDuty != null) {
                        onNavigateToDuty!();
                      }
                    },
                    tooltip: 'Back',
                  ),
                  const SizedBox(width: AppSpacing.x1),

                  // Title "My history"
                  Expanded(
                    child: Text(
                      'My history',
                      style: AppTypography.h3.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),

                  // Filter action with active badge "1"
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      IconButton(
                        key: const Key('history-filter-btn'),
                        icon: const Icon(
                          Icons.filter_list_rounded,
                          size: 22,
                          color: AppColors.neutral600,
                        ),
                        onPressed: () {
                          // Quick cycle or toggle filter for convenience
                          final nextFilter = historyState.filter == DutyHistoryFilter.thisMonth
                              ? DutyHistoryFilter.autoEnded
                              : DutyHistoryFilter.thisMonth;
                          historyNotifier.setFilter(nextFilter);
                        },
                        tooltip: 'Filter records',
                      ),
                      // Filter Badge '1'
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: AppColors.primary600,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.surface,
                              width: 2,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            '1',
                            style: TextStyle(
                              fontSize: 9,
                              height: 1.0,
                              fontWeight: FontWeight.bold,
                              color: AppColors.neutral0,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          color: AppColors.primary600,
          onRefresh: () => historyNotifier.loadHistory(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Horizontally scrolling filter chips row
                HistoryFilterChipsBar(
                  selectedFilter: historyState.filter,
                  onFilterSelected: (filter) {
                    historyNotifier.setFilter(filter);
                  },
                ),

                // 2. Monthly Summary Card (#E8F3F8)
                HistoryMonthlySummaryCard(
                  summary: historyState.summary,
                ),
                const SizedBox(height: AppSpacing.x4),

                // 3. History List Section
                if (historyState.isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary600,
                      ),
                    ),
                  )
                else if (historyState.items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.x4,
                      vertical: AppSpacing.x8,
                    ),
                    child: Center(
                      child: Text(
                        'No duty history records found for this period.',
                        style: AppTypography.body.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: historyState.items.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppSpacing.x3),
                      itemBuilder: (context, index) {
                        final item = historyState.items[index];
                        return DutyHistoryCard(
                          key: Key('history-card-${item.id}'),
                          item: item,
                        );
                      },
                    ),
                  ),

                // 4. Centered 24 dp #016893 spinner indicating pagination
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.x6),
                  child: Column(
                    children: [
                      const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: AppColors.primary600,
                          backgroundColor: AppColors.neutral300,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.x2),
                      Text(
                        'Loading earlier records…',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textDisabled,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.x4),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNavigation(context),
    );
  }

  Widget _buildBottomNavigation(BuildContext context) {
    return Container(
      height: 64,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.neutral200, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // Tab 1: Duty
          InkWell(
            key: const Key('bottom-nav-duty-tab'),
            onTap: () {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              } else if (onNavigateToDuty != null) {
                onNavigateToDuty!();
              }
            },
            borderRadius: AppRadius.mdAll,
            child: const Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.x3,
                vertical: AppSpacing.x1,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.shield_outlined,
                    size: 22,
                    color: AppColors.textDisabled,
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Duty',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textDisabled,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Tab 2: Map
          InkWell(
            key: const Key('bottom-nav-map-tab'),
            onTap: () {
              if (onNavigateToMap != null) {
                onNavigateToMap!();
              }
            },
            borderRadius: AppRadius.mdAll,
            child: const Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.x3,
                vertical: AppSpacing.x1,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.map_outlined,
                    size: 22,
                    color: AppColors.textDisabled,
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Map',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textDisabled,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Tab 3: History (Active in #016893)
          InkWell(
            key: const Key('bottom-nav-history-tab'),
            onTap: () {
              // Already on History tab
            },
            borderRadius: AppRadius.mdAll,
            child: const Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.x3,
                vertical: AppSpacing.x1,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.history_rounded,
                    size: 22,
                    color: AppColors.primary600,
                  ),
                  SizedBox(height: 2),
                  Text(
                    'History',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
