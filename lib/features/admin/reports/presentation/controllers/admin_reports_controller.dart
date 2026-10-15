import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'admin_reports_state.dart';

/// Riverpod 3 Notifier managing Screen 26 Reports configuration and export state.
class AdminReportsNotifier extends Notifier<AdminReportsState> {
  @override
  AdminReportsState build() {
    return const AdminReportsState();
  }

  void setReportType(ReportType type) {
    state = state.copyWith(reportType: type);
  }

  void setDateRangePreset(DateRangePreset preset) {
    state = state.copyWith(
      dateRangePreset: preset,
      dateRangeText: preset.defaultRangeText,
    );
  }

  void removeEmployee(String employeeName) {
    final updated = List<String>.from(state.selectedEmployees)
      ..remove(employeeName);
    state = state.copyWith(selectedEmployees: updated);
  }

  void resetEmployees() {
    state = state.copyWith(
      selectedEmployees: const ['Suresh Patel', 'Anil Sharma'],
    );
  }

  void setReportFormat(ReportFormat format) {
    final fileName = format == ReportFormat.pdf
        ? 'attendance-oct-2026.pdf'
        : 'attendance-oct-2026.xlsx';
    state = state.copyWith(
      reportFormat: format,
      generatedFileName: fileName,
    );
  }

  Future<void> generateReport() async {
    state = state.copyWith(isGenerating: true);
    // Simulate generation latency (100ms in code, responsive in tests and UI)
    await Future<void>.delayed(const Duration(milliseconds: 100));
    state = state.copyWith(
      isGenerating: false,
      isReady: true,
    );
  }

  void resetToBuild() {
    state = state.copyWith(
      isReady: false,
      isGenerating: false,
    );
  }
}

/// Provider for Screen 26 Reports Notifier.
final adminReportsControllerProvider =
    NotifierProvider<AdminReportsNotifier, AdminReportsState>(
  AdminReportsNotifier.new,
);
