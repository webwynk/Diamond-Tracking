import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/design/ds_colors.dart';
import '../../../core/design/ds_icons.dart';
import '../../../core/design/ds_layout.dart';
import '../../../core/design/ds_status.dart';
import '../../../core/design/ds_text.dart';
import '../../../core/links/open_link.dart';
import '../../../core/time/clock_providers.dart';
import '../../../core/time/ist_format.dart';
import '../../../shared/ds/ds_button.dart';
import '../../../shared/ds/ds_feedback.dart';
import '../../../shared/ds/ds_frame.dart';
import '../../duty/domain/duty_day.dart';
import '../../duty/presentation/home_page.dart' show firstNameOf;
import '../../users/application/users_providers.dart';
import '../../users/domain/profile.dart';
import '../../visits/application/visits_providers.dart';
import '../../visits/domain/visit.dart';
import '../application/route_providers.dart';
import '../domain/day_route.dart';
import '../domain/geo_point.dart';
import '../domain/history_month.dart' show dutyLength;
import '../domain/live_position.dart';
import 'app_map.dart';
import 'day_pins.dart';
import 'day_route_page.dart' show DayTimeline;
import 'map_controls.dart';
import 'route_parts.dart';

/// The admin's live map with one person picked (design v2, Live map ·
/// person selected): their route today, stops and visits, where they are
/// now, and a card with how they are doing. Opened from the live map.
class LivePersonPage extends ConsumerStatefulWidget {
  const LivePersonPage({required this.dayId, super.key});

  /// The person's duty day today.
  final int dayId;

  /// How often the route reloads while the person is on duty. The "now"
  /// pin moves at once: positions arrive live.
  static const Duration refreshEvery = Duration(minutes: 2);

  @override
  ConsumerState<LivePersonPage> createState() => _LivePersonPageState();
}

