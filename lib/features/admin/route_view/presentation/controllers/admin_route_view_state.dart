import 'package:flutter/foundation.dart';

/// Type of waypoint marked along the daily route for Screen 23.
enum AdminWaypointType {
  start,
  end,
  visit,
  longStop,
  flaggedAnomaly,
}

/// Individual waypoint item along the daily telemetry route.
class AdminRouteWaypoint {
  const AdminRouteWaypoint({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.relativeX,
    required this.relativeY,
    this.visitNumber,
    this.dwellMinutes,
    this.hasGeofence = false,
  });

  final String id;
  final AdminWaypointType type;
  final String title;
  final String subtitle;
  final String time;
  final double relativeX; // 0.0 to 1.0 within map canvas
  final double relativeY; // 0.0 to 1.0 within map canvas
  final int? visitNumber;
  final int? dwellMinutes;
  final bool hasGeofence;
}

/// Daily summary telemetry metrics displayed in the bottom sheet.
class AdminRouteTelemetry {
  const AdminRouteTelemetry({
    required this.distanceKm,
    required this.dutyHours,
    required this.visitsCount,
    required this.flagsCount,
    required this.shiftTimeRange,
    required this.stopsSummary,
    required this.flagNote,
  });

  final String distanceKm;
  final String dutyHours;
  final int visitsCount;
  final int flagsCount;
  final String shiftTimeRange;
  final String stopsSummary;
  final String flagNote;

  static const defaultOct11 = AdminRouteTelemetry(
    distanceKm: '47.3 km',
    dutyHours: '8h 08m',
    visitsCount: 5,
    flagsCount: 1,
    shiftTimeRange: '8:04 AM – 6:12 PM',
    stopsSummary: '2 long stops',
    flagNote: '1 flagged point excluded from distance',
  );
}

/// State model for Screen 23 (Route View — Admin).
@immutable
class AdminRouteViewState {
  const AdminRouteViewState({
    required this.employeeId,
    required this.employeeName,
    required this.selectedDateText,
    required this.telemetry,
    required this.waypoints,
    this.selectedWaypointId,
    this.isMapSatellite = false,
    this.showFlagExcludedRoute = true,
  });

  final String employeeId;
  final String employeeName;
  final String selectedDateText;
  final AdminRouteTelemetry telemetry;
  final List<AdminRouteWaypoint> waypoints;
  final String? selectedWaypointId;
  final bool isMapSatellite;
  final bool showFlagExcludedRoute;

  AdminRouteViewState copyWith({
    String? employeeId,
    String? employeeName,
    String? selectedDateText,
    AdminRouteTelemetry? telemetry,
    List<AdminRouteWaypoint>? waypoints,
    String? selectedWaypointId,
    bool? isMapSatellite,
    bool? showFlagExcludedRoute,
  }) {
    return AdminRouteViewState(
      employeeId: employeeId ?? this.employeeId,
      employeeName: employeeName ?? this.employeeName,
      selectedDateText: selectedDateText ?? this.selectedDateText,
      telemetry: telemetry ?? this.telemetry,
      waypoints: waypoints ?? this.waypoints,
      selectedWaypointId: selectedWaypointId ?? this.selectedWaypointId,
      isMapSatellite: isMapSatellite ?? this.isMapSatellite,
      showFlagExcludedRoute:
          showFlagExcludedRoute ?? this.showFlagExcludedRoute,
    );
  }
}
