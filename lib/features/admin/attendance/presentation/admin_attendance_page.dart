import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';
import 'controllers/admin_attendance_controller.dart';
import 'controllers/admin_attendance_state.dart';
import 'widgets/admin_attendance_daily_card.dart';
import 'widgets/admin_attendance_discrepancy_banner.dart';
import 'widgets/admin_attendance_filter_chips.dart';
import 'widgets/admin_attendance_meta_header.dart';
import 'widgets/admin_attendance_month_selector.dart';
import 'widgets/admin_attendance_settle_bar.dart';
import 'widgets/admin_attendance_summary_card.dart';
import 'widgets/admin_attendance_top_bar.dart';

/// Screen 22 — Duty History & Attendance (Admin).
///
/// Complete field staff attendance and payroll verification console:
/// - 56 dp white top app bar with back chevron and report download
/// - Employee profile meta sub-header with initials and Active Payroll badge
/// - 48 dp pinned month switcher ("October 2026")
/// - 2x3 telemetry audit metric grid (Days worked, Total hours, Distance, Visits, Auto-ended, Flags)
/// - Supervisor discrepancy review micro-banner
/// - Horizontally scrolling category filter chips
/// - Daily attendance cards stream (Normal, Auto-ended with amber accent, Multi-session, Absent dimmed)
/// - Sticky bottom payroll settlement bar with Adjust and Approve Month actions
class AdminAttendancePage extends ConsumerWidget {
  const AdminAttendancePage({
    super.key,
    this.employeeId = 'emp-1',
    this.onBack,
    this.onViewRouteDay,
    this.onExportReport,
  });

  final String employeeId;
  final VoidCallback? onBack;
  final ValueChanged<String>? onViewRouteDay;
  final VoidCallback? onExportReport;

  void _showAdjustDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController(text: '96h 40m');
    final amountController = TextEditingController(text: '₹14,500 Base');

    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: Text(
          'Adjust Payable Hours',
          style: AppTypography.title.copyWith(color: AppColors.neutral900),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Override verified hours for this settlement cycle:',
              style: AppTypography.body.copyWith(color: AppColors.neutral500),
            ),
            const SizedBox(height: AppSpacing.x3),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Payable Hours',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.x2),
            TextField(
              controller: amountController,
              decoration: const InputDecoration(
                labelText: 'Base Pay',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary600,
              foregroundColor: AppColors.neutral0,
            ),
            onPressed: () {
              ref.read(adminAttendanceControllerProvider.notifier).adjustPayableHours(
                    hours: controller.text.trim(),
                    amount: amountController.text.trim(),
                  );
              Navigator.of(dialogCtx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Payable hours adjusted.'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
            child: const Text('Save Override'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(adminAttendanceControllerProvider);
    final notifier = ref.read(adminAttendanceControllerProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AdminAttendanceTopBar(
        onBack: onBack ?? () => Navigator.of(context).maybePop(),
        onExport: onExportReport ??
            () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Exporting ${state.selectedMonth} payroll telemetry for ${state.employeeName} (CSV)...',
                  ),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
      ),
      body: Column(
        children: <Widget>[
          // 1. Employee Profile Meta Sub-Header
          AdminAttendanceMetaHeader(
            name: state.employeeName,
            code: state.employeeCode,
            roleSubtitle: state.roleSubtitle,
            initials: state.employeeInitials,
          ),

          // 2. Pinned Month Switcher
          AdminAttendanceMonthSelector(
            selectedMonth: state.selectedMonth,
            onPreviousMonth: notifier.previousMonth,
            onNextMonth: notifier.nextMonth,
            onMonthTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Selected cycle: ${state.selectedMonth}'),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
          ),

          // 3. Scrollable Attendance Log Stream
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: <Widget>[
                  // Telemetry Summary Card
                  AdminAttendanceSummaryCard(metrics: state.metrics),

                  // Supervisor Discrepancy Banner
                  if (state.hasDiscrepancy)
                    AdminAttendanceDiscrepancyBanner(
                      message:
                          '1 audit alert requires supervisor approval before payout',
                      onReview: () {
                        notifier.setFilter(AdminAttendanceFilter.autoEnded);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Displaying Day 10 auto-ended session for supervisor review.',
                            ),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                    ),

                  // Filter Chips Bar
                  AdminAttendanceFilterChips(
                    selectedFilter: state.selectedFilter,
                    onSelectFilter: notifier.setFilter,
                    totalDaysCount: 31,
                    autoEndedCount: state.metrics.autoEndedCount,
                    flagsCount: state.metrics.flagsCount,
                    absentCount: 19,
                  ),

                  // Daily Cards Stream
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.x4,
                    ),
                    child: Column(
                      children: state.filteredDailyLogs.map((item) {
                        return AdminAttendanceDailyCard(
                          item: item,
                          onTap: item.hasChevron
                              ? () => onViewRouteDay?.call(item.id)
                              : null,
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.x6),
                ],
              ),
            ),
          ),

          // 4. Sticky Bottom Payroll Settlement Bar
          AdminAttendanceSettleBar(
            payableHours: state.metrics.payableHoursText,
            payableAmount: state.metrics.payableAmountText,
            isApproved: state.isMonthApproved,
            onAdjust: () => _showAdjustDialog(context, ref),
            onApprove: () {
              notifier.approveMonth();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '${state.selectedMonth} attendance approved for payroll settlement.',
                  ),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
