import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/routes.dart';
import '../../../core/config/env.dart';
import '../../../core/logging/app_log.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/domain/auth_status.dart';
import '../data/notifications_repository.dart';
import '../domain/app_notification.dart';
import 'push_service.dart';

final Provider<NotificationsRepository> notificationsRepositoryProvider =
    Provider<NotificationsRepository>(
      (Ref ref) =>
          SupabaseNotificationsRepository(ref.watch(supabaseClientProvider)),
    );

final Provider<PushService> pushServiceProvider = Provider<PushService>(
  (Ref ref) =>
      Env.pushConfigured ? FirebasePushService() : const NoPushService(),
);

/// The signed-in user's notifications, live.
final StreamProvider<List<AppNotification>> notificationsProvider =
    StreamProvider.autoDispose<List<AppNotification>>((Ref ref) {
      final AuthStatus status = ref.watch(authStatusProvider);
      if (status is! SignedIn) {
        return Stream<List<AppNotification>>.value(const <AppNotification>[]);
      }
      return ref.watch(notificationsRepositoryProvider).watch(status.userId);
    });

final Provider<int> unreadCountProvider = Provider.autoDispose<int>(
  (Ref ref) =>
      ref
          .watch(notificationsProvider)
          .value
          ?.where((AppNotification n) => n.unread)
          .length ??
      0,
);

/// Where a notification about [requestId] opens, for [role].
String notificationTarget(AppRole role, int? requestId, {String? kind}) =>
    role == AppRole.admin
    ? (requestId == null
          ? Routes.adminNotifications
          : Routes.adminRequest(requestId))
    : kind == dutyOnAllowedKind
    ? Routes.userHome
    : (requestId == null
          ? Routes.userNotifications
          : Routes.userRequest(requestId));

/// The notification an employee gets when the admin allows duty on today
/// (L81): it opens Home, which reloads by itself.
const String dutyOnAllowedKind = 'duty_on_allowed';

/// An employee's request was decided.
const String requestDecidedKind = 'request_decided';

/// The server ended a forgotten duty at 11 PM; the data has the day.
const String dutyAutoOffKind = 'duty_auto_off';

/// The admin's notifications: a new attendance or leave request, and a
/// short duty to review.
const String attendanceRequestKind = 'attendance_request';
const String leaveRequestKind = 'leave_request';
const String shortDutyKind = 'short_duty';

/// Registers this phone for push after sign-in and opens tapped
/// notifications. Lives as long as the app.
final Provider<PushRegistrar> pushRegistrarProvider = Provider<PushRegistrar>((
  Ref ref,
) {
  final PushRegistrar r = PushRegistrar(ref);
  ref
    ..listen<AuthStatus>(
      authStatusProvider,
      (AuthStatus? _, AuthStatus next) => unawaited(r.onAuth(next)),
      fireImmediately: true,
    )
    ..onDispose(r.dispose);
  return r;
});

class PushRegistrar {
  PushRegistrar(this._ref);

  final Ref _ref;
  String? _token;
  StreamSubscription<String>? _refresh;
  StreamSubscription<PushOpen>? _opened;
  PushOpen? _pendingOpen;
  bool _hasPending = false;

  PushService get _push => _ref.read(pushServiceProvider);
  NotificationsRepository get _repo =>
      _ref.read(notificationsRepositoryProvider);

  Future<void> onAuth(AuthStatus status) async {
    _opened ??= _push.opened.listen(_open);
    if (status is! SignedIn || status.mustChangePassword) {
      await _refresh?.cancel();
      _refresh = null;
      _token = null;
      return;
    }
    if (_hasPending) {
      _hasPending = false;
      _open(_pendingOpen!);
    }
    try {
      final String? token = await _push.token();
      if (token == null) return;
      final String deviceId = await _ref.read(deviceIdStoreProvider).get();
      await _repo.setPushToken(deviceId, token);
      _token = token;
      _refresh ??= _push.tokenRefresh.listen((String t) async {
        try {
          await _repo.setPushToken(deviceId, t);
          _token = t;
        } on Object catch (e, s) {
          AppLog.failure('push token refresh', e, s);
        }
      });
    } on Object catch (e, s) {
      AppLog.failure('push register', e, s);
    }
  }

  void _open(PushOpen open) {
    final AuthStatus status = _ref.read(authStatusProvider);
    if (status is! SignedIn || status.mustChangePassword) {
      // Opened from a cold start before sign-in finished: open it after.
      _pendingOpen = open;
      _hasPending = true;
      return;
    }
    final String target = notificationTarget(
      status.role,
      open.requestId,
      kind: open.kind,
    );
    final GoRouter router = _ref.read(routerProvider);
    if (target == Routes.userHome) {
      // Home is the bottom of the stack: go back to it (L81).
      router.go(target);
    } else {
      unawaited(router.push(target));
    }
  }

  /// Call on logout, before signing out, so this phone stops getting the
  /// account's notifications.
  Future<void> clear() async {
    final String? token = _token;
    _token = null;
    if (token == null) return;
    try {
      await _repo.clearPushToken(token);
    } on Object catch (e, s) {
      AppLog.failure('push clear', e, s);
    }
  }

  void dispose() {
    unawaited(_refresh?.cancel());
    unawaited(_opened?.cancel());
  }
}
