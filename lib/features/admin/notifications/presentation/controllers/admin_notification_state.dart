import 'package:flutter/foundation.dart';

import '../../../../../domain/entities/admin_notification.dart';

/// Filter chips of Screen 21 (Notification Centre — Admin). There is no Visits
/// chip yet: no visit events exist.
enum AdminNotificationFilter { unread, all, duty, alerts }

/// State of the admin notification centre.
@immutable
class AdminNotificationState {
  const AdminNotificationState({
    this.items = const <AdminNotification>[],
    this.names = const <String, ({String name, String? code})>{},
    this.selectedFilter = AdminNotificationFilter.unread,
    this.employeeQuery = '',
    this.unreadCountOrNull,
    this.hasMore = false,
    this.isLoading = true,
    this.isLoadingMore = false,
    this.errorMessage,
    this.refreshFailed = false,
    this.loadMoreFailed = false,
    this.actionError,
  });

  /// The loaded pages, newest first.
  final List<AdminNotification> items;

  /// Employee names by id, from the team roster.
  final Map<String, ({String name, String? code})> names;
  final AdminNotificationFilter selectedFilter;

  /// Text typed to narrow the list to matching employees (name or code).
  final String employeeQuery;

  /// The server's count of unread notifications from the last 30 days; null
  /// until it has been read. Not counted from [items], which may be one page of
  /// many.
  final int? unreadCountOrNull;
  final bool hasMore;

  /// The first page of the current filter is loading.
  final bool isLoading;
  final bool isLoadingMore;

  /// Why the first page failed. Null once it loaded.
  final String? errorMessage;

  /// A background reload failed: what is shown may be out of date.
  final bool refreshFailed;
  final bool loadMoreFailed;

  /// Why marking read failed (the change was undone).
  final String? actionError;

  /// The number on the bell: 0 until the server has answered.
  int get unreadCount => unreadCountOrNull ?? 0;

  bool get hasActiveEmployeeQuery => employeeQuery.trim().isNotEmpty;

  AdminNotificationState copyWith({
    List<AdminNotification>? items,
    Map<String, ({String name, String? code})>? names,
    AdminNotificationFilter? selectedFilter,
    String? employeeQuery,
    int? unreadCountOrNull,
    bool? hasMore,
    bool? isLoading,
    bool? isLoadingMore,
    String? errorMessage,
    bool clearError = false,
    bool? refreshFailed,
    bool? loadMoreFailed,
    String? actionError,
    bool clearActionError = false,
  }) {
    return AdminNotificationState(
      items: items ?? this.items,
      names: names ?? this.names,
      selectedFilter: selectedFilter ?? this.selectedFilter,
      employeeQuery: employeeQuery ?? this.employeeQuery,
      unreadCountOrNull: unreadCountOrNull ?? this.unreadCountOrNull,
      hasMore: hasMore ?? this.hasMore,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      refreshFailed: refreshFailed ?? this.refreshFailed,
      loadMoreFailed: loadMoreFailed ?? this.loadMoreFailed,
      actionError: clearActionError ? null : (actionError ?? this.actionError),
    );
  }
}
