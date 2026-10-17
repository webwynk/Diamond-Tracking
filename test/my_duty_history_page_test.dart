import 'package:diamond_tracking/core/theme/app_theme.dart';
import 'package:diamond_tracking/domain/entities/duty_session.dart';
import 'package:diamond_tracking/domain/entities/location_point.dart';
import 'package:diamond_tracking/domain/entities/point_ingest_result.dart';
import 'package:diamond_tracking/domain/entities/user_profile.dart';
import 'package:diamond_tracking/domain/repositories/duty_repository.dart';
import 'package:diamond_tracking/features/auth/presentation/controllers/auth_controller.dart';
import 'package:diamond_tracking/features/auth/presentation/controllers/auth_state.dart';
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
  bool failHistory = false;

  @override
  Future<DutySession?> getActiveDutySession({
    required String employeeId,
  }) async => null;

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
  }) async => null;

  @override
  Future<List<DutySession>> getDutyHistory({
    required String employeeId,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 30,
    int offset = 0,
  }) async {
    if (failHistory) throw Exception('network down');
    return historySessions;
  }

  @override
  Future<DateTime> getServerTime() async => DateTime.now().toUtc();

  @override
  Future<PointIngestResult> ingestLocationPoints({
    required List<LocationPoint> points,
  }) async => const PointIngestResult();
}

class _SignedInEmployee extends AuthNotifier {
  @override
  AuthState build() => AuthAuthenticated(
    UserProfile(
      id: 'emp_1',
      role: UserRole.employee,
      status: UserStatus.active,
      fullName: 'Suresh Kumar',
      mustChangePin: false,
      failedLoginAttempts: 0,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      employeeCode: 'DA-001',
    ),
  );
}

class _SignedOut extends AuthNotifier {
  @override
  AuthState build() => const AuthUnauthenticated();
}

DutySession _session(
  String id,
  DateTime startedAt, {
  Duration length = const Duration(hours: 8, minutes: 15),
  double km = 40,
  int visits = 4,
  int mockPoints = 0,
  bool autoEnded = false,
}) {
  return DutySession(
    id: id,
    employeeId: 'emp_1',
    startedAt: startedAt,
    endedAt: startedAt.add(length),
    totalDistanceKm: km,
    visitsCount: visits,
    mockPointsCount: mockPoints,
    status: autoEnded
        ? DutySessionStatus.autoCurfew
        : DutySessionStatus.completed,
    endReason: autoEnded ? 'auto_curfew' : null,
  );
}

