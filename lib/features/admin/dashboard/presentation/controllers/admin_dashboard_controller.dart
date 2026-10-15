import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'admin_dashboard_state.dart';

/// Global provider for observing and controlling the Admin Dashboard.
final adminDashboardControllerProvider =
    NotifierProvider<AdminDashboardNotifier, AdminDashboardState>(
  AdminDashboardNotifier.new,
);

/// Notifier governing the administrator's dashboard telemetry, live counts,
/// and recent operational activity feed for Screen 14.
class AdminDashboardNotifier extends Notifier<AdminDashboardState> {
  @override
  AdminDashboardState build() {
    final defaultActivities = _getDefaultActivities();
    return AdminDashboardState(
      isLoading: false,
      onDutyCount: 112,
      offDutyCount: 31,
      noUpdateCount: 4,
      needsCheckCount: 3,
      unreadNotificationsCount: 7,
      activities: defaultActivities,
    );
  }

  /// Reloads dashboard metrics and activity stream.
  Future<void> refreshDashboard() async {
    state = state.copyWith(isLoading: true);
    // Simulates fast 150ms network roundtrip
    await Future<void>.delayed(const Duration(milliseconds: 150));
    state = state.copyWith(
      isLoading: false,
      activities: _getDefaultActivities(),
    );
  }

  List<AdminActivityItem> _getDefaultActivities() {
    final now = DateTime.now();
    return [
      AdminActivityItem(
        id: 'act_1',
        type: AdminActivityType.dutyStarted,
        title: 'Suresh Patel started duty',
        subtitle: 'DA-022 · Route 4B',
        timeAgo: '2m',
        timestamp: now.subtract(const Duration(minutes: 2)),
      ),
      AdminActivityItem(
        id: 'act_2',
        type: AdminActivityType.locationFlagged,
        title: 'Anil Sharma — location flagged',
        subtitle: 'DA-008 · Geofence deviation',
        timeAgo: '14m',
        timestamp: now.subtract(const Duration(minutes: 14)),
      ),
      AdminActivityItem(
        id: 'act_3',
        type: AdminActivityType.reachedFarm,
        title: 'Vijay Singh reached Shivpuri Farm',
        subtitle: 'DA-031 · Check-in verified',
        timeAgo: '26m',
        timestamp: now.subtract(const Duration(minutes: 26)),
      ),
      AdminActivityItem(
        id: 'act_4',
        type: AdminActivityType.noUpdate,
        title: 'Prakash Rao — no update 12 min',
        subtitle: 'DA-017 · Low GPS signal',
        timeAgo: '31m',
        timestamp: now.subtract(const Duration(minutes: 31)),
      ),
    ];
  }
}
