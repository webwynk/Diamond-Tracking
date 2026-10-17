import 'package:diamond_tracking/core/errors/app_exceptions.dart';
import 'package:diamond_tracking/core/theme/app_theme.dart';
import 'package:diamond_tracking/features/admin/employees/presentation/admin_employee_list_page.dart';
import 'package:diamond_tracking/features/admin/employees/presentation/controllers/admin_employee_list_state.dart';
import 'package:diamond_tracking/features/admin/employees/presentation/widgets/admin_employee_search_filter_bar.dart';
import 'package:diamond_tracking/shared/widgets/app_top_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/employee_fixtures.dart';
import 'support/fake_employee_repository.dart';

void main() {
  Widget buildTestableAdminEmployeeListPage({
    ValueChanged<AdminEmployeeItem>? onEmployeeSelected,
    VoidCallback? onCreateEmployee,
    bool seeded = true,
    FakeEmployeeRepository? repository,
  }) {
    return ProviderScope(
      overrides: [
        if (seeded) fixtureEmployeeListOverride,
        fakeEmployeeRepositoryOverride(repository),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: AdminEmployeeListPage(
          onEmployeeSelected: onEmployeeSelected,
          onCreateEmployee: onCreateEmployee,
        ),
      ),
    );
  }

  group('Screen 17 AdminEmployeeListPage Widget Tests', () {
    testWidgets(
      'renders 56 dp brand top bar with Team title and filter badge 1',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(buildTestableAdminEmployeeListPage());
        await tester.pump();

        expect(find.byType(AppTopBar), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(AppTopBar),
            matching: find.text('Team'),
          ),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('btn-employee-filter-tune')),
          findsOneWidget,
        );
        expect(find.text('1'), findsOneWidget); // Filter badge count
      },
    );

    testWidgets(
      'renders pinned search bar, horizontal filter chips, and active-filter strip',
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
        expect(
          find.text(
            'Active ${kFixtureEmployees.where((e) => e.isActive).length}',
          ),
          findsOneWidget,
        );
        expect(
          find.text(
            'On duty ${kFixtureEmployees.where((e) => e.status == AdminEmployeeStatus.onDuty).length}',
          ),
          findsOneWidget,
        );
        expect(
          find.text(
            'Off duty ${kFixtureEmployees.where((e) => e.status == AdminEmployeeStatus.offDuty).length}',
          ),
          findsOneWidget,
        );
        expect(find.text('Blocked 2'), findsOneWidget);
        expect(find.text('Has flags 3'), findsOneWidget);

        // Active Modifier Pill and Counter
        expect(
          find.byKey(const Key('pill-employee-active-only')),
          findsOneWidget,
        );
        expect(find.text('Active only'), findsOneWidget);
        expect(find.text('Clear all'), findsOneWidget);
        expect(find.textContaining('Showing'), findsOneWidget);
      },
    );

    testWidgets(
      'typing in search bar filters roster and clear button resets input',
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
        expect(
          find.byKey(const Key('btn-employee-search-clear')),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const Key('btn-employee-search-clear')));
        await tester.pump();

        expect(find.text('Suresh Patel'), findsOneWidget);
      },
    );

    testWidgets('switching filter chips filters employees by status', (
      tester,
    ) async {
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

    testWidgets(
      'renders all 5 representative status styles matching HTML reference',
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
      },
    );

    testWidgets('tapping employee card triggers onEmployeeSelected callback', (
      tester,
    ) async {
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

    testWidgets('tapping FAB triggers onCreateEmployee onboarding callback', (
      tester,
    ) async {
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

    testWidgets('loads the roster from the repository when the tab opens', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repository = FakeEmployeeRepository(
        roster: const [
          AdminEmployeeItem(
            id: 'real-1',
            name: 'Kiran Deshmukh',
            employeeCode: 'DA-144',
            phoneNumber: '+919822011334',
            status: AdminEmployeeStatus.offDuty,
          ),
        ],
      );
      await tester.pumpWidget(
        buildTestableAdminEmployeeListPage(
          seeded: false,
          repository: repository,
        ),
      );
      await tester.pumpAndSettle();

      expect(repository.calls, <String>['getEmployees']);
      expect(find.text('Kiran Deshmukh'), findsOneWidget);
      expect(find.text('No employees yet'), findsNothing);
    });

    testWidgets(
      'a failed load shows an error with Retry, never "No employees yet"',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final repository = FakeEmployeeRepository(
          error: const NetworkException(),
        );
        await tester.pumpWidget(
          buildTestableAdminEmployeeListPage(
            seeded: false,
            repository: repository,
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('view-employee-list-error')),
          findsOneWidget,
        );
        expect(find.text('No employees yet'), findsNothing);

        // The network comes back; Retry loads the real roster.
        repository
          ..error = null
          ..roster = const [
            AdminEmployeeItem(
              id: 'real-1',
              name: 'Kiran Deshmukh',
              employeeCode: 'DA-144',
              phoneNumber: '+919822011334',
              status: AdminEmployeeStatus.offDuty,
            ),
          ];
        await tester.tap(find.text('Retry'));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('view-employee-list-error')), findsNothing);
        expect(find.text('Kiran Deshmukh'), findsOneWidget);
      },
    );

    testWidgets(
      'starts with no employees: empty state, zero counts, no sample names',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        var created = 0;
        await tester.pumpWidget(
          buildTestableAdminEmployeeListPage(
            seeded: false,
            onCreateEmployee: () => created++,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('No employees yet'), findsOneWidget);
        expect(find.text('Active 0'), findsOneWidget);
        expect(find.text('On duty 0'), findsOneWidget);
        expect(find.text('Showing 0 of 0'), findsOneWidget);
        expect(find.text('Suresh Patel'), findsNothing);
        expect(find.text('No field officers match your search.'), findsNothing);

        await tester.tap(find.text('Add employee'));
        await tester.pump();
        expect(created, 1);
      },
    );

    testWidgets(
      'shows empty state illustration when search matches no employees',
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
      },
    );
  });
}
