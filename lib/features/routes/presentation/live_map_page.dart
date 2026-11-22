import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
import '../../../shared/ds/ds_field.dart';
import '../../duty/domain/duty_day.dart';
import '../../users/application/users_providers.dart';
import '../../users/domain/profile.dart';
import '../../visits/application/visits_providers.dart';
import '../../visits/domain/visit.dart';
import '../application/route_providers.dart';
import '../domain/geo_point.dart';
import '../domain/live_position.dart';
import 'app_map.dart';
import 'day_pins.dart';
import 'live_person_panel.dart';
import 'live_team_drawer.dart';

/// The admin's live map (design v2): everyone who did duty on today, where
/// they are now. Pins carry initials and a colour (live, no update, fake
/// GPS). The top has the team list, a name search, "fit everyone" and
/// filter chips; the bottom has cards for people who need attention. Tap a
/// person to see their route, stops and figures here.
class LiveMapPage extends ConsumerStatefulWidget {
  const LiveMapPage({super.key});

  @override
  ConsumerState<LiveMapPage> createState() => _LiveMapPageState();
}

class _LiveMapPageState extends ConsumerState<LiveMapPage> {
  Timer? _timer;
  final GlobalKey<AppMapState> _map = GlobalKey<AppMapState>();
  final GlobalKey<ScaffoldState> _scaffold = GlobalKey<ScaffoldState>();

  /// Duty days a reload was already asked for, so it is asked once.
  final Set<int> _asked = <int>{};

  LiveFilter? _filter;
  String _query = '';

  /// The duty day of the person picked, or null for everyone.
  int? _selected;

