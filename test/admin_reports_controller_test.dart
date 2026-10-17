import 'dart:convert';

import 'package:diamond_tracking/core/errors/app_exceptions.dart';
import 'package:diamond_tracking/domain/entities/report_data.dart';
import 'package:diamond_tracking/features/admin/reports/presentation/controllers/admin_reports_controller.dart';
import 'package:diamond_tracking/features/admin/reports/presentation/controllers/admin_reports_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_attendance.dart';
import 'support/fake_report.dart';

final ReportEmployee _asha = ReportEmployee(
  id: 'e1',
  name: 'Asha Patel',
  code: 'DA-001',
  createdAt: DateTime.utc(2026, 1, 1),
);
const ReportEmployeeChoice _ashaChoice = ReportEmployeeChoice(
  id: 'e1',
  name: 'Asha Patel',
  code: 'DA-001',
);

ReportSource _source({bool truncated = false}) => ReportSource(
  sessions: [
    attendanceSession(
      's1',
      year: 2026,
      month: 10,
      day: 5,
      employeeId: 'e1',
      km: 10.5,
    ),
  ],
  employees: [_asha],
  serverNow: kReportNow,
  truncated: truncated,
);

void main() {
  late FakeReportRepository repository;
  late FakeReportDelivery delivery;

  ProviderContainer container({DateTime? now}) {
    final c = ProviderContainer(
      overrides: reportOverrides(repository, delivery, now: now),
    );
    addTearDown(c.dispose);
    // autoDispose: keep it alive for the length of the test.
    c.listen(adminReportsControllerProvider, (_, _) {});
    return c;
  }

  AdminReportsNotifier notifier(ProviderContainer c) =>
      c.read(adminReportsControllerProvider.notifier);
  AdminReportsState state(ProviderContainer c) =>
      c.read(adminReportsControllerProvider);

  setUp(() {
    repository = FakeReportRepository(source: _source());
    delivery = FakeReportDelivery();
  });

  group('the period', () {
    test('starts on a daily detail for today, IST', () {
      final c = container();

      expect(state(c).type, ReportType.dailyDetail);
      expect(state(c).preset, ReportPeriodPreset.today);
      expect(state(c).from, DateTime(2026, 10, 17));
      expect(state(c).to, DateTime(2026, 10, 17));
      expect(state(c).canGenerate, isTrue);
    });

    test('today is the IST day, not the UTC one', () {
      // 00:10 IST on 18 October is still 17 October in UTC.
      final c = container(now: DateTime.utc(2026, 10, 17, 18, 40));

      expect(state(c).from, DateTime(2026, 10, 18));
    });

    test('yesterday', () {
      final c = container();

      notifier(c).setPreset(ReportPeriodPreset.yesterday);

      expect(state(c).from, DateTime(2026, 10, 16));
      expect(state(c).to, DateTime(2026, 10, 16));
    });

    test('this month, last month and the last seven days', () {
      final c = container();
      notifier(c).setType(ReportType.teamSummary);

      expect(state(c).preset, ReportPeriodPreset.thisMonth);
      expect(state(c).from, DateTime(2026, 10));
      expect(state(c).to, DateTime(2026, 10, 17));

      notifier(c).setPreset(ReportPeriodPreset.lastMonth);
      expect(state(c).from, DateTime(2026, 9));
      expect(state(c).to, DateTime(2026, 9, 30));

      notifier(c).setPreset(ReportPeriodPreset.last7Days);
      expect(state(c).from, DateTime(2026, 10, 11));
      expect(state(c).to, DateTime(2026, 10, 17));
      expect(state(c).days, 7);
    });

    test('last month in January is December of the year before', () {
      final c = container(now: DateTime.utc(2027, 1, 10, 4));
      notifier(c).setType(ReportType.teamSummary);

      notifier(c).setPreset(ReportPeriodPreset.lastMonth);

      expect(state(c).from, DateTime(2026, 12));
      expect(state(c).to, DateTime(2026, 12, 31));
    });

    test('moving to a report that has the same choice keeps the period', () {
      final c = container();
      notifier(c).setType(ReportType.teamSummary);
      notifier(c).setPreset(ReportPeriodPreset.last7Days);

      notifier(c).setType(ReportType.employeeSummary);

      expect(state(c).preset, ReportPeriodPreset.last7Days);
      expect(state(c).from, DateTime(2026, 10, 11));
    });

    test('moving to a daily detail falls back to today', () {
      final c = container();
      notifier(c).setType(ReportType.teamSummary);

      notifier(c).setType(ReportType.dailyDetail);

      expect(state(c).preset, ReportPeriodPreset.today);
      expect(state(c).from, DateTime(2026, 10, 17));
      expect(state(c).to, DateTime(2026, 10, 17));
    });

    test('a picked day is one day, whatever end was given', () {
      final c = container();

      notifier(c).setPickedRange(DateTime(2026, 10, 3), DateTime(2026, 10, 9));

      expect(state(c).preset, ReportPeriodPreset.pickDay);
      expect(state(c).from, DateTime(2026, 10, 3));
      expect(state(c).to, DateTime(2026, 10, 3));
    });

    test('a team summary covers at most 31 days', () {
      final c = container();
      notifier(c).setType(ReportType.teamSummary);

      notifier(c).setPickedRange(DateTime(2026, 9, 1), DateTime(2026, 10, 1));
      expect(state(c).days, 31);
      expect(state(c).periodProblem, isNull);
      expect(state(c).canGenerate, isTrue);

      notifier(c).setPickedRange(DateTime(2026, 9, 1), DateTime(2026, 10, 2));
      expect(state(c).days, 32);
      expect(state(c).periodProblem, contains('at most 31 days'));
      expect(state(c).canGenerate, isFalse);
    });

    test('an employee summary covers at most 62 days', () {
      final c = container();
      notifier(c).setType(ReportType.employeeSummary);
      notifier(c).selectEmployee(_ashaChoice);

      notifier(c).setPickedRange(DateTime(2026, 8, 17), DateTime(2026, 10, 17));
      expect(state(c).days, 62);
      expect(state(c).canGenerate, isTrue);

      notifier(c).setPickedRange(DateTime(2026, 8, 16), DateTime(2026, 10, 17));
      expect(state(c).days, 63);
      expect(state(c).periodProblem, contains('at most 62 days'));
      expect(state(c).canGenerate, isFalse);
    });

    test('an end before the start is refused', () {
      final c = container();
      notifier(c).setType(ReportType.teamSummary);

      notifier(c).setPickedRange(DateTime(2026, 10, 9), DateTime(2026, 10, 3));

      expect(state(c).periodProblem, isNotNull);
      expect(state(c).canGenerate, isFalse);
    });
  });

  group('what can be generated', () {
    test('an employee summary needs an employee', () {
      final c = container();
      notifier(c).setType(ReportType.employeeSummary);

      expect(state(c).blocker, 'Choose whose report to build.');
      expect(state(c).canGenerate, isFalse);

      notifier(c).selectEmployee(_ashaChoice);

      expect(state(c).blocker, isNull);
      expect(state(c).canGenerate, isTrue);
    });

    test('the visit log cannot be chosen', () {
      final c = container();

      notifier(c).setType(ReportType.visitLog);

      expect(state(c).type, ReportType.dailyDetail);
    });
  });

  group('generating', () {
    test(
      'reads, builds, records the export, then releases the report',
      () async {
        final c = container();
        notifier(c).setType(ReportType.teamSummary);

        await notifier(c).generate();

        final s = state(c);
        expect(s.phase, ReportPhase.ready);
        expect(s.errorMessage, isNull);
        expect(repository.events, ['fetch', 'log']);
        expect(repository.fetchCalls.single.from, DateTime(2026, 10));
        expect(repository.fetchCalls.single.to, DateTime(2026, 10, 17));
        expect(repository.fetchCalls.single.employeeId, isNull);
        expect(repository.logCalls.single.kind, ReportKind.teamSummary);
        expect(repository.logCalls.single.employeeId, isNull);
        expect(
          s.result!.fileName,
          'DiamondAgritech_TeamSummary_2026-10-01_to_2026-10-17.pdf',
        );
        expect(latin1.decode(s.result!.bytes.sublist(0, 5)), '%PDF-');
        expect(s.result!.truncated, isFalse);
      },
    );

    test('a daily detail reads the one day, for everyone', () async {
      final c = container();
      notifier(c).setPreset(ReportPeriodPreset.yesterday);

      await notifier(c).generate();

      expect(repository.fetchCalls.single.from, DateTime(2026, 10, 16));
      expect(repository.fetchCalls.single.to, DateTime(2026, 10, 16));
      expect(repository.fetchCalls.single.employeeId, isNull);
      expect(repository.logCalls.single.kind, ReportKind.dailyDetail);
      expect(
        state(c).result!.fileName,
        'DiamondAgritech_DailyDetail_2026-10-16.pdf',
      );
    });

    test('an employee summary reads and records that employee', () async {
      final c = container();
      notifier(c).setType(ReportType.employeeSummary);
      notifier(c).selectEmployee(_ashaChoice);

      await notifier(c).generate();

      expect(repository.fetchCalls.single.employeeId, 'e1');
      expect(repository.logCalls.single.employeeId, 'e1');
      expect(repository.logCalls.single.kind, ReportKind.employeeSummary);
      expect(state(c).result!.fileName, contains('EmployeeSummary_DA-001_'));
    });

    test('the report names the admin who made it', () async {
      final c = container();

      await notifier(c).generate();

      final text = latin1.decode(state(c).result!.bytes);
      expect(text, contains('Operations'));
      expect(text, contains('Administrator'));
    });

    test('says so when the data was cut short', () async {
      repository.source = _source(truncated: true);
      final c = container();

      await notifier(c).generate();

      expect(state(c).result!.truncated, isTrue);
    });

    test(
      'shows what it is doing while it works, and locks the choices',
      () async {
        repository.gateFetch();
        final c = container();

        final running = notifier(c).generate();
        await Future<void>.delayed(Duration.zero);

        expect(state(c).isWorking, isTrue);
        expect(state(c).stage, 'Reading duty records…');
        expect(state(c).canGenerate, isFalse);

        notifier(c).setType(ReportType.teamSummary);
        notifier(c).setPreset(ReportPeriodPreset.yesterday);
        notifier(c).selectEmployee(_ashaChoice);
        expect(state(c).type, ReportType.dailyDetail);
        expect(state(c).preset, ReportPeriodPreset.today);
        expect(state(c).employee, isNull);

        // A second tap while working does nothing.
        await notifier(c).generate();
        expect(repository.fetchCalls, hasLength(1));

        repository.release();
        await running;
        expect(state(c).phase, ReportPhase.ready);
      },
    );

    test('changing a choice after a report discards that report', () async {
      final c = container();
      await notifier(c).generate();
      expect(state(c).result, isNotNull);

      notifier(c).setPreset(ReportPeriodPreset.yesterday);

      expect(state(c).result, isNull);
      expect(state(c).phase, ReportPhase.ready);
      expect(state(c).canGenerate, isTrue);
    });

    test('generating again replaces the report', () async {
      final c = container();
      await notifier(c).generate();

      await notifier(c).generate();

      expect(repository.logCalls, hasLength(2));
      expect(state(c).phase, ReportPhase.ready);
    });
  });

  group('when something goes wrong', () {
    test('a failed read is shown and nothing is recorded', () async {
      repository.fetchError = const NetworkException();
      final c = container();

      await notifier(c).generate();

      expect(state(c).phase, ReportPhase.failed);
      expect(state(c).result, isNull);
      expect(state(c).errorMessage, const NetworkException().message);
      expect(repository.logCalls, isEmpty);
    });

    test('an unexpected failure gets a plain message', () async {
      repository.fetchError = Exception('boom');
      final c = container();

      await notifier(c).generate();

      expect(state(c).phase, ReportPhase.failed);
      expect(
        state(c).errorMessage,
        'Could not create the report. Please try again.',
      );
    });

    test(
      'no audit, no export: if recording fails nothing is released',
      () async {
        repository.logError = const ServerException(
          'Could not record the export.',
        );
        final c = container();

        await notifier(c).generate();

        final s = state(c);
        expect(s.phase, ReportPhase.failed);
        expect(s.result, isNull);
        expect(s.errorMessage, contains('so the report was not released'));
        expect(s.errorMessage, contains('Could not record the export.'));
        expect(repository.events, ['fetch', 'log']);
      },
    );

    test('a refused admin is told so', () async {
      repository.fetchError = const UnauthorizedRoleException(
        'Only active administrators can export reports.',
      );
      final c = container();

      await notifier(c).generate();

      expect(
        state(c).errorMessage,
        'Only active administrators can export reports.',
      );
    });

    test(
      'an employee who is not on the team is reported, not guessed',
      () async {
        repository.source = ReportSource(
          sessions: const [],
          employees: const [],
          serverNow: kReportNow,
        );
        final c = container();
        notifier(c).setType(ReportType.employeeSummary);
        notifier(c).selectEmployee(_ashaChoice);

        await notifier(c).generate();

        expect(state(c).phase, ReportPhase.failed);
        expect(state(c).errorMessage, 'That employee could not be found.');
        expect(repository.logCalls, isEmpty);
      },
    );

    test('trying again after a failure works', () async {
      repository.fetchError = const NetworkException();
      final c = container();
      await notifier(c).generate();
      expect(state(c).phase, ReportPhase.failed);

      repository.fetchError = null;
      await notifier(c).generate();

      expect(state(c).phase, ReportPhase.ready);
      expect(state(c).errorMessage, isNull);
    });

    test('leaving the screen while it works throws nothing', () async {
      repository.gateFetch();
      final c = ProviderContainer(
        overrides: reportOverrides(repository, delivery),
      );
      final subscription = c.listen(adminReportsControllerProvider, (_, _) {});

      final running = c
          .read(adminReportsControllerProvider.notifier)
          .generate();
      await Future<void>.delayed(Duration.zero);
      subscription.close();
      c.dispose();
      repository.release();

      await running;
      expect(repository.logCalls, isEmpty);
    });
  });
}