class _LivePersonPageState extends ConsumerState<LivePersonPage> {
  final GlobalKey<AppMapState> _map = GlobalKey<AppMapState>();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // "1 min ago" moves every minute; the route reloads every 2 minutes.
    _timer = Timer.periodic(const Duration(minutes: 1), (Timer t) {
      final DutyDay? day = ref.read(dayViewProvider(widget.dayId)).value?.day;
      if (day?.status == DayStatus.onDuty &&
          t.tick % LivePersonPage.refreshEvery.inMinutes == 0) {
        _reload();
      }
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
    final AsyncValue<DayView> view = ref.watch(dayViewProvider(widget.dayId));
    final List<Visit> visits = List<Visit>.of(
      ref.watch(dayVisitsProvider(widget.dayId)).value ?? const <Visit>[],
    )..sort((Visit a, Visit b) => a.capturedAt.compareTo(b.capturedAt));
    final DutyDay? day = view.value?.day;
    final DayRoute? route = view.value?.route;
    final String? userId = day?.userId;
    final Profile? person = userId == null
        ? null
        : ref.watch(userByIdProvider(userId)).value;
    final LivePosition? live = livePositionOf(
      ref.watch(livePositionsProvider).value,
      widget.dayId,
    );
    final DateTime now = ref.watch(serverClockProvider).now();
    final bool onDuty = day?.status == DayStatus.onDuty;
    final GeoPoint? here = onDuty ? live?.point ?? route?.end : route?.end;
    final String name = person?.fullName ?? 'Employee';
    final MediaQueryData media = MediaQuery.of(context);

    return Scaffold(
      backgroundColor: DsColors.surface,
      body: Stack(
        children: <Widget>[
          Positioned.fill(
            child: AppMap(
              key: _map,
              lines: route?.segments ?? const <List<GeoPoint>>[],
              pins: <MapPin>[
                for (final MapPin p in dayPins(day, route, visits))
                  if (p.id != 'now') p,
                if (onDuty && here != null)
                  MapPin(
                    id: 'now',
                    point: here,
                    kind: live == null || live.isStaleAt(now)
                        ? PinKind.personStale
                        : PinKind.person,
                    title: name,
                    snippet: live == null
                        ? null
                        : 'At ${IstFormat.time(live.recordedAt)}',
                  ),
              ],
              padding: EdgeInsets.only(
                top: media.padding.top + 70,
                bottom: 260,
              ),
            ),
          ),
          Positioned(
            top: media.padding.top + DsSpace.md,
            left: DsSpace.lg,
            child: DsIconButton(
              icon: DsIcons.back,
              label: 'Back to everyone',
              onPressed: () => context.canPop()
                  ? context.pop()
                  : context.go(Routes.adminLiveMap),
            ),
          ),
          Positioned(
            right: DsSpace.lg,
            top: media.size.height * 0.34,
            child: Column(
              children: <Widget>[
                MapZoomButtons(
                  onIn: () => _map.currentState?.zoomIn(),
                  onOut: () => _map.currentState?.zoomOut(),
                ),
                const SizedBox(height: 10),
                MapRoundButton(
                  icon: DsIcons.locate,
                  label: 'Centre on $name',
                  onPressed: here == null
                      ? null
                      : () => _map.currentState?.showPoint(here),
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _PersonCard(
              child: view.hasError && day == null
                  ? DsErrorState(
                      title: "Couldn't load this duty",
                      message: 'Check the internet and try again.',
                      onRetry: _reload,
                    )
                  : day == null
                  ? view.isLoading
                        ? const Padding(
                            padding: EdgeInsets.all(DsSpace.xl),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        : const DsEmptyState(
                            title: 'Duty not found',
                            message: 'It may have been removed.',
                            icon: DsIcons.empty,
                          )
                  : _PersonDetails(
                      day: day,
                      route: route,
                      visits: visits,
                      person: person,
                      live: live,
                      now: now,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The latest position sent for [dayId], if any.
LivePosition? livePositionOf(List<LivePosition>? positions, int dayId) {
  for (final LivePosition p in positions ?? const <LivePosition>[]) {
    if (p.dutyDayId == dayId) return p;
  }
  return null;
}

/// "Live · 1 min ago · since 7:12 AM", "No update for 12 min · since
/// 7:12 AM", "Duty off at 6:10 PM". The tone says how worried to be.
(DsStatus, String, String) liveStatusLine(
  DutyDay day,
  LivePosition? live,
  DateTime now,
) {
  final String since = day.dutyOnAt == null
      ? ''
      : ' · since ${IstFormat.time(day.dutyOnAt!)}';
  if (day.status != DayStatus.onDuty) {
    final DateTime? off = day.dutyOffAt;
    return (
      DsStatus.off,
      off == null ? day.status.label : 'Duty off',
      off == null
          ? ''
          : ' at ${IstFormat.time(off)}${day.autoEnded ? ' (auto off)' : ''}',
    );
  }
  if (live == null) return (DsStatus.waiting, 'No position yet', since);
  final Duration age = now.difference(live.recordedAt);
  if (live.mocked) {
    return (DsStatus.absent, 'Fake GPS', ' · ${_ago(age)}$since');
  }
  if (live.isStaleAt(now)) {
    return (DsStatus.waiting, 'No update', ' for ${_age(age)}$since');
  }
  return (DsStatus.present, 'Live', ' · ${_ago(age)}$since');
}

String _age(Duration d) =>
    d.inMinutes < 60 ? '${d.inMinutes} min' : IstFormat.hoursMinutes(d);

String _ago(Duration d) => d.inMinutes < 1 ? 'just now' : '${_age(d)} ago';

/// The white sheet at the bottom.
class _PersonCard extends StatelessWidget {
  const _PersonCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: DsColors.white,
        borderRadius: DsRadius.sheetTop,
        boxShadow: DsShadow.card,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            DsSpace.lg,
            10,
            DsSpace.lg,
            DsSpace.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
              const SizedBox(height: DsSpace.md),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _PersonDetails extends ConsumerWidget {
  const _PersonDetails({
    required this.day,
    required this.route,
    required this.visits,
    required this.person,
    required this.live,
    required this.now,
  });

  final DutyDay day;
  final DayRoute? route;
  final List<Visit> visits;
  final Profile? person;
  final LivePosition? live;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (DsStatus tone, String state, String rest) = liveStatusLine(
      day,
      live,
      now,
    );
    final bool onDuty = day.status == DayStatus.onDuty;
    final Duration? length = dutyLength(day, now);
    final int metres = route?.distanceM ?? day.distanceM ?? 0;
    final int stops = route?.stops.length ?? 0;
    final String name = person?.fullName ?? ' ';
    final String? phone = person?.phone;
    final int? battery = onDuty ? live?.battery : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          children: <Widget>[
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tone.tint,
                borderRadius: DsRadius.medium,
              ),
              child: Text(
                person == null ? '' : initialsOf(person!.fullName),
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
                      name,
                      style: DsText.section,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Row(
                    children: <Widget>[
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: tone.dot,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text.rich(
                          TextSpan(
                            children: <InlineSpan>[
                              TextSpan(
                                text: state,
                                style: TextStyle(
                                  color: tone.text,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              TextSpan(text: rest),
                            ],
                          ),
                          style: DsText.caption,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (battery != null) ...<Widget>[
              const SizedBox(width: DsSpace.sm),
              _BatteryChip(percent: battery),
            ],
          ],
        ),
        const SizedBox(height: DsSpace.md),
        Row(
          children: <Widget>[
            _Figure(
              value: (metres / 1000).toStringAsFixed(1),
              unit: 'km',
              bg: DsColors.primaryTint,
              fg: DsColors.deep,
            ),
            const SizedBox(width: 6),
            _Figure(
              value: length == null ? '–' : IstFormat.hoursMinutes(length),
              unit: 'duty',
              bg: DsColors.successTint,
              fg: DsColors.successText,
            ),
            const SizedBox(width: 6),
            _Figure(
              value: '${visits.length}',
              unit: visits.length == 1 ? 'visit' : 'visits',
              bg: const Color(0xFFF1EDFE),
              fg: const Color(0xFF4C1D95),
            ),
          ],
        ),
        if (route case final DayRoute r when r.mockedPoints > 0)
          FakeGpsWarning(points: r.mockedPoints),
        const SizedBox(height: DsSpace.md),
        Row(
          children: <Widget>[
            if (phone != null && phone.isNotEmpty) ...<Widget>[
              _CallButton(name: name, phone: phone),
              const SizedBox(width: DsSpace.sm),
            ],
            _StopsButton(
              count: stops,
              onPressed: () => showDsSheet<void>(
                context: context,
                builder: (_) => _StopsSheet(dayId: day.id, name: name),
              ),
            ),
            const SizedBox(width: DsSpace.sm),
            Expanded(
              child: DsButton(
                label: 'Full route',
                arrow: true,
                onPressed: () => context.push(Routes.adminDay(day.id)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _BatteryChip extends StatelessWidget {
  const _BatteryChip({required this.percent});

  final int percent;

  @override
  Widget build(BuildContext context) {
    final bool low = percent <= 20;
    final Color fg = low ? DsColors.dangerText : const Color(0xFF334155);
    return Semantics(
      label: 'Battery $percent percent',
      excludeSemantics: true,
      child: Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: low ? DsColors.dangerTint : const Color(0xFFEEF2F6),
          borderRadius: DsRadius.pill,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(DsIcons.battery, size: 15, color: fg),
            const SizedBox(width: 5),
            Text(
              '$percent%',
              style: DsText.caption.copyWith(
                color: fg,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "42.6 km", "3h 30m duty", "5 visits" as tinted pills.
class _Figure extends StatelessWidget {
  const _Figure({
    required this.value,
    required this.unit,
    required this.bg,
    required this.fg,
  });

  final String value;
  final String unit;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        label: '$value $unit',
        excludeSemantics: true,
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(color: bg, borderRadius: DsRadius.medium),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text.rich(
              TextSpan(
                children: <InlineSpan>[
                  TextSpan(
                    text: value,
                    style: DsText.body.copyWith(
                      color: fg,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextSpan(
                    text: ' $unit',
                    style: DsText.label.copyWith(
                      color: fg,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
              maxLines: 1,
            ),
          ),
        ),
      ),
    );
  }
}

/// Green round button that opens the phone's dialler.
class _CallButton extends ConsumerWidget {
  const _CallButton({required this.name, required this.phone});

  final String name;
  final String phone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Semantics(
      button: true,
      label: 'Call $name',
      excludeSemantics: true,
      child: Material(
        color: DsColors.successTint,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () async {
            final ScaffoldMessengerState messenger = ScaffoldMessenger.of(
              context,
            );
            final bool opened = await ref.read(openLinkProvider)(
              Uri(scheme: 'tel', path: phone),
            );
            if (!opened) {
              messenger.showSnackBar(
                const SnackBar(content: Text("Couldn't open the phone app.")),
              );
            }
          },
          child: const SizedBox.square(
            dimension: 50,
            child: Icon(DsIcons.phone, size: 20, color: DsColors.successText),
          ),
        ),
      ),
    );
  }
}

/// Outlined "Stops 2" button.
class _StopsButton extends StatelessWidget {
  const _StopsButton({required this.count, required this.onPressed});

  final int count;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Stops, $count',
      excludeSemantics: true,
      child: Material(
        color: DsColors.white,
        shape: const StadiumBorder(side: BorderSide(color: Color(0xFFCBD5E1))),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(DsIcons.pin, size: 18, color: DsColors.primary),
                const SizedBox(width: 6),
                Text(
                  'Stops',
                  style: DsText.body.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 6),
                Container(
                  constraints: const BoxConstraints(minWidth: 22),
                  height: 22,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: DsColors.primaryTint,
                    borderRadius: DsRadius.pill,
                  ),
                  child: Text(
                    '$count',
                    style: DsText.micro.copyWith(
                      color: DsColors.primary,
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

/// "Rahul's stops today": the day's timeline, kept live while open.
class _StopsSheet extends ConsumerWidget {
  const _StopsSheet({required this.dayId, required this.name});

  final int dayId;
  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DayView? view = ref.watch(dayViewProvider(dayId)).value;
    final List<Visit> visits = List<Visit>.of(
      ref.watch(dayVisitsProvider(dayId)).value ?? const <Visit>[],
    )..sort((Visit a, Visit b) => a.capturedAt.compareTo(b.capturedAt));
    final DayRoute? route = view?.route;
    final int stops = route?.stops.length ?? 0;
    final int metres = route?.distanceM ?? view?.day?.distanceM ?? 0;
    final String first = firstNameOf(name);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Semantics(
                    header: true,
                    child: Text(
                      first.isEmpty ? 'Stops today' : "$first's stops today",
                      style: DsText.section,
                    ),
                  ),
                  Text(
                    '$stops ${stops == 1 ? 'stop' : 'stops'} · '
                    '${visits.length} '
                    '${visits.length == 1 ? 'visit' : 'visits'} · '
                    '${formatKm(metres)}',
                    style: DsText.caption,
                  ),
                ],
              ),
            ),
            DsIconButton(
              icon: DsIcons.close,
              label: 'Close stops',
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
        const SizedBox(height: DsSpace.lg),
        DayTimeline(
          day: view?.day,
          route: route,
          visits: visits,
          updatedAt: null,
        ),
        const SizedBox(height: DsSpace.lg),
        DsButton(
          label: 'See full day route',
          arrow: true,
          onPressed: () {
            final GoRouter router = GoRouter.of(context);
            Navigator.pop(context);
            router.push(Routes.adminDay(dayId));
          },
        ),
      ],
    );
  }
}