  @override
  void initState() {
    super.initState();
    // Positions arrive live. The "min ago" moves every minute; the duty
    // list reloads every 5 minutes (L76), and at once when someone new shows
    // up on the map (below). An open person's route reloads every 2 minutes.
    _timer = Timer.periodic(const Duration(minutes: 1), (Timer t) {
      if (t.tick % dutyListReloadMinutes == 0) {
        ref.invalidate(todayDaysProvider);
      }
      final int? sel = _selected;
      if (sel != null && t.tick % personReloadMinutes == 0) {
        ref
          ..invalidate(dayViewProvider(sel))
          ..invalidate(dayVisitsProvider(sel));
      }
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _reloadForNewDuties(List<LivePosition> live, List<DutyDay> days) {
    final Set<int> fresh = unknownDutyDays(live, days, _asked);
    if (fresh.isEmpty) return;
    _asked.addAll(fresh);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.invalidate(todayDaysProvider);
    });
  }

  void _fitSoon() => WidgetsBinding.instance.addPostFrameCallback((_) {
    _map.currentState?.fitAll();
  });

  void _pick(LiveRow r) {
    FocusScope.of(context).unfocus();
    setState(() => _selected = r.day.id);
    _fitSoon();
  }

  void _back() {
    setState(() => _selected = null);
    _fitSoon();
  }

  void _retry() {
    ref
      ..invalidate(livePositionsProvider)
      ..invalidate(todayDaysProvider)
      ..invalidate(usersListProvider);
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<LivePosition>> live = ref.watch(
      livePositionsProvider,
    );
    final AsyncValue<List<DutyDay>> days = ref.watch(todayDaysProvider);
    final AsyncValue<List<Profile>> people = ref.watch(usersListProvider);
    final DateTime now = ref.read(serverClockProvider).now();

    Widget body;
    if (live.hasError || days.hasError || people.hasError) {
      body = Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(DsSpace.gutter),
          child: DsErrorState(
            message: 'The live map could not load. Check the internet.',
            onRetry: _retry,
          ),
        ),
      );
    } else if (!live.hasValue || !days.hasValue || !people.hasValue) {
      body = const Center(child: CircularProgressIndicator());
    } else {
      _reloadForNewDuties(live.value!, days.value!);
      final List<LiveRow> rows = liveRows(
        positions: live.value!,
        days: days.value!,
        people: people.value!,
        now: now,
      );
      LiveRow? sel;
      for (final LiveRow r in rows) {
        if (r.day.id == _selected) sel = r;
      }
      body = sel == null ? _everyone(rows, now) : _person(sel, rows, now);
    }
    return Scaffold(
      key: _scaffold,
      backgroundColor: DsColors.surface,
      drawer: days.hasValue && people.hasValue && live.hasValue
          ? LiveTeamDrawer(
              rows: liveRows(
                positions: live.value!,
                days: days.value!,
                people: people.value!,
                now: now,
              ),
              now: now,
              onPick: (LiveRow r) {
                Navigator.of(context).pop();
                _pick(r);
              },
            )
          : null,
      body: body,
    );
  }

  /// Everyone: filtered pins, the top bar and the attention cards.
  Widget _everyone(List<LiveRow> rows, DateTime now) {
    final String q = _query.trim().toLowerCase();
    bool shown(LiveRow r) =>
        (_filter?.matches(r) ?? r.onDuty) && (q.isEmpty || r.matches(q));
    final List<LiveRow> attention = <LiveRow>[
      for (final LiveRow r in rows)
        if (r.needsAttention) r,
    ];
    final List<MapPin> pins = <MapPin>[
      for (final LiveRow r in rows)
        if (shown(r))
          if (r.position case final LivePosition p)
            livePin(r, p.point, onTap: () => _pick(r)),
    ];
    final List<LiveRow> found = q.isEmpty
        ? const <LiveRow>[]
        : <LiveRow>[
            for (final LiveRow r in rows)
              if (r.matches(q)) r,
          ];
    final double bottom = rows.isEmpty
        ? 200
        : attention.isEmpty
        ? DsSpace.lg
        : 150;
    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: AppMap(
            key: _map,
            lines: const <List<GeoPoint>>[],
            pins: pins,
            padding: EdgeInsets.only(top: 150, bottom: bottom),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                DsSpace.gutter,
                DsSpace.md,
                DsSpace.gutter,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      _TeamButton(
                        attention: attention.length,
                        onTap: () => _scaffold.currentState?.openDrawer(),
                      ),
                      const SizedBox(width: DsSpace.sm),
                      Expanded(
                        child: DsSearchField(
                          hint: 'Search by name',
                          floating: true,
                          height: 48,
                          onChanged: (String v) => setState(() => _query = v),
                        ),
                      ),
                      const SizedBox(width: DsSpace.sm),
                      DsIconButton(
                        icon: DsIcons.expand,
                        label: 'Fit everyone on the map',
                        onPressed: () => _map.currentState?.fitAll(),
                      ),
                    ],
                  ),
                  const SizedBox(height: DsSpace.xs),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: <Widget>[
                        for (final LiveFilter f
                            in LiveFilter.values) ...<Widget>[
                          DsFilterChip(
                            label: f.label,
                            count: rows.where(f.matches).length,
                            selected: _filter == f,
                            onTap: () => setState(() {
                              _filter = _filter == f ? null : f;
                            }),
                          ),
                          const SizedBox(width: DsSpace.sm),
                        ],
                      ],
                    ),
                  ),
                  if (q.isNotEmpty)
                    _SearchResults(rows: found, now: now, onPick: _pick),
                ],
              ),
            ),
          ),
        ),
        if (rows.isEmpty)
          const Positioned(
            left: DsSpace.gutter,
            right: DsSpace.gutter,
            bottom: DsSpace.lg,
            child: _Floating(
              child: DsEmptyState(
                title: 'Nobody on duty yet',
                message: 'People show here after duty on.',
                icon: DsIcons.live,
              ),
            ),
          )
        else if (attention.isNotEmpty && q.isEmpty)
          Positioned(
            left: 0,
            right: 0,
            bottom: DsSpace.md,
            child: AttentionCards(rows: attention, now: now, onPick: _pick),
          ),
      ],
    );
  }

  /// One person: their route and stops, the card at the bottom.
  Widget _person(LiveRow sel, List<LiveRow> rows, DateTime now) {
    final AsyncValue<DayView> view = ref.watch(dayViewProvider(sel.day.id));
    final AsyncValue<List<Visit>> visits = ref.watch(
      dayVisitsProvider(sel.day.id),
    );
    final DayView? v = view.value;
    final List<Visit> dayVisits = visits.value ?? const <Visit>[];
    final GeoPoint? here = sel.position?.point ?? v?.route?.end;
    final List<MapPin> pins = <MapPin>[
      for (final MapPin p in dayPins(sel.day, v?.route, dayVisits))
        if (p.id != 'now' && !(sel.onDuty && p.id == 'end')) p,
      if (here != null && (sel.onDuty || sel.position != null))
        livePin(sel, here),
    ];
    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: AppMap(
            key: _map,
            lines: v?.route?.segments ?? const <List<GeoPoint>>[],
            pins: pins,
            padding: const EdgeInsets.only(top: 80, bottom: 260),
          ),
        ),
        Positioned(
          left: DsSpace.gutter,
          top: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(top: DsSpace.md),
              child: DsIconButton(
                icon: DsIcons.back,
                label: 'Back to everyone',
                onPressed: _back,
              ),
            ),
          ),
        ),
        Positioned(
          right: DsSpace.gutter,
          bottom: 280,
          child: MapControls(
            onZoomIn: () => _map.currentState?.zoomIn(),
            onZoomOut: () => _map.currentState?.zoomOut(),
            onCentre: here == null
                ? null
                : () => _map.currentState?.showPoint(here),
            centreLabel: 'Centre on ${sel.firstName}',
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: LivePersonCard(row: sel, now: now, view: view, visits: visits),
        ),
      ],
    );
  }
}

