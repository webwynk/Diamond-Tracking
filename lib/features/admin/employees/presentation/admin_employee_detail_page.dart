import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../domain/entities/visit_record.dart';
import '../../attendance/presentation/admin_attendance_page.dart';
import '../../attendance/presentation/controllers/admin_attendance_controller.dart';
import '../../attendance/presentation/controllers/admin_attendance_state.dart';
import '../../map/presentation/controllers/admin_live_map_controller.dart';
import '../../route_view/presentation/admin_route_view_page.dart';
import '../../shell/admin_tab.dart';
import '../../visits/presentation/admin_visit_details_page.dart';
import '../../visits/presentation/admin_visits_page.dart';
import '../../visits/presentation/controllers/admin_visits_controller.dart';
import '../../visits/presentation/widgets/admin_visits_card.dart';
import 'admin_employee_form_page.dart';
import 'controllers/admin_employee_list_controller.dart';
import 'controllers/admin_employee_list_state.dart';
import 'widgets/admin_block_employee_sheet.dart';
import 'widgets/admin_clear_device_sheet.dart';
import 'widgets/admin_employee_block_action_button.dart';
import 'widgets/admin_employee_clear_device_button.dart';
import 'widgets/admin_employee_contact_card.dart';
import 'widgets/admin_employee_detail_header.dart';
import 'widgets/admin_employee_monthly_stats_card.dart';
import 'widgets/admin_employee_quick_actions.dart';
import 'widgets/admin_employee_recent_duty_card.dart';
import 'widgets/admin_employee_reset_pin_button.dart';
import 'widgets/admin_reset_pin_sheet.dart';

/// Screen 18 — Employee Detail (Admin).
///
/// One employee at a glance, top to bottom:
/// - the identity hero: avatar, name, code and duty status, with Edit;
/// - the action bar floating over its edge: Track live (Screen 15/16), Route
///   view (Screen 23), Attendance (Screen 22) and Visits (PRD F10);
/// - "This month": days, hours, km, visits, auto-ended days, location flags;
/// - "Recent duty", each day opening its route;
/// - "Visits", the latest three;
/// - "Contact", phone and email with Copy;
/// - "Block employee" (Screen 20).
class AdminEmployeeDetailPage extends ConsumerWidget {
  const AdminEmployeeDetailPage({
    super.key,
    required this.employee,
    this.onBack,
    this.onTrackLive,
    this.onRouteView,
    this.onEdit,
  });

  final AdminEmployeeItem employee;
  final VoidCallback? onBack;
  final VoidCallback? onTrackLive;
  final VoidCallback? onRouteView;
  final VoidCallback? onEdit;

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

  void _openVisits(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AdminVisitsPage(
          employeeId: employee.id,
          employeeName: employee.name,
          employeeCode: employee.employeeCode,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visits = ref.watch(adminVisitsControllerProvider(employee.id));
    final attendance = ref.watch(
      adminAttendanceControllerProvider(employee.id),
    );
    // The roster is the live copy: it changes when a phone is cleared here.
    final deviceRegistered =
        ref.watch(
          adminEmployeeListControllerProvider.select(
            (list) => list.employees
                .where((e) => e.id == employee.id)
                .firstOrNull
                ?.deviceRegistered,
          ),
        ) ??
        employee.deviceRegistered;
    void openVisit(VisitRecord visit) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              AdminVisitDetailsPage(visit: visit, employeeName: employee.name),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: Column(
          children: <Widget>[
            AdminEmployeeDetailHeader(
              employee: employee,
              onBack: onBack ?? () => Navigator.of(context).maybePop(),
              onEdit:
                  onEdit ??
                  () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => AdminEmployeeFormPage(employee: employee),
                    ),
                  ),
            ),
            // The body starts over the hero's edge; the translate leaves the
            // same height free at the bottom, which the last gap absorbs.
            Transform.translate(
              offset: const Offset(0, -AdminEmployeeDetailHeader.overlap),
              child: Padding(
                padding: AppSpacing.screen,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    AdminEmployeeQuickActions(
                      onTrackLive:
                          onTrackLive ?? () => _trackLive(context, ref),
                      onRouteView: onRouteView ?? () => _openRoute(context),
                      onAttendance: () => _openAttendance(context),
                      onVisits: () => _openVisits(context),
                    ),
                    const SizedBox(height: AppSpacing.x4),
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
                      onViewAll: () => _openAttendance(context),
                      onLogSelected: (log) => _openRoute(context, log.id),
                    ),
                    const SizedBox(height: AppSpacing.x4),
                    AdminVisitsCard(
                      state: visits,
                      onViewAll: () => _openVisits(context),
                      onVisitSelected: openVisit,
                    ),
                    const SizedBox(height: AppSpacing.x4),
                    AdminEmployeeContactCard(employee: employee),
                    const SizedBox(height: AppSpacing.x6),
                    AdminEmployeeResetPinButton(
                      onPressed: () => _resetPin(context, ref),
                    ),
                    const SizedBox(height: AppSpacing.x3),
                    AdminEmployeeClearDeviceButton(
                      deviceRegistered: deviceRegistered,
                      onPressed: () => _clearDevice(context, ref),
                    ),
                    const SizedBox(height: AppSpacing.x3),
                    AdminEmployeeBlockActionButton(
                      onBlockPressed: () => _confirmBlock(context, ref),
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

  Future<void> _resetPin(BuildContext context, WidgetRef ref) async {
    final done = await AdminResetPinSheet.show(
      context,
      employee: employee,
      onConfirm: (pin) => ref
          .read(employeeRepositoryProvider)
          .resetPin(id: employee.id, newPin: pin),
    );
    if (done == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Temporary PIN set for ${employee.name}. They must choose a new '
            'one when they sign in.',
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _clearDevice(BuildContext context, WidgetRef ref) async {
    final cleared = await AdminClearDeviceSheet.show(
      context,
      employee: employee,
      onConfirm: () => ref
          .read(adminEmployeeListControllerProvider.notifier)
          .clearDevice(employeeId: employee.id),
    );
    if (cleared == null || !context.mounted) return; // cancelled
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          cleared
              ? 'Device binding cleared for ${employee.name}. The next phone '
                    'they sign in on will be registered.'
              : 'No phone was registered for ${employee.name}.',
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _confirmBlock(BuildContext context, WidgetRef ref) async {
    final confirmed = await AdminBlockEmployeeSheet.show(
      context,
      employee: employee,
      onConfirmBlock: (reason) async {
        await ref
            .read(adminEmployeeListControllerProvider.notifier)
            .blockEmployee(employeeId: employee.id, reason: reason);
      },
    );
    if (confirmed == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${employee.name} has been blocked.'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}
