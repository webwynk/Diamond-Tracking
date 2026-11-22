import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/design/ds_colors.dart';
import '../../../core/design/ds_icons.dart';
import '../../../core/design/ds_layout.dart';
import '../../../core/design/ds_text.dart';
import '../../../core/logging/app_log.dart';
import '../../../core/time/clock_providers.dart';
import '../../../core/time/ist_format.dart';
import '../../../shared/ds/ds_brand_bar.dart';
import '../../../shared/ds/ds_button.dart';
import '../../../shared/ds/ds_feedback.dart';
import '../../auth/domain/auth_status.dart';
import '../../duty/domain/duty_day.dart';
import '../../notifications/application/notifications_providers.dart';
import '../../notifications/domain/app_notification.dart';
import '../../notifications/presentation/my_notifications_page.dart'
    show NotificationRow, notificationWhen;
import '../../requests/application/requests_providers.dart';
import '../../requests/data/requests_repository.dart' show requestPageSize;
import '../../requests/domain/app_request.dart';
import '../../routes/application/route_providers.dart';
import '../../routes/domain/live_position.dart';
import '../../users/application/users_providers.dart';
import '../../users/domain/profile.dart';
import '../../visits/application/visits_providers.dart';

/// How often the dashboard reloads by itself (L85).
const Duration dashboardRefreshEvery = Duration(minutes: 2);

/// Recent notifications shown per page.
const int dashboardNotificationsPerPage = 10;

/// Today's figures for the dashboard, worked out from today's duty days,
/// the active employees and the live positions.
class DashboardToday {
  const DashboardToday({
    required this.onDuty,
    required this.employees,
    required this.noLocation,
    required this.notStarted,
    required this.onLeave,
    required this.metres,
  });

  factory DashboardToday.of({
    required List<DutyDay> days,
    required List<Profile> people,
    required List<LivePosition> positions,
    required DateTime now,
  }) {
    final Set<String> employees = <String>{
      for (final Profile p in people)
        if (p.isActive && p.role == AppRole.employee) p.id,
    };
    final Map<int, LivePosition> byDay = <int, LivePosition>{
      for (final LivePosition p in positions)
        if (p.dutyDayId != null) p.dutyDayId!: p,
    };
    final List<DutyDay> mine = <DutyDay>[
      for (final DutyDay d in days)
        if (employees.contains(d.userId)) d,
    ];
    final Set<String> withDay = <String>{
      for (final DutyDay d in mine)
        if (d.dutyOnAt != null || d.status == DayStatus.leave) d.userId!,
    };
    final List<DutyDay> onDuty = <DutyDay>[
      for (final DutyDay d in mine)
        if (d.status == DayStatus.onDuty) d,
    ];
    return DashboardToday(
      onDuty: onDuty.length,
      employees: employees.length,
      noLocation: onDuty
          .where((DutyDay d) => byDay[d.id]?.isStaleAt(now) ?? true)
          .length,
      notStarted: employees.difference(withDay).length,
      onLeave: mine.where((DutyDay d) => d.status == DayStatus.leave).length,
      metres: mine.fold<int>(0, (int a, DutyDay d) => a + (d.distanceM ?? 0)),
    );
  }

  final int onDuty;
  final int employees;
  final int noLocation;
  final int notStarted;
  final int onLeave;
  final int metres;
}

/// "Dashboard" (design v2), the admin's Home tab: who is on duty out of
/// everyone, today's visits and km, four tiles (requests, no location, not
/// started, on leave) and the recent notifications, 10 a page.
class AdminDashboardPage extends ConsumerStatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  ConsumerState<AdminDashboardPage> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends ConsumerState<AdminDashboardPage> {
  Timer? _timer;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(dashboardRefreshEvery, (_) => _reload());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _reload() {
    if (!mounted) return;
    ref
      ..invalidate(todayDaysProvider)
      ..invalidate(adminRequestsProvider)
      ..invalidate(usersListProvider)
      ..invalidate(todayVisitsCountProvider);
  }

