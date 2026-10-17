import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../../shared/widgets/app_error_view.dart';
import '../../../../shared/widgets/app_top_bar.dart';
import 'controllers/admin_attendance_controller.dart';
import 'controllers/admin_attendance_state.dart';
import 'widgets/admin_attendance_daily_card.dart';
import 'widgets/admin_attendance_discrepancy_banner.dart';
import 'widgets/admin_attendance_filter_chips.dart';
import 'widgets/admin_attendance_meta_header.dart';
import 'widgets/admin_attendance_month_selector.dart';
import 'widgets/admin_attendance_summary_card.dart';

/// Screen 22 — Duty History & Attendance (Admin), for one employee.
///
/// One IST month of real duty records (PRD F7): the totals at the top, one card
/// per day with its sessions, hours, kilometres and visits, days ended
/// automatically labelled "Duty ended automatically", and absent days. Every
/// figure is added up from the same session rows as the route view, so the two
/// agree. A day with a route opens it.
///
/// There is no payroll approval or payable-hours override here: payroll is a
/// non-goal (PRD section 2), and the screen only reads.
class AdminAttendancePage extends ConsumerWidget {
  const AdminAttendancePage({
    super.key,
    required this.employeeId,
    required this.employeeName,
    required this.employeeCode,
    this.onBack,
    this.onViewRouteDay,
  });

  final String employeeId;
  final String employeeName;
  final String employeeCode;
  final VoidCallback? onBack;

  /// Called with the day (`yyyy-MM-dd`, IST) whose route to open.
  final ValueChanged<String>? onViewRouteDay;

  String get _initials {
    final parts = employeeName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts[0].isEmpty) return 'EM';
    if (parts.length == 1) {
      return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    }
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = adminAttendanceControllerProvider(employeeId);
    final state = ref.watch(provider);
    final notifier = ref.read(provider.notifier);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppTopBar(
        leading: AppTopBarLeading.back,
        leadingKey: const Key('btn-attendance-back'),
        onLeadingPressed: onBack,
        title: 'Attendance & History',
        subtitle: '$employeeName · $employeeCode',
      ),
      body: Column(
        children: <Widget>[
          AdminAttendanceMetaHeader(
            name: employeeName,
            code: employeeCode,
            initials: _initials,
          ),
          AdminAttendanceMonthSelector(
            selectedMonth: state.selectedMonth,
            onPreviousMonth: notifier.previousMonth,
            onNextMonth: notifier.nextMonth,
          ),
          Expanded(child: _content(context, state, notifier)),
        ],
      ),
    );
  }

  Widget _content(
    BuildContext context,
    AdminAttendanceState state,
    AdminAttendanceNotifier notifier,
  ) {
    switch (state.load) {
      case AttendanceLoad.loading:
        return const Center(
          child: CircularProgressIndicator(key: Key('attendance-loading')),
        );
      case AttendanceLoad.failed:
        return AppErrorView(
          key: const Key('attendance-error'),
          title: "Couldn't load the attendance",
          message: state.errorMessage ?? '',
          onRetry: notifier.reload,
        );
      case AttendanceLoad.loaded:
        break;
    }

    final shown = state.filteredDailyLogs;
    return RefreshIndicator(
      onRefresh: notifier.reload,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: <Widget>[
            AdminAttendanceSummaryCard(metrics: state.metrics),
            if (state.truncated)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.x4,
                  AppSpacing.x3,
                  AppSpacing.x4,
                  0,
                ),
                child: Container(
                  key: const Key('attendance-truncated'),
                  padding: const EdgeInsets.all(AppSpacing.x2),
                  decoration: BoxDecoration(
                    color: AppColors.warningBg,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Text(
                    'This month has more sessions than can be shown. The '
                    'figures cover the first part of the month only.',
                    textAlign: TextAlign.center,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.warningText,
                    ),
                  ),
                ),
              ),
            if (state.autoEndedLogCount > 0)
              AdminAttendanceDiscrepancyBanner(
                message:
                    '${state.autoEndedLogCount} '
                    '${state.autoEndedLogCount == 1 ? 'day' : 'days'} '
                    'ended automatically at 23:00',
                onReview: () =>
                    notifier.setFilter(AdminAttendanceFilter.autoEnded),
              ),
            AdminAttendanceFilterChips(
              selectedFilter: state.selectedFilter,
              onSelectFilter: notifier.setFilter,
              totalDaysCount: state.dailyLogs.length,
              autoEndedCount: state.autoEndedLogCount,
              flagsCount: state.flaggedLogCount,
              absentCount: state.absentCount,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4),
              child: shown.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.x8,
                      ),
                      child: state.dailyLogs.isEmpty
                          ? const AppEmptyState(
                              icon: Icons.event_busy_outlined,
                              title: 'No duty this month',
                              description:
                                  'No duty sessions exist for this month.',
                            )
                          : AppEmptyState.filteredToNothing(
                              onClearFilters: () => notifier.setFilter(
                                AdminAttendanceFilter.allDays,
                              ),
                            ),
                    )
                  : Column(
                      children: [
                        for (final item in shown)
                          AdminAttendanceDailyCard(
                            item: item,
                            onTap: item.hasChevron
                                ? () => onViewRouteDay?.call(item.id)
                                : null,
                          ),
                      ],
                    ),
            ),
            const SizedBox(height: AppSpacing.x6),
          ],
        ),
      ),
    );
  }
}
