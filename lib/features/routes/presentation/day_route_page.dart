import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../core/design/ds_colors.dart';
import '../../../core/design/ds_icons.dart';
import '../../../core/design/ds_layout.dart';
import '../../../core/design/ds_status.dart';
import '../../../core/design/ds_text.dart';
import '../../../core/rules/duty_rules.dart';
import '../../../core/time/clock_providers.dart';
import '../../../core/time/ist.dart';
import '../../../core/time/ist_format.dart';
import '../../../shared/ds/ds_button.dart';
import '../../../shared/ds/ds_cards.dart';
import '../../../shared/ds/ds_chips.dart';
import '../../../shared/ds/ds_feedback.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/domain/auth_status.dart';
import '../../duty/domain/duty_day.dart';
import '../../duty/presentation/day_status_look.dart';
import '../../users/application/users_providers.dart';
import '../../users/domain/profile.dart';
import '../../visits/application/visits_providers.dart';
import '../../visits/domain/visit.dart';
import '../../visits/presentation/visit_detail_page.dart';
import '../../visits/presentation/visit_widgets.dart';
import '../application/route_providers.dart';
import '../domain/day_route.dart';
import '../domain/geo_point.dart';
import 'app_map.dart';
import 'day_pins.dart';
import 'route_parts.dart';

/// "Day route" (design v2): one day on a map, with the figures, the duty
/// bar and a Timeline / Visits sheet. Rahul opens it from History; the
/// admin opens it from the live map, reports and requests, and also sees
/// who it is and the 5 AM to 11 PM hours strip. While the duty is on it
/// reloads every 2 minutes.
class DayRoutePage extends ConsumerStatefulWidget {
  const DayRoutePage({required this.dayId, super.key});

  final int dayId;

  /// How often the day reloads while on duty.
  static const Duration refreshEvery = Duration(minutes: 2);

  @override
  ConsumerState<DayRoutePage> createState() => _DayRoutePageState();
}

class _DayRoutePageState extends ConsumerState<DayRoutePage> {
  final GlobalKey<AppMapState> _map = GlobalKey<AppMapState>();
  Timer? _timer;
  bool _fullMap = false;
  bool _visitsTab = false;