  Future<void> _open(AppNotification n) async {
    if (n.unread) {
      try {
        await ref.read(notificationsRepositoryProvider).markRead(<int>[n.id]);
      } on Object catch (e, s) {
        AppLog.failure('markRead', e, s);
      }
    }
    if (!mounted) return;
    context.push(
      n.requestId == null
          ? Routes.adminNotifications
          : Routes.adminRequest(n.requestId!),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<DutyDay>> days = ref.watch(todayDaysProvider);
    final AsyncValue<List<Profile>> people = ref.watch(usersListProvider);
    final AsyncValue<List<AppRequest>> waiting = ref.watch(
      adminRequestsProvider(true),
    );
    final List<LivePosition> positions =
        ref.watch(livePositionsProvider).value ?? const <LivePosition>[];
    final int? visits = ref.watch(todayVisitsCountProvider).value;
    final AsyncValue<List<AppNotification>> notes = ref.watch(
      notificationsProvider,
    );
    final int unread = ref.watch(unreadCountProvider);
    final Profile? me = ref.watch(myProfileProvider).value;
    final DateTime now = ref.watch(serverClockProvider).now();
    final bool failed =
        (days.hasError && !days.hasValue) ||
        (people.hasError && !people.hasValue);
    final DashboardToday? today = days.hasValue && people.hasValue
        ? DashboardToday.of(
            days: days.value!,
            people: people.value!,
            positions: positions,
            now: now,
          )
        : null;
    final int? waitingCount = waiting.value?.length;
    final Widget list = RefreshIndicator(
      onRefresh: () async => _reload(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          DsSpace.gutter,
          DsSpace.lg,
          DsSpace.gutter,
          DsSpace.xl,
        ),
        children: <Widget>[
          _Header(date: IstFormat.dayDate(now), name: me?.fullName),
          const SizedBox(height: DsSpace.lg),
          if (failed)
            DsErrorState(
              title: "Couldn't load today",
              message: 'Check the internet and try again.',
              onRetry: _reload,
            )
          else ...<Widget>[
            _OnDutyCard(today: today, visits: visits),
            const SizedBox(height: DsSpace.md),
            _Tiles(
              today: today,
              waiting: waitingCount,
              waitingCapped:
                  waitingCount != null && waitingCount >= requestPageSize,
            ),
          ],
          const SizedBox(height: DsSpace.xl),
          _RecentNotifications(
            value: notes,
            unread: unread,
            page: _page,
            now: now,
            onPage: (int p) => setState(() => _page = p),
            onOpen: _open,
            onRetry: () => ref.invalidate(notificationsProvider),
          ),
        ],
      ),
    );
    return Scaffold(
      backgroundColor: DsColors.surface,
      body: Column(
        children: <Widget>[
          DsBrandBar(
            trailing: DsIconButton(
              icon: DsIcons.bell,
              label: 'Notifications',
              kind: DsIconButtonKind.soft,
              badge: unread,
              onPressed: () => context.push(Routes.adminNotifications),
            ),
          ),
          Expanded(
            child: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              child: list,
            ),
          ),
        ],
      ),
    );
  }
}

/// The account initials, today's date and "Hello, Arjun", under the brand
/// bar (the same as the employee Home).
class _Header extends StatelessWidget {
  const _Header({required this.date, required this.name});

  final String date;
  final String? name;

