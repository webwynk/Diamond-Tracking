import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_colors.dart';
import 'admin_notification_state.dart';

/// Provider exposing the administrative notifications controller.
final adminNotificationControllerProvider =
    NotifierProvider<AdminNotificationNotifier, AdminNotificationState>(
  AdminNotificationNotifier.new,
);

/// Riverpod 3 Notifier managing admin notifications, filtering, and read receipts.
class AdminNotificationNotifier extends Notifier<AdminNotificationState> {
  @override
  AdminNotificationState build() {
    return AdminNotificationState(
      notifications: _buildDefaultNotifications(),
      selectedFilter: AdminNotificationFilter.unread,
    );
  }

  void setFilter(AdminNotificationFilter filter) {
    state = state.copyWith(selectedFilter: filter);
  }

  void markAsRead(String id) {
    state = state.copyWith(
      notifications: state.notifications.map((item) {
        if (item.id != id) return item;
        return item.copyWith(isUnread: false);
      }).toList(),
    );
  }

  void markAllAsRead() {
    state = state.copyWith(
      notifications: state.notifications.map((item) {
        return item.copyWith(isUnread: false);
      }).toList(),
    );
  }

  List<AdminNotificationItem> _buildDefaultNotifications() {
    return const <AdminNotificationItem>[
      // 1. UNREAD — Alerts (Mock location)
      AdminNotificationItem(
        id: 'notif-1',
        title: 'Location flagged as mock',
        subtitle: 'Anil Sharma · DA-008',
        timestamp: '2:46 PM',
        category: AdminNotificationCategory.alerts,
        isUnread: true,
        icon: Icons.gpp_maybe_rounded,
        iconColor: AppColors.error,
        badgeColor: AppColors.errorBg,
        isEarlierToday: false,
      ),

      // 2. UNREAD — Alerts (Timeout/Dropout)
      AdminNotificationItem(
        id: 'notif-2',
        title: 'No update for 12 minutes',
        subtitle: 'Prakash Rao · DA-017',
        timestamp: '2:36 PM',
        category: AdminNotificationCategory.alerts,
        isUnread: true,
        icon: Icons.wifi_off_rounded,
        iconColor: AppColors.warning,
        badgeColor: AppColors.warningBg,
        isEarlierToday: false,
      ),

      // 3. UNREAD — Duty (Started shift)
      AdminNotificationItem(
        id: 'notif-3',
        title: 'Started duty',
        subtitle: 'Suresh Patel · DA-022',
        timestamp: '2:14 PM',
        category: AdminNotificationCategory.duty,
        isUnread: true,
        icon: Icons.play_arrow_rounded,
        iconColor: AppColors.success,
        badgeColor: AppColors.successBg,
        isEarlierToday: false,
      ),

      // 4. UNREAD — Visits (Farm Arrival)
      AdminNotificationItem(
        id: 'notif-4',
        title: 'Arrived at Shivpuri Farm',
        subtitle: 'Vijay Singh · DA-031',
        timestamp: '1:58 PM',
        category: AdminNotificationCategory.visits,
        isUnread: true,
        icon: Icons.pin_drop_rounded,
        iconColor: AppColors.primary600,
        badgeColor: AppColors.primary100,
        isEarlierToday: false,
      ),

      // 5. READ — Alerts (Low battery) — EARLIER TODAY
      AdminNotificationItem(
        id: 'notif-5',
        title: 'Battery below 15%',
        subtitle: 'Meena Kulkarni · DA-045',
        timestamp: '1:20 PM',
        category: AdminNotificationCategory.alerts,
        isUnread: false,
        icon: Icons.battery_alert_rounded,
        iconColor: AppColors.warning,
        badgeColor: AppColors.warningBg,
        isEarlierToday: true,
      ),

      // 6. READ — Alerts (Hardware/Security anomaly) — EARLIER TODAY
      AdminNotificationItem(
        id: 'notif-6',
        title: 'Login from a new device',
        subtitle: 'Dinesh Joshi · DA-052',
        timestamp: '11:42 AM',
        category: AdminNotificationCategory.alerts,
        isUnread: false,
        icon: Icons.phonelink_lock_rounded,
        iconColor: AppColors.error,
        badgeColor: AppColors.errorBg,
        isEarlierToday: true,
      ),

      // 7. READ — Duty (Ended shift) — EARLIER TODAY
      AdminNotificationItem(
        id: 'notif-7',
        title: 'Ended duty',
        subtitle: 'Lata Bhosale · DA-009',
        timestamp: '11:05 AM',
        category: AdminNotificationCategory.duty,
        isUnread: false,
        icon: Icons.stop_rounded,
        iconColor: AppColors.neutral400,
        badgeColor: AppColors.neutral100,
        isEarlierToday: true,
      ),
    ];
  }
}
