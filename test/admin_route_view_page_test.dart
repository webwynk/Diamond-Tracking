import 'package:diamond_tracking/core/theme/app_theme.dart';
import 'package:diamond_tracking/features/admin/employees/presentation/admin_employee_detail_page.dart';
import 'package:diamond_tracking/features/admin/employees/presentation/controllers/admin_employee_list_state.dart';
import 'package:diamond_tracking/features/admin/employees/presentation/widgets/admin_employee_quick_actions.dart';
import 'package:diamond_tracking/features/admin/route_view/presentation/admin_route_view_page.dart';
import 'package:diamond_tracking/features/admin/route_view/presentation/controllers/admin_route_view_controller.dart';
import 'package:diamond_tracking/features/admin/route_view/presentation/widgets/admin_route_date_pill.dart';
import 'package:diamond_tracking/features/admin/route_view/presentation/widgets/admin_route_floating_app_bar.dart';
import 'package:diamond_tracking/features/admin/route_view/presentation/widgets/admin_route_map_view.dart';
import 'package:diamond_tracking/features/admin/route_view/presentation/widgets/admin_route_summary_sheet.dart';
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

  group('Screen 23 AdminRouteViewPage Visual & Structural Tests', () {
    testWidgets('renders all visual elements matching HTML design reference', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildTestableWidget(const AdminRouteViewPage()),
      );
      await tester.pumpAndSettle();

      // 1. Floating Top App Bar
      expect(find.byType(AdminRouteFloatingAppBar), findsOneWidget);
      expect(find.text('Route'), findsOneWidget);
      expect(find.text('Suresh Patel · Sat, 11 Oct'), findsOneWidget);
      expect(find.byKey(const Key('btn-route-back')), findsOneWidget);
      expect(find.byKey(const Key('btn-route-share')), findsOneWidget);

      // 2. Centered Date Selector Pill
      expect(find.byType(AdminRouteDatePill), findsOneWidget);
      expect(find.text('Sat, 11 Oct'), findsWidgets);
      expect(find.byKey(const Key('btn-route-prev-date')), findsOneWidget);
      expect(find.byKey(const Key('btn-route-next-date')), findsOneWidget);

      // 3. Map View & Waypoints
      expect(find.byType(AdminRouteMapView), findsOneWidget);
      expect(find.text('© OpenStreetMap contributors'), findsOneWidget);
      expect(find.byKey(const Key('btn-map-fit-route')), findsOneWidget);
      expect(find.byKey(const Key('btn-map-layers')), findsOneWidget);

      // Markers (Start, Stop, Visits 1-5, Flag, End)
      expect(find.byKey(const Key('marker-wp-start')), findsOneWidget);
      expect(find.byKey(const Key('marker-wp-end')), findsOneWidget);
      expect(find.byKey(const Key('marker-wp-visit-1')), findsOneWidget);
      expect(find.byKey(const Key('marker-wp-visit-2')), findsOneWidget);
      expect(find.byKey(const Key('marker-wp-visit-3')), findsOneWidget);
      expect(find.byKey(const Key('marker-wp-visit-4')), findsOneWidget);
      expect(find.byKey(const Key('marker-wp-visit-5')), findsOneWidget);
      expect(find.byKey(const Key('marker-wp-stop-1')), findsOneWidget);
      expect(find.byKey(const Key('marker-wp-stop-2')), findsOneWidget);
      expect(find.byKey(const Key('marker-wp-flag-1')), findsOneWidget);

      // 4. Lower 38% Telemetry Audit Summary Sheet
      expect(find.byType(AdminRouteSummarySheet), findsOneWidget);

      // 4 Stat Blocks
      expect(find.text('47.3 km'), findsOneWidget);
      expect(find.text('Distance'), findsOneWidget);
      expect(find.text('8h 08m'), findsOneWidget);
      expect(find.text('Duty hours'), findsOneWidget);
      expect(find.text('5'), findsWidgets);
      expect(find.text('Visits'), findsOneWidget);
      expect(find.text('1'), findsWidgets);
      expect(find.text('Flag'), findsOneWidget);

      // Inline Metadata Row
      expect(find.text('8:04 AM – 6:12 PM'), findsOneWidget);
      expect(find.text('2 long stops'), findsOneWidget);

      // Red Flag Alert Strip
      expect(
        find.text('1 flagged point excluded from distance'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('btn-route-view-flag')), findsOneWidget);

      // "View visits" Action Button
      expect(find.byKey(const Key('btn-route-view-visits')), findsOneWidget);
      expect(find.text('View visits'), findsOneWidget);
    });

    testWidgets('date selector pill navigates between dates', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        buildTestableWidget(
          const AdminRouteViewPage(),
          container: container,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        container.read(adminRouteViewControllerProvider).selectedDateText,
        'Sat, 11 Oct',
      );

      // Tap Previous Date Chevron
      await tester.tap(find.byKey(const Key('btn-route-prev-date')));
      await tester.pumpAndSettle();

      expect(
        container.read(adminRouteViewControllerProvider).selectedDateText,
        'Fri, 10 Oct',
      );
      expect(find.text('Fri, 10 Oct'), findsWidgets);

      // Tap Next Date Chevron
      await tester.tap(find.byKey(const Key('btn-route-next-date')));
      await tester.pumpAndSettle();

      expect(
        container.read(adminRouteViewControllerProvider).selectedDateText,
        'Sat, 11 Oct',
      );
    });

    testWidgets('tapping flagged anomaly View link opens anomaly audit dialog', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildTestableWidget(const AdminRouteViewPage()),
      );
      await tester.pumpAndSettle();

      // Tap "View" on the flagged point alert strip
      await tester.tap(find.byKey(const Key('btn-route-view-flag')));
      await tester.pumpAndSettle();

      // Dialog opens
      expect(find.text('Flagged Telemetry Anomaly'), findsOneWidget);
      expect(
        find.textContaining('GPS Jump / Mock Provider'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Location coordinate leaped 8.4 km in 2 seconds'),
        findsOneWidget,
      );

      // Close Dialog
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      expect(find.text('Flagged Telemetry Anomaly'), findsNothing);
    });

    testWidgets('tapping View visits button opens visits bottom sheet', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildTestableWidget(const AdminRouteViewPage()),
      );
      await tester.pumpAndSettle();

      // Tap "View visits" button
      await tester.tap(find.byKey(const Key('btn-route-view-visits')));
      await tester.pumpAndSettle();

      // Modal Bottom Sheet displays all 5 visits
      expect(find.text('Recorded Visits (5)'), findsOneWidget);
      expect(find.text('Shinde Orchards'), findsOneWidget);
      expect(find.text('Kisan Agro Hub'), findsOneWidget);
      expect(find.text('Shivpuri Farm'), findsOneWidget);
      expect(find.text('Someshwar Krishi Seva'), findsOneWidget);
      expect(find.text('Gangapur Cooperative'), findsOneWidget);
    });

    testWidgets('tapping map controls toggles layers and fit route', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        buildTestableWidget(
          const AdminRouteViewPage(),
          container: container,
        ),
      );
      await tester.pumpAndSettle();

      // Tap Layers Button
      await tester.tap(find.byKey(const Key('btn-map-layers')));
      await tester.pump();

      expect(
        find.text('Satellite imagery basemap enabled.'),
        findsOneWidget,
      );

      // Tap Fit Route Button
      await tester.tap(find.byKey(const Key('btn-map-fit-route')));
      await tester.pump();

      expect(
        find.text('Route centered to full 47.3 km corridor.'),
        findsOneWidget,
      );
    });

    testWidgets('AdminEmployeeDetailPage quick action Route view opens AdminRouteViewPage',
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
      await tester.pumpAndSettle();

      // Verify Quick Action "Route view" is present
      expect(find.byType(AdminEmployeeQuickActions), findsOneWidget);
      expect(find.text('Route view'), findsOneWidget);

      // Tap "Route view"
      await tester.tap(find.text('Route view'));
      await tester.pumpAndSettle();

      // AdminRouteViewPage opens
      expect(find.byType(AdminRouteViewPage), findsOneWidget);
      expect(find.text('Route'), findsOneWidget);
      expect(find.text('Suresh Patel · Sat, 11 Oct'), findsOneWidget);
    });
  });
}
