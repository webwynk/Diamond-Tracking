import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/design/ds_colors.dart';
import '../../../core/design/ds_icons.dart';
import '../../../core/design/ds_layout.dart';
import '../../../core/design/ds_status.dart';
import '../../../core/design/ds_text.dart';
import '../../../core/time/clock_providers.dart';
import '../../../core/time/ist_format.dart';
import '../../../shared/ds/ds_button.dart';
import '../../../shared/ds/ds_chips.dart';
import '../../../shared/ds/ds_feedback.dart';
import '../../../shared/ds/ds_frame.dart';
import '../../duty/domain/duty_day.dart';
import '../../notifications/application/notifications_providers.dart';
import '../../notifications/domain/app_notification.dart';
import '../../routes/domain/history_month.dart' show fullDay;
import '../../users/application/users_providers.dart';
import '../../users/domain/profile.dart';
import '../application/requests_providers.dart';
import '../domain/app_request.dart';
import 'admin_request_parts.dart';
import 'my_requests_page.dart'
    show requestDays, requestKindLook, requestStatusLook;

/// Which kind of request the list shows.
enum RequestKindFilter {
  all('All', null),
  review('Review', RequestKind.dutyReview),
  attendance('Attendance', RequestKind.attendance),
  leave('Leave', RequestKind.leave);

  const RequestKindFilter(this.label, this.kind);

  final String label;
  final RequestKind? kind;

  bool matches(AppRequest r) => kind == null || r.kind == kind;

  DsStatus get tone => switch (this) {
    all => DsStatus.off,
    review => DsStatus.waiting,
    attendance => DsStatus.onDuty,
    leave => DsStatus.leave,
  };
}

/// The admin's Requests tab (design v2): what is waiting, by kind, with
/// quick decisions for short duties and leave; "Decided" shows the rest.
class AdminRequestsPage extends ConsumerStatefulWidget {
  const AdminRequestsPage({super.key});

  @override
  ConsumerState<AdminRequestsPage> createState() => _AdminRequestsPageState();
}

class _AdminRequestsPageState extends ConsumerState<AdminRequestsPage> {
  bool _decided = false;
  RequestKindFilter _kind = RequestKindFilter.all;

