import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/design/ds_colors.dart';
import '../../../core/design/ds_icons.dart';
import '../../../core/design/ds_layout.dart';
import '../../../core/design/ds_status.dart';
import '../../../core/design/ds_text.dart';
import '../../../core/logging/app_log.dart';
import '../../../core/time/clock_providers.dart';
import '../../../core/time/ist.dart';
import '../../../core/time/ist_format.dart';
import '../../../shared/ds/ds_button.dart';
import '../../../shared/ds/ds_feedback.dart';
import '../../../shared/ds/ds_frame.dart';
import '../../users/domain/profile.dart' show initialsOf;
import '../application/notifications_providers.dart';
import '../domain/app_notification.dart';
import 'my_notifications_page.dart' show notificationLook;

/// The filters on the admin's notifications.
enum AdminNotificationsFilter {
  all('All'),
  unread('Unread'),
  review('Duty review'),
  requests('Requests');

  const AdminNotificationsFilter(this.label);

  final String label;

  bool matches(AppNotification n) => switch (this) {
    all => true,
    unread => n.unread,
    review => n.kind == dutyReviewKind,
    requests => n.kind == attendanceRequestKind || n.kind == leaveRequestKind,
  };
}

/// Who a notification is about and a short line about it, read from the
/// server's text ("Rahul Das asked for attendance on 19 Nov 2026" gives
/// "Rahul Das" and "for 19 Nov 2026"). Falls back to the title and body.
(String who, String detail) adminNotificationText(AppNotification n) {
  final String body = (n.body ?? '').trim();
  (String, String)? split(String marker) {
    final int i = body.indexOf(marker);
    if (i <= 0) return null;
    return (body.substring(0, i).trim(), body.substring(i + marker.length));
  }

  switch (n.kind) {
    case attendanceRequestKind:
      if (split(' asked for attendance on ') case (final who, final day)) {
        return (who, 'for $day');
      }
    case leaveRequestKind:
      if (split(' asked for ') case (final who, final rest)) {
        // "3 day(s) of sick leave from 24 Nov".
        final RegExpMatch? m = RegExp(
          r'^(\d+) day\(s\) of (\w+) leave from (.+)$',
        ).firstMatch(rest);
        if (m != null) {
          final int days = int.parse(m.group(1)!);
          return (
            who,
            '${m.group(2)}, $days ${days == 1 ? 'day' : 'days'} '
                'from ${m.group(3)}',
          );
        }
        return (who, rest);
      }
    case dutyReviewKind:
      // "Rahul Das worked 10 h 42 min · 86.4 km"; older alerts say
      // "Rahul Das ended duty after 7 h 40 min".
      if (split(' worked ') case (final who, final worked)) {
        return (who, 'worked $worked');
      }
      if (split(' ended duty after ') case (final who, final worked)) {
        return (who, 'worked $worked');
      }
  }
  return (n.title, body);
}

/// The kind as a word: "Duty review", "Attendance", "Leave".
String adminNotificationKind(AppNotification n) => switch (n.kind) {
  dutyReviewKind => 'Duty review',
  attendanceRequestKind => 'Attendance',
  leaveRequestKind => 'Leave',
  _ => 'Notice',
};

/// "Today", "Yesterday" or "Earlier", by the IST date.
String notificationGroup(DateTime t, DateTime now) {
  final int days = Ist.dateOf(now).difference(Ist.dateOf(t)).inDays;
  if (days <= 0) return 'Today';
  if (days == 1) return 'Yesterday';
  return 'Earlier';
}

/// "Just now", "12 min ago", "3h ago" today; "6:15 PM" yesterday; "19 Nov"
/// before that.
String adminNotificationWhen(DateTime t, DateTime now) {
  final int days = Ist.dateOf(now).difference(Ist.dateOf(t)).inDays;
  if (days == 1) return IstFormat.time(t);
  if (days > 1) return IstFormat.shortDate(t);
  final Duration ago = now.difference(t);
  if (ago.inMinutes < 1) return 'Just now';
  if (ago.inMinutes < 60) return '${ago.inMinutes} min ago';
  return '${ago.inHours}h ago';
}

