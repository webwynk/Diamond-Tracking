import 'package:diamond_tracking/core/theme/app_theme.dart';
import 'package:diamond_tracking/features/admin/attendance/presentation/admin_attendance_page.dart';
import 'package:diamond_tracking/features/admin/attendance/presentation/controllers/admin_attendance_controller.dart';
import 'package:diamond_tracking/features/admin/attendance/presentation/controllers/admin_attendance_state.dart';
import 'package:diamond_tracking/features/admin/attendance/presentation/widgets/admin_attendance_daily_card.dart';
import 'package:diamond_tracking/features/admin/attendance/presentation/widgets/admin_attendance_discrepancy_banner.dart';
import 'package:diamond_tracking/features/admin/attendance/presentation/widgets/admin_attendance_filter_chips.dart';
import 'package:diamond_tracking/features/admin/attendance/presentation/widgets/admin_attendance_meta_header.dart';
import 'package:diamond_tracking/features/admin/attendance/presentation/widgets/admin_attendance_month_selector.dart';
import 'package:diamond_tracking/features/admin/attendance/presentation/widgets/admin_attendance_settle_bar.dart';
import 'package:diamond_tracking/features/admin/attendance/presentation/widgets/admin_attendance_summary_card.dart';
import 'package:diamond_tracking/features/admin/attendance/presentation/widgets/admin_attendance_top_bar.dart';
import 'package:diamond_tracking/features/admin/employees/presentation/admin_employee_detail_page.dart';
import 'package:diamond_tracking/features/admin/employees/presentation/controllers/admin_employee_list_state.dart';
import 'package:diamond_tracking/features/admin/employees/presentation/widgets/admin_employee_recent_duty_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const sureshPatel = AdminEmployeeItem(
    id: 'emp-1',
    name: 'Suresh Patel',
    employeeCode: 'DA-022',
    phoneNumber: '+91 98201 44556',
    status: AdminEmployeeStatus.onDuty,
    dutyStartTime: '8:04 AM',
    distanceTodayKm: '38.6 km',
    locationName: 'Shivpuri Agricultural Cluster',
  );

  Widget buildTestableWidget(Widget child, {ProviderContainer? container}) {
    if (container != null) {
      return UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light,
          home: child,
        ),
      );
    }
    return ProviderScope(
      child: MaterialApp(
        theme: AppTheme.light,
        home: child,
      ),
    );
  }

  group('Screen 22 AdminAttendancePage Visual & Structural Tests', () {
    testWidgets('renders all visual elements matching HTML design reference', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildTestableWidget(const AdminAttendancePage()),
      );
      await tester.pumpAndSettle();

      // Top Bar
      expect(find.byType(AdminAttendanceTopBar), findsOneWidget);
      expect(find.text('Attendance & History'), findsOneWidget);
      expect(find.byKey(const Key('btn-attendance-back')), findsOneWidget);
      expect(find.byKey(const Key('btn-attendance-export')), findsOneWidget);

      // Meta Sub-header
      expect(find.byType(AdminAttendanceMetaHeader), findsOneWidget);
      expect(find.text('SP'), findsOneWidget);
      expect(find.text('Suresh Patel'), findsOneWidget);
      expect(find.text('DA-022'), findsOneWidget);
      expect(find.text('Agronomist · Nashik Central Beat'), findsOneWidget);
      expect(find.text('Active Payroll'), findsOneWidget);

      // Month Switcher
      expect(find.byType(AdminAttendanceMonthSelector), findsOneWidget);
      expect(find.text('October 2026'), findsOneWidget);
      expect(find.byKey(const Key('btn-prev-month')), findsOneWidget);
      expect(find.byKey(const Key('btn-next-month')), findsOneWidget);

      // Telemetry Summary Card (2x3 Grid)
      expect(find.byType(AdminAttendanceSummaryCard), findsOneWidget);
      expect(find.text('MONTHLY TELEMETRY AUDIT'), findsOneWidget);
      expect(find.text('Days worked'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      expect(find.text('Total hours'), findsOneWidget);
      expect(find.text('96h 40m'), findsWidgets);
      expect(find.text('Distance'), findsOneWidget);
      expect(find.text('578.3 km'), findsOneWidget);
      expect(find.text('Visits'), findsOneWidget);
      expect(find.text('54'), findsOneWidget);
      expect(find.text('Auto-ended'), findsWidgets);
      expect(find.text('1'), findsWidgets);
      expect(find.text('Flags'), findsOneWidget);
      expect(find.text('0'), findsWidgets);

      // Discrepancy Banner
      expect(find.byType(AdminAttendanceDiscrepancyBanner), findsOneWidget);
      expect(
        find.text('1 audit alert requires supervisor approval before payout'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('btn-discrepancy-review')), findsOneWidget);

      // Filter Chips
      expect(find.byType(AdminAttendanceFilterChips), findsOneWidget);
      expect(find.byKey(const Key('attendance-filter-all')), findsOneWidget);
      expect(find.byKey(const Key('attendance-filter-auto-ended')), findsOneWidget);
      expect(find.byKey(const Key('attendance-filter-flags')), findsOneWidget);
      expect(find.byKey(const Key('attendance-filter-absent')), findsOneWidget);

      // Daily Attendance Cards
      expect(find.byType(AdminAttendanceDailyCard), findsNWidgets(5));
      expect(find.text('11'), findsOneWidget);
      expect(find.text('Sat'), findsOneWidget);
      expect(find.text('8:04 AM – 6:12 PM'), findsOneWidget);
      expect(find.text('8h 08m · 47.3 km · 5 visits'), findsOneWidget);

      expect(find.text('10'), findsOneWidget);
      expect(find.text('Fri'), findsOneWidget);
      expect(find.text('AUTO-ENDED'), findsOneWidget);
      expect(find.text('Exceeded shift threshold (14h cap applied)'), findsOneWidget);

      expect(find.text('09'), findsOneWidget);
      expect(find.text('Thu'), findsOneWidget);
      expect(find.text('2 SESSIONS'), findsOneWidget);
      expect(find.text('8:02 AM – 1:10 PM'), findsOneWidget);
      expect(find.text('2:30 PM – 6:40 PM'), findsOneWidget);

      expect(find.text('08'), findsOneWidget);
      expect(find.text('Wed'), findsOneWidget);
      expect(find.text('No duty recorded'), findsOneWidget);
      expect(find.text('OFF'), findsOneWidget);

      expect(find.text('07'), findsOneWidget);
      expect(find.text('Tue'), findsOneWidget);
      expect(find.text('8:15 AM – 5:45 PM'), findsOneWidget);

      // Sticky Bottom Settlement Bar
      expect(find.byType(AdminAttendanceSettleBar), findsOneWidget);
      expect(find.text('PAYABLE HOURS'), findsOneWidget);
      expect(find.text('(₹14,500 Base)'), findsOneWidget);
      expect(find.byKey(const Key('btn-attendance-adjust')), findsOneWidget);
      expect(find.byKey(const Key('btn-attendance-approve')), findsOneWidget);
    });

    testWidgets('month selector navigates between months', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        buildTestableWidget(
          const AdminAttendancePage(),
          container: container,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('October 2026'), findsOneWidget);

      // Tap previous month
      await tester.tap(find.byKey(const Key('btn-prev-month')));
      await tester.pumpAndSettle();

      expect(find.text('September 2026'), findsOneWidget);
      expect(container.read(adminAttendanceControllerProvider).selectedMonth, 'September 2026');

      // Tap next month
      await tester.tap(find.byKey(const Key('btn-next-month')));
      await tester.pumpAndSettle();

      expect(find.text('October 2026'), findsOneWidget);
      expect(container.read(adminAttendanceControllerProvider).selectedMonth, 'October 2026');
    });

    testWidgets('filter chips filter daily attendance logs accurately', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildTestableWidget(const AdminAttendancePage()),
      );
      await tester.pumpAndSettle();

      // Tap "Auto-ended" filter chip
      await tester.tap(find.byKey(const Key('attendance-filter-auto-ended')));
      await tester.pumpAndSettle();

      // Only Day 10 is visible
      expect(find.byType(AdminAttendanceDailyCard), findsOneWidget);
      expect(find.text('10'), findsOneWidget);
      expect(find.text('AUTO-ENDED'), findsOneWidget);
      expect(find.text('11'), findsNothing);
      expect(find.text('08'), findsNothing);

      // Scroll to & Tap "Absent" filter chip
      await tester.ensureVisible(find.byKey(const Key('attendance-filter-absent')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('attendance-filter-absent')));
      await tester.pumpAndSettle();

      // Only Day 08 is visible
      expect(find.byType(AdminAttendanceDailyCard), findsOneWidget);
      expect(find.text('08'), findsOneWidget);
      expect(find.text('No duty recorded'), findsOneWidget);
      expect(find.text('10'), findsNothing);

      // Scroll to & Tap "All days" filter chip
      await tester.ensureVisible(find.byKey(const Key('attendance-filter-all')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('attendance-filter-all')));
      await tester.pumpAndSettle();

      // All 5 days visible again
      expect(find.byType(AdminAttendanceDailyCard), findsNWidgets(5));
    });

    testWidgets('tapping Review on discrepancy banner filters to auto-ended session',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        buildTestableWidget(
          const AdminAttendancePage(),
          container: container,
        ),
      );
      await tester.pumpAndSettle();

      // Tap Review
      await tester.tap(find.byKey(const Key('btn-discrepancy-review')));
      await tester.pumpAndSettle();

      expect(
        container.read(adminAttendanceControllerProvider).selectedFilter,
        AdminAttendanceFilter.autoEnded,
      );
      expect(find.byType(AdminAttendanceDailyCard), findsOneWidget);
      expect(find.text('10'), findsOneWidget);
    });

    testWidgets('payroll settle actions: adjust hours and approve month', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        buildTestableWidget(
          const AdminAttendancePage(),
          container: container,
        ),
      );
      await tester.pumpAndSettle();

      // Tap "Adjust" button
      await tester.tap(find.byKey(const Key('btn-attendance-adjust')));
      await tester.pumpAndSettle();

      // Dialog opens
      expect(find.text('Adjust Payable Hours'), findsOneWidget);
      await tester.tap(find.text('Save Override'));
      await tester.pumpAndSettle();

      // Clear SnackBar so it does not obscure the bottom settle bar
      ScaffoldMessenger.of(tester.element(find.byType(AdminAttendancePage))).clearSnackBars();
      await tester.pumpAndSettle();

      // Tap "Approve Month"
      await tester.tap(find.byKey(const Key('btn-attendance-approve')));
      await tester.pumpAndSettle();

      // Month approved: button changes to Approved and discrepancy banner hides
      expect(container.read(adminAttendanceControllerProvider).isMonthApproved, isTrue);
      expect(find.text('Approved'), findsOneWidget);
      expect(find.byType(AdminAttendanceDiscrepancyBanner), findsNothing);
      expect(
        find.text('October 2026 attendance approved for payroll settlement.'),
        findsOneWidget,
      );
    });

    testWidgets('AdminEmployeeDetailPage View all opens AdminAttendancePage', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildTestableWidget(
          const AdminEmployeeDetailPage(employee: sureshPatel),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll to Recent Duty Card
      await tester.scrollUntilVisible(
        find.byType(AdminEmployeeRecentDutyCard),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      // Tap "View all"
      await tester.tap(find.text('View all'));
      await tester.pumpAndSettle();

      // AdminAttendancePage is displayed
      expect(find.byType(AdminAttendancePage), findsOneWidget);
      expect(find.text('Attendance & History'), findsOneWidget);
    });
  });
}
