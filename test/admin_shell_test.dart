import 'package:diamond_tracking/core/theme/app_theme.dart';
import 'package:diamond_tracking/features/admin/dashboard/presentation/admin_dashboard_page.dart';
import 'package:diamond_tracking/features/admin/employees/presentation/admin_employee_list_page.dart';
import 'package:diamond_tracking/features/admin/map/presentation/admin_live_map_page.dart';
import 'package:diamond_tracking/features/admin/notifications/presentation/admin_notification_centre_page.dart';
import 'package:diamond_tracking/features/admin/reports/presentation/admin_reports_page.dart';
import 'package:diamond_tracking/features/admin/shell/admin_shell.dart';
import 'package:diamond_tracking/features/admin/shell/admin_tab.dart';
import 'package:diamond_tracking/shared/widgets/app_bottom_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_admin_activity.dart';
import 'support/fake_auth.dart';
import 'support/fake_employee_repository.dart';
import 'support/fake_live_locations.dart';
import 'support/fake_notification_repository.dart';

void main() {
  Future<void> pumpShell(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          signedInAdminOverride(),
          // The Home and the live map read the server; the test must not.
          ...liveMapOverrides(
            FakeLiveLocationRepository(),
            FakeEmployeeRepository(),
          ),
          activityOverride(FakeAdminActivityRepository()),
          notificationOverride(FakeNotificationRepository()),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const AdminShell()),
      ),
    );
    await tester.pump();
  }

  group('AdminShell', () {
    testWidgets('opens on Home with a four-item bottom bar', (tester) async {
      await pumpShell(tester);

      expect(find.byType(AdminDashboardPage), findsOneWidget);
      expect(find.byType(AppBottomNavigationBar), findsOneWidget);
      for (final label in const ['home', 'map', 'team', 'reports']) {
        expect(find.byKey(Key('nav-$label')), findsOneWidget);
      }
    });

    testWidgets('builds a tab only when it is first opened', (tester) async {
      await pumpShell(tester);

      expect(find.byType(AdminLiveMapPage, skipOffstage: false), findsNothing);
      expect(find.byType(AdminReportsPage, skipOffstage: false), findsNothing);

      await tester.tap(find.byKey(const Key('nav-map')));
      await tester.pump();

      expect(find.byType(AdminLiveMapPage), findsOneWidget);
      expect(find.byType(AdminReportsPage, skipOffstage: false), findsNothing);
    });

    testWidgets('every tab switches to its own page from any other tab', (
      tester,
    ) async {
      await pumpShell(tester);

      final pages = <String, Type>{
        'map': AdminLiveMapPage,
        'team': AdminEmployeeListPage,
        'reports': AdminReportsPage,
        'home': AdminDashboardPage,
      };

      // Walk every tab, then walk them again in reverse, so each tab is reached
      // from a different starting tab (the old pages had dead taps here).
      for (final label in [...pages.keys, ...pages.keys.toList().reversed]) {
        await tester.tap(find.byKey(Key('nav-$label')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        final onScreen = pages[label]!;
        expect(
          find.byWidgetPredicate((w) => w.runtimeType == onScreen),
          findsOneWidget,
          reason: 'tab $label',
        );
        for (final other in pages.entries.where((e) => e.key != label)) {
          expect(
            find.byWidgetPredicate((w) => w.runtimeType == other.value),
            findsNothing,
            reason: 'tab ${other.key} must be hidden while $label is open',
          );
        }
      }
    });

    testWidgets('a pushed screen covers the bottom bar', (tester) async {
      await pumpShell(tester);

      await tester.tap(find.byKey(const Key('admin-notifications-btn')));
      await tester.pumpAndSettle();

      expect(find.byType(AdminNotificationCentrePage), findsOneWidget);
      expect(find.byType(AppBottomNavigationBar), findsNothing);

      await tester.tap(find.byKey(const Key('btn-notif-back')));
      await tester.pumpAndSettle();

      expect(find.byType(AppBottomNavigationBar), findsOneWidget);
    });

    testWidgets('Home cards switch tabs through the shared provider', (
      tester,
    ) async {
      await pumpShell(tester);

      await tester.tap(find.text('View all'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(AdminLiveMapPage), findsOneWidget);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(AdminShell)),
      );
      expect(container.read(adminTabProvider), AdminTab.map);
    });

    testWidgets('back on another tab returns to Home before leaving the app', (
      tester,
    ) async {
      await pumpShell(tester);

      await tester.tap(find.byKey(const Key('nav-reports')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(AdminReportsPage), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(AdminDashboardPage), findsOneWidget);
      expect(find.byType(AdminReportsPage), findsNothing);
    });
  });
}
