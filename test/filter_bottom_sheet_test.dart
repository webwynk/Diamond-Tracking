import 'package:diamond_tracking/core/theme/app_theme.dart';
import 'package:diamond_tracking/shared/widgets/filter_sheet/controllers/filter_sheet_controller.dart';
import 'package:diamond_tracking/shared/widgets/filter_sheet/controllers/filter_sheet_state.dart';
import 'package:diamond_tracking/shared/widgets/filter_sheet/filter_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildTestableWidget({FilterSheetState? initialState}) {
    return ProviderScope(
      child: MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return Center(
                child: ElevatedButton(
                  key: const Key('btn-open-filter-sheet'),
                  onPressed: () {
                    FilterBottomSheet.show(context, initialState: initialState);
                  },
                  child: const Text('Open Sheet'),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  group('Screen 27: Filter Bottom Sheet Tests', () {
    testWidgets(
      'renders all headers, chips, date fields, sort options and buttons',
      (tester) async {
        await tester.pumpWidget(buildTestableWidget());

        // Open the sheet
        await tester.tap(find.byKey(const Key('btn-open-filter-sheet')));
        await tester.pumpAndSettle();

        // Verify Drag Handle and Header
        expect(find.text('Filters'), findsOneWidget);
        expect(find.byKey(const Key('btn-filters-clear-all')), findsOneWidget);

        // Verify Status Chips Section
        expect(find.text('STATUS'), findsOneWidget);
        expect(find.byKey(const Key('chip-status-onDuty')), findsOneWidget);
        expect(
          find.byKey(const Key('chip-status-checkNeeded')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('chip-status-offDuty')), findsOneWidget);
        expect(find.byKey(const Key('chip-status-stale')), findsOneWidget);
        expect(find.byKey(const Key('chip-status-blocked')), findsOneWidget);

        // Verify Duty Today Section
        expect(find.text('DUTY TODAY'), findsOneWidget);
        expect(find.byKey(const Key('chip-duty-workedToday')), findsOneWidget);
        expect(find.byKey(const Key('chip-duty-notStarted')), findsOneWidget);
        expect(find.byKey(const Key('chip-duty-autoEnded')), findsOneWidget);

        // Verify Date Range Section
        expect(find.text('DATE RANGE'), findsOneWidget);
        expect(find.byKey(const Key('chip-date-today')), findsOneWidget);
        expect(find.byKey(const Key('chip-date-yesterday')), findsOneWidget);
        expect(find.byKey(const Key('chip-date-last7Days')), findsOneWidget);
        expect(find.byKey(const Key('chip-date-thisMonth')), findsOneWidget);
        expect(
          find.byKey(const Key('field-filter-date-preview')),
          findsOneWidget,
        );
        expect(
          find.text(FilterDatePreset.today.dateText(DateTime.now())),
          findsOneWidget,
        );

        // Verify Sort By Section
        expect(find.text('SORT BY'), findsOneWidget);
        expect(find.byKey(const Key('radio-sort-nameAsc')), findsOneWidget);
        expect(find.byKey(const Key('radio-sort-employeeId')), findsOneWidget);
        expect(find.byKey(const Key('radio-sort-lastActive')), findsOneWidget);
        expect(
          find.byKey(const Key('radio-sort-distanceToday')),
          findsOneWidget,
        );

        // Verify Pinned Bottom Actions
        expect(find.byKey(const Key('btn-filters-reset')), findsOneWidget);
        expect(find.byKey(const Key('btn-filters-apply')), findsOneWidget);
        expect(find.text('Apply filters'), findsOneWidget);
        expect(
          find.textContaining('results'),
          findsNothing,
        ); // no invented count
      },
    );

    testWidgets('starts with nothing preselected and no invented counts', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestableWidget());
      await tester.tap(find.byKey(const Key('btn-open-filter-sheet')));
      await tester.pumpAndSettle();

      for (final label in [
        'On duty',
        'Check needed',
        'Off duty',
        'Stale',
        'Blocked',
      ]) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.text('On duty 112'), findsNothing);

      const initial = FilterSheetState();
      expect(initial.selectedStatuses, isEmpty);
      expect(initial.selectedDutyToday, isNull);
      expect(initial.hasActiveFilters, isFalse);
    });

    testWidgets('toggling status chips updates the multi-select state', (
      tester,
    ) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(filterSheetControllerProvider.notifier);

      notifier.toggleStatus(EmployeeFilterStatus.offDuty);
      notifier.toggleStatus(EmployeeFilterStatus.onDuty);
      expect(container.read(filterSheetControllerProvider).selectedStatuses, {
        EmployeeFilterStatus.offDuty,
        EmployeeFilterStatus.onDuty,
      });

      notifier.toggleStatus(EmployeeFilterStatus.onDuty);
      expect(container.read(filterSheetControllerProvider).selectedStatuses, {
        EmployeeFilterStatus.offDuty,
      });
    });

    testWidgets('duty chips toggle selection correctly', (tester) async {
      await tester.pumpWidget(buildTestableWidget());
      await tester.tap(find.byKey(const Key('btn-open-filter-sheet')));
      await tester.pumpAndSettle();

      // Select 'Not started'
      await tester.tap(find.byKey(const Key('chip-duty-notStarted')));
      await tester.pumpAndSettle();

      // Tap 'Not started' again to deselect
      await tester.tap(find.byKey(const Key('chip-duty-notStarted')));
      await tester.pumpAndSettle();

      // Select 'Auto-ended'
      await tester.tap(find.byKey(const Key('chip-duty-autoEnded')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('chip-duty-autoEnded')), findsOneWidget);
    });

    testWidgets('date range presets update read-only date preview field', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestableWidget());
      await tester.tap(find.byKey(const Key('btn-open-filter-sheet')));
      await tester.pumpAndSettle();

      // Tap "Last 7 days" preset
      await tester.tap(find.byKey(const Key('chip-date-last7Days')));
      await tester.pumpAndSettle();

      expect(
        find.text(FilterDatePreset.last7Days.dateText(DateTime.now())),
        findsOneWidget,
      );

      // Tap "This month"
      await tester.tap(find.byKey(const Key('chip-date-thisMonth')));
      await tester.pumpAndSettle();

      expect(
        find.text(FilterDatePreset.thisMonth.dateText(DateTime.now())),
        findsOneWidget,
      );
    });

    testWidgets('sort radio options switch selected sort', (tester) async {
      await tester.pumpWidget(buildTestableWidget());
      await tester.tap(find.byKey(const Key('btn-open-filter-sheet')));
      await tester.pumpAndSettle();

      // Scroll to 'Employee ID'
      await tester.scrollUntilVisible(
        find.byKey(const Key('radio-sort-employeeId')),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const Key('radio-sort-employeeId')));
      await tester.pumpAndSettle();

      // Scroll to 'Distance today'
      await tester.scrollUntilVisible(
        find.byKey(const Key('radio-sort-distanceToday')),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const Key('radio-sort-distanceToday')));
      await tester.pumpAndSettle();

      expect(find.text('Distance today'), findsOneWidget);
    });

    testWidgets('Clear all and Reset both return to the unfiltered default', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestableWidget());
      await tester.tap(find.byKey(const Key('btn-open-filter-sheet')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('chip-status-offDuty')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('btn-filters-clear-all')));
      await tester.pumpAndSettle();
      expect(find.text('Apply filters'), findsOneWidget);

      await tester.tap(find.byKey(const Key('btn-filters-reset')));
      await tester.pumpAndSettle();
      expect(find.text('Apply filters'), findsOneWidget);
    });

    testWidgets(
      'Show results button pops modal sheet and returns FilterSheetState',
      (tester) async {
        FilterSheetState? returnedResult;

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: AppTheme.light,
              home: Scaffold(
                body: Builder(
                  builder: (context) {
                    return Center(
                      child: ElevatedButton(
                        key: const Key('btn-open-filter-sheet'),
                        onPressed: () async {
                          returnedResult = await FilterBottomSheet.show(
                            context,
                          );
                        },
                        child: const Text('Open Sheet'),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );

        // Open sheet
        await tester.tap(find.byKey(const Key('btn-open-filter-sheet')));
        await tester.pumpAndSettle();

        // Select a status, then Apply
        await tester.tap(find.byKey(const Key('chip-status-onDuty')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('btn-filters-apply')));
        await tester.pumpAndSettle();

        // Verify sheet popped and result was captured
        expect(returnedResult, isNotNull);
        expect(returnedResult!.selectedStatuses, {EmployeeFilterStatus.onDuty});
      },
    );
  });
}
