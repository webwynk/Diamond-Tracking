import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/app_notification.dart';

abstract interface class NotificationsRepository {
  /// The user's latest 50 notifications, newest first, kept up to date live.
  Stream<List<AppNotification>> watch(String userId);

  /// Marks [ids] read, or all when null.
  Future<void> markRead([List<int>? ids]);

  /// Registers this phone's push token (after sign-in, and when it changes).
  Future<void> setPushToken(String deviceId, String token);

  /// Removes it (on logout, while still signed in).
  Future<void> clearPushToken(String token);
}

class SupabaseNotificationsRepository implements NotificationsRepository {
  SupabaseNotificationsRepository(this._client);

  final SupabaseClient _client;

  @override
  Stream<List<AppNotification>> watch(String userId) => _client
      .from('notifications')
      .stream(primaryKey: <String>['id'])
      .eq('user_id', userId)
      .order('created_at', ascending: false)
      .limit(50)
      .map(
        (List<Map<String, dynamic>> rows) =>
            rows.map(AppNotification.fromRow).toList()..sort(
              (AppNotification a, AppNotification b) =>
                  b.createdAt.compareTo(a.createdAt),
            ),
      );

  @override
  Future<void> markRead([List<int>? ids]) => _client.rpc<Object?>(
    'mark_notifications_read',
    params: <String, Object?>{'p_ids': ids},
  );

  @override
  Future<void> setPushToken(String deviceId, String token) =>
      _client.rpc<Object?>(
        'set_push_token',
        params: <String, Object?>{'p_device_id': deviceId, 'p_token': token},
      );

  @override
  Future<void> clearPushToken(String token) => _client.rpc<Object?>(
    'clear_push_token',
    params: <String, Object?>{'p_token': token},
  );
}
