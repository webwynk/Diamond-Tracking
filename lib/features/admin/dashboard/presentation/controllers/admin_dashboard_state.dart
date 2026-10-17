import 'package:flutter/foundation.dart';

import '../../../../../domain/entities/admin_activity_event.dart';

/// One row of the Recent activity feed on Screen 14, already worded.
@immutable
class AdminActivityItem {
  const AdminActivityItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.timeAgo,
  });

  final String id;
  final AdminActivityKind kind;
  final String title;
  final String subtitle;
  final String timeAgo;
}

/// State of the Recent activity feed on the admin Home.
///
/// The duty counts and the live-map card on Home come from the live feed
/// (`adminLiveMapControllerProvider`), so they always agree with the map.
@immutable
class AdminDashboardState {
  const AdminDashboardState({
    this.activities = const <AdminActivityItem>[],
    this.isLoading = true,
    this.errorMessage,
  });

  final List<AdminActivityItem> activities;

  /// True until the first load finishes (or fails).
  final bool isLoading;

  /// Why the first load failed. Null once loaded.
  final String? errorMessage;

  AdminDashboardState copyWith({
    List<AdminActivityItem>? activities,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AdminDashboardState(
      activities: activities ?? this.activities,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
