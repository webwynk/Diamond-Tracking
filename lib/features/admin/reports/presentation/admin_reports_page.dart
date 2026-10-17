import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/reports/report_delivery.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/duty_time_helper.dart';
import '../../../../core/utils/phone_clock.dart';
import '../../../../shared/widgets/app_snackbar.dart';
import '../../../../shared/widgets/app_top_bar.dart';
import 'controllers/admin_reports_controller.dart';
import 'controllers/admin_reports_state.dart';
import 'widgets/admin_reports_action_bar.dart';
import 'widgets/admin_reports_build_view.dart';
import 'widgets/admin_reports_employee_sheet.dart';

/// Screen 26 — Reports (Admin).
///
/// Pick a report, the days and (for an employee summary) the person, then
/// generate a PDF on this phone. It is recorded in the audit log, then offered
/// for sharing or printing. Nothing is shown that was not built from the
/// server's data.
class AdminReportsPage extends ConsumerWidget {
  const AdminReportsPage({super.key});

  /// How far back a date can be picked.
  static const int _pickerYears = 2;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(adminReportsControllerProvider);
    final notifier = ref.read(adminReportsControllerProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppTopBar(
        key: Key('admin-reports-top-bar'),
        style: AppTopBarStyle.brand,
        title: 'Reports',
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: AdminReportsBuildView(
              state: state,
              onSelectType: notifier.setType,
              onSelectPreset: (preset) => _onPreset(context, ref, preset),
              onPickEmployee: () => _pickEmployee(context, ref),
            ),
          ),
          AdminReportsActionBar(
            state: state,
            onGenerate: notifier.generate,
            onShare: () => _deliver(
              context,
              ref,
              (delivery, report) =>
                  delivery.share(report.bytes, report.fileName),
              'share',
            ),
            onPrint: () => _deliver(
              context,
              ref,
              (delivery, report) =>
                  delivery.printOrSave(report.bytes, report.fileName),
              'open the print dialog for',
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onPreset(
    BuildContext context,
    WidgetRef ref,
    ReportPeriodPreset preset,
  ) async {
    final notifier = ref.read(adminReportsControllerProvider.notifier);
    if (!preset.needsPicker) {
      notifier.setPreset(preset);
      return;
    }

    final ist = DutyTimeHelper.toIst(ref.read(phoneClockProvider)());
    final today = DateTime(ist.year, ist.month, ist.day);
    final earliest = DateTime(
      today.year - _pickerYears,
      today.month,
      today.day,
    );
    final state = ref.read(adminReportsControllerProvider);

    if (preset == ReportPeriodPreset.pickDay) {
      final day = await showDatePicker(
        context: context,
        initialDate: state.to.isAfter(today) ? today : state.to,
        firstDate: earliest,
        lastDate: today,
        helpText: 'Report for which day?',
      );
      if (day != null) notifier.setPickedRange(day, day);
      return;
    }

    final range = await showDateRangePicker(
      context: context,
      firstDate: earliest,
      lastDate: today,
      initialDateRange: DateTimeRange(
        start: state.from,
        end: state.to.isAfter(today) ? today : state.to,
      ),
      helpText: 'Report for which days?',
    );
    if (range != null) notifier.setPickedRange(range.start, range.end);
  }

  Future<void> _pickEmployee(BuildContext context, WidgetRef ref) async {
    final chosen = await AdminReportsEmployeeSheet.show(
      context,
      selectedId: ref.read(adminReportsControllerProvider).employee?.id,
    );
    if (chosen != null) {
      ref.read(adminReportsControllerProvider.notifier).selectEmployee(chosen);
    }
  }

  Future<void> _deliver(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function(ReportDelivery delivery, GeneratedReport report) act,
    String verb,
  ) async {
    final report = ref.read(adminReportsControllerProvider).result;
    if (report == null) return;
    try {
      await act(ref.read(reportDeliveryProvider), report);
    } catch (_) {
      if (context.mounted) {
        AppSnackbar.show(
          context,
          message: 'Could not $verb the report. Please try again.',
        );
      }
    }
  }
}
