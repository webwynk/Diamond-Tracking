import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/errors/app_exceptions.dart';
import '../../../../../core/reports/report_pdf_renderer.dart';
import '../../../../../core/reports/report_pdf_style.dart';
import '../../../../../core/utils/duty_time_helper.dart';
import '../../../../../core/utils/phone_clock.dart';
import '../../../../../data/repositories/supabase_report_repository.dart';
import '../../../../../domain/entities/report_builder.dart';
import '../../../../../domain/entities/report_data.dart';
import '../../../../auth/presentation/controllers/auth_controller.dart';
import '../../../../auth/presentation/controllers/auth_state.dart';
import 'admin_reports_state.dart';

/// Loads the PDF renderer: DM Sans and the white logo from the app bundle. A
/// provider so tests can use the built-in fonts.
final reportPdfRendererLoaderProvider =
    Provider<Future<ReportPdfRenderer> Function()>((ref) {
      return () async {
        final fonts = await ReportFonts.load();
        final logo = await rootBundle.load('assets/image/white-logo.png');
        return ReportPdfRenderer(fonts: fonts, logo: logo.buffer.asUint8List());
      };
    });

/// Screen 26 Reports: the admin's choices and the building of the PDF.
///
/// Building runs on the phone: read the server's data, build the report with
/// the same arithmetic as the attendance screen, draw the PDF, and only then
/// write the audit entry. A report is released only once that entry is saved
/// ("no audit, no export"). Auto-disposed, so a finished report (personal data)
/// does not outlive the admin's session.
final adminReportsControllerProvider =
    NotifierProvider.autoDispose<AdminReportsNotifier, AdminReportsState>(
      AdminReportsNotifier.new,
    );

class AdminReportsNotifier extends Notifier<AdminReportsState> {
  int _request = 0;
  bool _stopped = false;

  @override
  AdminReportsState build() {
    ref.onDispose(() => _stopped = true);
    final today = _today();
    return AdminReportsState(from: today, to: today);
  }

  /// Today in IST. The phone's clock only picks the default period; what the
  /// report says about today and absences is decided on the server's clock.
  DateTime _today() {
    final ist = DutyTimeHelper.toIst(ref.read(phoneClockProvider)());
    return DateTime(ist.year, ist.month, ist.day);
  }

  void setType(ReportType type) {
    if (state.isWorking || !type.isAvailable) return;
    final keep = type.presets.contains(state.preset);
    final today = _today();
    final range = keep ? null : _rangeFor(type.presets.first, today);
    state = state.copyWith(
      type: type,
      preset: keep ? state.preset : type.presets.first,
      from: range?.$1,
      to: range?.$2,
      clearResult: true,
      clearError: true,
    );
  }

  /// A preset that needs no date picker.
  void setPreset(ReportPeriodPreset preset) {
    if (state.isWorking || preset.needsPicker) return;
    final range = _rangeFor(preset, _today());
    state = state.copyWith(
      preset: preset,
      from: range.$1,
      to: range.$2,
      clearResult: true,
      clearError: true,
    );
  }

  /// "Pick a day" (daily detail) or "Custom" (the others), after the admin
  /// picked. [to] is ignored for a single day.
  void setPickedRange(DateTime from, DateTime to) {
    if (state.isWorking) return;
    final first = DateTime(from.year, from.month, from.day);
    final last = state.type == ReportType.dailyDetail
        ? first
        : DateTime(to.year, to.month, to.day);
    state = state.copyWith(
      preset: state.type == ReportType.dailyDetail
          ? ReportPeriodPreset.pickDay
          : ReportPeriodPreset.custom,
      from: first,
      to: last,
      clearResult: true,
      clearError: true,
    );
  }

  void selectEmployee(ReportEmployeeChoice employee) {
    if (state.isWorking) return;
    state = state.copyWith(
      employee: employee,
      clearResult: true,
      clearError: true,
    );
  }