  @override
  Widget build(BuildContext context) {
    // A new notification usually means a new request: reload the lists.
    ref.listen<AsyncValue<List<AppNotification>>>(notificationsProvider, (
      AsyncValue<List<AppNotification>>? before,
      AsyncValue<List<AppNotification>> now,
    ) {
      final int? was = before?.value?.firstOrNull?.id;
      final int? latest = now.value?.firstOrNull?.id;
      if (was != null && latest != was) {
        ref.invalidate(adminRequestsProvider);
      }
    });
    final bool pendingOnly = !_decided;
    final AsyncValue<List<AppRequest>> list = ref.watch(
      adminRequestsProvider(pendingOnly),
    );
    final int? waiting = ref.watch(adminRequestsProvider(true)).value?.length;
    final AsyncValue<List<Profile>> users = ref.watch(usersListProvider);
    final Map<String, Profile> people = <String, Profile>{
      for (final Profile p in users.value ?? const <Profile>[]) p.id: p,
    };
    // Names come from the users list; when it failed, say so (L71).
    final bool namesFailed = users.hasError && !users.hasValue;
    final int limit = ref.watch(adminRequestsLimitProvider(pendingOnly));
    final List<AppRequest> all = <AppRequest>[
      for (final AppRequest r in list.value ?? const <AppRequest>[])
        if (pendingOnly || !r.isPending) r,
    ];
    final List<AppRequest> shown = all.where(_kind.matches).toList();
    final DateTime now = ref.watch(serverClockProvider).now();

    return Scaffold(
      backgroundColor: DsColors.surface,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () =>
              ref.refresh(adminRequestsProvider(pendingOnly).future),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              DsSpace.gutter,
              DsSpace.md,
              DsSpace.gutter,
              DsSpace.xl,
            ),
            children: <Widget>[
              _Header(
                waiting: waiting,
                decided: _decided,
                onDecided: (bool v) => setState(() => _decided = v),
              ),
              const SizedBox(height: DsSpace.md),
              _KindChips(
                selected: _kind,
                counts: <RequestKindFilter, int>{
                  for (final RequestKindFilter f in RequestKindFilter.values)
                    f: all.where(f.matches).length,
                },
                onPick: (RequestKindFilter f) => setState(() => _kind = f),
              ),
              const SizedBox(height: DsSpace.md),
              if (namesFailed) ...<Widget>[
                DsBanner(
                  kind: DsBannerKind.warning,
                  title: 'Names could not load',
                  actionLabel: 'Retry',
                  onAction: () => ref.invalidate(usersListProvider),
                ),
                const SizedBox(height: DsSpace.md),
              ],
              if (list.hasError && !list.hasValue)
                DsErrorState(
                  title: "Couldn't load requests",
                  message: 'Check the internet and try again.',
                  onRetry: () =>
                      ref.invalidate(adminRequestsProvider(pendingOnly)),
                )
              else if (!list.hasValue)
                const Padding(
                  padding: EdgeInsets.only(top: DsSpace.xxl),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (shown.isEmpty)
                DsEmptyState(
                  title: pendingOnly
                      ? 'Nothing waiting'
                      : 'Nothing decided yet',
                  message: pendingOnly
                      ? 'New attendance, leave and short-duty requests show '
                            'here.'
                      : 'Decided requests show here.',
                  icon: DsIcons.requests,
                )
              else ...<Widget>[
                for (final AppRequest r in shown) ...<Widget>[
                  AdminRequestCard(
                    request: r,
                    person: people[r.userId],
                    namesLoading: !users.hasValue,
                    now: now,
                  ),
                  const SizedBox(height: 10),
                ],
                if ((list.value?.length ?? 0) >= limit)
                  Center(
                    child: DsTextLink(
                      label: 'Show more',
                      onPressed: () => ref
                          .read(
                            adminRequestsLimitProvider(pendingOnly).notifier,
                          )
                          .more(),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// "Requests", "4 waiting for you" and the Waiting / Decided switch.
class _Header extends StatelessWidget {
  const _Header({
    required this.waiting,
    required this.decided,
    required this.onDecided,
  });

  final int? waiting;
  final bool decided;
  final ValueChanged<bool> onDecided;

  @override
  Widget build(BuildContext context) {
    Widget tab(String label, bool value) => Semantics(
      button: true,
      selected: decided == value,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onDecided(value),
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: decided == value ? DsColors.white : Colors.transparent,
            borderRadius: DsRadius.medium,
            boxShadow: decided == value ? DsShadow.card : null,
          ),
          child: Text(
            label,
            style: DsText.label.copyWith(
              fontWeight: FontWeight.w700,
              color: decided == value ? DsColors.ink : DsColors.text2,
            ),
          ),
        ),
      ),
    );
    final int? w = waiting;
    return Row(
      children: <Widget>[
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(left: DsSpace.xs),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Semantics(
                  header: true,
                  child: const Text('Requests', style: DsText.title),
                ),
                Text(
                  w == null
                      ? ' '
                      : w == 0
                      ? 'Nothing waiting'
                      : '$w waiting for you',
                  style: DsText.caption,
                ),
              ],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(3),
          decoration: const BoxDecoration(
            color: Color(0xFFEEF2F6),
            borderRadius: DsRadius.medium,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[tab('Waiting', false), tab('Decided', true)],
          ),
        ),
      ],
    );
  }
}

/// All · Short · Attendance · Leave, each with its count and colour.
class _KindChips extends StatelessWidget {
  const _KindChips({
    required this.selected,
    required this.counts,
    required this.onPick,
  });

  final RequestKindFilter selected;
  final Map<RequestKindFilter, int> counts;
  final ValueChanged<RequestKindFilter> onPick;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: <Widget>[
          for (final RequestKindFilter f
              in RequestKindFilter.values) ...<Widget>[
            if (f != RequestKindFilter.all) const SizedBox(width: 6),
            _KindChip(
              filter: f,
              count: counts[f] ?? 0,
              selected: f == selected,
              onTap: () => onPick(f),
            ),
          ],
        ],
      ),
    );
  }
}

