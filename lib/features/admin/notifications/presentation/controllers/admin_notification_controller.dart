import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/errors/app_exceptions.dart';
import '../../../../../data/repositories/supabase_notification_repository.dart';
import '../../../../../domain/entities/admin_notification.dart';
import '../../../../../domain/repositories/notification_repository.dart';
import '../../../employees/presentation/controllers/admin_employee_list_controller.dart';
import '../../../employees/presentation/controllers/admin_employee_list_state.dart';
import 'admin_notification_state.dart';

/// Provider exposing the admin notification centre.
///
/// Auto-disposed with the admin shell, so on sign-out the live channel closes,
/// the timers stop, and the next person to sign in on the same phone never sees
/// the previous admin's notifications.
final adminNotificationControllerProvider =
    NotifierProvider.autoDispose<
      AdminNotificationNotifier,
      AdminNotificationState
    >(AdminNotificationNotifier.new);

/// Loads the admin's notifications and keeps them current.
///
/// How it stays right (PRD F12, docs/08):
/// - The number on the bell is the SERVER's unread count, not a count of what is
///   loaded: the list may be one page of many.
/// - The filters (unread, duty, alerts, employee) are applied by the server
///   before a page is cut, so paging is correct under every filter.
/// - New notifications arrive over Realtime and are shown at once; when the
///   connection comes back, and every minute, the first page and the count are
///   read again, so a missed event cannot stay missed.
/// - Marking read is optimistic and undone if the server refuses.
/// - A load overtaken by a newer one (the admin changed the filter) is dropped.
/// - Nothing is invented: until the first page is in, the screen shows loading;
///   a failure is an error with Retry, never an empty "all caught up".
class AdminNotificationNotifier extends Notifier<AdminNotificationState> {
  static const int pageSize = 30;
  static const Duration _reconcileEvery = Duration(minutes: 1);
  static const Duration _typingPause = Duration(milliseconds: 350);

  List<AdminEmployeeItem> _roster = const <AdminEmployeeItem>[];
  final Set<String> _unknownTried = <String>{};
  StreamSubscription<NotificationEvent>? _events;
  Timer? _timer;
  Timer? _typing;
  int _ticket = 0;
  int? _cursor;
  bool _stopped = false;

  /// The first roster read has finished (successfully or not): only after it
  /// is a missing name worth another read.
  bool _rosterReady = false;

  NotificationRepository get _repo => ref.read(notificationRepositoryProvider);

  @override
  AdminNotificationState build() {
    ref.onDispose(_stop);
    Future<void>.microtask(_start);
    return const AdminNotificationState();
  }

  void _stop() {
    _stopped = true;
    _timer?.cancel();
    _typing?.cancel();
    _events?.cancel();
  }

  Future<void> _start() async {
    if (_stopped) return;
    try {
      _events = _repo.watch().listen(_onEvent);
    } on Object {
      // The feed still reloads on the timer below.
    }
    _timer = Timer.periodic(
      _reconcileEvery,
      (_) => unawaited(_loadFirst(quiet: true)),
    );
    await Future.wait<void>(<Future<void>>[_loadRoster(), _loadFirst()]);
  }

  // -------------------------------------------------------------------------
  // What the admin does
  // -------------------------------------------------------------------------

  void setFilter(AdminNotificationFilter filter) {
    if (filter == state.selectedFilter) return;
    state = state.copyWith(selectedFilter: filter);
    unawaited(_loadFirst());
  }

  /// Narrows the list to employees whose name or code contains [query]. The
  /// field updates at once; the list follows a moment after typing stops.
  void setEmployeeQuery(String query) {
    state = state.copyWith(employeeQuery: query);
    _typing?.cancel();
    _typing = Timer(_typingPause, () => unawaited(_loadFirst()));
  }

  /// Reads the first page again with the loading state (Retry).
  Future<void> reload() => _loadFirst();

  /// Reads the first page again quietly (pull to refresh).
  Future<void> refresh() => _loadFirst(quiet: true);

