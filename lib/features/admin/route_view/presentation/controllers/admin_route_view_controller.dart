import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'admin_route_view_state.dart';

/// Riverpod 3 Notifier managing Screen 23 Route View.
class AdminRouteViewNotifier extends Notifier<AdminRouteViewState> {
  static final List<AdminRouteWaypoint> defaultWaypoints = [
    // 1. Shift Start
    const AdminRouteWaypoint(
      id: 'wp-start',
      type: AdminWaypointType.start,
      title: 'Shift Start',
      subtitle: 'Nashik Central Beat Unit',
      time: '8:04 AM',
      relativeX: 0.149,
      relativeY: 0.874,
    ),

    // 2. Long Stop 1
    const AdminRouteWaypoint(
      id: 'wp-stop-1',
      type: AdminWaypointType.longStop,
      title: 'Dwell Stop',
      subtitle: 'Dwell point: 32 mins',
      time: '9:00 AM',
      relativeX: 0.200,
      relativeY: 0.704,
      dwellMinutes: 32,
    ),

    // 3. Visit 1
    const AdminRouteWaypoint(
      id: 'wp-visit-1',
      type: AdminWaypointType.visit,
      title: 'Shinde Orchards',
      subtitle: 'Pesticide consultation & crop audit',
      time: '9:45 AM',
      relativeX: 0.267,
      relativeY: 0.589,
      visitNumber: 1,
    ),

    // 4. Visit 2
    const AdminRouteWaypoint(
      id: 'wp-visit-2',
      type: AdminWaypointType.visit,
      title: 'Kisan Agro Hub',
      subtitle: 'Fertilizer stock verification',
      time: '11:30 AM',
      relativeX: 0.364,
      relativeY: 0.542,
      visitNumber: 2,
    ),

    // 5. Visit 3 (Shivpuri Farm with 500m geofence)
    const AdminRouteWaypoint(
      id: 'wp-visit-3',
      type: AdminWaypointType.visit,
      title: 'Shivpuri Farm',
      subtitle: 'Soil testing & moisture reading',
      time: '1:45 PM',
      relativeX: 0.605,
      relativeY: 0.478,
      visitNumber: 3,
      hasGeofence: true,
    ),

    // 6. Visit 4
    const AdminRouteWaypoint(
      id: 'wp-visit-4',
      type: AdminWaypointType.visit,
      title: 'Someshwar Krishi Seva',
      subtitle: 'Dealer account reconciliation',
      time: '3:20 PM',
      relativeX: 0.636,
      relativeY: 0.383,
      visitNumber: 4,
    ),

    // 7. Long Stop 2 (Lunch)
    const AdminRouteWaypoint(
      id: 'wp-stop-2',
      type: AdminWaypointType.longStop,
      title: 'Dwell Stop (Lunch)',
      subtitle: 'Dwell point: 44 mins',
      time: '3:50 PM',
      relativeX: 0.523,
      relativeY: 0.316,
      dwellMinutes: 44,
    ),

    // 8. Flagged Anomaly Point
    const AdminRouteWaypoint(
      id: 'wp-flag-1',
      type: AdminWaypointType.flaggedAnomaly,
      title: 'GPS Jump / Mock Provider',
      subtitle: 'Excluded from payable distance calculation',
      time: '4:40 PM',
      relativeX: 0.364,
      relativeY: 0.138,
    ),

    // 9. Visit 5
    const AdminRouteWaypoint(
      id: 'wp-visit-5',
      type: AdminWaypointType.visit,
      title: 'Gangapur Cooperative',
      subtitle: 'Grape grower cluster handover',
      time: '5:10 PM',
      relativeX: 0.728,
      relativeY: 0.166,
      visitNumber: 5,
    ),

    // 10. Shift Terminus
    const AdminRouteWaypoint(
      id: 'wp-end',
      type: AdminWaypointType.end,
      title: 'Shift Terminus',
      subtitle: 'Gangapur Beat Outpost',
      time: '6:12 PM',
      relativeX: 0.862,
      relativeY: 0.182,
    ),
  ];

  static const List<String> availableDates = [
    'Fri, 10 Oct',
    'Sat, 11 Oct',
    'Sun, 12 Oct',
  ];

  @override
  AdminRouteViewState build() {
    return AdminRouteViewState(
      employeeId: 'emp-1',
      employeeName: 'Suresh Patel',
      selectedDateText: 'Sat, 11 Oct',
      telemetry: AdminRouteTelemetry.defaultOct11,
      waypoints: defaultWaypoints,
    );
  }

  void selectWaypoint(String? waypointId) {
    state = state.copyWith(selectedWaypointId: waypointId);
  }

  void toggleSatellite() {
    state = state.copyWith(isMapSatellite: !state.isMapSatellite);
  }

  void toggleFlagExcludedRoute() {
    state = state.copyWith(
      showFlagExcludedRoute: !state.showFlagExcludedRoute,
    );
  }

  void previousDate() {
    final currentIndex = availableDates.indexOf(state.selectedDateText);
    if (currentIndex > 0) {
      state = state.copyWith(
        selectedDateText: availableDates[currentIndex - 1],
      );
    }
  }

  void nextDate() {
    final currentIndex = availableDates.indexOf(state.selectedDateText);
    if (currentIndex >= 0 && currentIndex < availableDates.length - 1) {
      state = state.copyWith(
        selectedDateText: availableDates[currentIndex + 1],
      );
    }
  }
}

/// Provider for Screen 23 Route View Notifier.
final adminRouteViewControllerProvider =
    NotifierProvider<AdminRouteViewNotifier, AdminRouteViewState>(
  AdminRouteViewNotifier.new,
);
