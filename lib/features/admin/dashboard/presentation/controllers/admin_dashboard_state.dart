import 'package:flutter/foundation.dart';

/// Semantic type of an administrative field event in the activity stream.
enum AdminActivityType {
  dutyStarted,
  locationFlagged,
  reachedFarm,
  noUpdate,
}

/// A single live event row in the Recent Activity feed on Screen 14.
@immutable
class AdminActivityItem {
  const AdminActivityItem({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.timeAgo,
    required this.timestamp,
  });

  final String id;
  final AdminActivityType type;
  final String title;
  final String subtitle;
  final String timeAgo;
  final DateTime timestamp;

  AdminActivityItem copyWith({
    String? id,
    AdminActivityType? type,
    String? title,
    String? subtitle,
    String? timeAgo,
    DateTime? timestamp,
  }) {
    return AdminActivityItem(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      timeAgo: timeAgo ?? this.timeAgo,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}

/// Riverpod state model for Screen 14 (Admin Home / Dashboard).
@immutable
class AdminDashboardState {
  const AdminDashboardState({
    this.isLoading = false,
    this.onDutyCount = 112,
    this.offDutyCount = 31,
    this.noUpdateCount = 4,
    this.needsCheckCount = 3,
    this.unreadNotificationsCount = 7,
    this.activities = const <AdminActivityItem>[],
    this.errorMessage,
  });

  final bool isLoading;
  final int onDutyCount;
  final int offDutyCount;
  final int noUpdateCount;
  final int needsCheckCount;
  final int unreadNotificationsCount;
  final List<AdminActivityItem> activities;
  final String? errorMessage;

  AdminDashboardState copyWith({
    bool? isLoading,
    int? onDutyCount,
    int? offDutyCount,
    int? noUpdateCount,
    int? needsCheckCount,
    int? unreadNotificationsCount,
    List<AdminActivityItem>? activities,
    String? errorMessage,
  }) {
    return AdminDashboardState(
      isLoading: isLoading ?? this.isLoading,
      onDutyCount: onDutyCount ?? this.onDutyCount,
      offDutyCount: offDutyCount ?? this.offDutyCount,
      noUpdateCount: noUpdateCount ?? this.noUpdateCount,
      needsCheckCount: needsCheckCount ?? this.needsCheckCount,
      unreadNotificationsCount:
          unreadNotificationsCount ?? this.unreadNotificationsCount,
      activities: activities ?? this.activities,
      errorMessage: errorMessage,
    );
  }
}