/// How often the live map reloads today's duty list (L76).
const int dutyListReloadMinutes = 5;

/// How often an open person's route and visits reload.
const int personReloadMinutes = 2;

/// Duty days that send positions but are not in [days] yet (a new duty on),
/// leaving out those in [asked].
Set<int> unknownDutyDays(
  List<LivePosition> positions,
  List<DutyDay> days,
  Set<int> asked,
) {
  final Set<int> known = <int>{for (final DutyDay d in days) d.id};
  return <int>{
    for (final LivePosition p in positions)
      if (p.dutyDayId case final int id
          when !known.contains(id) && !asked.contains(id))
        id,
  };
}

/// Where a person on the live map stands. Lists follow this order.
enum LiveState {
  /// On duty, no position for over 5 minutes (or none yet).
  stale(DsStatus.waiting),

  /// On duty, the latest position came from a fake-location app.
  fake(DsStatus.absent),

  /// On duty, a fresh position.
  live(DsStatus.present),

  /// Duty is over for today.
  done(DsStatus.onDuty);

  const LiveState(this.status);

  /// Its colours.
  final DsStatus status;
}

/// The filter chips over the map and in the team list.
enum LiveFilter {
  live('Live', DsStatus.present),
  attention('No update', DsStatus.waiting),
  done('Finished', DsStatus.onDuty);

  const LiveFilter(this.label, this.status);

  final String label;
  final DsStatus status;

  bool matches(LiveRow r) => switch (this) {
    LiveFilter.live => r.state == LiveState.live,
    LiveFilter.attention => r.needsAttention,
    LiveFilter.done => r.state == LiveState.done,
  };
}

/// One person on today's live map.
class LiveRow {
  const LiveRow({
    required this.name,
    required this.code,
    required this.day,
    required this.position,
    required this.state,
    this.phone,
  });

  final String name;

  /// The employee's phone number, for the Call button.
  final String? phone;

  /// The employee ID ("EMP014"), for the search.
  final String code;
  final DutyDay day;
  final LivePosition? position;
  final LiveState state;

  bool get onDuty => day.status == DayStatus.onDuty;

  /// On duty with no position for over 5 minutes.
  bool get stale => state == LiveState.stale;

  /// No update or fake GPS: shown first and on the cards.
  bool get needsAttention =>
      state == LiveState.stale || state == LiveState.fake;

  String get initials => initialsOf(name);

  String get firstName => name.trim().split(RegExp(r'\s+')).first;

  /// Battery from the latest position: "64%".
  String get battery => switch (position?.battery) {
    final int b => '$b%',
    null => '–',
  };

  bool get lowBattery => (position?.battery ?? 100) <= 20;

  /// The name or the employee ID contains [q] (lower case).
  bool matches(String q) =>
      name.toLowerCase().contains(q) || code.toLowerCase().contains(q);
}

/// Everyone who did duty on today: no update first, then fake GPS, live
/// and finished, each by name.
List<LiveRow> liveRows({
  required List<LivePosition> positions,
  required List<DutyDay> days,
  required List<Profile> people,
  required DateTime now,
}) {
  final Map<String, Profile> byId = <String, Profile>{
    for (final Profile p in people) p.id: p,
  };
  final Map<int, LivePosition> byDay = <int, LivePosition>{
    for (final LivePosition p in positions)
      if (p.dutyDayId != null) p.dutyDayId!: p,
  };
  LiveState stateOf(DutyDay d, LivePosition? p) {
    if (d.status != DayStatus.onDuty) return LiveState.done;
    if (p == null || p.isStaleAt(now)) return LiveState.stale;
    if (p.mocked) return LiveState.fake;
    return LiveState.live;
  }

  final List<LiveRow> rows = <LiveRow>[
    for (final DutyDay d in days)
      if (d.dutyOnAt != null)
        LiveRow(
          name: byId[d.userId]?.fullName ?? 'Unknown',
          code: byId[d.userId]?.userCode ?? '',
          phone: byId[d.userId]?.phone,
          day: d,
          position: byDay[d.id],
          state: stateOf(d, byDay[d.id]),
        ),
  ];
  int rank(LiveRow r) => r.state.index;
  rows.sort((LiveRow a, LiveRow b) {
    final int byRank = rank(a).compareTo(rank(b));
    if (byRank != 0) return byRank;
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });
  return rows;
}

