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
import '../../../core/time/clock_providers.dart';
import '../../../core/time/ist_format.dart';
import '../../../shared/ds/ds_button.dart';
import '../../../shared/ds/ds_chips.dart';
import '../../../shared/ds/ds_feedback.dart';
import '../../duty/domain/duty_day.dart';
import '../../visits/application/visits_providers.dart';
import '../../visits/domain/visit.dart';
import '../application/route_providers.dart';
import '../domain/day_route.dart';
import '../domain/geo_point.dart';
import 'app_map.dart';
import 'day_pins.dart';
import 'route_parts.dart';

/// The employee's Map tab (design v2, My map): today's route on a full
/// screen map, with a floating title, zoom buttons and a card with the
/// day's figures. While on duty it refreshes every 2 minutes.
class MyMapPage extends ConsumerStatefulWidget {
  const MyMapPage({super.key});

  /// How often the route reloads while on duty.
  static const Duration refreshEvery = Duration(minutes: 2);

  @override
  ConsumerState<MyMapPage> createState() => _MyMapPageState();
}

class _MyMapPageState extends ConsumerState<MyMapPage> {
  final GlobalKey<AppMapState> _map = GlobalKey<AppMapState>();
  Timer? _timer;

  /// When the route last arrived, for "Updated 1 min ago".
  DateTime? _updatedAt;
  DayView? _lastView;

