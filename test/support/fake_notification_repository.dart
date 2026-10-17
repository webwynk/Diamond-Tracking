import 'dart:async';

import 'package:diamond_tracking/data/repositories/supabase_notification_repository.dart';
import 'package:diamond_tracking/domain/entities/admin_notification.dart';
import 'package:diamond_tracking/domain/repositories/notification_repository.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

/// One call to [FakeNotificationRepository.fetchPage].
class PageCall {
  const PageCall({
    required this.before,
    required this.limit,
    required this.unreadOnly,
    required this.types,
    required this.employeeIds,
  });

  final int? before;
  final int limit;
  final bool unreadOnly;
  final List<AdminNotificationType>? types;
  final List<String>? employeeIds;
}

/// Test-only [NotificationRepository] that stands in for the server. It lives
/// in test/ so production code never contains a pretend backend. It applies the
/// filters, the cursor and the page size the way the real function does, so the
/// controller is tested against a server that behaves.
class FakeNotificationRepository implements NotificationRepository {
  FakeNotificationRepository({List<AdminNotification>? notifications})
    : all = notifications ?? <AdminNotification>[];

  /// Everything on the "server", newest first.
  List<AdminNotification> all;

  /// What this admin has read.
  final Set<int> read = <int>{};

  /// Set to make a call fail.
  Exception? pageError;
  Exception? countError;
  Exception? markError;

  final List<PageCall> pageCalls = <PageCall>[];
  final List<List<int>> markReadCalls = <List<int>>[];
  int markAllCalls = 0;
  int countCalls = 0;
  bool listening = false;

  final Map<int, Completer<void>> _gates = <int, Completer<void>>{};

  final StreamController<NotificationEvent> _events =
      StreamController<NotificationEvent>.broadcast(sync: true);

  void emit(NotificationEvent event) => _events.add(event);

  /// Holds back the answer of the [callNumber]-th page call (1-based) until
  /// [release].
  void gateCall(int callNumber) => _gates[callNumber] = Completer<void>();

  void release(int callNumber) => _gates[callNumber]?.complete();

  @override
  Future<NotificationPage> fetchPage({
    int? before,
    int limit = 30,
    bool unreadOnly = false,
    List<AdminNotificationType>? types,
    List<String>? employeeIds,
  }) async {
    pageCalls.add(
      PageCall(
        before: before,
        limit: limit,
        unreadOnly: unreadOnly,
        types: types,
        employeeIds: employeeIds,
      ),
    );
    final gate = _gates[pageCalls.length];
    if (gate != null) await gate.future;
    final failure = pageError;
    if (failure != null) throw failure;

    final matching = all.where((n) {
      if (before != null && n.id >= before) return false;
      if (unreadOnly && read.contains(n.id)) return false;
      if (types != null && !types.contains(n.type)) return false;
      if (employeeIds != null && !employeeIds.contains(n.employeeId)) {
        return false;
      }
      return true;
    }).toList()..sort((a, b) => b.id.compareTo(a.id));

    final page = matching.take(limit).toList();
    return NotificationPage(
      items: [for (final n in page) n.copyWith(isRead: read.contains(n.id))],
      hasMore: matching.length > limit,
      nextCursor: page.isEmpty ? null : page.last.id,
    );
  }

  @override
  Future<int> unreadCount() async {
    countCalls++;
    final failure = countError;
    if (failure != null) throw failure;
    return all.where((n) => !read.contains(n.id)).length;
  }

  @override
  Future<void> markRead(List<int> ids) async {
    markReadCalls.add(List<int>.of(ids));
    final failure = markError;
    if (failure != null) throw failure;
    read.addAll(ids);
  }

  @override
  Future<void> markAllRead() async {
    markAllCalls++;
    final failure = markError;
    if (failure != null) throw failure;
    read.addAll(all.map((n) => n.id));
  }

  @override
  Stream<NotificationEvent> watch() {
    listening = true;
    return _events.stream;
  }
}

/// A notification for tests, newest has the highest [id].
AdminNotification notification(
  int id, {
  AdminNotificationType type = AdminNotificationType.dutyOn,
  String employeeId = 'e-asha',
  Duration ago = const Duration(minutes: 5),
  DateTime? now,
  Map<String, dynamic> details = const <String, dynamic>{},
  String? sessionId,
}) {
  return AdminNotification(
    id: id,
    type: type,
    employeeId: employeeId,
    sessionId: sessionId,
    details: details,
    createdAt: (now ?? DateTime.now().toUtc()).subtract(ago),
  );
}

/// Provider override that feeds the notification centre from [repository].
Override notificationOverride(FakeNotificationRepository repository) =>
    notificationRepositoryProvider.overrideWithValue(repository);
