import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../attendance/presentation/admin_attendance_page.dart';
import '../../route_view/presentation/admin_route_view_page.dart';
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
    this.email = 'suresh.p@diamondagritech.in',
    this.joinedDate = '18 Feb 2026',
    this.onBack,
    this.onTrackLive,
    this.onRouteView,
    this.onRecentDutyViewAll,
    this.onBlockEmployee,
    this.onMoreOptions,
  });

  final AdminEmployeeItem employee;
  final String email;
  final String joinedDate;
  final VoidCallback? onBack;
  final VoidCallback? onTrackLive;
  final VoidCallback? onRouteView;
  final VoidCallback? onRecentDutyViewAll;
  final VoidCallback? onBlockEmployee;
  final VoidCallback? onMoreOptions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
              onMoreOptions: onMoreOptions ??
                  () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => AdminEmployeeFormPage(employee: employee),
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
                      onTrackLive: onTrackLive ??
                          () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Tracking live telemetry for ${employee.name}...'),
                                duration: const Duration(seconds: 1),
                              ),
                            );
                          },
                      onRouteView: onRouteView ??
                          () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => AdminRouteViewPage(
                                  employeeId: employee.id,
                                ),
                              ),
                            );
                          },
                    ),

                    const SizedBox(height: AppSpacing.x4),

                    // Section 2: CONTACT Card
                    AdminEmployeeContactCard(
                      employee: employee,
                      email: email,
                      joinedDate: joinedDate,
                    ),

                    const SizedBox(height: AppSpacing.x4),

                    // Section 3: THIS MONTH Telemetry Card
                    AdminEmployeeMonthlyStatsCard(
                      onMonthSelect: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (ctx) => AdminAttendancePage(
                              employeeId: employee.id,
                              onViewRouteDay: (dayId) {
                                Navigator.of(ctx).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => AdminRouteViewPage(
                                      employeeId: employee.id,
                                      dayId: dayId,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: AppSpacing.x4),

                    // Section 4: Recent Duty Log Card
                    AdminEmployeeRecentDutyCard(
                      onViewAll: onRecentDutyViewAll ??
                          () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (ctx) => AdminAttendancePage(
                                  employeeId: employee.id,
                                  onViewRouteDay: (dayId) {
                                    Navigator.of(ctx).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) => AdminRouteViewPage(
                                          employeeId: employee.id,
                                          dayId: dayId,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            );
                          },
                    ),

                    const SizedBox(height: AppSpacing.x5),

                    // Section 5: Danger Action: Block Employee
                    AdminEmployeeBlockActionButton(
                      onBlockPressed: onBlockEmployee ??
                          () async {
                            final confirmed = await AdminBlockEmployeeSheet.show(
                              context,
                              employee: employee,
                              onConfirmBlock: (reason) async {
                                ref
                                    .read(adminEmployeeListControllerProvider.notifier)
                                    .blockEmployee(
                                      employeeId: employee.id,
                                      reason: reason,
                                    );
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
