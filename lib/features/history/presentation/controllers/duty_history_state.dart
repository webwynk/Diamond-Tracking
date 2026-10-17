import 'package:flutter/foundation.dart';

import '../../../../domain/entities/duty_session.dart';

/// Visual status badge shown on a duty history row.
enum DutyHistoryChipType {
  /// Standard completed shift with no exceptions or flags.
  none,

  /// Shift terminated by 23:00 curfew job (PRD BR-2).
  autoEnded,

  /// Telemetry points triggered mock-GPS or physics anomaly flags (PRD BR-9).
  flagged,

  /// Day with zero tracked duty (weekend, holiday, or rest day).
  noDuty,
}

/// Filter options for employee duty history list.
enum DutyHistoryFilter {
  thisMonth('This month'),
  lastMonth('Last month'),
  autoEnded('Auto-ended'),
  custom('Custom');

  const DutyHistoryFilter(this.label);
  final String label;
}

/// Represents a single day / shift entry in the history list.
@immutable
class DutyHistoryItem {
  const DutyHistoryItem({
    required this.id,
    required this.date,
    required this.dateTitle,
    required this.chipType,
    required this.dutyTimeStr,
    required this.durationStr,
    required this.distanceStr,
    required this.visitsStr,
    this.flagCount = 0,
    this.rawSession,
  });

  final String id;
  final DateTime date;
  final String dateTitle;
  final DutyHistoryChipType chipType;
  final int flagCount;
  final String dutyTimeStr;
  final String durationStr;
  final String distanceStr;
  final String visitsStr;
  final DutySession? rawSession;

  bool get isNoDuty => chipType == DutyHistoryChipType.noDuty;

  DutyHistoryItem copyWith({
    String? id,
    DateTime? date,
    String? dateTitle,
    DutyHistoryChipType? chipType,
    int? flagCount,
    String? dutyTimeStr,
    String? durationStr,
    String? distanceStr,
    String? visitsStr,
    DutySession? rawSession,
  }) {
    return DutyHistoryItem(
      id: id ?? this.id,
      date: date ?? this.date,
      dateTitle: dateTitle ?? this.dateTitle,
      chipType: chipType ?? this.chipType,
      flagCount: flagCount ?? this.flagCount,
      dutyTimeStr: dutyTimeStr ?? this.dutyTimeStr,
      durationStr: durationStr ?? this.durationStr,
      distanceStr: distanceStr ?? this.distanceStr,
      visitsStr: visitsStr ?? this.visitsStr,
      rawSession: rawSession ?? this.rawSession,
    );
  }
}

/// Aggregated period metrics displayed in the #E8F3F8 summary card.
@immutable
class DutyHistorySummary {
  const DutyHistorySummary({
    this.periodLabel = '',
    this.totalDays = 0,
    this.totalHours = '0h 0m',
    this.totalKm = 0.0,
    this.totalVisits = 0,
  });

  final String periodLabel;
  final int totalDays;
  final String totalHours;
  final double totalKm;
  final int totalVisits;

  DutyHistorySummary copyWith({
    String? periodLabel,
    int? totalDays,
    String? totalHours,
    double? totalKm,
    int? totalVisits,
  }) {
    return DutyHistorySummary(
      periodLabel: periodLabel ?? this.periodLabel,
      totalDays: totalDays ?? this.totalDays,
      totalHours: totalHours ?? this.totalHours,
      totalKm: totalKm ?? this.totalKm,
      totalVisits: totalVisits ?? this.totalVisits,
    );
  }
}

/// Riverpod state model for Screen 12 (My Duty History).
@immutable
class DutyHistoryState {
  const DutyHistoryState({
    this.isLoading = false,
    this.filter = DutyHistoryFilter.thisMonth,
    this.summary = const DutyHistorySummary(),
    this.items = const <DutyHistoryItem>[],
    this.errorMessage,
  });

  final bool isLoading;
  final DutyHistoryFilter filter;
  final DutyHistorySummary summary;
  final List<DutyHistoryItem> items;
  final String? errorMessage;

  DutyHistoryState copyWith({
    bool? isLoading,
    DutyHistoryFilter? filter,
    DutyHistorySummary? summary,
    List<DutyHistoryItem>? items,
    String? errorMessage,
  }) {
    return DutyHistoryState(
      isLoading: isLoading ?? this.isLoading,
      filter: filter ?? this.filter,
      summary: summary ?? this.summary,
      items: items ?? this.items,
      errorMessage: errorMessage,
    );
  }
}