/// "Notifications" (design v2), the admin's side: new attendance and leave
/// requests and duty days to review, newest first, grouped by day. A
/// tap marks one read and opens its request. (The employee's are
/// MyNotificationsPage.)
class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  AdminNotificationsFilter _filter = AdminNotificationsFilter.all;

  Future<void> _markRead([List<int>? ids]) async {
    try {
      await ref.read(notificationsRepositoryProvider).markRead(ids);
    } on Object catch (e, s) {
      AppLog.failure('markRead', e, s);
    }
  }

  void _open(AppNotification n) {
    if (n.unread) _markRead(<int>[n.id]);
    if (n.requestId case final int id) {
      context.push(Routes.adminRequest(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<AppNotification>> list = ref.watch(
      notificationsProvider,
    );
    final List<AppNotification> all = list.value ?? const <AppNotification>[];
    final int unread = all.where((AppNotification n) => n.unread).length;
    final List<AppNotification> shown = all.where(_filter.matches).toList();
    final DateTime now = ref.watch(serverClockProvider).now();
    final Map<String, List<AppNotification>> groups =
        <String, List<AppNotification>>{};
    for (final AppNotification n in shown) {
      (groups[notificationGroup(n.createdAt, now)] ??= <AppNotification>[]).add(
        n,
      );
    }
    return Scaffold(
      backgroundColor: DsColors.surface,
      body: Column(
        children: <Widget>[
          DsScreenHeader(
            title: 'Notifications',
            onBack: () => Navigator.of(context).maybePop(),
            actions: <Widget>[
              if (unread > 0)
                DsIconButton(
                  icon: DsIcons.markRead,
                  label: 'Mark all as read',
                  onPressed: _markRead,
                ),
            ],
          ),
          Expanded(
            child: list.hasError && !list.hasValue
                ? DsErrorState(
                    title: "Couldn't load notifications",
                    message: 'Check the internet and try again.',
                    onRetry: () => ref.invalidate(notificationsProvider),
                  )
                : !list.hasValue
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: EdgeInsets.fromLTRB(
                      DsSpace.gutter,
                      DsSpace.xs,
                      DsSpace.gutter,
                      DsSpace.xl + MediaQuery.paddingOf(context).bottom,
                    ),
                    children: <Widget>[
                      _FilterBar(
                        selected: _filter,
                        unread: unread,
                        onPick: (AdminNotificationsFilter f) =>
                            setState(() => _filter = f),
                      ),
                      const SizedBox(height: DsSpace.lg),
                      if (shown.isEmpty)
                        _AllCaughtUp(filtered: all.isNotEmpty)
                      else
                        for (final String g in <String>[
                          'Today',
                          'Yesterday',
                          'Earlier',
                        ])
                          if (groups[g] case final List<AppNotification> items)
                            Padding(
                              padding: const EdgeInsets.only(
                                bottom: DsSpace.lg,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: <Widget>[
                                  _GroupTitle(title: g),
                                  for (final AppNotification n in items)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 10),
                                      child: AdminNotificationCard(
                                        notification: n,
                                        when: adminNotificationWhen(
                                          n.createdAt,
                                          now,
                                        ),
                                        onTap: () => _open(n),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// All · Unread (count) · Duty review · Requests on a grey track.
class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.selected,
    required this.unread,
    required this.onPick,
  });

  final AdminNotificationsFilter selected;
  final int unread;
  final ValueChanged<AdminNotificationsFilter> onPick;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: const BoxDecoration(
        color: Color(0xFFEEF2F6),
        borderRadius: DsRadius.large,
      ),
      child: Row(
        children: <Widget>[
          for (final AdminNotificationsFilter f
              in AdminNotificationsFilter.values)
            Expanded(
              child: Semantics(
                button: true,
                selected: f == selected,
                label: f == AdminNotificationsFilter.unread && unread > 0
                    ? '${f.label}, $unread'
                    : f.label,
                excludeSemantics: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onPick(f),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: f == selected
                          ? DsColors.white
                          : Colors.transparent,
                      borderRadius: DsRadius.medium,
                      boxShadow: f == selected ? DsShadow.card : null,
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            f.label,
                            style: DsText.label.copyWith(
                              fontWeight: FontWeight.w700,
                              color: f == selected
                                  ? DsColors.ink
                                  : DsColors.text2,
                            ),
                          ),
                          if (f == AdminNotificationsFilter.unread &&
                              unread > 0) ...<Widget>[
                            const SizedBox(width: 5),
                            Container(
                              constraints: const BoxConstraints(minWidth: 18),
                              height: 18,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                              ),
                              alignment: Alignment.center,
                              decoration: const BoxDecoration(
                                color: DsColors.primary,
                                borderRadius: DsRadius.pill,
                              ),
                              child: Text(
                                '$unread',
                                style: DsText.micro.copyWith(
                                  color: DsColors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// "Today ———".
class _GroupTitle extends StatelessWidget {
  const _GroupTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DsSpace.xs),
      child: Row(
        children: <Widget>[
          Semantics(
            header: true,
            child: Text(
              title,
              style: DsText.body.copyWith(
                fontWeight: FontWeight.w700,
                color: const Color(0xFF334155),
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(child: Divider(height: 1, color: Color(0xFFDCE3EA))),
        ],
      ),
    );
  }
}

/// One admin notification: the person's initials with a kind badge, name,
/// time, an unread dot, and "Kind · detail". Unread cards have a blue ring.
class AdminNotificationCard extends StatelessWidget {
  const AdminNotificationCard({
    required this.notification,
    required this.when,
    required this.onTap,
    super.key,
  });

  final AppNotification notification;
  final String when;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppNotification n = notification;
    final (IconData icon, DsStatus tone) = notificationLook(n);
    final (String who, String detail) = adminNotificationText(n);
    final String kind = adminNotificationKind(n);
    return Semantics(
      button: true,
      label: '${n.unread ? 'Unread. ' : ''}$who, $kind, $detail, $when',
      excludeSemantics: true,
      child: Container(
        decoration: BoxDecoration(
          color: DsColors.white,
          borderRadius: DsRadius.large,
          boxShadow: n.unread
              ? const <BoxShadow>[
                  BoxShadow(color: Color(0xFFB9DCEA), spreadRadius: 2),
                  BoxShadow(
                    color: Color(0x1A016893),
                    blurRadius: 22,
                    offset: Offset(0, 8),
                  ),
                ]
              : const <BoxShadow>[
                  BoxShadow(
                    color: Color(0x0A0F172A),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
        ),
        child: Material(
          type: MaterialType.transparency,
          borderRadius: DsRadius.large,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: <Widget>[
                  SizedBox(
                    width: 52,
                    height: 52,
                    child: Stack(
                      children: <Widget>[
                        Container(
                          width: 48,
                          height: 48,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: tone.tint,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            initialsOf(who),
                            style: DsText.body.copyWith(
                              color: tone.text,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: tone.text,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: DsColors.white,
                                width: 2,
                              ),
                            ),
                            child: Icon(icon, size: 11, color: DsColors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: DsSpace.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                who,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: DsText.body.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: DsSpace.sm),
                            Text(when, style: DsText.caption),
                            if (n.unread) ...<Widget>[
                              const SizedBox(width: DsSpace.sm),
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: DsColors.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text.rich(
                          TextSpan(
                            children: <InlineSpan>[
                              TextSpan(
                                text: kind,
                                style: TextStyle(
                                  color: tone.text,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (detail.isNotEmpty)
                                TextSpan(text: ' · $detail'),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: DsText.label.copyWith(
                            fontWeight: FontWeight.w400,
                            color: const Color(0xFF334155),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Nothing to show: a green tick and "You're all caught up".
class _AllCaughtUp extends StatelessWidget {
  const _AllCaughtUp({required this.filtered});

  /// There are notifications, just none for this filter.
  final bool filtered;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: DsSpace.xl, vertical: 36),
      decoration: const BoxDecoration(
        color: DsColors.white,
        borderRadius: DsRadius.large,
      ),
      child: Column(
        children: <Widget>[
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: DsColors.successTint,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              DsIcons.check,
              size: 30,
              color: DsColors.successText,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            filtered ? 'Nothing here' : "You're all caught up",
            style: DsText.section,
          ),
          const SizedBox(height: DsSpace.xs),
          Text(
            filtered
                ? 'No notifications match this filter.'
                : 'New requests show up here as soon as they are sent.',
            textAlign: TextAlign.center,
            style: DsText.body.copyWith(color: DsColors.text2),
          ),
        ],
      ),
    );
  }
}
