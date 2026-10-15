import 'package:diamond_tracking/core/theme/app_theme.dart';
import 'package:diamond_tracking/features/admin/employees/presentation/admin_employee_detail_page.dart';
import 'package:diamond_tracking/features/admin/employees/presentation/controllers/admin_employee_list_state.dart';
import 'package:diamond_tracking/features/admin/employees/presentation/widgets/admin_employee_block_action_button.dart';
import 'package:diamond_tracking/features/admin/employees/presentation/widgets/admin_employee_contact_card.dart';
import 'package:diamond_tracking/features/admin/employees/presentation/widgets/admin_employee_detail_header.dart';
import 'package:diamond_tracking/features/admin/employees/presentation/widgets/admin_employee_monthly_stats_card.dart';
import 'package:diamond_tracking/features/admin/employees/presentation/widgets/admin_employee_quick_actions.dart';
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

  Widget buildTestableWidget(Widget child) {
    return ProviderScope(
      child: MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: child),
      ),
    );
  }

  group('Screen 18 AdminEmployeeDetailPage Widget Tests', () {
    testWidgets('renders curved hero header with SP avatar, name, DA-022, and duty pill',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      bool backTapped = false;
      bool moreTapped = false;

      await tester.pumpWidget(
        buildTestableWidget(
          AdminEmployeeDetailHeader(
            employee: sureshPatel,
            onBack: () => backTapped = true,
            onMoreOptions: () => moreTapped = true,
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
      expect(find.byKey(const Key('pill-employee-duty-status')), findsOneWidget);
      expect(find.text('On duty · 7h 24m'), findsOneWidget);

      // Action Icons
      await tester.tap(find.byKey(const Key('btn-employee-detail-back')));
      await tester.pump();
      expect(backTapped, isTrue);

      await tester.tap(find.byKey(const Key('btn-employee-detail-overflow')));
      await tester.pump();
      expect(moreTapped, isTrue);
    });

    testWidgets('renders status pill with appropriate labels for various employee statuses',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // 1. Check needed
      final checkEmp = sureshPatel.copyWith(status: AdminEmployeeStatus.needsCheck);
      await tester.pumpWidget(
        buildTestableWidget(AdminEmployeeDetailHeader(employee: checkEmp)),
      );
      await tester.pump();
      expect(find.text('Check needed'), findsOneWidget);

      // 2. Stale / No update
      final staleEmp = sureshPatel.copyWith(status: AdminEmployeeStatus.stale);
      await tester.pumpWidget(
        buildTestableWidget(AdminEmployeeDetailHeader(employee: staleEmp)),
      );
      await tester.pump();
      expect(find.text('No update 5 min'), findsOneWidget);

      // 3. Off duty
      final offEmp = sureshPatel.copyWith(status: AdminEmployeeStatus.offDuty);
      await tester.pumpWidget(
        buildTestableWidget(AdminEmployeeDetailHeader(employee: offEmp)),
      );
      await tester.pump();
      expect(find.text('Off duty'), findsOneWidget);

      // 4. Blocked
      final blockedEmp = sureshPatel.copyWith(status: AdminEmployeeStatus.blocked);
      await tester.pumpWidget(
        buildTestableWidget(AdminEmployeeDetailHeader(employee: blockedEmp)),
      );
      await tester.pump();
      expect(find.text('Blocked'), findsOneWidget);
    });

    testWidgets('renders quick action buttons: Track live and Route view with callbacks',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      bool trackTapped = false;
      bool routeTapped = false;

      await tester.pumpWidget(
        buildTestableWidget(
          AdminEmployeeQuickActions(
            onTrackLive: () => trackTapped = true,
            onRouteView: () => routeTapped = true,
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
    });

    testWidgets('renders CONTACT card with phone, email, and joined date rows',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildTestableWidget(
          const AdminEmployeeContactCard(
            employee: sureshPatel,
            email: 'suresh.p@diamondagritech.in',
            joinedDate: '18 Feb 2026',
          ),
        ),
      );
      await tester.pump();

      expect(find.text('CONTACT'), findsOneWidget);
      expect(find.byKey(const Key('row-contact-phone')), findsOneWidget);
      expect(find.text('Phone'), findsOneWidget);
      expect(find.text('+91 98201 44556'), findsOneWidget);

      expect(find.byKey(const Key('row-contact-email')), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('suresh.p@diamondagritech.in'), findsOneWidget);

      expect(find.byKey(const Key('row-contact-joined')), findsOneWidget);
      expect(find.text('Joined'), findsOneWidget);
      expect(find.text('18 Feb 2026'), findsOneWidget);
    });

    testWidgets('renders THIS MONTH card with 2x2 grid and diagnostic footnotes',
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

      expect(find.text('THIS MONTH'), findsOneWidget);
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
    });

    testWidgets('renders Recent duty card with all three history rows and View all action',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      bool viewAllTapped = false;

      await tester.pumpWidget(
        buildTestableWidget(
          AdminEmployeeRecentDutyCard(
            onViewAll: () => viewAllTapped = true,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Recent duty'), findsOneWidget);
      expect(find.byKey(const Key('btn-recent-duty-view-all')), findsOneWidget);
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
    });

    testWidgets('renders Block employee button and invokes callback',
        (tester) async {
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

      expect(find.byKey(const Key('btn-employee-block-action')), findsOneWidget);
      expect(find.text('Block employee'), findsOneWidget);

      await tester.tap(find.byKey(const Key('btn-employee-block-action')));
      await tester.pump();
      expect(blockTapped, isTrue);
    });

    testWidgets('renders complete AdminEmployeeDetailPage layout with all sections',
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
    });
  });
}
