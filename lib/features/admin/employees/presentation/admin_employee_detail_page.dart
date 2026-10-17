import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../attendance/presentation/admin_attendance_page.dart';
import '../../attendance/presentation/controllers/admin_attendance_controller.dart';
import '../../attendance/presentation/controllers/admin_attendance_state.dart';
import '../../map/presentation/controllers/admin_live_map_controller.dart';
import '../../route_view/presentation/admin_route_view_page.dart';
import '../../shell/admin_tab.dart';
import 'admin_employee_form_page.dart';
import 'controllers/admin_employee_list_controller.dart';
import 'controllers/admin_employee_list_state.dart';
import 'widgets/admin_block_employee_sheet.dart';
import 'widgets/admin_employee_block_action_button.dart';
import 'widgets/admin_employee_contact_card.dart';
import 'widgets/admin_employee_detail_header.dart';
import 'widgets/admin_employee_monthly_stats_card.dart';
import 'widgets/admin_employee_quick_actions.dart';
import 'widgets/admin_employee_recent_duty_card.dart';

/// Screen 18 — Employee Detail (Admin).
///
/// Full profile and operational telemetry of a single field staff member:
/// - 170+ dp curved hero header with avatar, name, employee ID, and duty status
/// - Quick action buttons: "Track live" (Screen 15/16) and "Route view" (Screen 23)
/// - Contact details card (Phone, Email, Joined date)
/// - "THIS MONTH" telemetry card with 2x2 metric grid and audit footnotes
/// - "Recent duty" session log history card with "View all" link (Screen 22)
/// - Danger zone "Block employee" action button (Screen 20)
class AdminEmployeeDetailPage extends ConsumerWidget {
  const AdminEmployeeDetailPage({
    super.key,
    required this.employee,
    this.onBack,
    this.onTrackLive,
    this.onRouteView,
    this.onRecentDutyViewAll,
    this.onBlockEmployee,
    this.onMoreOptions,
  });

  final AdminEmployeeItem employee;
  final VoidCallback? onBack;
  final VoidCallback? onTrackLive;
  final VoidCallback? onRouteView;
  final VoidCallback? onRecentDutyViewAll;
  final VoidCallback? onBlockEmployee;
  final VoidCallback? onMoreOptions;

  /// Shows this employee on the live map: closes the profile, opens the Map
  /// tab, and asks the map to zoom to them. Someone who is not on duty has no
  /// live location, and the admin is told so instead of nothing happening.
  void _trackLive(BuildContext context, WidgetRef ref) {
    final onDuty = ref
        .read(adminLiveMapControllerProvider)
        .officers
        .any((officer) => officer.id == employee.id);
    if (!onDuty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${employee.name} is off duty. No live location.'),
        ),
      );
      return;
    }
    ref.read(liveMapFocusProvider.notifier).request(employee.id);
    ref.read(adminTabProvider.notifier).select(AdminTab.map);
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _openRoute(BuildContext context, [String? dayId]) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AdminRouteViewPage(
          employeeId: employee.id,
          employeeName: employee.name,
          dayId: dayId,
        ),
      ),
    );
  }

  void _openAttendance(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AdminAttendancePage(
          employeeId: employee.id,
          employeeName: employee.name,
          employeeCode: employee.employeeCode,
          onViewRouteDay: (dayId) => _openRoute(context, dayId),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attendance = ref.watch(
      adminAttendanceControllerProvider(employee.id),
    );
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: Column(
          children: [
            // 1. Curved Hero Header (170+ dp, rounded bottom corners)
            AdminEmployeeDetailHeader(
              employee: employee,
              onBack: onBack ?? () => Navigator.of(context).maybePop(),
              onMoreOptions:
                  onMoreOptions ??
                  () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            AdminEmployeeFormPage(employee: employee),
                      ),
                    );
                  },
            ),

            // 2. Body Content (Overlaps header by 24 dp)
            Transform.translate(
              offset: const Offset(0, -24),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Section 1: Quick Action Controls
                    AdminEmployeeQuickActions(
                      onTrackLive:
                          onTrackLive ?? () => _trackLive(context, ref),
                      onRouteView: onRouteView ?? () => _openRoute(context),
                    ),

                    const SizedBox(height: AppSpacing.x4),

                    // Section 2: CONTACT Card
                    AdminEmployeeContactCard(employee: employee),

                    const SizedBox(height: AppSpacing.x4),

                    // Section 3: THIS MONTH Telemetry Card
                    AdminEmployeeMonthlyStatsCard(
                      monthName: attendance.selectedMonth.split(' ').first,
                      isAvailable: attendance.isLoaded,
                      daysWorked: attendance.metrics.daysWorked,
                      hoursWorked: attendance.metrics.totalHoursText,
                      distanceKm: attendance.metrics.distanceKm,
                      visitsCount: attendance.metrics.visitsCount,
                      autoEndedDays: attendance.metrics.autoEndedCount,
                      locationFlags: attendance.metrics.flagsCount,
                      onMonthSelect: () => _openAttendance(context),
                    ),

                    const SizedBox(height: AppSpacing.x4),

                    // Section 4: Recent Duty Log Card
                    AdminEmployeeRecentDutyCard(
                      logs: [
                        for (final day
                            in attendance.dailyLogs
                                .where((d) => !d.isAbsent)
                                .take(3))
                          EmployeeDutyLogRecord(
                            id: day.id,
                            dateStr: day.dateLabel,
                            timeWindow:
                                '${day.sessions.first.start} – '
                                '${day.sessions.last.end}',
                            durationStr: day.durationText,
                            distanceStr: day.distanceText,
                          ),
                      ],
                      emptyText: switch (attendance.load) {
                        AttendanceLoad.loading => 'Loading…',
                        AttendanceLoad.failed => "Couldn't load recent duty.",
                        AttendanceLoad.loaded => 'No duty recorded this month.',
                      },
                      onViewAll:
                          onRecentDutyViewAll ?? () => _openAttendance(context),
                      onLogSelected: (log) => _openRoute(context, log.id),
                    ),

                    const SizedBox(height: AppSpacing.x5),

                    // Section 5: Danger Action: Block Employee
                    AdminEmployeeBlockActionButton(
                      onBlockPressed:
                          onBlockEmployee ??
                          () async {
                            final confirmed =
                                await AdminBlockEmployeeSheet.show(
                                  context,
                                  employee: employee,
                                  onConfirmBlock: (reason) async {
                                    await ref
                                        .read(
                                          adminEmployeeListControllerProvider
                                              .notifier,
                                        )
                                        .blockEmployee(
                                          employeeId: employee.id,
                                          reason: reason,
                                        );
                                  },
                                );
                            if (confirmed == true && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '${employee.name} has been blocked.',
                                  ),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          },
                    ),

                    const SizedBox(height: AppSpacing.x6),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
