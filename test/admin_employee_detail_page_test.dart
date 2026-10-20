import 'package:diamond_tracking/core/theme/app_colors.dart';
import 'package:diamond_tracking/core/theme/app_theme.dart';
import 'package:diamond_tracking/features/admin/employees/presentation/admin_employee_detail_page.dart';
import 'package:diamond_tracking/features/admin/employees/presentation/controllers/admin_employee_list_state.dart';
import 'package:diamond_tracking/features/admin/employees/presentation/widgets/admin_employee_block_action_button.dart';
import 'package:diamond_tracking/features/admin/employees/presentation/widgets/admin_employee_contact_card.dart';
import 'package:diamond_tracking/features/admin/employees/presentation/widgets/admin_employee_detail_header.dart';
import 'package:diamond_tracking/features/admin/employees/presentation/widgets/admin_employee_monthly_stats_card.dart';
import 'package:diamond_tracking/features/admin/employees/presentation/widgets/admin_employee_quick_actions.dart';
import 'package:diamond_tracking/features/admin/employees/presentation/widgets/admin_employee_recent_duty_card.dart';
import 'package:diamond_tracking/features/admin/employees/presentation/widgets/admin_profile_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_admin_visits.dart';
import 'support/fake_attendance.dart';

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

  Widget buildTestableWidget(Widget child) {
    return ProviderScope(
      // The profile reads the server; the test must not.
      overrides: [
        ...attendanceOverrides(FakeAttendanceRepository()),
        adminVisitsOverride(),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: child),
      ),
    );
  }

  group('Screen 18 AdminEmployeeDetailPage Widget Tests', () {
    testWidgets(
      'renders curved hero header with SP avatar, name, DA-022, and duty pill',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        bool backTapped = false;
        bool editTapped = false;

        await tester.pumpWidget(
          buildTestableWidget(
            AdminEmployeeDetailHeader(
              employee: sureshPatel,
              onBack: () => backTapped = true,
              onEdit: () => editTapped = true,
            ),
          ),
        );
        await tester.pump();

        // Avatar Monogram
        expect(find.byKey(const Key('avatar-employee-detail')), findsOneWidget);
        expect(find.text('SP'), findsOneWidget);

        // Name
        expect(find.text('Suresh Patel'), findsOneWidget);

        // Employee Code Pill
        expect(find.byKey(const Key('pill-employee-code')), findsOneWidget);
        expect(find.text('DA-022'), findsOneWidget);

        // Live Duty Status Pill
        expect(
          find.byKey(const Key('pill-employee-duty-status')),
          findsOneWidget,
        );
        // No hours are invented: the real status and the real start time.
        expect(find.text('On duty · since 8:04 AM'), findsOneWidget);
        expect(find.textContaining('7h 24m'), findsNothing);

        // Action Icons
        await tester.tap(find.byKey(const Key('btn-employee-detail-back')));
        await tester.pump();
        expect(backTapped, isTrue);

        await tester.tap(find.byKey(const Key('btn-employee-detail-edit')));
        await tester.pump();
        expect(editTapped, isTrue);
        expect(find.byTooltip('Edit employee'), findsOneWidget);
      },
    );

    testWidgets(
      'renders status pill with appropriate labels for various employee statuses',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        // 0. On duty with no known start time: just the status
        await tester.pumpWidget(
          buildTestableWidget(
            const AdminEmployeeDetailHeader(
              employee: AdminEmployeeItem(
                id: 'emp-2',
                name: 'Asha Patil',
                employeeCode: 'DA-101',
                phoneNumber: '+919820000101',
                status: AdminEmployeeStatus.onDuty,
              ),
            ),
          ),
        );
        await tester.pump();
        expect(find.text('On duty'), findsOneWidget);

        // 1. Check needed
        final checkEmp = sureshPatel.copyWith(
          status: AdminEmployeeStatus.needsCheck,
        );
        await tester.pumpWidget(
          buildTestableWidget(AdminEmployeeDetailHeader(employee: checkEmp)),
        );
        await tester.pump();
        expect(find.text('Check needed'), findsOneWidget);

        // 2. Stale / No update
        final staleEmp = sureshPatel.copyWith(
          status: AdminEmployeeStatus.stale,
        );
        await tester.pumpWidget(
          buildTestableWidget(AdminEmployeeDetailHeader(employee: staleEmp)),
        );
        await tester.pump();
        expect(find.text('No update 5 min'), findsOneWidget);

        // 3. Off duty
        final offEmp = sureshPatel.copyWith(
          status: AdminEmployeeStatus.offDuty,
        );
        await tester.pumpWidget(
          buildTestableWidget(AdminEmployeeDetailHeader(employee: offEmp)),
        );
        await tester.pump();
        expect(find.text('Off duty'), findsOneWidget);

        // 4. Blocked
        final blockedEmp = sureshPatel.copyWith(
          status: AdminEmployeeStatus.blocked,
        );
        await tester.pumpWidget(
          buildTestableWidget(AdminEmployeeDetailHeader(employee: blockedEmp)),
        );
        await tester.pump();
        expect(find.text('Blocked'), findsOneWidget);
      },
    );

    testWidgets(
      'renders quick action buttons: Track live and Route view with callbacks',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        bool trackTapped = false;
        bool routeTapped = false;
        bool attendanceTapped = false;
        bool visitsTapped = false;

        await tester.pumpWidget(
          buildTestableWidget(
            AdminEmployeeQuickActions(
              onTrackLive: () => trackTapped = true,
              onRouteView: () => routeTapped = true,
              onAttendance: () => attendanceTapped = true,
              onVisits: () => visitsTapped = true,
            ),
          ),
        );
        await tester.pump();

        expect(find.byKey(const Key('btn-quick-track-live')), findsOneWidget);
        expect(find.text('Track live'), findsOneWidget);
        expect(find.byKey(const Key('btn-quick-route-view')), findsOneWidget);
        expect(find.text('Route view'), findsOneWidget);

        await tester.tap(find.byKey(const Key('btn-quick-track-live')));
        await tester.pump();
        expect(trackTapped, isTrue);

        await tester.tap(find.byKey(const Key('btn-quick-route-view')));
        await tester.pump();
        expect(routeTapped, isTrue);

        expect(find.text('Attendance'), findsOneWidget);
        await tester.tap(find.byKey(const Key('btn-quick-attendance')));
        await tester.pump();
        expect(attendanceTapped, isTrue);

        expect(find.text('Visits'), findsOneWidget);
        await tester.tap(find.byKey(const Key('btn-quick-visits')));
        await tester.pump();
        expect(visitsTapped, isTrue);
      },
    );

    testWidgets(
      'renders CONTACT card with phone and email rows and no invented join date',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          buildTestableWidget(
            const AdminEmployeeContactCard(
              employee: AdminEmployeeItem(
                id: 'emp-1',
                name: 'Suresh Patel',
                employeeCode: 'DA-022',
                phoneNumber: '+91 98201 44556',
                status: AdminEmployeeStatus.onDuty,
                email: 'suresh.p@diamondagritech.in',
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('Contact'), findsOneWidget);
        expect(find.byKey(const Key('row-contact-phone')), findsOneWidget);
        expect(find.text('Phone'), findsOneWidget);
        expect(find.text('+91 98201 44556'), findsOneWidget);

        expect(find.byKey(const Key('row-contact-email')), findsOneWidget);
        expect(find.text('Email'), findsOneWidget);
        expect(find.text('suresh.p@diamondagritech.in'), findsOneWidget);

        expect(find.byKey(const Key('row-contact-joined')), findsNothing);
        expect(find.text('18 Feb 2026'), findsNothing);
      },
    );

    testWidgets(
      'renders THIS MONTH card with 2x2 grid and diagnostic footnotes',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          buildTestableWidget(
            const AdminEmployeeMonthlyStatsCard(
              monthName: 'October',
              daysWorked: 12,
              hoursWorked: '96h 40m',
              distanceKm: '578.3 km',
              visitsCount: 54,
              autoEndedDays: 1,
              locationFlags: 0,
            ),
          ),
        );
        await tester.pump();

        expect(find.text('This month'), findsOneWidget);
        expect(find.text('October'), findsOneWidget);

        // 4 Metric Blocks
        expect(find.byKey(const Key('metric-days-worked')), findsOneWidget);
        expect(find.text('12'), findsOneWidget);
        expect(find.text('Days worked'), findsOneWidget);

        expect(find.byKey(const Key('metric-hours-worked')), findsOneWidget);
        expect(find.text('96h 40m'), findsOneWidget);
        expect(find.text('Hours'), findsOneWidget);

        expect(find.byKey(const Key('metric-distance-km')), findsOneWidget);
        expect(find.text('578.3 km'), findsOneWidget);
        expect(find.text('Distance'), findsOneWidget);

        expect(find.byKey(const Key('metric-visits-count')), findsOneWidget);
        expect(find.text('54'), findsOneWidget);
        expect(find.text('Visits'), findsOneWidget);

        // Diagnostics Footnotes
        expect(find.text('1 day auto-ended'), findsOneWidget);
        expect(find.text('0 location flags'), findsOneWidget);
      },
    );

    testWidgets(
      'renders Recent duty card with all three history rows and View all action',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        bool viewAllTapped = false;

        await tester.pumpWidget(
          buildTestableWidget(
            AdminEmployeeRecentDutyCard(
              logs: const [
                EmployeeDutyLogRecord(
                  id: 'log-1',
                  dateStr: '12 Oct 2026',
                  timeWindow: '8:04 AM – 6:12 PM',
                  durationStr: '8h 08m',
                  distanceStr: '47.3 km',
                ),
                EmployeeDutyLogRecord(
                  id: 'log-2',
                  dateStr: '11 Oct 2026',
                  timeWindow: '8:10 AM – 5:45 PM',
                  durationStr: '9h 35m',
                  distanceStr: '52.1 km',
                ),
                EmployeeDutyLogRecord(
                  id: 'log-3',
                  dateStr: '10 Oct 2026',
                  timeWindow: '7:55 AM – 4:20 PM',
                  durationStr: '8h 25m',
                  distanceStr: '44.8 km',
                ),
              ],
              onViewAll: () => viewAllTapped = true,
            ),
          ),
        );
        await tester.pump();

        expect(find.text('Recent duty'), findsOneWidget);
        expect(
          find.byKey(const Key('btn-recent-duty-view-all')),
          findsOneWidget,
        );
        expect(find.text('View all'), findsOneWidget);

        // Row 1
        expect(find.text('12 Oct 2026'), findsOneWidget);
        expect(find.text('8:04 AM – 6:12 PM'), findsOneWidget);
        expect(find.text('8h 08m'), findsOneWidget);
        expect(find.text('47.3 km'), findsOneWidget);

        // Row 2
        expect(find.text('11 Oct 2026'), findsOneWidget);
        expect(find.text('8:10 AM – 5:45 PM'), findsOneWidget);
        expect(find.text('9h 35m'), findsOneWidget);
        expect(find.text('52.1 km'), findsOneWidget);

        // Row 3
        expect(find.text('10 Oct 2026'), findsOneWidget);
        expect(find.text('7:55 AM – 4:20 PM'), findsOneWidget);
        expect(find.text('8h 25m'), findsOneWidget);
        expect(find.text('44.8 km'), findsOneWidget);

        // Tap View all
        await tester.tap(find.byKey(const Key('btn-recent-duty-view-all')));
        await tester.pump();
        expect(viewAllTapped, isTrue);
      },
    );

    testWidgets(
      'Recent duty and THIS MONTH show no invented figures by default',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          buildTestableWidget(
            const Column(
              children: [
                AdminEmployeeMonthlyStatsCard(),
                AdminEmployeeRecentDutyCard(),
              ],
            ),
          ),
        );
        await tester.pump();

        expect(find.text('No duty recorded this month.'), findsOneWidget);
        expect(find.text('96h 40m'), findsNothing);
        expect(find.text('578.3 km'), findsNothing);
        expect(find.text('0h 00m'), findsOneWidget);
        expect(find.text('0.0 km'), findsOneWidget);
      },
    );

    testWidgets('Copy puts the phone number on the clipboard and says so', (
      tester,
    ) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      await tester.pumpWidget(
        buildTestableWidget(
          const AdminEmployeeContactCard(
            employee: AdminEmployeeItem(
              id: 'emp-1',
              name: 'Suresh Patel',
              employeeCode: 'DA-022',
              phoneNumber: '+91 98201 44556',
              status: AdminEmployeeStatus.onDuty,
              email: 'suresh.p@diamondagritech.in',
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('btn-copy-phone')));
      await tester.pump();
      expect(copied, '+91 98201 44556');
      expect(find.text('Phone number copied'), findsOneWidget);

      await tester.tap(find.byKey(const Key('btn-copy-email')));
      await tester.pump();
      expect(copied, 'suresh.p@diamondagritech.in');
      // Nothing pretends to dial or send.
      expect(find.textContaining('Dialing'), findsNothing);
    });

    testWidgets('no email on file shows a dash and nothing to copy', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestableWidget(
          const AdminEmployeeContactCard(employee: sureshPatel),
        ),
      );

      expect(find.text('—'), findsOneWidget);
      expect(find.byKey(const Key('btn-copy-email')), findsNothing);
      expect(find.byKey(const Key('btn-copy-phone')), findsOneWidget);
    });

    testWidgets('flag chips are grey at zero and tinted only when needed', (
      tester,
    ) async {
      Color chipBackground(String key) => tester
          .widget<AdminProfileStatusChip>(find.byKey(Key(key)))
          .background;

      await tester.pumpWidget(
        buildTestableWidget(const AdminEmployeeMonthlyStatsCard()),
      );
      expect(chipBackground('chip-auto-ended'), AppColors.neutral100);
      expect(chipBackground('chip-location-flags'), AppColors.neutral100);

      await tester.pumpWidget(
        buildTestableWidget(
          const AdminEmployeeMonthlyStatsCard(
            autoEndedDays: 2,
            locationFlags: 1,
          ),
        ),
      );
      expect(find.text('2 days auto-ended'), findsOneWidget);
      expect(find.text('1 location flag'), findsOneWidget);
      expect(chipBackground('chip-auto-ended'), AppColors.warningBg);
      expect(chipBackground('chip-location-flags'), AppColors.errorBg);
    });

    testWidgets('while the month loads the figures are dashes, not zeros', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestableWidget(
          const AdminEmployeeMonthlyStatsCard(isAvailable: false),
        ),
      );

      expect(find.text('–'), findsNWidgets(4));
      expect(find.text('0h 00m'), findsNothing);
    });

    testWidgets('renders Block employee button and invokes callback', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      bool blockTapped = false;

      await tester.pumpWidget(
        buildTestableWidget(
          AdminEmployeeBlockActionButton(
            onBlockPressed: () => blockTapped = true,
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('btn-employee-block-action')),
        findsOneWidget,
      );
      expect(find.text('Block employee'), findsOneWidget);

      await tester.tap(find.byKey(const Key('btn-employee-block-action')));
      await tester.pump();
      expect(blockTapped, isTrue);
    });

    testWidgets(
      'renders complete AdminEmployeeDetailPage layout with all sections',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          buildTestableWidget(
            const AdminEmployeeDetailPage(employee: sureshPatel),
          ),
        );
        await tester.pump();

        expect(find.byType(AdminEmployeeDetailHeader), findsOneWidget);
        expect(find.byType(AdminEmployeeQuickActions), findsOneWidget);
        expect(find.byType(AdminEmployeeContactCard), findsOneWidget);
        expect(find.byType(AdminEmployeeMonthlyStatsCard), findsOneWidget);
        expect(find.byType(AdminEmployeeRecentDutyCard), findsOneWidget);
        expect(find.byType(AdminEmployeeBlockActionButton), findsOneWidget);
      },
    );
  });
}
