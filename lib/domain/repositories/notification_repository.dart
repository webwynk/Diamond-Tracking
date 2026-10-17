import '../entities/admin_notification.dart';

/// One page of notifications, newest first.
class NotificationPage {
  const NotificationPage({
    required this.items,
    required this.hasMore,
    this.nextCursor,
  });

  final List<AdminNotification> items;

  /// More, older notifications exist.
  final bool hasMore;

  /// The id to pass as `before` to get the next page. It comes from the last row
  /// the server sent, even one this app skipped as unknown, so paging cannot
  /// stall on it.
  final int? nextCursor;
}

/// Something that happened to the notification feed while it was open.
sealed class NotificationEvent {
  const NotificationEvent();
}

/// A new notification was written.
class NotificationArrived extends NotificationEvent {
  const NotificationArrived(this.notification);

  final AdminNotification notification;
}

/// The live connection came up or went down. Coming up means events may have
/// been missed, so the listener must reload.
class NotificationConnectionChanged extends NotificationEvent {
  const NotificationConnectionChanged({required this.connected});

  final bool connected;
}

/// Contract for the admin notification centre (PRD F12).
///
/// Implemented by `SupabaseNotificationRepository`. Returns real server data or
/// throws an `AppException`; nothing is invented.
abstract class NotificationRepository {
  /// One page, newest first, with this admin's read state. The filters are
  /// applied by the server before the page is cut, so paging is correct under
  /// any of them.
  ///
  /// Throws [NetworkException] when offline, [UnauthorizedRoleException] when
  /// the caller is not an active admin, or [ServerException] otherwise.
  Future<NotificationPage> fetchPage({
    int? before,
    int limit = 30,
    bool unreadOnly = false,
    List<AdminNotificationType>? types,
    List<String>? employeeIds,
  });

  /// How many notifications from the last 30 days this admin has not read: the
  /// number on the bell. Counted by the server, not from what is loaded.
  Future<int> unreadCount();

  /// Marks these notifications read for this admin only.
  Future<void> markRead(List<int> ids);

  /// Marks every notification read for this admin only.
  Future<void> markAllRead();

  /// New notifications as they are written. Listening opens the connection;
  /// cancelling closes it. The stream never errors: a connection problem
  /// arrives as a [NotificationConnectionChanged].
  Stream<NotificationEvent> watch();
}
