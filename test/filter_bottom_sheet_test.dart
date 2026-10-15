import 'package:diamond_tracking/core/theme/app_theme.dart';
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
    testWidgets('renders all headers, chips, date fields, sort options and buttons', (tester) async {
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
      expect(find.byKey(const Key('chip-status-checkNeeded')), findsOneWidget);
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
      expect(find.byKey(const Key('field-filter-date-preview')), findsOneWidget);
      expect(find.text('12 Oct 2026'), findsOneWidget);

      // Verify Sort By Section
      expect(find.text('SORT BY'), findsOneWidget);
      expect(find.byKey(const Key('radio-sort-nameAsc')), findsOneWidget);
      expect(find.byKey(const Key('radio-sort-employeeId')), findsOneWidget);
      expect(find.byKey(const Key('radio-sort-lastActive')), findsOneWidget);
      expect(find.byKey(const Key('radio-sort-distanceToday')), findsOneWidget);

      // Verify Pinned Bottom Actions
      expect(find.byKey(const Key('btn-filters-reset')), findsOneWidget);
      expect(find.byKey(const Key('btn-filters-apply')), findsOneWidget);
      expect(find.text('Show 115 results'), findsOneWidget);
    });

    testWidgets('toggling status chips updates multi-select state and dynamic result count', (tester) async {
      await tester.pumpWidget(buildTestableWidget());
      await tester.tap(find.byKey(const Key('btn-open-filter-sheet')));
      await tester.pumpAndSettle();

      // Initial: onDuty (112) + checkNeeded (3) = 115 results
      expect(find.text('Show 115 results'), findsOneWidget);

      // Tap offDuty (31) chip to add
      await tester.tap(find.byKey(const Key('chip-status-offDuty')));
      await tester.pumpAndSettle();
      // 112 + 3 + 31 = 146
      expect(find.text('Show 146 results'), findsOneWidget);

      // Unselect onDuty (112)
      await tester.tap(find.byKey(const Key('chip-status-onDuty')));
      await tester.pumpAndSettle();
      // 3 + 31 = 34
      expect(find.text('Show 34 results'), findsOneWidget);
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

    testWidgets('date range presets update read-only date preview field', (tester) async {
      await tester.pumpWidget(buildTestableWidget());
      await tester.tap(find.byKey(const Key('btn-open-filter-sheet')));
      await tester.pumpAndSettle();

      // Tap "Last 7 days" preset
      await tester.tap(find.byKey(const Key('chip-date-last7Days')));
      await tester.pumpAndSettle();

      expect(find.text('05 Oct 2026 – 12 Oct 2026'), findsOneWidget);

      // Tap "This month"
      await tester.tap(find.byKey(const Key('chip-date-thisMonth')));
      await tester.pumpAndSettle();

      expect(find.text('01 Oct 2026 – 12 Oct 2026'), findsOneWidget);
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

    testWidgets('Clear all resets active filters to blank with 143 total count', (tester) async {
      await tester.pumpWidget(buildTestableWidget());
      await tester.tap(find.byKey(const Key('btn-open-filter-sheet')));
      await tester.pumpAndSettle();

      // Tap Clear all
      await tester.tap(find.byKey(const Key('btn-filters-clear-all')));
      await tester.pumpAndSettle();

      expect(find.text('Show 143 results'), findsOneWidget);
    });

    testWidgets('Reset button restores default initial state with 115 results', (tester) async {
      await tester.pumpWidget(buildTestableWidget());
      await tester.tap(find.byKey(const Key('btn-open-filter-sheet')));
      await tester.pumpAndSettle();

      // Tap Clear all first
      await tester.tap(find.byKey(const Key('btn-filters-clear-all')));
      await tester.pumpAndSettle();
      expect(find.text('Show 143 results'), findsOneWidget);

      // Tap Reset
      await tester.tap(find.byKey(const Key('btn-filters-reset')));
      await tester.pumpAndSettle();

      expect(find.text('Show 115 results'), findsOneWidget);
    });

    testWidgets('Show results button pops modal sheet and returns FilterSheetState', (tester) async {
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
                        returnedResult = await FilterBottomSheet.show(context);
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

      // Tap Apply / Show results
      await tester.tap(find.byKey(const Key('btn-filters-apply')));
      await tester.pumpAndSettle();

      // Verify sheet popped and result was captured
      expect(returnedResult, isNotNull);
      expect(returnedResult!.matchingResultsCount, 115);
      expect(returnedResult!.selectedStatuses, contains(EmployeeFilterStatus.onDuty));
      expect(returnedResult!.selectedStatuses, contains(EmployeeFilterStatus.checkNeeded));
    });
  });
}
