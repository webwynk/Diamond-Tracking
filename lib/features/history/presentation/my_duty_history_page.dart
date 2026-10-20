import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_error_view.dart';
import '../../../shared/widgets/app_top_bar.dart';
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
  const MyDutyHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyState = ref.watch(dutyHistoryControllerProvider);
    final historyNotifier = ref.read(dutyHistoryControllerProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppTopBar(
        style: AppTopBarStyle.brand,
        title: 'My history',
        actions: <Widget>[
          AppTopBarIconButton(
            key: const Key('history-filter-btn'),
            icon: Icons.filter_list_rounded,
            tooltip: 'Filter records',
            badgeCount: 1,
            badgeColor: AppColors.neutral0,
            badgeTextColor: AppColors.primary600,
            onPressed: () {
              // Quick cycle or toggle filter for convenience
              final nextFilter =
                  historyState.filter == DutyHistoryFilter.thisMonth
                  ? DutyHistoryFilter.autoEnded
                  : DutyHistoryFilter.thisMonth;
              historyNotifier.setFilter(nextFilter);
            },
          ),
        ],
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
                HistoryMonthlySummaryCard(summary: historyState.summary),
                const SizedBox(height: AppSpacing.x4),

                // 3. History List Section
                if (historyState.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.x8,
                    ),
                    child: AppErrorView(
                      title: "Couldn't load your history",
                      message: historyState.errorMessage!,
                      onRetry: historyNotifier.loadHistory,
                    ),
                  )
                else if (historyState.isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary600,
                      ),
                    ),
                  )
                else if (historyState.items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.x4,
                      vertical: AppSpacing.x8,
                    ),
                    child: AppEmptyState(
                      icon: Icons.history_rounded,
                      title: 'No duty history',
                      description:
                          'No duty history records found for this period.',
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.x4,
                    ),
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

                const SizedBox(height: AppSpacing.x4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