  /// Builds the report: read, build, draw, record, release.
  Future<void> generate() async {
    final chosen = state;
    final kind = chosen.type.kind;
    if (!chosen.canGenerate || kind == null) return;
    final employeeId = kind == ReportKind.employeeSummary
        ? chosen.employee?.id
        : null;

    final ticket = ++_request;
    bool stale() => ticket != _request || _stopped;

    state = chosen.copyWith(
      phase: ReportPhase.working,
      stage: 'Reading duty records…',
      clearResult: true,
      clearError: true,
    );

    final repository = ref.read(reportRepositoryProvider);
    try {
      final source = await repository.fetch(
        from: chosen.from,
        to: chosen.to,
        employeeId: employeeId,
      );
      if (stale()) return;

      state = state.copyWith(stage: 'Building the PDF…');
      final report = _build(kind, chosen, source);
      final renderer = await ref.read(reportPdfRendererLoaderProvider)();
      final bytes = await renderer.render(report, generatedBy: _adminName());
      if (stale()) return;

      state = state.copyWith(stage: 'Recording the export…');
      try {
        await repository.logExport(
          kind: kind,
          from: chosen.from,
          to: chosen.to,
          employeeId: employeeId,
        );
      } on AppException catch (e) {
        throw ServerException(
          'The export could not be recorded, so the report was not released. '
          '${e.message}',
        );
      }
      if (stale()) return;

      state = state.copyWith(
        phase: ReportPhase.ready,
        result: GeneratedReport(
          bytes: bytes,
          fileName: ReportPdfRenderer.fileName(report),
          truncated: source.truncated,
        ),
      );
    } on AppException catch (e) {
      if (stale()) return;
      state = state.copyWith(
        phase: ReportPhase.failed,
        errorMessage: e.message,
      );
    } catch (e, st) {
      debugPrint('AdminReports: could not create the report: $e\n$st');
      if (stale()) return;
      state = state.copyWith(
        phase: ReportPhase.failed,
        errorMessage: 'Could not create the report. Please try again.',
      );
    }
  }

  ReportData _build(
    ReportKind kind,
    AdminReportsState chosen,
    ReportSource source,
  ) {
    switch (kind) {
      case ReportKind.dailyDetail:
        return ReportBuilder.daily(source, day: chosen.from);
      case ReportKind.teamSummary:
        return ReportBuilder.team(source, from: chosen.from, to: chosen.to);
      case ReportKind.employeeSummary:
        final id = chosen.employee?.id;
        final matches = source.employees.where((e) => e.id == id);
        if (matches.isEmpty) {
          throw const ServerException('That employee could not be found.');
        }
        return ReportBuilder.employee(
          source,
          employee: matches.first,
          from: chosen.from,
          to: chosen.to,
        );
    }
  }

  String _adminName() {
    final auth = ref.read(authControllerProvider);
    final name = auth is AuthAuthenticated ? auth.profile.fullName.trim() : '';
    return name.isEmpty ? 'Administrator' : name;
  }

  /// The days a preset covers, both included, given IST [today].
  static (DateTime, DateTime) _rangeFor(
    ReportPeriodPreset preset,
    DateTime today,
  ) {
    switch (preset) {
      case ReportPeriodPreset.today:
        return (today, today);
      case ReportPeriodPreset.yesterday:
        final yesterday = DateTime(today.year, today.month, today.day - 1);
        return (yesterday, yesterday);
      case ReportPeriodPreset.last7Days:
        return (DateTime(today.year, today.month, today.day - 6), today);
      case ReportPeriodPreset.thisMonth:
        return (DateTime(today.year, today.month), today);
      case ReportPeriodPreset.lastMonth:
        return (
          DateTime(today.year, today.month - 1),
          DateTime(today.year, today.month, 0),
        );
      case ReportPeriodPreset.pickDay:
      case ReportPeriodPreset.custom:
        return (today, today);
    }
  }
}