void main() {
  final now = DateTime.now();
  // Mid-morning times inside the current and the previous month.
  final thisMonthA = DateTime(now.year, now.month, 1, 9);
  final thisMonthB = DateTime(now.year, now.month, 2, 9);
  final thisMonthC = DateTime(now.year, now.month, 3, 9);
  final lastMonthA = DateTime(now.year, now.month - 1, 15, 9);

  Widget buildTestWidget({
    DutyRepository? dutyRepository,
    bool signedIn = true,
  }) {
    return ProviderScope(
      overrides: [
        if (dutyRepository != null)
          dutyRepositoryProvider.overrideWithValue(dutyRepository),
        if (signedIn)
          authControllerProvider.overrideWith(_SignedInEmployee.new),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: const MyDutyHistoryPage(),
      ),
    );
  }

  ProviderContainer containerWith(
    _FakeDutyRepository repo, {
    bool signedIn = true,
  }) {
    final container = ProviderContainer(
      overrides: [
        dutyRepositoryProvider.overrideWithValue(repo),
        authControllerProvider.overrideWith(
          signedIn ? _SignedInEmployee.new : _SignedOut.new,
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  void tall(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  group('DutyHistoryController', () {
    test(
      'with no sessions it is empty: zero summary, no invented records',
      () async {
        final container = containerWith(_FakeDutyRepository());

        final notifier = container.read(dutyHistoryControllerProvider.notifier);
        await notifier.loadHistory();

        final state = container.read(dutyHistoryControllerProvider);
        expect(state.isLoading, isFalse);
        expect(state.errorMessage, isNull);
        expect(state.filter, DutyHistoryFilter.thisMonth);
        expect(state.items, isEmpty);
        expect(state.summary.totalDays, 0);
        expect(state.summary.totalHours, '0h 0m');
        expect(state.summary.totalKm, 0);
        expect(state.summary.totalVisits, 0);
        expect(state.summary.periodLabel, isNotEmpty);
      },
    );

    test(
      'a repository failure sets an error and never falls back to sample data',
      () async {
        final repo = _FakeDutyRepository()..failHistory = true;
        final container = containerWith(repo);

        final notifier = container.read(dutyHistoryControllerProvider.notifier);
        await notifier.loadHistory();

        final state = container.read(dutyHistoryControllerProvider);
        expect(state.isLoading, isFalse);
        expect(state.errorMessage, isNotNull);
        expect(state.items, isEmpty);
        expect(state.summary.totalDays, 0);

        // A retry that succeeds clears the error.
        repo
          ..failHistory = false
          ..historySessions = [_session('s1', thisMonthA)];
        await notifier.loadHistory();
        final recovered = container.read(dutyHistoryControllerProvider);
        expect(recovered.errorMessage, isNull);
        expect(recovered.items.length, 1);
      },
    );

    test('a signed-out user gets an empty history without querying', () async {
      final repo = _FakeDutyRepository()
        ..historySessions = [_session('s1', thisMonthA)];
      final container = containerWith(repo, signedIn: false);

      final notifier = container.read(dutyHistoryControllerProvider.notifier);
      await notifier.loadHistory();

      final state = container.read(dutyHistoryControllerProvider);
      expect(state.items, isEmpty);
      expect(state.isLoading, isFalse);
    });

    test('maps real sessions and computes the summary from them', () async {
      final repo = _FakeDutyRepository()
        ..historySessions = [
          _session('sess_1', thisMonthB, km: 42.5, visits: 4),
          _session('sess_2', thisMonthA, km: 58, visits: 6, autoEnded: true),
        ];
      final container = containerWith(repo);

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

    test(
      'this month, last month, auto-ended and custom filter the loaded sessions',
      () async {
        final repo = _FakeDutyRepository()
          ..historySessions = [
            _session('a', thisMonthB),
            _session('b', thisMonthA, autoEnded: true),
            _session('c', lastMonthA, km: 10, visits: 1),
          ];
        final container = containerWith(repo);
        final notifier = container.read(dutyHistoryControllerProvider.notifier);
        await notifier.loadHistory();

        DutyHistoryState read() =>
            container.read(dutyHistoryControllerProvider);

        expect(read().items.length, 2); // this month

        notifier.setFilter(DutyHistoryFilter.lastMonth);
        expect(read().filter, DutyHistoryFilter.lastMonth);
        expect(read().items.map((i) => i.id), ['c']);
        expect(read().summary.totalKm, 10);

        notifier.setFilter(DutyHistoryFilter.autoEnded);
        expect(read().items.map((i) => i.id), ['b']);
        expect(read().summary.periodLabel, 'AUTO-ENDED SHIFTS');

        notifier.setFilter(DutyHistoryFilter.custom);
        expect(read().items.length, 3);
      },
    );
  });

  group('MyDutyHistoryPage', () {
    testWidgets('renders header, chips and real session cards', (tester) async {
      tall(tester);
      final repo = _FakeDutyRepository()
        ..historySessions = [
          _session('a', thisMonthB, km: 47.3, visits: 5),
          _session('b', thisMonthA, km: 54.2, visits: 6, autoEnded: true),
          _session('c', thisMonthC, mockPoints: 2),
        ];

      await tester.pumpWidget(buildTestWidget(dutyRepository: repo));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('My history'), findsOneWidget);
      expect(find.byTooltip('Back'), findsNothing); // tab screen
      expect(find.byKey(const Key('history-filter-btn')), findsOneWidget);

      expect(find.byType(HistoryFilterChipsBar), findsOneWidget);
      expect(find.text('This month'), findsOneWidget);
      expect(find.text('Last month'), findsOneWidget);
      expect(find.text('Custom'), findsOneWidget);

      expect(find.byType(HistoryMonthlySummaryCard), findsOneWidget);
      expect(find.byType(DutyHistoryCard), findsNWidgets(3));
      expect(find.text('47.3 km'), findsOneWidget);
      expect(find.text('5 visits'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(DutyHistoryCard),
          matching: find.text('Auto-ended'),
        ),
        findsOneWidget,
      );
      expect(find.text('2 flags'), findsOneWidget);

      // The endless "Loading earlier records…" spinner was a fake and is gone.
      expect(find.text('Loading earlier records…'), findsNothing);
    });

    testWidgets('shows an honest empty message, not sample records', (
      tester,
    ) async {
      tall(tester);

      await tester.pumpWidget(
        buildTestWidget(dutyRepository: _FakeDutyRepository()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(DutyHistoryCard), findsNothing);
      expect(
        find.text('No duty history records found for this period.'),
        findsOneWidget,
      );
      expect(find.text('89h 12m'), findsNothing);
      expect(find.text('534.8'), findsNothing);
      expect(find.text('Sat, 11 Oct'), findsNothing);
      expect(find.text('Loading earlier records…'), findsNothing);
    });

    testWidgets('shows an error with Retry when loading fails, and recovers', (
      tester,
    ) async {
      tall(tester);
      final repo = _FakeDutyRepository()..failHistory = true;

      await tester.pumpWidget(buildTestWidget(dutyRepository: repo));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text("Couldn't load your history"), findsOneWidget);
      expect(find.byType(DutyHistoryCard), findsNothing);

      repo
        ..failHistory = false
        ..historySessions = [_session('a', thisMonthA)];
      await tester.tap(find.text('Retry'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text("Couldn't load your history"), findsNothing);
      expect(find.byType(DutyHistoryCard), findsOneWidget);
    });

    testWidgets('tapping filter chips updates the list and summary', (
      tester,
    ) async {
      tall(tester);
      final repo = _FakeDutyRepository()
        ..historySessions = [
          _session('a', thisMonthA),
          _session('b', lastMonthA, km: 10, visits: 1, autoEnded: true),
        ];

      await tester.pumpWidget(buildTestWidget(dutyRepository: repo));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(DutyHistoryCard), findsOneWidget);

      await tester.tap(find.byKey(const Key('filter-chip-lastMonth')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byKey(const Key('history-card-b')), findsOneWidget);
      expect(find.byKey(const Key('history-card-a')), findsNothing);

      await tester.tap(find.byKey(const Key('filter-chip-autoEnded')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('AUTO-ENDED SHIFTS'), findsOneWidget);
      expect(find.byType(DutyHistoryCard), findsOneWidget);
    });
  });
}
