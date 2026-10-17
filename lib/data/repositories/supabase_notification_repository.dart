import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/errors/app_exceptions.dart';
import '../../domain/entities/admin_notification.dart';
import '../../domain/repositories/notification_repository.dart';
import '../network_failure.dart';

/// Provider exposing the notification repository.
final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return SupabaseNotificationRepository();
});

/// Supabase implementation of [NotificationRepository].
///
/// Reads through four functions that run as the signed-in admin, so the
/// row-level rules decide who sees what: `list_notifications` (a page with this
/// admin's read state and the filters applied before the page is cut),
/// `unread_notification_count`, `mark_notifications_read` and
/// `mark_all_notifications_read`. New notifications arrive over Realtime on
/// `public.notifications` (admins only, by the same rules).
class SupabaseNotificationRepository implements NotificationRepository {
  SupabaseNotificationRepository([SupabaseClient? client]) : _injected = client;

  final SupabaseClient? _injected;

  SupabaseClient get _client => _injected ?? Supabase.instance.client;

  @override
  Future<NotificationPage> fetchPage({
    int? before,
    int limit = 30,
    bool unreadOnly = false,
    List<AdminNotificationType>? types,
    List<String>? employeeIds,
  }) {
    return _run('load the notifications', () async {
      // One extra row tells whether another page exists.
      final rows = await _client.rpc<dynamic>(
        'list_notifications',
        params: <String, dynamic>{
          'p_before': before,
          'p_limit': limit + 1,
          'p_unread_only': unreadOnly,
          'p_types': types?.map((t) => t.wire).toList(),
          'p_employees': employeeIds,
        },
      );
      final list = rows is List ? rows : const <dynamic>[];
      final hasMore = list.length > limit;
      final shown = list.take(limit).whereType<Map<String, dynamic>>().toList();
      final items = <AdminNotification>[
        for (final row in shown) ?AdminNotification.tryParse(row),
      ];
      final lastId = shown.isEmpty ? null : shown.last['id'];
      return NotificationPage(
        items: items,
        hasMore: hasMore,
        nextCursor: lastId is num ? lastId.toInt() : null,
      );
    });
  }

  @override
  Future<int> unreadCount() {
    return _run('count the unread notifications', () async {
      final count = await _client.rpc<dynamic>('unread_notification_count');
      if (count is num) return count.toInt();
      return int.tryParse('$count') ?? 0;
    });
  }

  @override
  Future<void> markRead(List<int> ids) {
    if (ids.isEmpty) return Future.value();
    return _run('mark the notification as read', () async {
      await _client.rpc<dynamic>(
        'mark_notifications_read',
        params: <String, dynamic>{'p_ids': ids},
      );
    });
  }

  @override
  Future<void> markAllRead() {
    return _run('mark the notifications as read', () async {
      await _client.rpc<dynamic>('mark_all_notifications_read');
    });
  }

  @override
  Stream<NotificationEvent> watch() {
    late final StreamController<NotificationEvent> controller;
    RealtimeChannel? channel;

    void emit(NotificationEvent event) {
      if (!controller.isClosed) controller.add(event);
    }

    controller = StreamController<NotificationEvent>(
      onListen: () {
        try {
          channel = _client
              .channel('notifications-${DateTime.now().microsecondsSinceEpoch}')
              .onPostgresChanges(
                event: PostgresChangeEvent.insert,
                schema: 'public',
                table: 'notifications',
                callback: (payload) {
                  final notification = AdminNotification.tryParse(
                    payload.newRecord,
                  );
                  if (notification != null) {
                    emit(NotificationArrived(notification));
                  }
                },
              )
              .subscribe((status, error) {
                emit(
                  NotificationConnectionChanged(
                    connected: status == RealtimeSubscribeStatus.subscribed,
                  ),
                );
              });
        } on Object catch (e) {
          // An exception thrown from onListen would reach the zone as an
          // uncaught error. Say "not connected" instead; the feed still
          // reloads on a timer.
          debugPrint('NotificationRepository: could not open the channel: $e');
          emit(const NotificationConnectionChanged(connected: false));
        }
      },
      onCancel: () async {
        final open = channel;
        channel = null;
        if (open != null) await _client.removeChannel(open);
        unawaited(controller.close());
      },
    );
    return controller.stream;
  }

  Future<T> _run<T>(String action, Future<T> Function() body) async {
    try {
      return await body();
    } on AppException {
      rethrow;
    } on PostgrestException catch (e) {
      if (e.code == '42501') {
        throw const UnauthorizedRoleException(
          'Only active administrators can see notifications.',
        );
      }
      throw ServerException('Could not $action. Please try again.');
    } catch (e, st) {
      final network = asNetworkFailure(e);
      if (network != null) throw network;
      debugPrint('NotificationRepository: could not $action: $e\n$st');
      throw ServerException('Could not $action. Please try again.');
    }
  }
}