class _KindChip extends StatelessWidget {
  const _KindChip({
    required this.filter,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final RequestKindFilter filter;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool all = filter == RequestKindFilter.all;
    final Color strong = all ? DsColors.ink : filter.tone.text;
    final Color soft = all ? const Color(0xFFEEF2F6) : filter.tone.tint;
    return Semantics(
      button: true,
      selected: selected,
      label: '${filter.label}, $count',
      excludeSemantics: true,
      child: Material(
        color: selected ? strong : DsColors.white,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  filter.label,
                  style: DsText.label.copyWith(
                    fontWeight: FontWeight.w700,
                    color: selected ? DsColors.white : strong,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  constraints: const BoxConstraints(minWidth: 18),
                  height: 18,
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected ? DsColors.white : soft,
                    borderRadius: DsRadius.pill,
                  ),
                  child: Text(
                    '$count',
                    style: DsText.micro.copyWith(
                      color: strong,
                      fontWeight: FontWeight.w700,
                    ),
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

/// One request on the list: who, when, the kind, what it is about, and
/// for waiting short duties and leave the decision buttons.
class AdminRequestCard extends ConsumerStatefulWidget {
  const AdminRequestCard({
    required this.request,
    required this.person,
    required this.now,
    this.namesLoading = false,
    super.key,
  });

  final AppRequest request;
  final Profile? person;
  final DateTime now;
  final bool namesLoading;

  @override
  ConsumerState<AdminRequestCard> createState() => _AdminRequestCardState();
}

class _AdminRequestCardState extends ConsumerState<AdminRequestCard> {
  DayStatus? _busy;

  Future<void> _decide(DayStatus d) async {
    final AppRequest r = widget.request;
    final String name = widget.person?.fullName ?? 'this person';
    if (d == DayStatus.absent) {
      final bool sure = await showDsConfirm(
        context: context,
        title: r.kind == RequestKind.leave
            ? 'Reject this leave?'
            : 'Mark $name absent?',
        message: r.kind == RequestKind.leave
            ? '$name gets a notification.'
            : 'The day counts as absent. $name gets a notification.',
        confirm: r.kind == RequestKind.leave ? 'Reject' : 'Mark absent',
        keep: 'Go back',
      );
      if (!sure || !mounted) return;
    }
    setState(() => _busy = d);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final String? error = await sendDecision(ref, r, d);
    if (mounted) setState(() => _busy = null);
    messenger.showSnackBar(
      SnackBar(content: Text(error ?? 'Saved: ${decisionLabel(r.kind, d)}.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppRequest r = widget.request;
    final (IconData icon, DsStatus tone) = requestKindLook(r);
    final String name =
        widget.person?.fullName ?? (widget.namesLoading ? '…' : 'Unknown');
    void open() => context.push(Routes.adminRequest(r.id));
    return RequestCardBox(
      onTap: open,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              RequestAvatar(
                initials: initialsOf(name == '…' ? '' : name),
                tone: tone,
                icon: icon,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text.rich(
                      TextSpan(
                        children: <InlineSpan>[
                          TextSpan(
                            text: name,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          TextSpan(
                            text: ' · ${requestAgo(r.createdAt, widget.now)}',
                            style: DsText.caption,
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DsText.body,
                    ),
                    Text(
                      adminRequestKind(r),
                      style: DsText.caption.copyWith(
                        color: tone.text,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: DsSpace.sm),
              if (!r.isPending)
                _StatusPill(request: r)
              else if (r.kind == RequestKind.attendance)
                _ReviewButton(onTap: open)
              else
                Semantics(
                  button: true,
                  label: 'Open request',
                  excludeSemantics: true,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEEF2F6),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      DsIcons.forward,
                      size: 14,
                      color: DsColors.ink,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          switch (r.kind) {
            RequestKind.dutyReview => _ReviewStrip(request: r),
            RequestKind.attendance => _AttendanceStrip(request: r),
            RequestKind.leave => _LeaveStrip(request: r),
          },
          if (r.isPending && r.kind != RequestKind.attendance) ...<Widget>[
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                for (final (int i, DayStatus d) in _quickChoices(
                  r,
                ).indexed) ...<Widget>[
                  if (i > 0) const SizedBox(width: 6),
                  Expanded(
                    child: _QuickButton(
                      label: decisionLabel(r.kind, d),
                      decision: d,
                      kind: r.kind,
                      busy: _busy == d,
                      enabled: _busy == null,
                      onTap: () => _decide(d),
                    ),
                  ),
                ],
              ],
            ),
          ] else if (!r.isPending && r.decisionNote != null) ...<Widget>[
            const SizedBox(height: DsSpace.sm),
            Text(
              'Note: ${r.decisionNote}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: DsText.caption,
            ),
          ],
        ],
      ),
    );
  }

  /// Duty review: Present, Half day, Absent. Leave: Reject, Approve.
  static List<DayStatus> _quickChoices(AppRequest r) =>
      r.kind == RequestKind.leave
      ? const <DayStatus>[DayStatus.absent, DayStatus.leave]
      : r.choices;
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.request});

  final AppRequest request;

  @override
  Widget build(BuildContext context) {
    final (DsStatus tone, String _) = requestStatusLook(request.status);
    return DsStatusPill(status: tone, label: requestOutcome(request));
  }
}

class _ReviewButton extends StatelessWidget {
  const _ReviewButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Review',
    excludeSemantics: true,
    child: Material(
      color: DsColors.ink,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                'Review',
                style: DsText.caption.copyWith(
                  color: DsColors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(DsIcons.forward, size: 13, color: DsColors.white),
            ],
          ),
        ),
      ),
    ),
  );
}

class _QuickButton extends StatelessWidget {
  const _QuickButton({
    required this.label,
    required this.decision,
    required this.kind,
    required this.busy,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final DayStatus decision;
  final RequestKind kind;
  final bool busy;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg) = switch (decision) {
      DayStatus.absent => (DsColors.dangerTint, DsColors.dangerText),
      DayStatus.halfDay => (DsColors.primaryTint, DsColors.deep),
      _ => (decisionColor(kind, decision), DsColors.white),
    };
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: enabled || busy ? bg : DsColors.disabled,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: SizedBox(
            height: 40,
            child: Center(
              child: busy
                  ? SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: fg,
                      ),
                    )
                  : Text(
                      label,
                      style: DsText.label.copyWith(
                        fontWeight: FontWeight.w700,
                        color: enabled ? fg : DsColors.text3,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Duty review: "10h 42m / 10h · 86.4 km", a bar (green at 10 h, amber
/// under) and the day.
class _ReviewStrip extends ConsumerWidget {
  const _ReviewStrip({required this.request});

  final AppRequest request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppRequest r = request;
    final DutyDay? d = r.day == null
        ? null
        : ref.watch(requestDayProvider((r.userId, r.day!))).value;
    final int? minutes = d?.workedMinutes;
    final bool met = minutes != null && minutes >= fullDay.inMinutes;
    final DsStatus tone = met ? DsStatus.present : DsStatus.waiting;
    final double part = minutes == null
        ? 0
        : (minutes / fullDay.inMinutes).clamp(0, 1).toDouble();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: tone.tint,
        borderRadius: DsRadius.medium,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: <InlineSpan>[
                      TextSpan(
                        text: minutes == null
                            ? '…'
                            : IstFormat.hoursMinutes(
                                Duration(minutes: minutes),
                              ),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const TextSpan(text: ' / 10h'),
                      if (d?.distanceM case final int m)
                        TextSpan(text: ' · ${reviewKm(m)}'),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DsText.label.copyWith(
                    color: DsColors.ink,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              if (r.day case final DateTime day) ...<Widget>[
                const SizedBox(width: 10),
                Text(
                  IstFormat.weekdayDay(day).replaceAll(',', ''),
                  maxLines: 1,
                  style: DsText.caption,
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: DsRadius.pill,
            child: LinearProgressIndicator(
              value: part,
              minHeight: 6,
              backgroundColor: DsColors.white,
              color: tone.dot,
            ),
          ),
        ],
      ),
    );
  }
}

/// Attendance: the message, the day, times and hours (ticked at 10 h).
class _AttendanceStrip extends StatelessWidget {
  const _AttendanceStrip({required this.request});

  final AppRequest request;

  @override
  Widget build(BuildContext context) {
    final AppRequest r = request;
    final DateTime? on = r.dutyOnAt;
    final DateTime? off = r.dutyOffAt;
    final Duration? worked = on == null || off == null
        ? null
        : off.difference(on);
    final bool met = worked != null && worked >= fullDay;
    final String? m = r.message?.trim();
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: const BoxDecoration(
        color: DsColors.surface,
        borderRadius: DsRadius.medium,
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: Color(0xFFCBD5E1),
              borderRadius: DsRadius.medium,
            ),
            child: Icon(
              r.photoCount > 0 ? DsIcons.camera : DsIcons.message,
              size: 18,
              color: const Color(0xFF475569),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (m != null && m.isNotEmpty)
                  Text(
                    '"$m"',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: DsText.label.copyWith(
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFF334155),
                    ),
                  ),
                Text.rich(
                  TextSpan(
                    children: <InlineSpan>[
                      TextSpan(
                        text: <String>[
                          if (r.day case final DateTime d) IstFormat.day(d),
                          if (on != null && off != null)
                            '${IstFormat.clock(on)}–${IstFormat.clock(off)}',
                        ].join(' · '),
                      ),
                      if (worked != null)
                        TextSpan(
                          text:
                              ' · ${IstFormat.hoursMinutes(worked)}'
                              '${met ? ' ✓' : ''}',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: met
                                ? DsColors.successText
                                : DsColors.warningText,
                          ),
                        ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DsText.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Leave: the dates and number of days, and the reason.
class _LeaveStrip extends StatelessWidget {
  const _LeaveStrip({required this.request});

  final AppRequest request;

  @override
  Widget build(BuildContext context) {
    final AppRequest r = request;
    final int n = r.dates.length;
    final String? m = r.message?.trim();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFFF7F5FF),
        borderRadius: DsRadius.medium,
      ),
      child: Row(
        children: <Widget>[
          Container(
            height: 28,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: DsStatus.leave.tint,
              borderRadius: DsRadius.pill,
            ),
            child: Text(
              '${requestDays(r)} · $n ${n == 1 ? 'day' : 'days'}',
              style: DsText.caption.copyWith(
                color: const Color(0xFF4C1D95),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: DsSpace.sm),
          Expanded(
            child: Text(
              m ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: DsText.caption,
            ),
          ),
        ],
      ),
    );
  }
}