  /// Loads the next, older page.
  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoadingMore || state.isLoading) return;
    final ticket = _ticket;
    state = state.copyWith(isLoadingMore: true, loadMoreFailed: false);
    try {
      final page = await _fetch(before: _cursor);
      if (_stopped) return;
      if (ticket != _ticket) {
        // A reload took over and has the say on what is shown.
        state = state.copyWith(isLoadingMore: false);
        return;
      }
      final held = state.items.map((n) => n.id).toSet();
      _cursor = page.nextCursor ?? _cursor;
      state = state.copyWith(
        items: [
          ...state.items,
          ...page.items.where((n) => !held.contains(n.id)),
        ],
        hasMore: page.hasMore,
        isLoadingMore: false,
      );
      _learnNames(page.items);
    } on Object {
      if (_stopped) return;
      if (ticket != _ticket) {
        state = state.copyWith(isLoadingMore: false);
        return;
      }
      state = state.copyWith(isLoadingMore: false, loadMoreFailed: true);
    }
  }

  /// Marks one notification read for this admin. Undone if the server refuses.
  Future<void> markRead(int id) async {
    final index = state.items.indexWhere((n) => n.id == id);
    if (index == -1 || state.items[index].isRead) return;
    _setRead(id, read: true);
    try {
      await _repo.markRead(<int>[id]);
    } on Object {
      if (_stopped) return;
      _setRead(id, read: false);
      state = state.copyWith(
        actionError: 'Could not mark it as read. Please try again.',
      );
    }
  }

  /// Marks everything read for this admin, then reads the list again so it
  /// matches the server.
  Future<void> markAllRead() async {
    final ticket = ++_ticket;
    state = state.copyWith(
      items: [for (final n in state.items) n.copyWith(isRead: true)],
      unreadCountOrNull: 0,
    );
    try {
      await _repo.markAllRead();
    } on Object {
      if (_stopped) return;
      state = state.copyWith(
        actionError: 'Could not mark everything as read. Please try again.',
      );
    }
    if (ticket == _ticket) await _loadFirst(quiet: true);
  }

  void clearActionError() {
    state = state.copyWith(clearActionError: true);
  }

  // -------------------------------------------------------------------------
  // Loading
  // -------------------------------------------------------------------------

  /// The employees the name/code text matches, or null for no such filter.
  List<String>? _employeeIds() {
    final query = state.employeeQuery.trim().toLowerCase();
    if (query.isEmpty) return null;
    return <String>[
      for (final e in _roster)
        if (e.name.toLowerCase().contains(query) ||
            e.employeeCode.toLowerCase().contains(query))
          e.id,
    ];
  }

  List<AdminNotificationType>? get _types => switch (state.selectedFilter) {
    AdminNotificationFilter.duty => AdminNotificationType.dutyTypes,
    AdminNotificationFilter.alerts => AdminNotificationType.alertTypes,
    _ => null,
  };

  Future<NotificationPage> _fetch({int? before}) {
    return _repo.fetchPage(
      before: before,
      limit: pageSize,
      unreadOnly: state.selectedFilter == AdminNotificationFilter.unread,
      types: _types,
      employeeIds: _employeeIds(),
    );
  }

  Future<void> _loadFirst({bool quiet = false}) async {
    if (_stopped) return;
    final ticket = ++_ticket;
    if (!quiet) {
      state = state.copyWith(
        items: const <AdminNotification>[],
        hasMore: false,
        isLoading: true,
        isLoadingMore: false,
        clearError: true,
        refreshFailed: false,
        loadMoreFailed: false,
      );
    }

    // Typed text that matches nobody: nothing to ask the server for.
    final ids = _employeeIds();
    if (ids != null && ids.isEmpty) {
      state = state.copyWith(
        items: const <AdminNotification>[],
        hasMore: false,
        isLoading: false,
        clearError: true,
      );
      return;
    }

    try {
      final pageRequest = _fetch();
      final countRequest = _tolerate(_repo.unreadCount());
      final page = await pageRequest;
      final count = await countRequest;
      if (ticket != _ticket || _stopped) return;

      // A quiet refresh (the timer, a reconnect, pull to refresh) replaces the
      // newest page but keeps the older pages the admin already scrolled to, so
      // the list does not jump back to the top.
      final keepOlder =
          quiet &&
          page.items.isNotEmpty &&
          state.items.length > page.items.length;
      final older = keepOlder
          ? state.items.where((n) => n.id < page.items.last.id).toList()
          : const <AdminNotification>[];
      final keepDeeper = older.isNotEmpty;
      if (!keepDeeper) _cursor = page.nextCursor;
      state = state.copyWith(
        items: [...page.items, ...older],
        hasMore: keepDeeper ? state.hasMore : page.hasMore,
        isLoading: false,
        isLoadingMore: false,
        clearError: true,
        refreshFailed: false,
        loadMoreFailed: false,
        unreadCountOrNull: count,
      );
      _learnNames(page.items);
    } on AppException catch (e) {
      if (ticket != _ticket || _stopped) return;
      _failed(e.message, quiet: quiet);
    } on Object {
      if (ticket != _ticket || _stopped) return;
      _failed(
        'Could not load the notifications. Please try again.',
        quiet: quiet,
      );
    }
  }

  /// A failed refresh keeps what is shown and says it may be out of date; only
  /// a failed first load becomes an error screen.
  void _failed(String message, {required bool quiet}) {
    if (quiet && state.items.isNotEmpty) {
      state = state.copyWith(refreshFailed: true);
    } else {
      state = state.copyWith(
        isLoading: false,
        errorMessage: message,
        refreshFailed: false,
      );
    }
  }

  Future<T?> _tolerate<T>(Future<T> request) async {
    try {
      return await request;
    } on Object {
      return null;
    }
  }

  Future<void> _loadRoster() async {
    try {
      final roster = await ref.read(employeeRepositoryProvider).getEmployees();
      if (_stopped) return;
      _roster = roster;
      state = state.copyWith(names: _namesOf(roster));
    } on Object {
      // Names are a refinement: rows then say "An employee".
    } finally {
      _rosterReady = true;
    }
  }

  Map<String, ({String name, String? code})> _namesOf(
    List<AdminEmployeeItem> roster,
  ) => <String, ({String name, String? code})>{
    for (final e in roster) e.id: (name: e.name, code: e.employeeCode),
  };

  /// A notification about someone created after the roster was read: read the
  /// roster once more (once per such person).
  void _learnNames(List<AdminNotification> items) {
    if (!_rosterReady) return;
    final unknown = items
        .map((n) => n.employeeId)
        .where((id) => !state.names.containsKey(id))
        .where(_unknownTried.add)
        .toList();
    if (unknown.isNotEmpty) unawaited(_loadRoster());
  }

  // -------------------------------------------------------------------------
  // Live
  // -------------------------------------------------------------------------

  void _onEvent(NotificationEvent event) {
    switch (event) {
      case NotificationArrived(:final notification):
        _onArrived(notification);
      case NotificationConnectionChanged(:final connected):
        // Changes may have been missed while it was down, or before it came up.
        if (connected) unawaited(_loadFirst(quiet: true));
    }
  }

  void _onArrived(AdminNotification n) {
    if (state.items.any((held) => held.id == n.id)) return;
    final count = state.unreadCountOrNull;
    final ids = _employeeIds();
    final matchesType = switch (state.selectedFilter) {
      AdminNotificationFilter.duty => n.type.isDutyEvent,
      AdminNotificationFilter.alerts => n.type.isAlert,
      _ => true,
    };
    final matchesEmployee = ids == null || ids.contains(n.employeeId);
    state = state.copyWith(
      items: matchesType && matchesEmployee ? [n, ...state.items] : state.items,
      unreadCountOrNull: count == null ? null : count + 1,
    );
    _learnNames(<AdminNotification>[n]);
  }

  void _setRead(int id, {required bool read}) {
    final count = state.unreadCountOrNull;
    state = state.copyWith(
      items: [
        for (final n in state.items)
          if (n.id == id) n.copyWith(isRead: read) else n,
      ],
      unreadCountOrNull: count == null
          ? null
          : (read ? (count > 0 ? count - 1 : 0) : count + 1),
    );
  }
}
