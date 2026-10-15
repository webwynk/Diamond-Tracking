import 'package:diamond_tracking/core/theme/app_theme.dart';
import 'package:diamond_tracking/features/admin/map/presentation/admin_live_map_page.dart';
import 'package:diamond_tracking/features/admin/map/presentation/controllers/admin_live_map_state.dart';
import 'package:diamond_tracking/features/admin/map/presentation/widgets/admin_map_filter_chips_bar.dart';
import 'package:diamond_tracking/features/admin/map/presentation/widgets/admin_map_floating_controls.dart';
import 'package:diamond_tracking/features/admin/map/presentation/widgets/admin_map_search_bar.dart';
import 'package:diamond_tracking/features/admin/map/presentation/widgets/admin_map_top_bar.dart';
import 'package:diamond_tracking/features/admin/map/presentation/widgets/admin_map_vector_canvas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildTestableAdminLiveMap({
    VoidCallback? onNavigateToHome,
    VoidCallback? onNavigateToTeam,
    VoidCallback? onNavigateToPlaces,
    VoidCallback? onNavigateToReports,
    VoidCallback? onNavigateToNotifications,
    ValueChanged<MapOfficerItem>? onOfficerSelected,
  }) {
    return ProviderScope(
      child: MaterialApp(
        theme: AppTheme.light,
        home: AdminLiveMapPage(
          onNavigateToHome: onNavigateToHome,
          onNavigateToTeam: onNavigateToTeam,
          onNavigateToPlaces: onNavigateToPlaces,
          onNavigateToReports: onNavigateToReports,
          onNavigateToNotifications: onNavigateToNotifications,
          onOfficerSelected: onOfficerSelected,
        ),
      ),
    );
  }

  group('Screen 15 AdminLiveMapPage Widget Tests', () {
    testWidgets('renders top header with branding, title, search, and notifications',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      bool notified = false;
      await tester.pumpWidget(
        buildTestableAdminLiveMap(
          onNavigateToNotifications: () => notified = true,
        ),
      );
      await tester.pump();

      expect(find.byType(AdminMapTopBar), findsOneWidget);
      expect(find.text('DIAMOND AGRITECH'), findsOneWidget);
      expect(find.text('Live Map Telemetry'), findsOneWidget);

      // Tap notifications action
      await tester.tap(find.byKey(const Key('btn-telemetry-notifications-action')));
      await tester.pump();
      expect(notified, isTrue);
    });

    testWidgets('renders floating search bar and all 6 status filter chips with counts',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestableAdminLiveMap());
      await tester.pump();

      expect(find.byType(AdminMapSearchBar), findsOneWidget);
      expect(find.text('Search name or ID'), findsOneWidget);
      expect(find.text('2'), findsOneWidget); // Filter tune badge

      // 6 Status Filter Chips
      expect(find.byType(AdminMapFilterChipsBar), findsOneWidget);
      expect(find.text('All 143'), findsOneWidget);
      expect(find.text('On duty 112'), findsOneWidget);
      expect(find.text('Stale 4'), findsOneWidget);
      expect(find.text('Check 3'), findsOneWidget);
      expect(find.text('Off 31'), findsOneWidget);
      expect(find.text('Blocked 2'), findsOneWidget);
    });

    testWidgets('renders cluster bubbles and individual markers including SOS alert',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestableAdminLiveMap());
      await tester.pump();

      expect(find.byType(AdminMapVectorCanvas), findsOneWidget);

      // 4 Cluster Bubbles: 34, 21, 12, 6
      expect(find.text('34'), findsOneWidget);
      expect(find.text('21'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      expect(find.text('6'), findsOneWidget);

      // SOS Critical Officer
      expect(find.text('SOS • R. SHINDE'), findsOneWidget);
      expect(find.byKey(const Key('marker-officer-officer-sos-1')), findsOneWidget);
    });

    testWidgets('selecting status filter chip filters officers and clusters',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestableAdminLiveMap());
      await tester.pump();

      // Tap Check 3 filter chip
      final checkChip = find.text('Check 3');
      await tester.ensureVisible(checkChip);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(checkChip);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Clusters should be hidden in Check filter mode
      expect(find.text('34'), findsNothing);
      expect(find.text('21'), findsNothing);

      // SOS marker remains visible
      expect(find.text('SOS • R. SHINDE'), findsOneWidget);

      // Tap All 143 filter chip to restore
      final allChip = find.text('All 143');
      await tester.ensureVisible(allChip);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(allChip);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('34'), findsOneWidget);
    });

    testWidgets('typing in search bar filters officers and hides clusters',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestableAdminLiveMap());
      await tester.pump();

      // Enter search term "Vijay"
      await tester.enterText(
        find.byKey(const Key('input-admin-map-search')),
        'Vijay',
      );
      await tester.pump();

      // Clusters should be hidden while searching
      expect(find.text('34'), findsNothing);

      // Clear search
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();
      expect(find.text('34'), findsOneWidget);
    });

    testWidgets('tapping officer marker presents preview card with details and triggers callback',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      MapOfficerItem? selectedOfficer;
      await tester.pumpWidget(
        buildTestableAdminLiveMap(
          onOfficerSelected: (officer) => selectedOfficer = officer,
        ),
      );
      await tester.pump();

      // Tap SOS officer marker
      await tester.tap(find.byKey(const Key('marker-officer-officer-sos-1')));
      await tester.pump();

      // Preview card details
      expect(find.text('R. Shinde'), findsOneWidget);
      expect(find.text('DA-003 · Dindori Road Border'), findsOneWidget);
      expect(find.text('14%'), findsOneWidget);
      expect(find.text('View Detail'), findsOneWidget);
      expect(selectedOfficer?.id, 'officer-sos-1');

      // Tap View Detail button
      await tester.tap(find.byKey(const Key('btn-view-officer-detail')));
      await tester.pump();
    });

    testWidgets('tapping cluster bubble displays deployment feedback snackbar',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestableAdminLiveMap());
      await tester.pump();

      // Tap Niphad Cluster (34)
      await tester.tap(find.text('34'));
      await tester.pump();

      expect(
        find.text('Niphad Onion & Grape Zone: 34 officers deployed in cluster.'),
        findsOneWidget,
      );
    });

    testWidgets('floating map controls re-center, toggle layer, and toggle list view',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      bool teamNavigated = false;
      await tester.pumpWidget(
        buildTestableAdminLiveMap(
          onNavigateToTeam: () => teamNavigated = true,
        ),
      );
      await tester.pump();

      expect(find.byType(AdminMapFloatingControls), findsOneWidget);
      expect(find.text('Live'), findsOneWidget);
      expect(find.text('Mapbox © OpenStreetMap'), findsOneWidget);

      // Tap Layers Toggle
      await tester.tap(find.byKey(const Key('btn-admin-map-layers')));
      await tester.pump();
      expect(find.text('Switched to Satellite Imagery.'), findsOneWidget);

      // Tap Recenter GPS
      await tester.tap(find.byKey(const Key('btn-admin-map-recenter')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Map bounds re-centered to Nashik Basin.'), findsOneWidget);

      // Tap List-view alternative
      await tester.tap(find.byKey(const Key('btn-admin-map-list-view')));
      await tester.pump();
      expect(teamNavigated, isTrue);
    });

    testWidgets('bottom navigation has Map active and responds to Home tap',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      bool homeNavigated = false;
      await tester.pumpWidget(
        buildTestableAdminLiveMap(
          onNavigateToHome: () => homeNavigated = true,
        ),
      );
      await tester.pump();

      // Tap Home in bottom nav
      await tester.tap(find.text('Home'));
      await tester.pump();
      expect(homeNavigated, isTrue);
    });
  });
}
