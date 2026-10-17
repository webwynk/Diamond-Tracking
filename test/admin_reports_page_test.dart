import 'package:diamond_tracking/core/errors/app_exceptions.dart';
import 'package:diamond_tracking/core/theme/app_theme.dart';
import 'package:diamond_tracking/domain/entities/report_data.dart';
import 'package:diamond_tracking/features/admin/reports/presentation/admin_reports_page.dart';
import 'package:diamond_tracking/features/admin/reports/presentation/controllers/admin_reports_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/employee_fixtures.dart';
import 'support/fake_attendance.dart';
import 'support/fake_report.dart';

void main() {
  late FakeReportRepository repository;
  late FakeReportDelivery delivery;
  late ProviderContainer container;

  Future<void> pumpPage(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    container = ProviderContainer(
      overrides: [
        ...reportOverrides(repository, delivery),
        fixtureEmployeeListOverride,
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light,
          home: const AdminReportsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
  }

  setUp(() {
    repository = FakeReportRepository(
      source: ReportSource(
        sessions: [
          attendanceSession(
            's1',
            year: 2026,
            month: 10,
            day: 5,
            employeeId: 'emp-1',
          ),
        ],
        employees: [
          ReportEmployee(
            id: 'emp-1',
            name: 'Suresh Patel',
            code: 'DA-022',
            createdAt: DateTime.utc(2026, 1, 1),
          ),
        ],
        serverNow: kReportNow,
      ),
    );
    delivery = FakeReportDelivery();
  });

  group('the builder', () {
    testWidgets('opens on a daily detail for today with PDF only', (
      tester,
    ) async {
      await pumpPage(tester);

      expect(find.byKey(const Key('admin-reports-top-bar')), findsOneWidget);
      for (final key in ['daily', 'employee', 'team', 'visit']) {
        expect(find.byKey(Key('tile-report-type-$key')), findsOneWidget);
      }
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Yesterday'), findsOneWidget);
      expect(find.text('Pick a day'), findsOneWidget);
      expect(find.text('Saturday, 17 October 2026'), findsOneWidget);
      expect(find.text('All employees'), findsOneWidget);
      expect(find.byKey(const Key('tile-format-pdf')), findsOneWidget);
      expect(find.byKey(const Key('tile-format-excel')), findsNothing);
      expect(find.byKey(const Key('reports-info-banner')), findsOneWidget);
      expect(
        find.text('Report generation is not available yet.'),
        findsNothing,
      );

      final button = tester.widget<ElevatedButton>(
        find.descendant(
          of: find.byKey(const Key('btn-generate-report')),
          matching: find.byType(ElevatedButton),
        ),
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets('the visit log is shown as coming soon and cannot be chosen', (
      tester,
    ) async {
      await pumpPage(tester);

      expect(find.text('SOON'), findsOneWidget);
      await tester.tap(find.byKey(const Key('tile-report-type-visit')));
      await tester.pumpAndSettle();

      expect(find.text('Saturday, 17 October 2026'), findsOneWidget);
      expect(find.byKey(const Key('chip-period-today')), findsOneWidget);
    });

    testWidgets('a team summary offers months and weeks, and shows the days', (
      tester,
    ) async {
      await pumpPage(tester);

      await tapKey(tester, 'tile-report-type-team');

      expect(find.text('This month'), findsOneWidget);
      expect(find.text('Last month'), findsOneWidget);
      expect(find.text('Last 7 days'), findsOneWidget);
      expect(find.text('Custom'), findsOneWidget);
      expect(find.text('Today'), findsNothing);
      expect(find.text('01 Oct 2026 – 17 Oct 2026 (17 days)'), findsOneWidget);

      await tapKey(tester, 'chip-period-lastMonth');
      expect(find.text('01 Sep 2026 – 30 Sep 2026 (30 days)'), findsOneWidget);
    });

    testWidgets('a period that is too long says so and blocks the button', (
      tester,
    ) async {
      await pumpPage(tester);
      await tapKey(tester, 'tile-report-type-team');

      container
          .read(adminReportsControllerProvider.notifier)
          .setPickedRange(DateTime(2026, 9), DateTime(2026, 10, 2));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('text-period-problem')), findsOneWidget);
      expect(find.textContaining('at most 31 days'), findsWidgets);
      final button = tester.widget<ElevatedButton>(
        find.descendant(
          of: find.byKey(const Key('btn-generate-report')),
          matching: find.byType(ElevatedButton),
        ),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('Pick a day opens the calendar and uses the day chosen', (
      tester,
    ) async {
      await pumpPage(tester);

      await tapKey(tester, 'chip-period-pickDay');
      await tester.tap(find.text('12'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(find.text('Monday, 12 October 2026'), findsOneWidget);
    });

    testWidgets(
      'an employee summary needs an employee, chosen from the roster',
      (tester) async {
        await pumpPage(tester);
        await tapKey(tester, 'tile-report-type-employee');

        expect(find.text('Choose whose report to build.'), findsOneWidget);
        expect(find.text('Choose an employee'), findsOneWidget);

        await tapKey(tester, 'field-employee-select');
        // The roster is listed by name.
        expect(find.text('Amit Deshmukh'), findsOneWidget);
        await tester.enterText(
          find.byKey(const Key('field-report-employee-search')),
          'anil',
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('report-employee-row-emp-1')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('report-employee-row-emp-2')),
          findsOneWidget,
        );

        await tester.enterText(
          find.byKey(const Key('field-report-employee-search')),
          'DA-022',
        );
        await tester.pumpAndSettle();
        await tapKey(tester, 'report-employee-row-emp-1');

        expect(find.text('Suresh Patel (DA-022)'), findsOneWidget);
        expect(find.text('Choose whose report to build.'), findsNothing);
      },
    );
  });

  group('generating', () {
    testWidgets('builds the report, then offers it to share or print', (
      tester,
    ) async {
      await pumpPage(tester);
      await tapKey(tester, 'tile-report-type-team');

      await tapKey(tester, 'btn-generate-report');

      expect(find.byKey(const Key('report-result-card')), findsOneWidget);
      expect(find.text('Report ready'), findsOneWidget);
      expect(
        find.text('DiamondAgritech_TeamSummary_2026-10-01_to_2026-10-17.pdf'),
        findsOneWidget,
      );
      expect(find.textContaining('PDF · '), findsOneWidget);
      expect(find.byKey(const Key('btn-generate-report')), findsNothing);
      expect(repository.events, ['fetch', 'log']);

      await tapKey(tester, 'btn-share-report');
      expect(delivery.shared.single.$2, contains('TeamSummary'));
      expect(delivery.shared.single.$1.length, greaterThan(1000));

      await tapKey(tester, 'btn-print-report');
      expect(delivery.printed.single.$2, contains('TeamSummary'));
    });

    testWidgets('shows progress while it works and locks the choices', (
      tester,
    ) async {
      repository.gateFetch();
      await pumpPage(tester);

      await tester.tap(find.byKey(const Key('btn-generate-report')));
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const Key('text-generate-stage')), findsOneWidget);
      expect(find.text('Reading duty records…'), findsOneWidget);
      expect(find.text('Preparing report…'), findsOneWidget);

      await tester.tap(find.byKey(const Key('tile-report-type-team')));
      await tester.pump();
      expect(find.text('Saturday, 17 October 2026'), findsOneWidget);

      repository.release();
      await tester.pumpAndSettle();
      expect(find.text('Report ready'), findsOneWidget);
    });

    testWidgets('a failure is shown with a way to try again', (tester) async {
      repository.fetchError = const NetworkException();
      await pumpPage(tester);

      await tapKey(tester, 'btn-generate-report');

      expect(find.byKey(const Key('text-report-error')), findsOneWidget);
      expect(find.text(const NetworkException().message), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      expect(find.byKey(const Key('report-result-card')), findsNothing);

      repository.fetchError = null;
      await tapKey(tester, 'btn-generate-report');

      expect(find.byKey(const Key('report-result-card')), findsOneWidget);
      expect(find.byKey(const Key('text-report-error')), findsNothing);
    });

    testWidgets('no audit, no export: nothing is offered if recording fails', (
      tester,
    ) async {
      repository.logError = const ServerException(
        'Could not record the export.',
      );
      await pumpPage(tester);

      await tapKey(tester, 'btn-generate-report');

      expect(
        find.textContaining('so the report was not released'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('report-result-card')), findsNothing);
      expect(find.byKey(const Key('btn-share-report')), findsNothing);
      expect(delivery.shared, isEmpty);
    });

    testWidgets('changing a choice discards the finished report', (
      tester,
    ) async {
      await pumpPage(tester);
      await tapKey(tester, 'btn-generate-report');
      expect(find.byKey(const Key('report-result-card')), findsOneWidget);

      await tapKey(tester, 'chip-period-yesterday');

      expect(find.byKey(const Key('report-result-card')), findsNothing);
      expect(find.byKey(const Key('btn-generate-report')), findsOneWidget);
    });

    testWidgets('warns when the report was cut short', (tester) async {
      repository.source = ReportSource(
        sessions: const [],
        employees: const [],
        serverNow: kReportNow,
        truncated: true,
      );
      await pumpPage(tester);

      await tapKey(tester, 'btn-generate-report');

      expect(find.byKey(const Key('text-report-truncated')), findsOneWidget);
    });

    testWidgets('a share that cannot open says so', (tester) async {
      await pumpPage(tester);
      await tapKey(tester, 'btn-generate-report');
      delivery.error = Exception('no share sheet');

      await tester.tap(find.byKey(const Key('btn-share-report')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.text('Could not share the report. Please try again.'),
        findsOneWidget,
      );
    });
  });
}