/// "Just now", "1 min ago", "1 h 05 min ago".
String agoText(DateTime t, DateTime now) {
  final Duration d = now.difference(t);
  if (d.inMinutes < 1) return 'Just now';
  return '${IstFormat.duration(d)} ago';
}

/// The short line under a name: "1 min ago", "No update · 12 min",
/// "Fake GPS · at 10:41 AM", "Duty off 10:05 AM".
String liveLine(LiveRow r, DateTime now) {
  final LivePosition? p = r.position;
  return switch (r.state) {
    LiveState.live => agoText(p!.recordedAt, now),
    LiveState.stale =>
      p == null
          ? 'No location yet'
          : 'No update · ${IstFormat.duration(now.difference(p.recordedAt))}',
    LiveState.fake => 'Fake GPS · at ${IstFormat.time(p!.recordedAt)}',
    LiveState.done =>
      r.day.dutyOffAt == null
          ? r.day.status.label
          : 'Duty off ${IstFormat.time(r.day.dutyOffAt!)}',
  };
}

/// The pin of a person: initials in their state's colour.
MapPin livePin(LiveRow r, GeoPoint at, {VoidCallback? onTap}) => MapPin(
  id: 'person-${r.day.id}',
  point: at,
  kind: switch (r.state) {
    LiveState.live => PinKind.teamLive,
    LiveState.stale => PinKind.teamStale,
    LiveState.fake => PinKind.teamFake,
    LiveState.done => PinKind.teamDone,
  },
  label: r.initials,
  title: r.name,
  snippet: r.position == null
      ? null
      : r.position!.mocked
      ? 'FAKE GPS at ${IstFormat.time(r.position!.recordedAt)}'
      : 'At ${IstFormat.time(r.position!.recordedAt)}',
  onTap: onTap,
);

/// The dark round "team list" button with the amber "needs attention"
/// count.
class _TeamButton extends StatelessWidget {
  const _TeamButton({required this.attention, required this.onTap});

  final int attention;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: attention == 0
        ? 'Open team list'
        : 'Open team list, $attention need attention',
    excludeSemantics: true,
    child: SizedBox.square(
      dimension: 48,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Positioned.fill(
            child: Material(
              color: DsColors.ink,
              shape: const CircleBorder(),
              elevation: 4,
              shadowColor: const Color(0x440F172A),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onTap,
                child: const Icon(
                  DsIcons.team,
                  size: 22,
                  color: DsColors.white,
                ),
              ),
            ),
          ),
          if (attention > 0)
            Positioned(
              top: -2,
              right: -2,
              child: DsCountBadge(count: attention, waiting: true),
            ),
        ],
      ),
    ),
  );
}

/// People matching the top search, under the chips.
class _SearchResults extends StatelessWidget {
  const _SearchResults({
    required this.rows,
    required this.now,
    required this.onPick,
  });

  final List<LiveRow> rows;
  final DateTime now;
  final ValueChanged<LiveRow> onPick;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: DsSpace.xs),
    child: _Floating(
      padding: const EdgeInsets.all(DsSpace.sm),
      child: rows.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(DsSpace.sm),
              child: Text(
                'Nobody on today\'s duty list has that name.',
                style: DsText.body.copyWith(color: DsColors.text2),
              ),
            )
          : Column(
              children: <Widget>[
                for (final LiveRow r in rows.take(5))
                  LiveTeamRow(row: r, now: now, onTap: () => onPick(r)),
              ],
            ),
    ),
  );
}

/// A white rounded card floating over the map.
class _Floating extends StatelessWidget {
  const _Floating({required this.child, this.padding = EdgeInsets.zero});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: const BoxDecoration(
      color: DsColors.white,
      borderRadius: DsRadius.large,
      boxShadow: DsShadow.card,
    ),
    child: child,
  );
}