  /// When the day last arrived, for "updated 1 min ago".
  DateTime? _updatedAt;
  DayView? _lastView;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(DayRoutePage.refreshEvery, (_) {
      final DayView? view = ref.read(dayViewProvider(widget.dayId)).value;
      if (view?.day?.status == DayStatus.onDuty) _reload();
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _reload() => ref
    ..invalidate(dayViewProvider(widget.dayId))
    ..invalidate(dayVisitsProvider(widget.dayId));

  @override
  Widget build(BuildContext context) {
    final AuthStatus auth = ref.watch(authStatusProvider);
    final bool admin = auth is SignedIn && auth.role == AppRole.admin;
    final AsyncValue<DayView> view = ref.watch(dayViewProvider(widget.dayId));
    final AsyncValue<List<Visit>> visitsValue = ref.watch(
      dayVisitsProvider(widget.dayId),
    );
    final List<Visit> visits = List<Visit>.of(
      visitsValue.value ?? const <Visit>[],
    )..sort((Visit a, Visit b) => a.capturedAt.compareTo(b.capturedAt));
    final DayView? loaded = view.value;
    if (loaded != null && !identical(loaded, _lastView)) {
      _lastView = loaded;
      _updatedAt = DateTime.now();
    }
    final DutyDay? day = loaded?.day;
    final DayRoute? route = loaded?.route;
    final MediaQueryData media = MediaQuery.of(context);
    final double mapHeight = _fullMap
        ? media.size.height
        : (media.size.height * 0.4).clamp(260, 380).toDouble();

    return Scaffold(
      backgroundColor: DsColors.white,
      body: Stack(
        children: <Widget>[
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: mapHeight,
            child: AppMap(
              key: _map,
              lines: route?.segments ?? const <List<GeoPoint>>[],
              pins: dayPins(
                day,
                route,
                visits,
                nowTitle: admin ? 'Last position' : 'You',
              ),
              padding: EdgeInsets.only(
                top: media.padding.top + 64,
                bottom: _fullMap ? 0 : 32,
              ),
            ),
          ),
          if (!_fullMap)
            Positioned(
              top: mapHeight - 24,
              left: 0,
              right: 0,
              bottom: 0,
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  color: DsColors.white,
                  borderRadius: DsRadius.sheetTop,
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Color(0x1F0F172A),
                      blurRadius: 24,
                      offset: Offset(0, -8),
                    ),
                  ],
                ),
                child: view.hasError && loaded == null
                    ? DsErrorState(
                        title: "Couldn't load this day",
                        message: 'Check the internet and try again.',
                        onRetry: _reload,
                      )
                    : loaded == null
                    ? const Center(child: CircularProgressIndicator())
                    : _Sheet(
                        admin: admin,
                        day: day,
                        route: route,
                        visits: visits,
                        visitsFailed: visitsValue.hasError && visits.isEmpty,
                        onRetryVisits: () =>
                            ref.invalidate(dayVisitsProvider(widget.dayId)),
                        visitsTab: _visitsTab,
                        onTab: (bool v) => setState(() => _visitsTab = v),
                        updatedAt: _updatedAt,
                      ),
              ),
            ),
          Positioned(
            top: media.padding.top + DsSpace.md,
            left: DsSpace.lg,
            right: DsSpace.lg,
            child: Row(
              children: <Widget>[
                _Round(
                  child: DsIconButton(
                    icon: DsIcons.back,
                    label: 'Back',
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ),
                const SizedBox(width: DsSpace.sm),
                Expanded(
                  child: admin && day != null
                      ? Center(child: _DatePill(day: day))
                      : const SizedBox.shrink(),
                ),
                const SizedBox(width: DsSpace.sm),
                _Round(
                  child: DsIconButton(
                    icon: _fullMap ? DsIcons.shrink : DsIcons.expand,
                    label: _fullMap ? 'Show the details' : 'Full screen map',
                    onPressed: () => setState(() => _fullMap = !_fullMap),
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

/// A white round button with the floating shadow.
class _Round extends StatelessWidget {
  const _Round({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      shape: BoxShape.circle,
      boxShadow: DsShadow.card,
    ),
    child: child,
  );
}

/// "Today · Sat, 21 Nov" over the admin's map.
class _DatePill extends ConsumerWidget {
  const _DatePill({required this.day});

  final DutyDay day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DateTime today = Ist.dateOf(ref.watch(serverClockProvider).now());
    final String date = IstFormat.weekdayDay(day.day);
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: DsSpace.lg),
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: DsColors.white,
        borderRadius: DsRadius.pill,
        boxShadow: DsShadow.card,
      ),
      child: Text(
        day.day == today ? 'Today · $date' : date,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: DsText.body.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _Sheet extends ConsumerWidget {
  const _Sheet({
    required this.admin,
    required this.day,
    required this.route,
    required this.visits,
    required this.visitsFailed,
    required this.onRetryVisits,
    required this.visitsTab,
    required this.onTab,
    required this.updatedAt,
  });

  final bool admin;
  final DutyDay? day;
  final DayRoute? route;
  final List<Visit> visits;
  final bool visitsFailed;
  final VoidCallback onRetryVisits;
  final bool visitsTab;
  final ValueChanged<bool> onTab;
  final DateTime? updatedAt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DutyDay? d = day;
    final DateTime now = ref.watch(serverClockProvider).now();
    final Duration? worked = workedSoFar(d, now);
    final int metres = route?.distanceM ?? d?.distanceM ?? 0;
    final int stops = route?.stops.length ?? 0;
    return ListView(
      padding: EdgeInsets.fromLTRB(
        DsSpace.gutter,
        10,
        DsSpace.gutter,
        DsSpace.xl + MediaQuery.paddingOf(context).bottom,
      ),
      children: <Widget>[
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: const BoxDecoration(
              color: Color(0xFFCBD5E1),
              borderRadius: DsRadius.pill,
            ),
          ),
        ),
        const SizedBox(height: DsSpace.lg),
        if (admin)
          _PersonHeader(day: d)
        else if (d != null)
          _DateHeader(day: d),
        const SizedBox(height: DsSpace.lg),
        Row(
          children: <Widget>[
            if (admin) ...<Widget>[
              Expanded(
                child: DsStatTile(value: formatKm(metres), label: 'Distance'),
              ),
              const SizedBox(width: DsSpace.sm),
              Expanded(
                child: DsStatTile(
                  value: worked == null ? '–' : IstFormat.hoursMinutes(worked),
                  label: d?.status == DayStatus.onDuty ? 'On duty' : 'Worked',
                  status: DsStatus.present,
                ),
              ),
              const SizedBox(width: DsSpace.sm),
              Expanded(
                child: DsStatTile(
                  value: '$stops · ${visits.length}',
                  label: 'Stops · visits',
                  status: DsStatus.leave,
                ),
              ),
            ] else ...<Widget>[
              Expanded(
                child: DsStatTile(
                  value: worked == null ? '–' : IstFormat.hoursMinutes(worked),
                  label: d?.status == DayStatus.onDuty ? 'So far' : 'Worked',
                  status: DsStatus.present,
                ),
              ),
              const SizedBox(width: DsSpace.sm),
              Expanded(
                child: DsStatTile(value: formatKm(metres), label: 'Distance'),
              ),
              const SizedBox(width: DsSpace.sm),
              Expanded(
                child: DsStatTile(
                  value: '${visits.length}',
                  label: 'Visits',
                  status: DsStatus.leave,
                ),
              ),
            ],
          ],
        ),
        if (d?.dutyOnAt != null) ...<Widget>[
          const SizedBox(height: DsSpace.lg),
          if (admin)
            HoursStrip(day: d!, notes: route?.notes ?? const <RouteNote>[])
          else
            DutyGoalBar(day: d!, worked: worked ?? Duration.zero),
        ],
        if ((route?.mockedPoints ?? 0) > 0)
          FakeGpsWarning(points: route!.mockedPoints),
        const SizedBox(height: DsSpace.lg),
        _Tabs(visits: visits.length, visitsTab: visitsTab, onTab: onTab),
        const SizedBox(height: DsSpace.lg),
        if (visitsTab)
          _VisitsGrid(
            visits: visits,
            stops: route?.stops ?? const <RouteStop>[],
            failed: visitsFailed,
            onRetry: onRetryVisits,
          )
        else
          DayTimeline(
            day: d,
            route: route,
            visits: visits,
            updatedAt: updatedAt,
          ),
      ],
    );
  }
}

/// The time on duty: running while on duty, else what the server counted.
Duration? workedSoFar(DutyDay? d, DateTime now) {
  if (d == null || d.dutyOnAt == null) return null;
  if (d.status == DayStatus.onDuty) return now.difference(d.dutyOnAt!);
  final int? m = d.workedMinutes;
  return m == null ? null : Duration(minutes: m);
}

/// "Thursday" / "19 November" and the day's status (employee).
class _DateHeader extends StatelessWidget {
  const _DateHeader({required this.day});

  final DutyDay day;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(DateFormat('EEEE').format(day.day), style: DsText.label),
              Semantics(
                header: true,
                child: Text(
                  DateFormat('d MMMM').format(day.day),
                  style: DsText.title,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: DsSpace.sm),
        DsStatusPill(status: dayStatusTone(day), label: dayStatusText(day)),
      ],
    );
  }
}

/// Initials, name, code and status (admin).
class _PersonHeader extends ConsumerWidget {
  const _PersonHeader({required this.day});

  final DutyDay? day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DutyDay? d = day;
    final String? userId = d?.userId;
    final Profile? p = userId == null
        ? null
        : ref.watch(userByIdProvider(userId)).value;
    final DsStatus tone = d == null ? DsStatus.off : dayStatusTone(d);
    return Row(
      children: <Widget>[
        Container(
          width: 46,
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: tone.tint,
            borderRadius: DsRadius.medium,
          ),
          child: p == null
              ? Icon(DsIcons.profile, size: 20, color: tone.text)
              : Text(
                  initialsOf(p.fullName),
                  style: DsText.body.copyWith(
                    color: tone.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
        const SizedBox(width: DsSpace.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Semantics(
                header: true,
                child: Text(
                  p?.fullName ?? ' ',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DsText.section,
                ),
              ),
              if (p != null) Text(p.userCode, style: DsText.caption),
            ],
          ),
        ),
        if (d != null) ...<Widget>[
          const SizedBox(width: DsSpace.sm),
          DsStatusPill(status: tone, label: dayStatusText(d)),
        ],
      ],
    );
  }
}

/// The employee's duty bar: how far towards the 10 h goal, with duty on
/// and duty off times under it.
class DutyGoalBar extends StatelessWidget {
  const DutyGoalBar({required this.day, required this.worked, super.key});

  final DutyDay day;
  final Duration worked;

  @override
  Widget build(BuildContext context) {
    const Duration goal = DutyRules.minimumDuty;
    final bool onDuty = day.status == DayStatus.onDuty;
    final bool met = worked >= goal;
    final double part = math.min(1, worked.inSeconds / goal.inSeconds);
    final Color fill = met
        ? DsColors.successDot
        : onDuty
        ? DsColors.primary
        : DsColors.warningDot;
    final String middle = met
        ? '${goal.inHours} h goal met'
        : onDuty
        ? '${IstFormat.hoursMinutes(worked)} so far'
        : '${IstFormat.hoursMinutes(worked)} of ${goal.inHours} h';
    final TextStyle small = DsText.micro.copyWith(color: DsColors.text2);
    return Semantics(
      label:
          'Duty on ${IstFormat.time(day.dutyOnAt!)}. $middle.'
          '${day.dutyOffAt == null ? '' : ' Off ${IstFormat.time(day.dutyOffAt!)}.'}',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          ClipRRect(
            borderRadius: DsRadius.pill,
            child: SizedBox(
              height: 8,
              child: Stack(
                children: <Widget>[
                  const Positioned.fill(
                    child: ColoredBox(color: DsColors.disabled),
                  ),
                  FractionallySizedBox(
                    widthFactor: part,
                    heightFactor: 1,
                    child: ColoredBox(color: fill),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '${IstFormat.time(day.dutyOnAt!)} on',
                  style: small,
                  maxLines: 1,
                ),
              ),
              Text(
                middle,
                style: small.copyWith(
                  color: met ? DsColors.successText : DsColors.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Expanded(
                child: Text(
                  day.dutyOffAt != null
                      ? '${IstFormat.time(day.dutyOffAt!)} off'
                      : onDuty
                      ? 'Now'
                      : '',
                  textAlign: TextAlign.right,
                  style: small,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The admin's 5 AM to 11 PM strip: recorded time in blue, holes in the
/// route (phone off, no location) in amber, and a green dot for now.
class HoursStrip extends ConsumerWidget {
  const HoursStrip({required this.day, required this.notes, super.key});

  final DutyDay day;
  final List<RouteNote> notes;

  static const int startMinute = 5 * 60;
  static const int endMinute = 23 * 60;

  /// Where an instant falls on the strip, 0 to 1.
  static double place(DateTime t) =>
      ((Ist.minuteOfDay(t) - startMinute) / (endMinute - startMinute))
          .clamp(0, 1)
          .toDouble();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool onDuty = day.status == DayStatus.onDuty;
    final DateTime now = ref.watch(serverClockProvider).now();
    final DateTime from = day.dutyOnAt!;
    final DateTime to = day.dutyOffAt ?? (onDuty ? now : from);
    final List<RouteNote> holes = <RouteNote>[
      for (final RouteNote n in notes)
        if (n.to.isAfter(from) && n.from.isBefore(to)) n,
    ];
    Widget legend(Color c, String label, {bool round = false}) => Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: c,
            borderRadius: round ? null : BorderRadius.circular(3),
            shape: round ? BoxShape.circle : BoxShape.rectangle,
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: DsText.micro.copyWith(color: DsColors.slate)),
      ],
    );
    return Semantics(
      label:
          'Duty from ${IstFormat.time(from)}'
          '${onDuty ? ' until now' : ' to ${IstFormat.time(to)}'}'
          '${holes.isEmpty ? '' : ', ${holes.length} with no route'}',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SizedBox(
            height: 14,
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints c) {
                final double w = c.maxWidth;
                Widget span(DateTime a, DateTime b, Color color) {
                  final double l = place(a) * w;
                  final double r = place(b) * w;
                  return Positioned(
                    left: l,
                    width: math.max(2, r - l),
                    top: 0,
                    bottom: 0,
                    child: ColoredBox(color: color),
                  );
                }

                return ClipRRect(
                  borderRadius: DsRadius.pill,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: <Widget>[
                      const Positioned.fill(
                        child: ColoredBox(color: DsColors.disabled),
                      ),
                      span(from, to, DsColors.primary),
                      for (final RouteNote n in holes)
                        span(
                          n.from.isBefore(from) ? from : n.from,
                          n.to.isAfter(to) ? to : n.to,
                          DsColors.warningDot,
                        ),
                      if (onDuty)
                        Positioned(
                          left: place(now) * w - 6,
                          top: 1,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: DsColors.successDot,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: DsColors.white,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              for (final String h in <String>['5 AM', '11 AM', '5 PM', '11 PM'])
                Text(h, style: DsText.micro.copyWith(color: DsColors.text2)),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 14,
            runSpacing: 4,
            children: <Widget>[
              legend(DsColors.primary, 'Recorded'),
              legend(DsColors.warningDot, 'No route'),
              if (onDuty) legend(DsColors.successDot, 'Now', round: true),
            ],
          ),
        ],
      ),
    );
  }
}

/// Timeline | Visits · N.
class _Tabs extends StatelessWidget {
  const _Tabs({
    required this.visits,
    required this.visitsTab,
    required this.onTab,
  });

  final int visits;
  final bool visitsTab;
  final ValueChanged<bool> onTab;

  @override
  Widget build(BuildContext context) {
    Widget tab(String label, bool selected, VoidCallback onTap) => Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        excludeSemantics: true,
        child: Material(
          color: selected ? DsColors.ink : Colors.transparent,
          borderRadius: DsRadius.pill,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              height: 42,
              child: Center(
                child: Text(
                  label,
                  style: DsText.body.copyWith(
                    fontWeight: FontWeight.w700,
                    color: selected ? DsColors.white : DsColors.text2,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: const BoxDecoration(
        color: DsColors.surface,
        borderRadius: DsRadius.pill,
      ),
      child: Row(
        children: <Widget>[
          tab('Timeline', !visitsTab, () => onTab(false)),
          tab('Visits · $visits', visitsTab, () => onTab(true)),
        ],
      ),
    );
  }
}

/// Which stop a visit was made at (its time falls inside the stop, with
/// 5 minutes either side), or null.
int? stopOfVisit(Visit v, List<RouteStop> stops) {
  const Duration slack = Duration(minutes: 5);
  for (final (int i, RouteStop s) in stops.indexed) {
    if (!v.capturedAt.isBefore(s.start.subtract(slack)) &&
        !v.capturedAt.isAfter(s.end.add(slack))) {
      return i;
    }
  }
  return null;
}

/// The day in time order: duty on, stops (with their visits), visits away
/// from a stop, holes in the route, and duty off or "Now".
class DayTimeline extends StatelessWidget {
  const DayTimeline({
    required this.day,
    required this.route,
    required this.visits,
    required this.updatedAt,
    super.key,
  });

  final DutyDay? day;
  final DayRoute? route;
  final List<Visit> visits;
  final DateTime? updatedAt;

  @override
  Widget build(BuildContext context) {
    final DutyDay? d = day;
    final List<RouteStop> stops = route?.stops ?? const <RouteStop>[];
    final Map<int, List<Visit>> atStop = <int, List<Visit>>{};
    final List<Visit> loose = <Visit>[];
    for (final Visit v in visits) {
      final int? i = stopOfVisit(v, stops);
      if (i == null) {
        loose.add(v);
      } else {
        (atStop[i] ??= <Visit>[]).add(v);
      }
    }
    final List<(DateTime, _Entry)> items =
        <(DateTime, _Entry)>[
          for (final (int i, RouteStop s) in stops.indexed)
            (
              s.start,
              _StopEntry(index: i, stop: s, visits: atStop[i] ?? const []),
            ),
          for (final RouteNote n in route?.notes ?? const <RouteNote>[])
            (n.from, _NoteEntry(note: n)),
          for (final Visit v in loose) (v.capturedAt, _VisitEntry(visit: v)),
        ]..sort(
          ((DateTime, _Entry) a, (DateTime, _Entry) b) => a.$1.compareTo(b.$1),
        );
    final bool onDuty = d?.status == DayStatus.onDuty;
    final List<_Entry> entries = <_Entry>[
      if (d?.dutyOnAt case final DateTime on) _EdgeEntry.on(on),
      for (final (DateTime, _Entry) i in items) i.$2,
      if (onDuty)
        _NowEntry(updatedAt: updatedAt)
      else if (d?.dutyOffAt case final DateTime off)
        _EdgeEntry.off(off, auto: d!.autoEnded),
    ];
    if (items.isEmpty && (route?.isEmpty ?? true)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final _Entry e in entries) e.row(context, last: false),
          DsEmptyState(
            title: d?.dutyOnAt == null
                ? 'No duty this day'
                : 'No route recorded yet',
            message: d?.dutyOnAt == null
                ? null
                : 'The route shows up here once the phone sends it.',
            icon: DsIcons.route,
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final (int i, _Entry e) in entries.indexed)
          e.row(context, last: i == entries.length - 1),
      ],
    );
  }
}

/// One line of the timeline.
abstract class _Entry {
  const _Entry();

  Widget row(BuildContext context, {required bool last});
}

/// The time on the left, the dot and line in the middle, the card right.
Widget _timelineRow({
  required String time,
  required Widget dot,
  required Widget body,
  required bool last,
  Color timeColor = DsColors.text2,
  bool dashedLine = false,
}) {
  return IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 60,
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              time,
              textAlign: TextAlign.right,
              maxLines: 1,
              style: DsText.micro.copyWith(
                color: timeColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 28,
          child: Column(
            children: <Widget>[
              const SizedBox(height: 7),
              dot,
              if (!last)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.only(top: 6),
                    color: dashedLine ? const Color(0xFFFCD34D) : DsColors.line,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: last ? 0 : DsSpace.md),
            child: body,
          ),
        ),
      ],
    ),
  );
}

Widget _dot({required Color bg, required Color halo, Widget? child}) =>
    Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        boxShadow: <BoxShadow>[BoxShadow(color: halo, spreadRadius: 4)],
      ),
      child: child,
    );

Widget _card({required Color color, required Widget child}) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
  decoration: BoxDecoration(color: color, borderRadius: DsRadius.medium),
  child: child,
);

final TextStyle _bold = DsText.body.copyWith(fontWeight: FontWeight.w700);

class _EdgeEntry extends _Entry {
  const _EdgeEntry.on(this.at) : isOn = true, auto = false;
  const _EdgeEntry.off(this.at, {required this.auto}) : isOn = false;

  final DateTime at;
  final bool isOn;
  final bool auto;

  @override
  Widget row(BuildContext context, {required bool last}) => _timelineRow(
    time: IstFormat.time(at),
    last: last,
    dot: isOn
        ? _dot(
            bg: DsColors.successDot,
            halo: DsColors.successTint,
            child: const Icon(DsIcons.dutyOn, size: 13, color: DsColors.white),
          )
        : _dot(
            bg: DsColors.ink,
            halo: DsColors.line,
            child: const Icon(DsIcons.dutyOff, size: 12, color: DsColors.white),
          ),
    body: Padding(
      padding: const EdgeInsets.only(top: 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(isOn ? 'Duty on' : 'Duty off', style: _bold),
          if (auto) const Text('Turned off at 11 PM', style: DsText.caption),
        ],
      ),
    ),
  );
}

class _NowEntry extends _Entry {
  const _NowEntry({required this.updatedAt});

  final DateTime? updatedAt;

  @override
  Widget row(BuildContext context, {required bool last}) {
    final DateTime? at = updatedAt;
    final int minutes = at == null
        ? 0
        : DateTime.now().difference(at).inMinutes;
    return _timelineRow(
      time: 'Now',
      timeColor: DsColors.successText,
      last: last,
      dot: Container(
        width: 16,
        height: 16,
        margin: const EdgeInsets.all(6),
        decoration: const BoxDecoration(
          color: DsColors.successDot,
          shape: BoxShape.circle,
          boxShadow: <BoxShadow>[
            BoxShadow(color: DsColors.successTint, spreadRadius: 4),
            BoxShadow(color: Color(0xFFF0FDF4), spreadRadius: 8),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.only(top: 9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Now · on duty', style: _bold),
            Text(
              minutes < 1 ? 'Updated just now' : 'Updated $minutes min ago',
              style: DsText.caption,
            ),
          ],
        ),
      ),
    );
  }
}

class _StopEntry extends _Entry {
  const _StopEntry({
    required this.index,
    required this.stop,
    required this.visits,
  });

  final int index;
  final RouteStop stop;
  final List<Visit> visits;

  @override
  Widget row(BuildContext context, {required bool last}) => _timelineRow(
    time: IstFormat.time(stop.start),
    last: last,
    dot: _dot(
      bg: DsColors.primary,
      halo: DsColors.primaryTint,
      child: Text(
        '${index + 1}',
        style: DsText.micro.copyWith(
          color: DsColors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    body: _card(
      color: DsColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            stop.address ?? 'Finding address…',
            style: stop.address == null
                ? DsText.body.copyWith(color: DsColors.text2)
                : _bold,
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: <Widget>[
              _Chip(
                label:
                    '${IstFormat.clock(stop.start)} – '
                    '${IstFormat.clock(stop.end)} · '
                    '${IstFormat.duration(stop.length)}',
                status: DsStatus.onDuty,
              ),
              if (visits.isNotEmpty)
                _Chip(
                  label:
                      '${visits.length} ${visits.length == 1 ? 'visit' : 'visits'}',
                  status: DsStatus.leave,
                ),
            ],
          ),
          for (final Visit v in visits) ...<Widget>[
            const SizedBox(height: DsSpace.sm),
            _VisitRow(visit: v),
          ],
        ],
      ),
    ),
  );
}

class _VisitEntry extends _Entry {
  const _VisitEntry({required this.visit});

  final Visit visit;

  @override
  Widget row(BuildContext context, {required bool last}) => _timelineRow(
    time: IstFormat.time(visit.capturedAt),
    last: last,
    dot: _dot(
      bg: DsStatus.leave.tint,
      halo: DsColors.white,
      child: Icon(DsIcons.camera, size: 14, color: DsStatus.leave.text),
    ),
    body: _VisitRow(visit: visit, tinted: true),
  );
}

class _NoteEntry extends _Entry {
  const _NoteEntry({required this.note});

  final RouteNote note;

  @override
  Widget row(BuildContext context, {required bool last}) {
    final Duration length = note.to.difference(note.from);
    return _timelineRow(
      time: IstFormat.time(note.from),
      timeColor: DsColors.warningText,
      dashedLine: true,
      last: last,
      dot: _dot(
        bg: DsColors.warningTint,
        halo: DsColors.white,
        child: Icon(
          note.kind == NoteKind.phoneOff ? DsIcons.phone : DsIcons.warning,
          size: 14,
          color: DsColors.warningText,
        ),
      ),
      body: _card(
        color: DsColors.warningTint,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '${note.label} · ${IstFormat.duration(length)}',
              style: _bold.copyWith(color: DsColors.warningText),
            ),
            Text(
              '${IstFormat.time(note.from)} – ${IstFormat.time(note.to)} · '
              'no route for this time',
              style: DsText.caption.copyWith(color: DsColors.warningText),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.status});

  final String label;
  final DsStatus status;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(color: status.tint, borderRadius: DsRadius.pill),
    child: Text(
      label,
      style: DsText.micro.copyWith(
        color: status.text,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

/// A visit in the timeline: photo, store, time. Tap to open it.
class _VisitRow extends StatelessWidget {
  const _VisitRow({required this.visit, this.tinted = false});

  final Visit visit;
  final bool tinted;

  @override
  Widget build(BuildContext context) => Material(
    color: tinted ? DsColors.surface : DsColors.white,
    borderRadius: DsRadius.medium,
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: () => openVisit(context, visit),
      child: Padding(
        padding: const EdgeInsets.all(DsSpace.sm),
        child: Row(
          children: <Widget>[
            _Thumb(visit: visit, size: 40),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    visit.storeName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _bold,
                  ),
                  Text(
                    'Visit ${IstFormat.time(visit.capturedAt)}'
                    '${visit.fromGallery ? ' · gallery' : ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: DsText.caption,
                  ),
                ],
              ),
            ),
            const Icon(DsIcons.forward, size: 18, color: DsColors.text3),
          ],
        ),
      ),
    ),
  );
}

/// A visit's small photo, or a store icon when there is none.
class _Thumb extends StatelessWidget {
  const _Thumb({required this.visit, this.size});

  final Visit visit;
  final double? size;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: DsRadius.medium,
    child: SizedBox(
      width: size,
      height: size,
      child: visit.showsPhoto
          ? VisitPhoto(visitId: visit.id, small: true)
          : const ColoredBox(
              color: Color(0xFFCBD5E1),
              child: Center(
                child: Icon(DsIcons.store, size: 20, color: Color(0xFF475569)),
              ),
            ),
    ),
  );
}

/// The Visits tab: two photo cards a row, each with its time and stop.
class _VisitsGrid extends StatelessWidget {
  const _VisitsGrid({
    required this.visits,
    required this.stops,
    required this.failed,
    required this.onRetry,
  });

  final List<Visit> visits;
  final List<RouteStop> stops;
  final bool failed;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (failed) {
      return DsErrorState(
        title: "Couldn't load the visits",
        message: 'Check the internet and try again.',
        onRetry: onRetry,
      );
    }
    if (visits.isEmpty) {
      return const DsEmptyState(
        title: 'No visits this day',
        message: 'Shop visits with a photo show up here.',
        icon: DsIcons.camera,
      );
    }
    final List<Widget> cards = <Widget>[
      for (final Visit v in visits) _VisitCard(visit: v, stops: stops),
    ];
    return Column(
      children: <Widget>[
        for (int i = 0; i < cards.length; i += 2)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(child: cards[i]),
                const SizedBox(width: 10),
                Expanded(
                  child: i + 1 < cards.length
                      ? cards[i + 1]
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _VisitCard extends StatelessWidget {
  const _VisitCard({required this.visit, required this.stops});

  final Visit visit;
  final List<RouteStop> stops;

  @override
  Widget build(BuildContext context) {
    final int? stop = stopOfVisit(visit, stops);
    return Semantics(
      button: true,
      label:
          '${visit.storeName}, ${IstFormat.time(visit.capturedAt)}'
          '${stop == null ? '' : ', stop ${stop + 1}'}',
      excludeSemantics: true,
      child: Material(
        color: DsColors.surface,
        borderRadius: DsRadius.large,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => openVisit(context, visit),
          child: Padding(
            padding: const EdgeInsets.all(DsSpace.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                SizedBox(
                  height: 92,
                  child: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      _Thumb(visit: visit),
                      Positioned(
                        left: 6,
                        top: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: const BoxDecoration(
                            color: DsColors.white,
                            borderRadius: DsRadius.pill,
                          ),
                          child: Text(
                            IstFormat.clock(visit.capturedAt),
                            style: DsText.micro.copyWith(
                              color: DsColors.ink,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: DsSpace.sm),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        visit.storeName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: DsText.label.copyWith(
                          color: DsColors.ink,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        stop == null ? 'Away from a stop' : 'Stop ${stop + 1}',
                        style: DsText.micro.copyWith(color: DsColors.text2),
                      ),
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
