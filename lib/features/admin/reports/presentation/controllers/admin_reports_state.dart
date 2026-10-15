import 'package:flutter/foundation.dart';

/// Report types available in Screen 26 (Reports — Admin).
enum ReportType {
  dailyDetail,
  employeeSummary,
  teamSummary,
  visitLog,
}

extension ReportTypeX on ReportType {
  String get title => switch (this) {
        ReportType.dailyDetail => 'Daily detail',
        ReportType.employeeSummary => 'Employee summary',
        ReportType.teamSummary => 'Team summary',
        ReportType.visitLog => 'Visit log',
      };
}

/// Date range presets in Screen 26.
enum DateRangePreset {
  thisMonth,
  today,
  last7Days,
  custom,
}

extension DateRangePresetX on DateRangePreset {
  String get label => switch (this) {
        DateRangePreset.thisMonth => 'This month',
        DateRangePreset.today => 'Today',
        DateRangePreset.last7Days => 'Last 7 days',
        DateRangePreset.custom => 'Custom',
      };

  String get defaultRangeText => switch (this) {
        DateRangePreset.thisMonth => '01 Oct 2026 – 12 Oct 2026',
        DateRangePreset.today => '12 Oct 2026',
        DateRangePreset.last7Days => '05 Oct 2026 – 12 Oct 2026',
        DateRangePreset.custom => '01 Oct 2026 – 12 Oct 2026',
      };
}

/// File formats available for export.
enum ReportFormat {
  pdf,
  excel,
}

extension ReportFormatX on ReportFormat {
  String get label => switch (this) {
        ReportFormat.pdf => 'PDF',
        ReportFormat.excel => 'Excel',
      };

  String get subtitle => switch (this) {
        ReportFormat.pdf => 'Printable audit',
        ReportFormat.excel => 'Raw tabular (.xlsx)',
      };

  String get fileExtension => switch (this) {
        ReportFormat.pdf => '.pdf',
        ReportFormat.excel => '.xlsx',
      };
}

/// Immutable state for Screen 26 Reports (Admin).
@immutable
class AdminReportsState {
  const AdminReportsState({
    this.reportType = ReportType.dailyDetail,
    this.dateRangePreset = DateRangePreset.thisMonth,
    this.dateRangeText = '01 Oct 2026 – 12 Oct 2026',
    this.selectedEmployees = const ['Suresh Patel', 'Anil Sharma'],
    this.totalEmployeesCount = 143,
    this.reportFormat = ReportFormat.pdf,
    this.isGenerating = false,
    this.isReady = false,
    this.generatedFileName = 'attendance-oct-2026.pdf',
    this.generatedFileSize = '2.4 MB',
    this.generatedRowCount = 1716,
    this.generationDurationSeconds = 14,
  });

  final ReportType reportType;
  final DateRangePreset dateRangePreset;
  final String dateRangeText;
  final List<String> selectedEmployees;
  final int totalEmployeesCount;
  final ReportFormat reportFormat;
  final bool isGenerating;
  final bool isReady;
  final String generatedFileName;
  final String generatedFileSize;
  final int generatedRowCount;
  final int generationDurationSeconds;

  String get employeeSelectorLabel {
    if (selectedEmployees.isEmpty) {
      return 'All employees ($totalEmployeesCount)';
    }
    return '${selectedEmployees.length} of $totalEmployeesCount employees selected';
  }

  String get readySubtitle {
    return '${reportType.title} · 01–12 Oct 2026 · $totalEmployeesCount employees';
  }

  String get readyFileMetrics {
    final formattedRows = generatedRowCount >= 1000
        ? '${generatedRowCount ~/ 1000},${(generatedRowCount % 1000).toString().padLeft(3, '0')}'
        : '$generatedRowCount';
    return '$generatedFileSize · $formattedRows rows';
  }

  AdminReportsState copyWith({
    ReportType? reportType,
    DateRangePreset? dateRangePreset,
    String? dateRangeText,
    List<String>? selectedEmployees,
    int? totalEmployeesCount,
    ReportFormat? reportFormat,
    bool? isGenerating,
    bool? isReady,
    String? generatedFileName,
    String? generatedFileSize,
    int? generatedRowCount,
    int? generationDurationSeconds,
  }) {
    return AdminReportsState(
      reportType: reportType ?? this.reportType,
      dateRangePreset: dateRangePreset ?? this.dateRangePreset,
      dateRangeText: dateRangeText ?? this.dateRangeText,
      selectedEmployees: selectedEmployees ?? this.selectedEmployees,
      totalEmployeesCount: totalEmployeesCount ?? this.totalEmployeesCount,
      reportFormat: reportFormat ?? this.reportFormat,
      isGenerating: isGenerating ?? this.isGenerating,
      isReady: isReady ?? this.isReady,
      generatedFileName: generatedFileName ?? this.generatedFileName,
      generatedFileSize: generatedFileSize ?? this.generatedFileSize,
      generatedRowCount: generatedRowCount ?? this.generatedRowCount,
      generationDurationSeconds:
          generationDurationSeconds ?? this.generationDurationSeconds,
    );
  }
}
