import 'package:flutter/material.dart';

/// Categories of administrative alerts and notifications.
enum AdminNotificationCategory {
  duty,
  alerts,
  visits,
}

/// Filter modes for Screen 21 (Notification Centre — Admin).
enum AdminNotificationFilter {
  unread,
  all,
  duty,
  alerts,
  visits,
}

/// Domain entity representing an administrative notification or operational alert.
@immutable
class AdminNotificationItem {
  const AdminNotificationItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.timestamp,
    required this.category,
    required this.isUnread,
    required this.icon,
    required this.iconColor,
    required this.badgeColor,
    this.isEarlierToday = false,
  });

  final String id;
  final String title;
  final String subtitle;
  final String timestamp;
  final AdminNotificationCategory category;
  final bool isUnread;
  final IconData icon;
  final Color iconColor;
  final Color badgeColor;
  final bool isEarlierToday;

  AdminNotificationItem copyWith({
    String? id,
    String? title,
    String? subtitle,
    String? timestamp,
    AdminNotificationCategory? category,
    bool? isUnread,
    IconData? icon,
    Color? iconColor,
    Color? badgeColor,
    bool? isEarlierToday,
  }) {
    return AdminNotificationItem(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      timestamp: timestamp ?? this.timestamp,
      category: category ?? this.category,
      isUnread: isUnread ?? this.isUnread,
      icon: icon ?? this.icon,
      iconColor: iconColor ?? this.iconColor,
      badgeColor: badgeColor ?? this.badgeColor,
      isEarlierToday: isEarlierToday ?? this.isEarlierToday,
    );
  }
}

/// State representation for Screen 21 (Notification Centre — Admin).
@immutable
class AdminNotificationState {
  const AdminNotificationState({
    this.notifications = const <AdminNotificationItem>[],
    this.selectedFilter = AdminNotificationFilter.unread,
  });

  final List<AdminNotificationItem> notifications;
  final AdminNotificationFilter selectedFilter;

  /// Count of currently unread notifications.
  int get unreadCount => notifications.where((n) => n.isUnread).length;

  /// Notifications filtered by the currently active chip filter.
  List<AdminNotificationItem> get filteredNotifications {
    switch (selectedFilter) {
      case AdminNotificationFilter.unread:
        return notifications.where((n) => n.isUnread).toList();
      case AdminNotificationFilter.all:
        return notifications;
      case AdminNotificationFilter.duty:
        return notifications
            .where((n) => n.category == AdminNotificationCategory.duty)
            .toList();
      case AdminNotificationFilter.alerts:
        return notifications
            .where((n) => n.category == AdminNotificationCategory.alerts)
            .toList();
      case AdminNotificationFilter.visits:
        return notifications
            .where((n) => n.category == AdminNotificationCategory.visits)
            .toList();
    }
  }

  AdminNotificationState copyWith({
    List<AdminNotificationItem>? notifications,
    AdminNotificationFilter? selectedFilter,
  }) {
    return AdminNotificationState(
      notifications: notifications ?? this.notifications,
      selectedFilter: selectedFilter ?? this.selectedFilter,
    );
  }
}
