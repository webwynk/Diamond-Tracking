import 'package:diamond_tracking/core/theme/app_theme.dart';
import 'package:diamond_tracking/domain/entities/duty_session.dart';
import 'package:diamond_tracking/domain/repositories/duty_repository.dart';
import 'package:diamond_tracking/features/duty/presentation/controllers/duty_controller.dart';
import 'package:diamond_tracking/features/history/presentation/controllers/duty_history_controller.dart';
import 'package:diamond_tracking/features/history/presentation/controllers/duty_history_state.dart';
import 'package:diamond_tracking/features/history/presentation/my_duty_history_page.dart';
import 'package:diamond_tracking/features/history/presentation/widgets/duty_history_card.dart';
import 'package:diamond_tracking/features/history/presentation/widgets/history_filter_chips_bar.dart';
import 'package:diamond_tracking/features/history/presentation/widgets/history_monthly_summary_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeDutyRepository implements DutyRepository {
  List<DutySession> historySessions = [];

  @override
  Future<DutySession?> getActiveDutySession({required String employeeId}) async =>
      null;

  @override
  Future<DutySession> startDutySession({required String employeeId}) async {
    throw UnimplementedError();
  }

  @override
  Future<DutySession> endDutySession({
    required String sessionId,
    String? endReason,
    String? notes,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<DutySession?> getYesterdayDutySession({
    required String employeeId,
  }) async =>
      null;

  @override
  Future<List<DutySession>> getDutyHistory({
    required String employeeId,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 30,
    int offset = 0,
  }) async {
    return historySessions;
  }

  @override
  Future<void> uploadLocationPointsBatch({
    required List<dynamic> points,
  }) async {}
}

void main() {
  Widget buildTestWidget({
    DutyRepository? dutyRepository,
    VoidCallback? onNavigateToDuty,
    VoidCallback? onNavigateToMap,
  }) {
    return ProviderScope(
      overrides: [
        if (dutyRepository != null)
          dutyRepositoryProvider.overrideWithValue(dutyRepository),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: MyDutyHistoryPage(
          onNavigateToDuty: onNavigateToDuty,
          onNavigateToMap: onNavigateToMap,
        ),
      ),
    );
  }

  group('DutyHistoryController & State Unit Tests', () {
    test('initializes with default design reference seed data', () async {
      final container = ProviderContainer(
        overrides: [
          dutyRepositoryProvider.overrideWithValue(_FakeDutyRepository()),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(dutyHistoryControllerProvider.notifier);
      await notifier.loadHistory();

      final state = container.read(dutyHistoryControllerProvider);
      expect(state.isLoading, false);
      expect(state.filter, DutyHistoryFilter.thisMonth);
      expect(state.summary.periodLabel, 'OCTOBER 2026');
      expect(state.summary.totalDays, 11);
      expect(state.summary.totalHours, '89h 12m');
      expect(state.summary.totalKm, 534.8);
      expect(state.summary.totalVisits, 48);

      expect(state.items.length, 4);
      expect(state.items[0].dateTitle, 'Sat, 11 Oct');
      expect(state.items[0].chipType, DutyHistoryChipType.none);
      expect(state.items[1].dateTitle, 'Fri, 10 Oct');
      expect(state.items[1].chipType, DutyHistoryChipType.autoEnded);
      expect(state.items[2].dateTitle, 'Thu, 09 Oct');
      expect(state.items[2].chipType, DutyHistoryChipType.flagged);
      expect(state.items[2].flagCount, 2);
      expect(state.items[3].dateTitle, 'Wed, 08 Oct');
      expect(state.items[3].chipType, DutyHistoryChipType.noDuty);
    });

    test('switches filter to last month and recalculates summary', () async {
      final container = ProviderContainer(
        overrides: [
          dutyRepositoryProvider.overrideWithValue(_FakeDutyRepository()),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(dutyHistoryControllerProvider.notifier);
      await notifier.loadHistory();

      notifier.setFilter(DutyHistoryFilter.lastMonth);
      final state = container.read(dutyHistoryControllerProvider);

      expect(state.filter, DutyHistoryFilter.lastMonth);
      expect(state.summary.periodLabel, 'SEPTEMBER 2026');
      expect(state.summary.totalDays, 24);
      expect(state.summary.totalHours, '192h 40m');
      expect(state.summary.totalKm, 1140.2);
      expect(state.summary.totalVisits, 102);
      expect(state.items.length, 2);
    });

    test('switches filter to auto-ended and shows only auto-ended items', () async {
      final container = ProviderContainer(
        overrides: [
          dutyRepositoryProvider.overrideWithValue(_FakeDutyRepository()),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(dutyHistoryControllerProvider.notifier);
      await notifier.loadHistory();

      notifier.setFilter(DutyHistoryFilter.autoEnded);
      final state = container.read(dutyHistoryControllerProvider);

      expect(state.filter, DutyHistoryFilter.autoEnded);
      expect(state.items.length, 1);
      expect(state.items.first.chipType, DutyHistoryChipType.autoEnded);
      expect(state.items.first.dateTitle, 'Fri, 10 Oct');
    });

    test('correctly maps real sessions returned from repository', () async {
      final repo = _FakeDutyRepository();
      final now = DateTime(2026, 10, 15, 8, 30);
      repo.historySessions = [
        DutySession(
          id: 'sess_1',
          employeeId: 'emp_1',
          startedAt: now,
          endedAt: now.add(const Duration(hours: 8, minutes: 15)),
          totalDistanceKm: 42.5,
          visitsCount: 4,
          status: DutySessionStatus.completed,
        ),
        DutySession(
          id: 'sess_2',
          employeeId: 'emp_1',
          startedAt: now.subtract(const Duration(days: 1)),
          endedAt: now.subtract(const Duration(days: 1)).add(const Duration(hours: 14)),
          totalDistanceKm: 58.0,
          visitsCount: 6,
          status: DutySessionStatus.autoCurfew,
          endReason: 'auto_curfew',
        ),
      ];

      final container = ProviderContainer(
        overrides: [
          dutyRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(dutyHistoryControllerProvider.notifier);
      await notifier.loadHistory();

      final state = container.read(dutyHistoryControllerProvider);
      expect(state.items.length, 2);
      expect(state.items[0].chipType, DutyHistoryChipType.none);
      expect(state.items[1].chipType, DutyHistoryChipType.autoEnded);
      expect(state.summary.totalDays, 2);
      expect(state.summary.totalVisits, 10);
      expect(state.summary.totalKm, 100.5);
    });
  });

  group('MyDutyHistoryPage Widget Tests', () {
    testWidgets('renders all key elements of Screen 12 matching design specification',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 1. App Bar
      expect(find.text('My history'), findsOneWidget);
      expect(find.byKey(const Key('history-back-btn')), findsOneWidget);
      expect(find.byKey(const Key('history-filter-btn')), findsOneWidget);
      expect(find.text('1'), findsOneWidget); // Filter badge count

      // 2. Filter Chips
      expect(find.byType(HistoryFilterChipsBar), findsOneWidget);
      expect(find.text('This month'), findsOneWidget);
      expect(find.text('Last month'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(HistoryFilterChipsBar),
          matching: find.text('Auto-ended'),
        ),
        findsOneWidget,
      );
      expect(find.text('Custom'), findsOneWidget);

      // 3. Monthly Summary Card
      expect(find.byType(HistoryMonthlySummaryCard), findsOneWidget);
      expect(find.text('OCTOBER 2026'), findsOneWidget);
      expect(find.text('11'), findsOneWidget); // Days
      expect(find.text('89h 12m'), findsOneWidget); // Hours
      expect(find.text('534.8'), findsOneWidget); // km
      expect(find.text('48'), findsOneWidget); // Visits

      // 4. History Cards List
      expect(find.byType(DutyHistoryCard), findsNWidgets(4));

      // Row 1: Sat, 11 Oct (Normal day, no chip)
      expect(find.text('Sat, 11 Oct'), findsOneWidget);
      expect(find.text('8:02 AM–6:30 PM'), findsOneWidget);
      expect(find.text('8h 28m'), findsOneWidget);
      expect(find.text('47.3 km'), findsOneWidget);
      expect(find.text('5 visits'), findsOneWidget);

      // Row 2: Fri, 10 Oct (Auto-ended chip)
      expect(find.text('Fri, 10 Oct'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(DutyHistoryCard),
          matching: find.text('Auto-ended'),
        ),
        findsOneWidget,
      );
      expect(find.text('15h 00m'), findsOneWidget);

      // Row 3: Thu, 09 Oct (2 flags chip)
      expect(find.text('Thu, 09 Oct'), findsOneWidget);
      expect(find.text('2 flags'), findsOneWidget);

      // Row 4: Wed, 08 Oct (No duty chip, dashes)
      expect(find.text('Wed, 08 Oct'), findsOneWidget);
      expect(find.text('No duty'), findsOneWidget);

      // 5. Pagination Loading Indicator
      expect(find.text('Loading earlier records…'), findsOneWidget);

      // 6. Persistent Bottom Navigation Bar
      expect(find.byKey(const Key('bottom-nav-duty-tab')), findsOneWidget);
      expect(find.byKey(const Key('bottom-nav-map-tab')), findsOneWidget);
      expect(find.byKey(const Key('bottom-nav-history-tab')), findsOneWidget);
      expect(find.text('Duty'), findsOneWidget);
      expect(find.text('Map'), findsOneWidget);
      expect(find.text('History'), findsOneWidget);
    });

    testWidgets('tapping filter chips updates list and summary card',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Tap 'Last month' chip
      await tester.tap(find.byKey(const Key('filter-chip-lastMonth')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('SEPTEMBER 2026'), findsOneWidget);
      expect(find.text('192h 40m'), findsOneWidget);
      expect(find.text('1140.2'), findsOneWidget);
      expect(find.text('Wed, 30 Sep'), findsOneWidget);

      // Tap 'Auto-ended' chip
      await tester.tap(find.byKey(const Key('filter-chip-autoEnded')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('AUTO-ENDED SHIFTS'), findsOneWidget);
      expect(find.text('Fri, 10 Oct'), findsOneWidget);
      expect(find.byType(DutyHistoryCard), findsOneWidget);
    });

    testWidgets('tapping bottom navigation tabs invokes navigation callbacks',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      bool navigatedToDuty = false;
      bool navigatedToMap = false;

      await tester.pumpWidget(buildTestWidget(
        onNavigateToDuty: () => navigatedToDuty = true,
        onNavigateToMap: () => navigatedToMap = true,
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));


      await tester.tap(find.byKey(const Key('bottom-nav-duty-tab')));
      await tester.pump();
      expect(navigatedToDuty, true);

      await tester.tap(find.byKey(const Key('bottom-nav-map-tab')));
      await tester.pump();
      expect(navigatedToMap, true);
    });
  });
}
