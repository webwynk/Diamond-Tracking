import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/logging/app_log.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/time/ist.dart';
import '../../../core/time/ist_format.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_error_view.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/domain/auth_status.dart';
import '../application/notifications_providers.dart';
import '../domain/app_notification.dart';

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  Future<void> _markRead(WidgetRef ref, [List<int>? ids]) async {
    try {
      await ref.read(notificationsRepositoryProvider).markRead(ids);
    } on Object catch (e, s) {
      AppLog.failure('markRead', e, s);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<AppNotification>> list = ref.watch(
      notificationsProvider,
    );
    final int unread = ref.watch(unreadCountProvider);
    final AuthStatus status = ref.watch(authStatusProvider);
    final AppRole role = status is SignedIn ? status.role : AppRole.employee;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: <Widget>[
          if (unread > 0)
            TextButton(
              onPressed: () => _markRead(ref),
              child: const Text('Mark all read'),
            ),
        ],
      ),
      body: list.when(
        data: (List<AppNotification> items) => items.isEmpty
            ? Padding(
                padding: AppSpacing.screen,
                child: AppEmptyState.noNotifications(),
              )
            : ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (BuildContext context, int i) {
                  final AppNotification n = items[i];
                  return ListTile(
                    tileColor: n.unread ? AppColors.primary50 : null,
                    leading: Icon(
                      _icon(n.kind),
                      color: n.unread
                          ? AppColors.primary600
                          : AppColors.textSecondary,
                    ),
                    title: Text(
                      n.title,
                      style: n.unread
                          ? AppTypography.bodyLarge.copyWith(
                              fontWeight: FontWeight.w700,
                            )
                          : AppTypography.bodyLarge,
                    ),
                    subtitle: Text(
                      <String>[
                        if (n.body case final String b) b,
                        _when(n.createdAt),
                      ].join('\n'),
                    ),
                    isThreeLine: n.body != null,
                    onTap: () {
                      if (n.unread) _markRead(ref, <int>[n.id]);
                      if (role == AppRole.employee &&
                          n.kind == dutyOnAllowedKind) {
                        context.go(Routes.userHome);
                      } else if (n.requestId case final int id) {
                        context.push(notificationTarget(role, id));
                      }
                    },
                  );
                },
              ),
        error: (_, _) =>
            AppErrorView(onRetry: () => ref.invalidate(notificationsProvider)),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  static IconData _icon(String kind) => switch (kind) {
    'attendance_request' => Icons.event_available_rounded,
    'leave_request' => Icons.beach_access_rounded,
    'short_duty' => Icons.timelapse_rounded,
    'request_decided' => Icons.task_alt_rounded,
    _ => Icons.notifications_rounded,
  };

  static String _when(DateTime t) =>
      '${IstFormat.date(Ist.dateOf(t))}, ${IstFormat.time(t)}';
}
