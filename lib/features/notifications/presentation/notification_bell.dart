import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/domain/auth_status.dart';
import '../application/notifications_providers.dart';

/// The bell in the app bar, with the number of unread notifications.
class NotificationBell extends ConsumerWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int unread = ref.watch(unreadCountProvider);
    final AuthStatus status = ref.watch(authStatusProvider);
    final bool admin = status is SignedIn && status.role == AppRole.admin;
    return IconButton(
      tooltip: unread == 0 ? 'Notifications' : '$unread unread notifications',
      icon: Badge(
        isLabelVisible: unread > 0,
        label: Text(unread > 99 ? '99+' : '$unread'),
        child: const Icon(Icons.notifications_rounded),
      ),
      onPressed: () => context.push(
        admin ? Routes.adminNotifications : Routes.userNotifications,
      ),
    );
  }
}
