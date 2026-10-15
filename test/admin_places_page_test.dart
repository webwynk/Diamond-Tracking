import 'package:diamond_tracking/core/theme/app_theme.dart';
import 'package:diamond_tracking/features/admin/dashboard/presentation/admin_dashboard_page.dart';
import 'package:diamond_tracking/features/admin/dashboard/presentation/widgets/admin_bottom_navigation.dart';
import 'package:diamond_tracking/features/admin/places/presentation/admin_places_page.dart';
import 'package:diamond_tracking/features/admin/places/presentation/controllers/admin_places_controller.dart';
import 'package:diamond_tracking/features/admin/places/presentation/controllers/admin_places_state.dart';
import 'package:diamond_tracking/features/admin/places/presentation/widgets/admin_place_card.dart';
import 'package:diamond_tracking/features/admin/places/presentation/widgets/admin_places_filter_chips.dart';
import 'package:diamond_tracking/features/admin/places/presentation/widgets/admin_places_search_bar.dart';
import 'package:diamond_tracking/features/admin/places/presentation/widgets/admin_places_telemetry_banner.dart';
import 'package:diamond_tracking/features/admin/places/presentation/widgets/admin_places_top_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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

  group('Screen 24 AdminPlacesPage Visual & Structural Tests', () {
    testWidgets('renders all visual elements matching HTML design reference', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildTestableWidget(const AdminPlacesPage()),
      );
      await tester.pumpAndSettle();

      // 1. Top App Bar
      expect(find.byType(AdminPlacesTopBar), findsOneWidget);
      expect(find.text('Places'), findsWidgets);
      expect(find.text('38 ACTIVE'), findsOneWidget);
      expect(find.byKey(const Key('btn-places-filter')), findsOneWidget);
      expect(find.byKey(const Key('btn-places-export')), findsOneWidget);

      // 2. Search Field
      expect(find.byType(AdminPlacesSearchBar), findsOneWidget);
      expect(find.byKey(const Key('input-places-search')), findsOneWidget);
      expect(
        find.text('Search places (name, taluka, radius)...'),
        findsOneWidget,
      );

      // 3. Category Filter Chips
      expect(find.byType(AdminPlacesFilterChips), findsOneWidget);
      expect(find.byKey(const Key('chip-place-all')), findsOneWidget);
      expect(find.byKey(const Key('chip-place-farms')), findsOneWidget);
      expect(find.byKey(const Key('chip-place-dealers')), findsOneWidget);
      expect(find.byKey(const Key('chip-place-offices')), findsOneWidget);
      expect(find.byKey(const Key('chip-place-warehouses')), findsOneWidget);
      expect(find.byKey(const Key('chip-place-inactive')), findsOneWidget);

      // 4. RTK Telemetry Banner
      expect(find.byType(AdminPlacesTelemetryBanner), findsOneWidget);
      expect(
        find.text('POLYGON GEOFENCE GRID · RTK SYNCED'),
        findsOneWidget,
      );
      expect(find.text('accuracy ±1.8m'), findsOneWidget);

      // 5. Places List Cards (All 5 items)
      expect(find.byType(AdminPlaceCard), findsNWidgets(5));
      expect(find.text('Shivpuri Farm'), findsOneWidget);
      expect(find.text('BIO'), findsOneWidget);
      expect(find.text('500 m radius · Nashik, Maharashtra'), findsOneWidget);
      expect(find.text('14 visits this month'), findsOneWidget);

      expect(find.text('Patel Agro Dealer'), findsOneWidget);
      expect(find.text('TIER 1'), findsOneWidget);
      expect(find.text('500 m radius · Sinnar, Maharashtra'), findsOneWidget);
      expect(find.text('9 visits this month'), findsOneWidget);

      expect(find.text('Head Office'), findsOneWidget);
      expect(find.text('HQ'), findsOneWidget);
      expect(find.text('200 m radius · Nashik, Maharashtra'), findsOneWidget);
      expect(find.text('41 visits this month'), findsOneWidget);

      expect(find.text('Igatpuri Warehouse'), findsOneWidget);
      expect(find.text('STOCK'), findsOneWidget);
      expect(find.text('800 m radius · Igatpuri, Maharashtra'), findsOneWidget);
      expect(find.text('6 visits this month'), findsOneWidget);

      expect(find.text('Old Deolali Farm'), findsOneWidget);
      expect(find.text('Inactive'), findsWidgets);
      expect(find.text('500 m radius · Deolali, Maharashtra'), findsOneWidget);
      expect(find.text('0 visits this month'), findsOneWidget);

      // 6. Field Agronomy Helper Banner
      expect(find.text('Need a custom perimeter?'), findsOneWidget);

      // 7. Floating Action Button
      expect(find.byKey(const Key('btn-add-place')), findsOneWidget);

      // 8. Admin Bottom Navigation Bar with "Places" active
      expect(find.byType(AdminBottomNavigationBar), findsOneWidget);
    });

    testWidgets('search bar filters places by name and location', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildTestableWidget(const AdminPlacesPage()),
      );
      await tester.pumpAndSettle();

      // Enter search query "Sinnar"
      await tester.enterText(
        find.byKey(const Key('input-places-search')),
        'Sinnar',
      );
      await tester.pumpAndSettle();

      // Only Patel Agro Dealer is shown
      expect(find.byType(AdminPlaceCard), findsOneWidget);
      expect(find.text('Patel Agro Dealer'), findsOneWidget);
      expect(find.text('Shivpuri Farm'), findsNothing);

      // Tap clear search button
      await tester.tap(find.byKey(const Key('btn-clear-places-search')));
      await tester.pumpAndSettle();

      // All 5 cards restored
      expect(find.byType(AdminPlaceCard), findsNWidgets(5));
    });

    testWidgets('category chips filter places accurately', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        buildTestableWidget(
          const AdminPlacesPage(),
          container: container,
        ),
      );
      await tester.pumpAndSettle();

      // Tap "Dealers" chip
      await tester.tap(find.byKey(const Key('chip-place-dealers')));
      await tester.pumpAndSettle();

      expect(
        container.read(adminPlacesControllerProvider).selectedCategory,
        AdminPlaceCategory.dealers,
      );
      expect(find.byType(AdminPlaceCard), findsOneWidget);
      expect(find.text('Patel Agro Dealer'), findsOneWidget);
      expect(find.text('Shivpuri Farm'), findsNothing);

      // Tap "Offices" chip
      await tester.tap(find.byKey(const Key('chip-place-offices')));
      await tester.pumpAndSettle();

      expect(
        container.read(adminPlacesControllerProvider).selectedCategory,
        AdminPlaceCategory.offices,
      );
      expect(find.byType(AdminPlaceCard), findsOneWidget);
      expect(find.text('Head Office'), findsOneWidget);

      // Tap "Inactive" chip
      await tester.ensureVisible(find.byKey(const Key('chip-place-inactive')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('chip-place-inactive')));
      await tester.pumpAndSettle();

      expect(
        container.read(adminPlacesControllerProvider).selectedCategory,
        AdminPlaceCategory.inactive,
      );
      expect(find.byType(AdminPlaceCard), findsOneWidget);
      expect(find.text('Old Deolali Farm'), findsOneWidget);

      // Tap "All" chip
      await tester.ensureVisible(find.byKey(const Key('chip-place-all')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('chip-place-all')));
      await tester.pumpAndSettle();

      expect(find.byType(AdminPlaceCard), findsNWidgets(5));
    });

    testWidgets('empty search state appears and reset button restores places', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        buildTestableWidget(
          const AdminPlacesPage(),
          container: container,
        ),
      );
      await tester.pumpAndSettle();

      // Enter search term with 0 matches
      await tester.enterText(
        find.byKey(const Key('input-places-search')),
        'Nonexistent Geofence',
      );
      await tester.pumpAndSettle();

      // Empty State displays
      expect(find.byType(AdminPlaceCard), findsNothing);
      expect(find.text('No matching geofences'), findsOneWidget);
      expect(find.byKey(const Key('btn-reset-places-filter')), findsOneWidget);

      // Tap Reset button
      await tester.tap(find.byKey(const Key('btn-reset-places-filter')));
      await tester.pumpAndSettle();

      // All places restored
      expect(find.byType(AdminPlaceCard), findsNWidgets(5));
    });

    testWidgets('AdminDashboardPage places bottom nav tab navigates to AdminPlacesPage',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildTestableWidget(const AdminDashboardPage()),
      );
      await tester.pumpAndSettle();

      // Tap Places navigation item
      await tester.tap(find.byKey(const Key('admin-nav-places')));
      await tester.pumpAndSettle();

      // AdminPlacesPage is displayed
      expect(find.byType(AdminPlacesPage), findsOneWidget);
      expect(find.text('38 ACTIVE'), findsOneWidget);
    });
  });
}
