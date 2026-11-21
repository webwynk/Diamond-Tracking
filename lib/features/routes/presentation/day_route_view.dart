import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/time/ist_format.dart';
import '../../../shared/widgets/app_error_view.dart';
import '../../duty/domain/duty_day.dart';
import '../../visits/application/visits_providers.dart';
import '../../visits/domain/visit.dart';
import '../../visits/presentation/visit_widgets.dart';
import '../application/route_providers.dart';
import '../domain/day_route.dart';
import 'app_map.dart';
import 'day_pins.dart';

/// A day's route: the map on top, the day's summary, stops and notes below.
/// While the duty is on it refreshes every 2 minutes.
class DayRouteView extends ConsumerStatefulWidget {
  const DayRouteView({required this.dayId, super.key});

  final int dayId;

  @override
  ConsumerState<DayRouteView> createState() => _DayRouteViewState();
}

class _DayRouteViewState extends ConsumerState<DayRouteView> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(minutes: 2), (_) {
      final DayView? view = ref.read(dayViewProvider(widget.dayId)).value;
      if (view?.day?.status == DayStatus.onDuty) {
        ref.invalidate(dayViewProvider(widget.dayId));
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<DayView> view = ref.watch(dayViewProvider(widget.dayId));
    return view.when(
      skipLoadingOnRefresh: true,
      data: (DayView v) => _Body(view: v),
      error: (_, _) => AppErrorView(
        onRetry: () => ref.invalidate(dayViewProvider(widget.dayId)),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.view});

  final DayView view;

  @override
  Widget build(BuildContext context) {
    final DayRoute? route = view.route;
    final DutyDay? day = view.day;
    return Column(
      children: <Widget>[
        Expanded(
          flex: 5,
          child: Consumer(
            builder: (BuildContext context, WidgetRef ref, Widget? _) => AppMap(
              lines: route?.segments ?? const [],
              pins: dayPins(
                day,
                route,
                day == null
                    ? const <Visit>[]
                    : ref.watch(dayVisitsProvider(day.id)).value ??
                          const <Visit>[],
              ),
            ),
          ),
        ),
        Expanded(
          flex: 4,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.x4),
            children: <Widget>[
              _Summary(day: day, route: route),
              if (route != null && route.mockedPoints > 0)
                FakeGpsWarning(points: route.mockedPoints),
              if (route == null || route.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: AppSpacing.x4),
                  child: Text('No route recorded for this day yet.'),
                ),
              ..._timeline(route),
              if (day != null) DayVisitsSection(dayId: day.id),
            ],
          ),
        ),
      ],
    );
  }

  /// Stops and notes in time order.
  static List<Widget> _timeline(DayRoute? route) {
    if (route == null) return const <Widget>[];
    final List<(DateTime, Widget)> items = <(DateTime, Widget)>[
      for (final RouteStop s in route.stops)
        (
          s.start,
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.place_rounded, color: AppColors.warning),
            title: Text(s.address ?? 'Finding address…'),
            subtitle: Text(stopTimes(s)),
          ),
        ),
      for (final RouteNote n in route.notes)
        (
          n.from,
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              n.kind == NoteKind.phoneOff
                  ? Icons.phonelink_erase_rounded
                  : Icons.location_disabled_rounded,
              color: AppColors.error,
            ),
            title: Text(
              '${n.label} ${IstFormat.time(n.from)} to ${IstFormat.time(n.to)}',
            ),
            subtitle: Text(IstFormat.duration(n.to.difference(n.from))),
          ),
        ),
    ]..sort(((DateTime, Widget) a, (DateTime, Widget) b) => a.$1.compareTo(b.$1));
    return <Widget>[for (final (DateTime, Widget) i in items) i.$2];
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.day, required this.route});

  final DutyDay? day;
  final DayRoute? route;

  @override
  Widget build(BuildContext context) {
    final DutyDay? d = day;
    final int metres = route?.distanceM ?? d?.distanceM ?? 0;
    final Duration? worked = d?.workedMinutes != null
        ? Duration(minutes: d!.workedMinutes!)
        : null;
    return Row(
      children: <Widget>[
        _Figure(label: 'Distance', value: formatKm(metres)),
        _Figure(
          label: 'Duty',
          value: worked == null ? '–' : IstFormat.duration(worked),
        ),
        _Figure(label: 'Stops', value: '${route?.stops.length ?? 0}'),
        if (d != null) _Figure(label: 'Status', value: d.status.label),
      ],
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
        ),
        Text(value, style: AppTypography.title),
      ],
    ),
  );
}

/// Shown when some of the day's points came from a fake-location app.
class FakeGpsWarning extends StatelessWidget {
  const FakeGpsWarning({required this.points, super.key});

  final int points;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: AppSpacing.x4),
    padding: const EdgeInsets.all(AppSpacing.x3),
    decoration: BoxDecoration(
      color: AppColors.errorBg,
      borderRadius: BorderRadius.circular(AppRadius.md),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Icon(Icons.gpp_bad_rounded, color: AppColors.error),
        const SizedBox(width: AppSpacing.x3),
        Expanded(
          child: Text(
            'Fake GPS: $points ${points == 1 ? 'point' : 'points'} came from '
            'a fake-location app. They are not counted in the route or the '
            'distance.',
            style: AppTypography.body.copyWith(color: AppColors.errorText),
          ),
        ),
      ],
    ),
  );
}

/// "12.4 km".
String formatKm(int metres) => '${(metres / 1000).toStringAsFixed(1)} km';
