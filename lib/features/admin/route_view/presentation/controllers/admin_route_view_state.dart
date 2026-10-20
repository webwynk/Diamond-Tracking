import 'package:flutter/foundation.dart';

import '../../../../../core/utils/date_labels.dart';
import '../../../../../core/utils/duty_time_helper.dart';
import '../../../../../core/utils/route_geometry.dart';
import '../../../../../domain/entities/route_day.dart';

/// Where the load of the selected day stands.
enum RouteLoad { loading, loaded, failed }

/// The numbers under the map for one day. All of them come from the server's
/// session rows (distance, times, counts); none is measured on the phone.
@immutable
class RouteSummary {
  const RouteSummary({
    required this.sessionCount,
    required this.dutyDuration,
    required this.visitsCount,
    required this.flaggedPoints,
    required this.weakGpsPoints,
    required this.jumpCount,
    required this.shiftTimeRange,
    this.distanceKm,
    this.endNote,
    this.hasOpenSession = false,
  });

  final int sessionCount;

  /// Null when the server's figure is not available (an open session whose
  /// running distance could not be read). Never guessed.
  final double? distanceKm;
  final Duration dutyDuration;
  final int visitsCount;

  /// Fake-location points (left out of the line). "Flagged" means this and
  /// only this, the same as on the attendance and report screens.
  final int flaggedPoints;

  /// Points with a weak GPS signal (left out of the line). Information, not a
  /// warning.
  final int weakGpsPoints;

  /// Impossible jumps the line is broken at.
  final int jumpCount;

  /// "8:04 AM – 4:30 PM" (IST), or "8:04 AM – now" for an open session.
  final String shiftTimeRange;

  /// "Duty ended automatically", "Employee was blocked" or "On duty now".
  final String? endNote;
  final bool hasOpenSession;

  /// Builds the summary of [day]. Hours of an open session run to the server's
  /// clock, never the phone's.
  static RouteSummary from(RouteDay day, RouteAnalysis analysis) {
    var duration = Duration.zero;
    double? distance = 0;
    var visits = 0;
    for (final session in day.sessions) {
      duration += session.durationAt(day.serverNow);
      visits += session.visitsCount;
      final km = session.distanceKm;
      distance = (distance == null || km == null) ? null : distance + km;
    }

    final first = day.sessions.first;
    final last = day.sessions.last;
    final range =
        '${DutyTimeHelper.formatTime(first.startedAt)} – '
        '${last.endedAt == null ? 'now' : DutyTimeHelper.formatTime(last.endedAt!)}';

    return RouteSummary(
      sessionCount: day.sessions.length,
      distanceKm: distance,
      dutyDuration: duration,
      visitsCount: visits,
      flaggedPoints: analysis.fakeLocationCount,
      weakGpsPoints: analysis.weakGpsCount,
      jumpCount: analysis.jumpCount,
      shiftTimeRange: range,
      endNote: last.isOpen
          ? 'On duty now'
          : last.endedAutomatically
          ? 'Duty ended automatically'
          : last.endedByBlock
          ? 'Employee was blocked'
          : null,
      hasOpenSession: day.sessions.any((s) => s.isOpen),
    );
  }
}

/// State of the admin route view for one employee.
@immutable
class AdminRouteViewState {
  const AdminRouteViewState({
    required this.selectedDate,
    required this.isExpired,
    this.load = RouteLoad.loading,
    this.errorMessage,
    this.day,
    this.analysis,
    this.summary,
    this.isToday = false,
  });

  /// The IST calendar day being shown (time of day is midnight).
  final DateTime selectedDate;

  /// Older than the 30 days of stored points: the totals are still shown, the
  /// route is not.
  final bool isExpired;
  final RouteLoad load;
  final String? errorMessage;
  final RouteDay? day;
  final RouteAnalysis? analysis;

  /// Null when the employee had no duty that day.
  final RouteSummary? summary;

  /// The selected day is today on the server's clock.
  final bool isToday;

  bool get hasNoDuty => load == RouteLoad.loaded && summary == null;

  /// Duty happened but the phone left no usable point (and the route has not
  /// simply expired).
  bool get hasNoRoute =>
      load == RouteLoad.loaded &&
      summary != null &&
      !isExpired &&
      !(analysis?.hasAnythingToDraw ?? false);

  /// "Sat, 11 Oct".
  String get selectedDateText => DateLabels.shortDate(selectedDate);

  AdminRouteViewState copyWith({
    DateTime? selectedDate,
    bool? isExpired,
    RouteLoad? load,
    String? errorMessage,
    bool clearError = false,
    RouteDay? day,
    RouteAnalysis? analysis,
    RouteSummary? summary,
    bool clearDay = false,
    bool? isToday,
  }) {
    return AdminRouteViewState(
      selectedDate: selectedDate ?? this.selectedDate,
      isExpired: isExpired ?? this.isExpired,
      load: load ?? this.load,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      day: clearDay ? null : (day ?? this.day),
      analysis: clearDay ? null : (analysis ?? this.analysis),
      summary: clearDay ? null : (summary ?? this.summary),
      isToday: isToday ?? this.isToday,
    );
  }
}
