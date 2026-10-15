import 'package:diamond_tracking/core/theme/app_theme.dart';
import 'package:diamond_tracking/features/admin/employees/presentation/admin_employee_list_page.dart';
import 'package:diamond_tracking/features/admin/employees/presentation/controllers/admin_employee_list_state.dart';
import 'package:diamond_tracking/features/admin/employees/presentation/widgets/admin_employee_search_filter_bar.dart';
import 'package:diamond_tracking/features/admin/employees/presentation/widgets/admin_employee_top_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildTestableAdminEmployeeListPage({
    ValueChanged<AdminEmployeeItem>? onEmployeeSelected,
    VoidCallback? onCreateEmployee,
    VoidCallback? onNavigateToHome,
    VoidCallback? onNavigateToMap,
    VoidCallback? onNavigateToPlaces,
    VoidCallback? onNavigateToReports,
  }) {
    return ProviderScope(
      child: MaterialApp(
        theme: AppTheme.light,
        home: AdminEmployeeListPage(
          onEmployeeSelected: onEmployeeSelected,
          onCreateEmployee: onCreateEmployee,
          onNavigateToHome: onNavigateToHome,
          onNavigateToMap: onNavigateToMap,
          onNavigateToPlaces: onNavigateToPlaces,
          onNavigateToReports: onNavigateToReports,
        ),
      ),
    );
  }

  group('Screen 17 AdminEmployeeListPage Widget Tests', () {
    testWidgets('renders white 56 dp top bar with Team title and filter badge 1',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestableAdminEmployeeListPage());
      await tester.pump();

      expect(find.byType(AdminEmployeeTopBar), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AdminEmployeeTopBar),
          matching: find.text('Team'),
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('btn-employee-filter-tune')), findsOneWidget);
      expect(find.text('1'), findsOneWidget); // Filter badge count
    });

    testWidgets('renders pinned search bar, horizontal filter chips, and active-filter strip',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestableAdminEmployeeListPage());
      await tester.pump();

      expect(find.byType(AdminEmployeeSearchFilterBar), findsOneWidget);
      expect(find.byKey(const Key('input-employee-search')), findsOneWidget);
      expect(find.text('Search field officers'), findsOneWidget);

      // 5 Filter Chips
      expect(find.text('Active 141'), findsOneWidget);
      expect(find.text('On duty 112'), findsOneWidget);
      expect(find.text('Off duty 31'), findsOneWidget);
      expect(find.text('Blocked 2'), findsOneWidget);
      expect(find.text('Has flags 3'), findsOneWidget);

      // Active Modifier Pill and Counter
      expect(find.byKey(const Key('pill-employee-active-only')), findsOneWidget);
      expect(find.text('Active only'), findsOneWidget);
      expect(find.text('Clear all'), findsOneWidget);
      expect(find.textContaining('Showing'), findsOneWidget);
    });

    testWidgets('typing in search bar filters roster and clear button resets input',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestableAdminEmployeeListPage());
      await tester.pump();

      // Suresh Patel is visible initially
      expect(find.text('Suresh Patel'), findsOneWidget);

      // Search for "Sharma"
      await tester.enterText(
        find.byKey(const Key('input-employee-search')),
        'Sharma',
      );
      await tester.pump();

      expect(find.text('Anil Sharma'), findsOneWidget);
      expect(find.text('Suresh Patel'), findsNothing);

      // Clear search with clear button
      expect(find.byKey(const Key('btn-employee-search-clear')), findsOneWidget);
      await tester.tap(find.byKey(const Key('btn-employee-search-clear')));
      await tester.pump();

      expect(find.text('Suresh Patel'), findsOneWidget);
    });

    testWidgets('switching filter chips filters employees by status',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestableAdminEmployeeListPage());
      await tester.pump();

      // Tap "Off duty 31" chip
      await tester.tap(find.byKey(const Key('chip-employee-filter-offduty')));
      await tester.pump();

      expect(find.text('Meena Kulkarni'), findsOneWidget);
      expect(find.text('Suresh Patel'), findsNothing);

      // Tap "Blocked 2" chip (use ensureVisible before tapping)
      await tester.ensureVisible(
        find.byKey(const Key('chip-employee-filter-blocked')),
      );
      await tester.tap(find.byKey(const Key('chip-employee-filter-blocked')));
      await tester.pump();

      expect(find.text('Dinesh Joshi'), findsOneWidget);
      expect(find.text('Meena Kulkarni'), findsNothing);
    });

    testWidgets('renders all 5 representative status styles matching HTML reference',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestableAdminEmployeeListPage());
      await tester.pump();

      // Remove active-only to show all 5 including blocked
      await tester.tap(find.byKey(const Key('btn-remove-active-only')));
      await tester.pump();

      // 1. Suresh Patel — On duty
      expect(find.text('SP'), findsOneWidget);
      expect(find.text('Suresh Patel'), findsOneWidget);
      expect(find.text('DA-022 · +91 98201 44556'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('card-employee-emp-1')),
          matching: find.text('On duty'),
        ),
        findsOneWidget,
      );

      // 2. Anil Sharma — Check needed
      expect(find.text('AS'), findsOneWidget);
      expect(find.text('Anil Sharma'), findsOneWidget);
      expect(find.text('DA-008 · +91 98332 11094'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('card-employee-emp-2')),
          matching: find.text('Check needed'),
        ),
        findsOneWidget,
      );

      // 3. Prakash Rao — No update
      expect(find.text('PR'), findsOneWidget);
      expect(find.text('Prakash Rao'), findsOneWidget);
      expect(find.text('DA-017 · +91 97123 88412'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('card-employee-emp-3')),
          matching: find.text('No update'),
        ),
        findsOneWidget,
      );

      // 4. Meena Kulkarni — Off duty
      expect(find.text('MK'), findsOneWidget);
      expect(find.text('Meena Kulkarni'), findsOneWidget);
      expect(find.text('DA-045 · +91 98450 67231'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('card-employee-emp-4')),
          matching: find.text('Off duty'),
        ),
        findsOneWidget,
      );

      // 5. Dinesh Joshi — Blocked
      expect(find.text('DJ'), findsOneWidget);
      expect(find.text('Dinesh Joshi'), findsOneWidget);
      expect(find.text('DA-099 · +91 98210 55432'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('card-employee-emp-5')),
          matching: find.text('Blocked'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('tapping employee card triggers onEmployeeSelected callback',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      AdminEmployeeItem? selected;
      await tester.pumpWidget(
        buildTestableAdminEmployeeListPage(
          onEmployeeSelected: (emp) => selected = emp,
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('card-employee-emp-1')));
      await tester.pump();

      expect(selected?.id, 'emp-1');
      expect(selected?.name, 'Suresh Patel');
    });

    testWidgets('tapping FAB triggers onCreateEmployee onboarding callback',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      bool createTapped = false;
      await tester.pumpWidget(
        buildTestableAdminEmployeeListPage(
          onCreateEmployee: () => createTapped = true,
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('fab-add-employee')), findsOneWidget);
      await tester.tap(find.byKey(const Key('fab-add-employee')));
      await tester.pump();

      expect(createTapped, isTrue);
    });

    testWidgets('bottom navigation has Team active and handles tab switches',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      bool homeNavigated = false;
      bool mapNavigated = false;

      await tester.pumpWidget(
        buildTestableAdminEmployeeListPage(
          onNavigateToHome: () => homeNavigated = true,
          onNavigateToMap: () => mapNavigated = true,
        ),
      );
      await tester.pump();

      // Tap Home
      await tester.tap(find.byKey(const Key('admin-nav-home')));
      await tester.pump();
      expect(homeNavigated, isTrue);

      // Tap Map
      await tester.tap(find.byKey(const Key('admin-nav-map')));
      await tester.pump();
      expect(mapNavigated, isTrue);
    });

    testWidgets('shows empty state illustration when search matches no employees',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestableAdminEmployeeListPage());
      await tester.pump();

      // Enter nonsense search
      await tester.enterText(
        find.byKey(const Key('input-employee-search')),
        'NonExistentStaffMember999',
      );
      await tester.pump();

      expect(
        find.text('No field officers match your search.'),
        findsOneWidget,
      );
      expect(
        find.text('Try adjusting your search terms or filter criteria.'),
        findsOneWidget,
      );
    });
  });
}
