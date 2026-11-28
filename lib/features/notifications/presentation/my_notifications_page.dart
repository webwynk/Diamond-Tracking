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
import '../../../shared/ds/ds_chips.dart';
import '../../../shared/ds/ds_feedback.dart';
import '../../../shared/ds/ds_frame.dart';
import '../application/notifications_providers.dart';
import '../domain/app_notification.dart';

/// The filters on the employee's notifications.
enum MyNotificationsFilter {
  all('All'),
  requests('Requests'),
  duty('Duty');

  const MyNotificationsFilter(this.label);

  final String label;

  bool matches(AppNotification n) => switch (this) {
    all => true,
    requests => n.kind == requestDecidedKind || n.requestId != null,
    duty => n.kind != requestDecidedKind && n.requestId == null,
  };
}

/// The icon and colours of a notification: a green tick for an approval,
/// a red cross for a rejection or absent, grey for duty turned off; for the
/// admin, blue attendance, purple leave and amber duty review.
(IconData, DsStatus) notificationLook(AppNotification n) {
  final String t = n.title.toLowerCase();
  return switch (n.kind) {
    requestDecidedKind when t.contains('reject') || t.contains('absent') => (
      DsIcons.close,
      DsStatus.absent,
    ),
    requestDecidedKind => (DsIcons.check, DsStatus.present),
    dutyAutoOffKind => (DsIcons.dutyOff, DsStatus.off),
    dutyOnAllowedKind => (DsIcons.dutyOn, DsStatus.onDuty),
    // The admin's kinds.
    attendanceRequestKind => (DsIcons.attendance, DsStatus.onDuty),
    leaveRequestKind => (DsIcons.sickLeave, DsStatus.sick),
    dutyReviewKind => (DsIcons.waiting, DsStatus.waiting),
    _ => (DsIcons.bell, DsStatus.onDuty),
  };
}

/// "2:30 PM" today, "Yesterday", "13 Nov" before that.
String notificationWhen(DateTime t, DateTime now) {
  final int days = Ist.dateOf(now).difference(Ist.dateOf(t)).inDays;
  if (days <= 0) return IstFormat.time(t);
  if (days == 1) return 'Yesterday';
  return IstFormat.shortDate(t);
}

/// "Notifications" (design v2), the employee's side: decisions on requests
/// and duty notices from the last 60 days, newest first.
class MyNotificationsPage extends ConsumerStatefulWidget {
  const MyNotificationsPage({super.key});

  @override
  ConsumerState<MyNotificationsPage> createState() =>
      _MyNotificationsPageState();
}

class _MyNotificationsPageState extends ConsumerState<MyNotificationsPage> {
  MyNotificationsFilter _filter = MyNotificationsFilter.all;

  Future<void> _markRead([List<int>? ids]) async {
    try {
      await ref.read(notificationsRepositoryProvider).markRead(ids);
    } on Object catch (e, s) {
      AppLog.failure('markRead', e, s);
    }
  }

  void _open(AppNotification n) {
    if (n.unread) _markRead(<int>[n.id]);
    if (n.kind == dutyOnAllowedKind) {
      context.go(Routes.userHome);
    } else if (n.requestId case final int id) {
      context.push(Routes.userRequest(id));
    } else if (n.dutyDayId case final int id) {
      context.push(Routes.userDay(id));
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
    final DateTime now = ref.read(serverClockProvider).now();
    return Scaffold(
      backgroundColor: DsColors.surface,
      body: Column(
        children: <Widget>[
          DsScreenHeader(
            title: 'Notifications',
            subtitle: !list.hasValue
                ? null
                : unread == 0
                ? 'All read'
                : '$unread unread',
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
                : all.isEmpty
                ? const DsEmptyState(
                    title: 'No notifications yet',
                    message: 'Decisions on your requests show up here.',
                    icon: DsIcons.bell,
                  )
                : ListView(
                    padding: EdgeInsets.fromLTRB(
                      DsSpace.gutter,
                      DsSpace.xs,
                      DsSpace.gutter,
                      DsSpace.xl + MediaQuery.paddingOf(context).bottom,
                    ),
                    children: <Widget>[
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        clipBehavior: Clip.none,
                        child: Row(
                          children: <Widget>[
                            for (final MyNotificationsFilter f
                                in MyNotificationsFilter.values) ...<Widget>[
                              if (f != MyNotificationsFilter.all)
                                const SizedBox(width: DsSpace.sm),
                              DsFilterChip(
                                label: f.label,
                                selected: f == _filter,
                                onTap: () => setState(() => _filter = f),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: DsSpace.sm),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: DsSpace.xs),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: Text('Recent', style: DsText.section),
                            ),
                            Text('Last 60 days', style: DsText.caption),
                          ],
                        ),
                      ),
                      const SizedBox(height: DsSpace.sm),
                      if (shown.isEmpty)
                        DsEmptyState(
                          title:
                              'No ${_filter.label.toLowerCase()} notifications',
                          icon: DsIcons.bell,
                        )
                      else
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: DsColors.white,
                            borderRadius: DsRadius.large,
                          ),
                          child: Column(
                            children: <Widget>[
                              for (final AppNotification n in shown)
                                NotificationRow(
                                  notification: n,
                                  when: notificationWhen(n.createdAt, now),
                                  onTap: () => _open(n),
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

/// One notification: round status icon, title, time, and a line under it.
/// Unread rows are tinted blue.
class NotificationRow extends StatelessWidget {
  const NotificationRow({
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
    final String sub = switch (n.body?.trim()) {
      final String b when b.isNotEmpty =>
        n.kind == requestDecidedKind ? 'Admin: $b' : b,
      _ =>
        n.requestId != null
            ? 'Tap to see the request'
            : n.dutyDayId != null
            ? 'Tap to see the day'
            : '',
    };
    return Semantics(
      button: true,
      label: '${n.unread ? 'Unread. ' : ''}${n.title}, $when. $sub',
      excludeSemantics: true,
      child: Material(
        color: n.unread ? DsColors.primaryTint : Colors.transparent,
        borderRadius: DsRadius.medium,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: <Widget>[
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    // On a blue unread row the circle is white.
                    color: n.unread
                        ? DsColors.white
                        : tone == DsStatus.off
                        ? DsColors.disabled
                        : tone.tint,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 20, color: tone.text),
                ),
                const SizedBox(width: DsSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              n.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: DsText.body.copyWith(
                                fontWeight: FontWeight.w700,
                                fontVariations: const <FontVariation>[
                                  FontVariation('wght', 700),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: DsSpace.sm),
                          Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Text(
                              when,
                              style: DsText.micro.copyWith(
                                color: DsColors.text3,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (sub.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 2),
                        Text(
                          sub,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: DsText.caption,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