  @override
  Widget build(BuildContext context) {
    final String? n = name;
    final String first = n == null ? '' : n.trim().split(RegExp(r'\s+')).first;
    return Row(
      children: <Widget>[
        Semantics(
          container: true,
          button: true,
          label: 'My account',
          excludeSemantics: true,
          child: Material(
            color: DsColors.primary,
            shape: const CircleBorder(
              side: BorderSide(color: DsColors.white, width: 3),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => context.push(Routes.adminAccount),
              child: SizedBox.square(
                dimension: DsSize.tap,
                child: Center(
                  child: n == null
                      ? const Icon(
                          DsIcons.profile,
                          size: 20,
                          color: DsColors.white,
                        )
                      : Text(
                          initialsOf(n),
                          style: DsText.button.copyWith(color: DsColors.white),
                        ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: DsSpace.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                date,
                style: DsText.label.copyWith(fontWeight: FontWeight.w500),
              ),
              Semantics(
                header: true,
                child: Text(
                  first.isEmpty ? 'Hello' : 'Hello, $first',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DsText.title,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The big blue card: on duty out of everyone, with a ring, and today's
/// visits and km. Opens the live map.
class _OnDutyCard extends StatelessWidget {
  const _OnDutyCard({required this.today, required this.visits});

  final DashboardToday? today;
  final int? visits;

  @override
  Widget build(BuildContext context) {
    final DashboardToday? t = today;
    final String km = t == null ? '–' : (t.metres / 1000).round().toString();
    final TextStyle strong = DsText.body.copyWith(
      color: DsColors.white,
      fontWeight: FontWeight.w700,
    );
    final TextStyle soft = DsText.body.copyWith(color: DsColors.skyText);
    return Semantics(
      button: true,
      label: t == null
          ? 'On duty now. Open live map.'
          : '${t.onDuty} of ${t.employees} people on duty. Open live map.',
      excludeSemantics: true,
      child: Material(
        color: DsColors.primary,
        borderRadius: DsRadius.large,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.go(Routes.adminLiveMap),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'On duty now',
                            style: DsText.label.copyWith(
                              color: DsColors.skyText,
                            ),
                          ),
                          const SizedBox(height: 2),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text.rich(
                              TextSpan(
                                children: <InlineSpan>[
                                  TextSpan(
                                    text: t == null ? '–' : '${t.onDuty}',
                                    style: DsText.number.copyWith(
                                      color: DsColors.white,
                                      fontSize: 44,
                                    ),
                                  ),
                                  TextSpan(
                                    text: t == null ? '' : '/${t.employees}',
                                    style: DsText.value.copyWith(
                                      color: DsColors.skyText,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: DsSpace.md),
                    SizedBox.square(
                      dimension: 76,
                      child: CustomPaint(
                        painter: _RingPainter(
                          part: t == null || t.employees == 0
                              ? 0
                              : t.onDuty / t.employees,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: DsSpace.lg),
                Container(height: 1, color: const Color(0x33FFFFFF)),
                const SizedBox(height: 14),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: <InlineSpan>[
                            TextSpan(
                              text: visits == null ? '–' : '$visits',
                              style: strong,
                            ),
                            TextSpan(text: ' visits · ', style: soft),
                            TextSpan(text: km, style: strong),
                            TextSpan(text: ' km', style: soft),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: DsSpace.sm),
                    Text('Live map', style: strong),
                    const SizedBox(width: 4),
                    const Icon(
                      DsIcons.forward,
                      size: 18,
                      color: DsColors.white,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.part});

  final double part;

  @override
  void paint(Canvas canvas, Size size) {
    const double stroke = 9;
    final Rect r = Offset.zero & size;
    final Rect ring = r.deflate(stroke / 2);
    canvas.drawArc(
      ring,
      0,
      math.pi * 2,
      false,
      Paint()
        ..color = const Color(0x33FFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );
    if (part > 0) {
      canvas.drawArc(
        ring,
        -math.pi / 2,
        math.pi * 2 * part.clamp(0, 1),
        false,
        Paint()
          ..color = DsColors.liveOnDeep
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = stroke,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.part != part;
}

/// Requests, No location, Not started, On leave.
class _Tiles extends StatelessWidget {
  const _Tiles({
    required this.today,
    required this.waiting,
    required this.waitingCapped,
  });

  final DashboardToday? today;
  final int? waiting;
  final bool waitingCapped;

  @override
  Widget build(BuildContext context) {
    final DashboardToday? t = today;
    String n(int? v) => v == null ? '–' : '$v';
    final List<Widget> tiles = <Widget>[
      _Tile(
        icon: DsIcons.requests,
        count: waitingCapped ? '$waiting+' : n(waiting),
        label: 'Requests',
        sub: 'Needs your decision',
        bg: DsColors.primaryTint,
        fg: DsColors.primary,
        onTap: () => context.go(Routes.adminRequests),
      ),
      _Tile(
        icon: DsIcons.pin,
        count: n(t?.noLocation),
        label: 'No location',
        sub: 'Check now',
        bg: DsColors.warningTint,
        fg: DsColors.warningText,
        onTap: () => context.go(Routes.adminLiveMap),
      ),
      _Tile(
        icon: DsIcons.waiting,
        count: n(t?.notStarted),
        label: 'Not started',
        sub: 'No duty on yet',
        bg: const Color(0xFFEDF1F5),
        fg: const Color(0xFF475569),
        subColor: DsColors.text2,
        onTap: () => context.go(Routes.adminUsers),
      ),
      _Tile(
        icon: DsIcons.casualLeave,
        count: n(t?.onLeave),
        label: 'On leave',
        sub: 'Approved',
        bg: const Color(0xFFF1EDFE),
        fg: const Color(0xFF6D28D9),
        subColor: DsColors.text2,
        onTap: () => context.go(Routes.adminUsers),
      ),
    ];
    return Column(
      children: <Widget>[
        for (int i = 0; i < tiles.length; i += 2) ...<Widget>[
          if (i > 0) const SizedBox(height: DsSpace.md),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(child: tiles[i]),
                const SizedBox(width: DsSpace.md),
                Expanded(child: tiles[i + 1]),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.count,
    required this.label,
    required this.sub,
    required this.bg,
    required this.fg,
    required this.onTap,
    this.subColor,
  });

  final IconData icon;
  final String count;
  final String label;
  final String sub;
  final Color bg;
  final Color fg;
  final Color? subColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '$label $count, $sub',
    excludeSemantics: true,
    child: Material(
      color: bg,
      borderRadius: DsRadius.large,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(DsSpace.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 38,
                    height: 38,
                    decoration: const BoxDecoration(
                      color: DsColors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 18, color: fg),
                  ),
                  const Spacer(),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        count,
                        style: DsText.display.copyWith(color: DsColors.ink),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: DsSpace.md),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: DsText.body.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          sub,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: DsText.micro.copyWith(
                            color: subColor ?? fg,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(DsIcons.forward, size: 18, color: subColor ?? fg),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// The newest notifications, 10 a page, with page buttons and a link to
/// the notification centre.
class _RecentNotifications extends StatelessWidget {
  const _RecentNotifications({
    required this.value,
    required this.unread,
    required this.page,
    required this.now,
    required this.onPage,
    required this.onOpen,
    required this.onRetry,
  });

  final AsyncValue<List<AppNotification>> value;
  final int unread;
  final int page;
  final DateTime now;
  final ValueChanged<int> onPage;
  final ValueChanged<AppNotification> onOpen;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final List<AppNotification> all = value.value ?? const <AppNotification>[];
    const int per = dashboardNotificationsPerPage;
    final int pages = math.max(1, (all.length / per).ceil());
    final int p = page.clamp(0, pages - 1);
    final int start = p * per;
    final int end = math.min(start + per, all.length);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: DsSpace.xs),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Semantics(
                  header: true,
                  child: const Text(
                    'Recent notifications',
                    style: DsText.section,
                  ),
                ),
              ),
              if (unread > 0)
                Text(
                  '$unread new',
                  style: DsText.label.copyWith(color: DsColors.primary),
                ),
            ],
          ),
        ),
        const SizedBox(height: DsSpace.sm),
        if (value.hasError && !value.hasValue)
          DsErrorState(
            title: "Couldn't load notifications",
            message: 'Check the internet and try again.',
            onRetry: onRetry,
          )
        else if (!value.hasValue)
          const Padding(
            padding: EdgeInsets.all(DsSpace.xl),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (all.isEmpty)
          const DsEmptyState(
            title: 'No notifications yet',
            message: 'New requests and short duties show up here.',
            icon: DsIcons.bell,
          )
        else ...<Widget>[
          Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(
              color: DsColors.white,
              borderRadius: DsRadius.large,
            ),
            child: Column(
              children: <Widget>[
                for (final AppNotification n in all.sublist(start, end))
                  NotificationRow(
                    notification: n,
                    when: notificationWhen(n.createdAt, now),
                    onTap: () => onOpen(n),
                  ),
              ],
            ),
          ),
          if (pages > 1) ...<Widget>[
            const SizedBox(height: DsSpace.md),
            _Pager(
              text: '${start + 1}–$end of ${all.length}',
              page: p,
              pages: pages,
              onPage: onPage,
            ),
          ],
        ],
        const SizedBox(height: DsSpace.sm),
        Center(
          child: DsTextLink(
            label: 'Open notification centre',
            onPressed: () => context.push(Routes.adminNotifications),
          ),
        ),
      ],
    );
  }
}

/// "1–10 of 27" and ‹ 1 2 3 ›. Shows at most 5 page numbers around the
/// open one.
class _Pager extends StatelessWidget {
  const _Pager({
    required this.text,
    required this.page,
    required this.pages,
    required this.onPage,
  });

  final String text;
  final int page;
  final int pages;
  final ValueChanged<int> onPage;

  @override
  Widget build(BuildContext context) {
    final int from = math.max(0, math.min(page - 2, pages - 5));
    final int to = math.min(pages, from + 5);
    Widget button({
      required Widget child,
      required String label,
      required VoidCallback? onTap,
      bool current = false,
    }) => Semantics(
      button: true,
      label: label,
      selected: current,
      enabled: onTap != null,
      excludeSemantics: true,
      child: Material(
        color: current ? DsColors.primary : DsColors.disabled,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox.square(dimension: 36, child: Center(child: child)),
        ),
      ),
    );
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: DsText.caption,
          ),
        ),
        button(
          label: 'Previous page',
          onTap: page == 0 ? null : () => onPage(page - 1),
          child: Icon(
            DsIcons.back,
            size: 18,
            color: page == 0 ? DsColors.text3 : DsColors.ink,
          ),
        ),
        for (int i = from; i < to; i++) ...<Widget>[
          const SizedBox(width: 6),
          button(
            label: 'Page ${i + 1}',
            current: i == page,
            onTap: () => onPage(i),
            child: Text(
              '${i + 1}',
              style: DsText.label.copyWith(
                color: i == page ? DsColors.white : DsColors.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
        const SizedBox(width: 6),
        button(
          label: 'Next page',
          onTap: page >= pages - 1 ? null : () => onPage(page + 1),
          child: Icon(
            DsIcons.forward,
            size: 18,
            color: page >= pages - 1 ? DsColors.text3 : DsColors.ink,
          ),
        ),
      ],
    );
  }
}
