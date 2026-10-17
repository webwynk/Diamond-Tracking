import 'package:diamond_tracking/core/theme/app_theme.dart';
import 'package:diamond_tracking/features/admin/employees/presentation/admin_employee_detail_page.dart';
import 'package:diamond_tracking/features/admin/employees/presentation/controllers/admin_employee_list_state.dart';
import 'package:diamond_tracking/features/admin/map/presentation/controllers/admin_live_map_controller.dart';
import 'package:diamond_tracking/features/admin/map/presentation/controllers/admin_live_map_state.dart';
import 'package:diamond_tracking/features/admin/shell/admin_shell.dart';
import 'package:diamond_tracking/features/admin/shell/admin_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_admin_activity.dart';
import 'support/fake_employee_repository.dart';
import 'support/fake_live_locations.dart';
import 'support/fake_notification_repository.dart';

/// "Track live" on a Team profile: show that employee on the live map.
void main() {
  late FakeLiveLocationRepository live;
  late FakeEmployeeRepository roster;

  const asha = AdminEmployeeItem(
    id: 'e-asha',
    name: 'Asha Patil',
    employeeCode: 'DA-101',
    phoneNumber: '+919820000101',
    status: AdminEmployeeStatus.onDuty,
  );
  const ravi = AdminEmployeeItem(
    id: 'e-ravi',
    name: 'Ravi Kumar',
    employeeCode: 'DA-102',
    phoneNumber: '+919820000102',
    status: AdminEmployeeStatus.offDuty,
  );

  setUp(() {
    live = FakeLiveLocationRepository(positions: [livePosition('e-asha')]);
    roster = FakeEmployeeRepository(roster: [asha, ravi]);
  });

  Future<ProviderContainer> pumpShell(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...liveMapOverrides(live, roster),
          activityOverride(FakeAdminActivityRepository()),
          notificationOverride(FakeNotificationRepository()),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const AdminShell()),
      ),
    );
    for (var i = 0; i < 4; i++) {
      await tester.pump();
    }
    return ProviderScope.containerOf(tester.element(find.byType(AdminShell)));
  }

  /// Opens a profile over the shell, as the Team list does.
  Future<void> openProfile(
    WidgetTester tester,
    AdminEmployeeItem employee,
  ) async {
    final navigator = Navigator.of(tester.element(find.byType(AdminShell)));
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => AdminEmployeeDetailPage(employee: employee),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// The shell owns timers, so it is taken down before the test ends.
  Future<void> closeShell(WidgetTester tester) =>
      tester.pumpWidget(const SizedBox());

  Future<void> tapTrackLive(WidgetTester tester) async {
    await tester.tap(find.text('Track live'));
    await tester.pumpAndSettle();
  }

  group('Track live', () {
    testWidgets(
      'an employee on duty: closes the profile, opens the Map tab and their card',
      (tester) async {
        final container = await pumpShell(tester);
        await openProfile(tester, asha);
        expect(find.byType(AdminEmployeeDetailPage), findsOneWidget);

        await tapTrackLive(tester);

        expect(find.byType(AdminEmployeeDetailPage), findsNothing);
        expect(container.read(adminTabProvider), AdminTab.map);
        final card = find.byKey(const Key('live-officer-card'));
        expect(card, findsOneWidget);
        expect(
          find.descendant(of: card, matching: find.text('Asha Patil')),
          findsOneWidget,
        );
        // The request was answered, not left waiting.
        expect(container.read(liveMapFocusProvider), isNull);
        await closeShell(tester);
      },
    );

    testWidgets('works again when the Map tab is already open', (tester) async {
      live.positions = [livePosition('e-asha'), livePosition('e-ravi')];
      final container = await pumpShell(tester);
      container.read(adminTabProvider.notifier).select(AdminTab.map);
      await tester.pumpAndSettle();
      container.read(adminLiveMapControllerProvider.notifier).select('e-ravi');
      await tester.pump();
      expect(
        find.descendant(
          of: find.byKey(const Key('live-officer-card')),
          matching: find.text('Ravi Kumar'),
        ),
        findsOneWidget,
      );

      await openProfile(tester, asha);
      await tapTrackLive(tester);

      final card = find.byKey(const Key('live-officer-card'));
      expect(
        find.descendant(of: card, matching: find.text('Asha Patil')),
        findsOneWidget,
      );
      expect(find.text('Ravi Kumar'), findsNothing);
      await closeShell(tester);
    });

    testWidgets('clears a search or chip that would hide their dot', (
      tester,
    ) async {
      final container = await pumpShell(tester);
      container.read(adminTabProvider.notifier).select(AdminTab.map);
      await tester.pumpAndSettle();
      container
          .read(adminLiveMapControllerProvider.notifier)
          .setFilter(AdminMapFilter.stale);
      container
          .read(adminLiveMapControllerProvider.notifier)
          .setSearchQuery('nobody');
      await tester.pump();

      container.read(adminTabProvider.notifier).select(AdminTab.team);
      await tester.pump();
      await openProfile(tester, asha);
      await tapTrackLive(tester);

      final state = container.read(adminLiveMapControllerProvider);
      expect(state.selectedFilter, AdminMapFilter.all);
      expect(state.searchQuery, isEmpty);
      expect(state.selectedOfficer?.name, 'Asha Patil');
      await closeShell(tester);
    });

    testWidgets(
      'an employee off duty: says so, stays on the profile and does not switch tab',
      (tester) async {
        final container = await pumpShell(tester);
        await openProfile(tester, ravi);

        await tapTrackLive(tester);

        expect(
          find.text('Ravi Kumar is off duty. No live location.'),
          findsOneWidget,
        );
        expect(find.byType(AdminEmployeeDetailPage), findsOneWidget);
        expect(container.read(adminTabProvider), AdminTab.home);
        expect(container.read(liveMapFocusProvider), isNull);
        await closeShell(tester);
      },
    );

    testWidgets(
      'a request for someone who went off duty meanwhile is dropped, not stuck',
      (tester) async {
        final container = await pumpShell(tester);

        container.read(liveMapFocusProvider.notifier).request('e-ravi');
        container.read(adminTabProvider.notifier).select(AdminTab.map);
        await tester.pumpAndSettle();

        expect(container.read(liveMapFocusProvider), isNull);
        expect(find.byKey(const Key('live-officer-card')), findsNothing);
        await closeShell(tester);
      },
    );
  });
}