  @override
  void initState() {
    super.initState();
    // Reloads while on duty; also redraws "Updated … ago" every 2 minutes.
    _timer = Timer.periodic(MyMapPage.refreshEvery, (_) {
      final DutyDay? day = ref.read(myTodayProvider).value;
      if (day?.status == DayStatus.onDuty) _reload(day);
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _reload(DutyDay? day) {
    ref.invalidate(myTodayProvider);
    if (day != null) {
      ref
        ..invalidate(dayViewProvider(day.id))
        ..invalidate(dayVisitsProvider(day.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<DutyDay?> today = ref.watch(myTodayProvider);
    final DutyDay? day = today.value;
    final bool started = day != null && day.dutyOnAt != null;
    final AsyncValue<DayView>? view = started
        ? ref.watch(dayViewProvider(day.id))
        : null;
    final List<Visit> visits = started
        ? ref.watch(dayVisitsProvider(day.id)).value ?? const <Visit>[]
        : const <Visit>[];
    // A new route value means it was just loaded.
    final DayView? loaded = view?.value;
    if (loaded != null && !identical(loaded, _lastView)) {
      _lastView = loaded;
      _updatedAt = DateTime.now();
    }
    final DayRoute? route = view?.value?.route;
    final DutyDay? shownDay = view?.value?.day ?? day;
    final MediaQueryData media = MediaQuery.of(context);
    final bool failed = today.hasError || (view?.hasError ?? false);

    return Scaffold(
      backgroundColor: DsColors.surface,
      body: Stack(
        children: <Widget>[
          Positioned.fill(
            child: AppMap(
              key: _map,
              lines: route?.segments ?? const <List<GeoPoint>>[],
              pins: dayPins(shownDay, route, visits, nowTitle: 'You'),
              padding: EdgeInsets.only(
                top: media.padding.top + 80,
                bottom: 250,
              ),
            ),
          ),
          Positioned(
            top: media.padding.top + DsSpace.md,
            left: DsSpace.lg,
            right: DsSpace.lg,
            child: _TopBar(
              day: shownDay,
              onShowMe: route?.end == null
                  ? null
                  : () => _map.currentState?.showPoint(route!.end!),
            ),
          ),
          Positioned(
            right: DsSpace.lg,
            top: media.size.height * 0.36,
            child: _ZoomButtons(
              onIn: () => _map.currentState?.zoomIn(),
              onOut: () => _map.currentState?.zoomOut(),
            ),
          ),
          Positioned(
            left: DsSpace.md,
            right: DsSpace.md,
            bottom: DsSpace.lg,
            child: failed
                ? _Card(
                    child: DsErrorState(
                      title: "Couldn't load your route",
                      message: 'Check the internet and try again.',
                      onRetry: () => _reload(day),
                    ),
                  )
                : _RouteCard(
                    day: shownDay,
                    route: route,
                    visits: visits,
                    loading:
                        today.isLoading && day == null ||
                        (view?.isLoading ?? false) && route == null,
                    updatedAt: _updatedAt,
                  ),
          ),
        ],
      ),
    );
  }
}

/// White pill with the title and the day, a status chip, and the
/// "Show my position" button.
class _TopBar extends StatelessWidget {
  const _TopBar({required this.day, required this.onShowMe});

  final DutyDay? day;
  final VoidCallback? onShowMe;

  @override
  Widget build(BuildContext context) {
    final DutyDay? d = day;
    final (DsStatus status, String label) = switch (d) {
      DutyDay(status: DayStatus.onDuty) => (DsStatus.onDuty, 'Recording'),
      DutyDay(dutyOnAt: _?) => (DsStatus.off, 'Duty off'),
      _ => (DsStatus.off, 'Not started'),
    };
    return Row(
      children: <Widget>[
        Expanded(
          child: Container(
            height: DsSize.control,
            padding: const EdgeInsets.fromLTRB(18, 0, DsSpace.sm, 0),
            decoration: const BoxDecoration(
              color: DsColors.white,
              borderRadius: DsRadius.pill,
              boxShadow: DsShadow.card,
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Semantics(
                        header: true,
                        child: const Text(
                          'My map',
                          style: DsText.section,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        d == null
                            ? 'Today'
                            : 'Today, ${IstFormat.shortDate(d.day)}',
                        style: DsText.caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                DsStatusPill(status: status, label: label),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        _RoundButton(
          icon: DsIcons.locate,
          label: 'Show my position',
          onPressed: onShowMe,
        ),
      ],
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: label,
      excludeSemantics: true,
      child: Container(
        width: DsSize.control,
        height: DsSize.control,
        decoration: const BoxDecoration(
          color: DsColors.white,
          shape: BoxShape.circle,
          boxShadow: DsShadow.card,
        ),
        child: Material(
          type: MaterialType.transparency,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: Icon(
              icon,
              size: 22,
              color: onPressed == null ? DsColors.text3 : DsColors.primary,
            ),
          ),
        ),
      ),
    );
  }
}

/// + and − in one white pill.
class _ZoomButtons extends StatelessWidget {
  const _ZoomButtons({required this.onIn, required this.onOut});

  final VoidCallback onIn;
  final VoidCallback onOut;

  @override
  Widget build(BuildContext context) {
    Widget button(String text, String label, VoidCallback onTap) => Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: Text(
              text,
              style: DsText.value.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
        ),
      ),
    );
    return Container(
      decoration: const BoxDecoration(
        color: DsColors.white,
        borderRadius: DsRadius.large,
        boxShadow: DsShadow.card,
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: DsRadius.large,
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            button('+', 'Zoom in', onIn),
            Container(width: 24, height: 1, color: DsColors.line),
            button('−', 'Zoom out', onOut),
          ],
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Container(
          padding: const EdgeInsets.fromLTRB(
            DsSpace.lg,
            10,
            DsSpace.lg,
            DsSpace.lg,
          ),
          decoration: const BoxDecoration(
            color: DsColors.white,
            borderRadius: DsRadius.large,
            boxShadow: DsShadow.card,
          ),
          child: child,
        ),
      ),
    );
  }
}

/// "Today's route": distance, time on duty, visits, and the two actions.
class _RouteCard extends ConsumerWidget {
  const _RouteCard({
    required this.day,
    required this.route,
    required this.visits,
    required this.loading,
    required this.updatedAt,
  });

  final DutyDay? day;
  final DayRoute? route;
  final List<Visit> visits;
  final bool loading;
  final DateTime? updatedAt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DutyDay? d = day;
    final bool started = d != null && d.dutyOnAt != null;
    final bool onDuty = d?.status == DayStatus.onDuty;
    final DateTime now = ref.watch(serverClockProvider).now();
    final Duration? onDutyFor = !started
        ? null
        : onDuty
        ? now.difference(d.dutyOnAt!)
        : d.workedMinutes == null
        ? null
        : Duration(minutes: d.workedMinutes!);
    final int metres = route?.distanceM ?? d?.distanceM ?? 0;
    final DateTime? updated = updatedAt;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: const BoxDecoration(
                color: Color(0xFFCBD5E1),
                borderRadius: DsRadius.pill,
              ),
            ),
          ),
          const SizedBox(height: DsSpace.md),
          Row(
            children: <Widget>[
              Expanded(
                child: Semantics(
                  header: true,
                  child: const Text("Today's route", style: DsText.section),
                ),
              ),
              if (started && updated != null)
                Text(
                  _updatedText(DateTime.now(), updated),
                  style: DsText.caption,
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (!started && !loading)
            Text(
              'No route today. Your route shows here after duty on.',
              style: DsText.body.copyWith(color: DsColors.text2),
            )
          else
            Row(
              children: <Widget>[
                Expanded(
                  child: _Figure(
                    icon: DsIcons.route,
                    tint: DsColors.primaryTint,
                    color: DsColors.primary,
                    value: loading ? '…' : formatKm(metres),
                    label: 'Distance',
                  ),
                ),
                Expanded(
                  child: _Figure(
                    icon: DsIcons.clock,
                    tint: DsColors.successTint,
                    color: DsColors.successText,
                    value: onDutyFor == null
                        ? '–'
                        : IstFormat.hoursMinutes(onDutyFor),
                    label: 'On duty',
                  ),
                ),
                Expanded(
                  child: _Figure(
                    icon: DsIcons.camera,
                    tint: const Color(0xFFF1EDFE),
                    color: const Color(0xFF6D28D9),
                    value: '${visits.length}',
                    label: 'Visits',
                  ),
                ),
              ],
            ),
          if (route != null && route!.mockedPoints > 0)
            FakeGpsWarning(points: route!.mockedPoints),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Expanded(
                child: DsButton(
                  label: 'Stops & timeline',
                  arrow: true,
                  onPressed: started
                      ? () => context.push(Routes.userDay(d.id))
                      : null,
                ),
              ),
              const SizedBox(width: 10),
              _AddVisitButton(dayId: onDuty ? d!.id : null),
            ],
          ),
        ],
      ),
    );
  }

  /// "Updated just now", "Updated 3 min ago".
  static String _updatedText(DateTime now, DateTime at) {
    final int minutes = now.difference(at).inMinutes;
    return minutes < 1 ? 'Updated just now' : 'Updated $minutes min ago';
  }
}

class _Figure extends StatelessWidget {
  const _Figure({
    required this.icon,
    required this.tint,
    required this.color,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color tint;
  final Color color;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label $value',
      excludeSemantics: true,
      child: Row(
        children: <Widget>[
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
            child: Icon(icon, size: 17, color: color),
          ),
          const SizedBox(width: DsSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: DsText.body.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                Text(label, style: DsText.micro, maxLines: 1),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Round "Add visit" button: only on duty (greyed before).
class _AddVisitButton extends StatelessWidget {
  const _AddVisitButton({required this.dayId});

  final int? dayId;

  @override
  Widget build(BuildContext context) {
    final int? id = dayId;
    return Semantics(
      button: true,
      enabled: id != null,
      label: id == null ? 'Add visit, duty on first' : 'Add visit',
      excludeSemantics: true,
      child: Tooltip(
        message: id == null ? 'Duty on first' : 'Add visit',
        child: Material(
          color: id == null ? DsColors.disabled : DsColors.primaryTint,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: id == null
                ? null
                : () => context.push(Routes.userAddVisit(id)),
            child: SizedBox(
              width: 54,
              height: 54,
              child: Icon(
                DsIcons.camera,
                size: 22,
                color: id == null ? DsColors.text3 : DsColors.primary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
