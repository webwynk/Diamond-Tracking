import 'package:flutter/material.dart';

/// The 6 canonical empty state scenarios for Diamond Agritech Tracking.
///
/// Source of truth: Screen 28 (Empty States Reference Sheet) and
/// HTML design reference `screen_28_empty_states/code.html`.
enum EmptyStateType {
  /// Case 01: Initial state when no field officers have been created yet.
  noEmployees,

  /// Case 02: Radar idle state when no employees have started duty today.
  nobodyOnDuty,

  /// Case 03: Notification feed clear state when there are no alerts.
  noNotifications,

  /// Case 04: Filter criteria zero-match query state.
  filteredToNothing,

  /// Case 05: GPS/Route missing for an employee on a selected date.
  noRoute,

  /// Case 06: Detailed GPS route archived after 60-day retention window.
  routeExpired,
}

extension EmptyStateTypeX on EmptyStateType {
  /// Case label displayed in the top card header (e.g. "CASE 01 · NO EMPLOYEES").
  String get caseLabel => switch (this) {
    EmptyStateType.noEmployees => 'CASE 01 · NO EMPLOYEES',
    EmptyStateType.nobodyOnDuty => 'CASE 02 · NOBODY ON DUTY',
    EmptyStateType.noNotifications => 'CASE 03 · NO NOTIFICATIONS',
    EmptyStateType.filteredToNothing => 'CASE 04 · FILTERED TO NOTHING',
    EmptyStateType.noRoute => 'CASE 05 · NO ROUTE',
    EmptyStateType.routeExpired => 'CASE 06 · ROUTE EXPIRED',
  };

  /// System status code displayed in the top card header (e.g. "EMPTY_INIT").
  String get statusCode => switch (this) {
    EmptyStateType.noEmployees => 'EMPTY_INIT',
    EmptyStateType.nobodyOnDuty => 'RADAR_IDLE',
    EmptyStateType.noNotifications => 'FEED_CLEAR',
    EmptyStateType.filteredToNothing => 'QUERY_ZERO',
    EmptyStateType.noRoute => 'GPS_NULL',
    EmptyStateType.routeExpired => 'ARCHIVE_60D',
  };

  /// Primary headline for the empty state.
  String get title => switch (this) {
    EmptyStateType.noEmployees => 'No employees yet',
    EmptyStateType.nobodyOnDuty => 'No one is on duty',
    EmptyStateType.noNotifications => "You're all caught up",
    EmptyStateType.filteredToNothing => 'No results for these filters',
    EmptyStateType.noRoute => 'No location recorded',
    EmptyStateType.routeExpired => 'Route older than 60 days',
  };

  /// Explanatory description text.
  String get defaultDescription => switch (this) {
    EmptyStateType.noEmployees =>
      'Add your first team member to initiate regional tracking.',
    EmptyStateType.nobodyOnDuty =>
      'Nobody has started duty today in this agritech sector.',
    EmptyStateType.noNotifications =>
      'New alerts and dispatch notices will appear here.',
    EmptyStateType.filteredToNothing =>
      'Try removing one or more filters to view field records.',
    EmptyStateType.noRoute => 'This employee did not go on duty on 08 Oct.',
    EmptyStateType.routeExpired =>
      'Detailed routes are kept for 60 days. Totals are still available.',
  };

  /// Label for the action button, or null if no interactive action is needed.
  String? get actionLabel => switch (this) {
    EmptyStateType.noEmployees => 'Add employee',
    EmptyStateType.nobodyOnDuty => 'View team',
    EmptyStateType.noNotifications => null,
    EmptyStateType.filteredToNothing => 'Clear filters',
    EmptyStateType.noRoute => 'Pick another date',
    EmptyStateType.routeExpired => 'View summary',
  };

  /// Action icon displayed beside the label.
  IconData? get actionIcon => switch (this) {
    EmptyStateType.noEmployees => Icons.person_add_outlined,
    EmptyStateType.nobodyOnDuty => Icons.groups_outlined,
    EmptyStateType.noNotifications => null,
    EmptyStateType.filteredToNothing => Icons.filter_alt_off_outlined,
    EmptyStateType.noRoute => Icons.calendar_today_outlined,
    EmptyStateType.routeExpired => Icons.bar_chart_outlined,
  };

  /// True if the button uses filled brand primary style.
  bool get isPrimaryAction => this == EmptyStateType.noEmployees;

  /// Custom status badge text for passive cases without button.
  String? get pendingBadgeText => switch (this) {
    EmptyStateType.noNotifications => 'NO ACTIONS PENDING',
    _ => null,
  };
}
