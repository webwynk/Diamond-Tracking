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
import '../../../core/time/ist_format.dart';
import '../../../shared/ds/ds_button.dart';
import '../../../shared/ds/ds_cards.dart';
import '../../../shared/ds/ds_frame.dart';
import '../../visits/domain/visit.dart';
import '../application/route_providers.dart';
import 'day_route_page.dart';
import 'live_map_page.dart';
import 'live_team_drawer.dart';
import 'route_parts.dart';

/// The card at the bottom of the live map when a person is picked: who,
/// how they are now, km / duty time / visits, and buttons for their stops
/// and full day route.
class LivePersonCard extends ConsumerWidget {
  const LivePersonCard({
    required this.row,
    required this.now,
    required this.view,
    required this.visits,
    super.key,
  });

  final LiveRow row;
  final DateTime now;
  final AsyncValue<DayView> view;
  final AsyncValue<List<Visit>> visits;

  Future<void> _call(BuildContext context, WidgetRef ref, String phone) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final bool opened = await ref.read(openLinkProvider)(
      Uri(scheme: 'tel', path: phone),
    );
    if (!opened) {
      messenger.showSnackBar(
        const SnackBar(content: Text("Couldn't open the phone app.")),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DayView? v = view.value;
    final String? phone = row.phone?.trim();
    final int? battery = row.onDuty ? row.position?.battery : null;
    final int metres = row.day.distanceM ?? v?.route?.distanceM ?? 0;
    final Duration? worked = workedSoFar(row.day, now);
    final int stops = v?.route?.stops.length ?? 0;
    final bool loading = view.isLoading && v == null;
    return Container(
      decoration: const BoxDecoration(
        color: DsColors.white,
        borderRadius: DsRadius.sheetTop,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Color(0x240F172A),
            blurRadius: 34,
            offset: Offset(0, -12),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(
        DsSpace.gutter,
        10,
        DsSpace.gutter,
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
                color: DsColors.line,
                borderRadius: DsRadius.pill,
              ),
            ),
          ),
          const SizedBox(height: DsSpace.md),
          Row(
            children: <Widget>[
              LiveAvatar(row: row, size: 44, dot: false),
              const SizedBox(width: DsSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      row.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DsText.value.copyWith(fontSize: 17),
                    ),
                    _StateLine(row: row, now: now),
                  ],
                ),
              ),
              if (battery != null) ...<Widget>[
                const SizedBox(width: DsSpace.sm),
                BatteryChip(percent: battery),
              ],
            ],
          ),
          const SizedBox(height: DsSpace.md),
          Row(
            children: <Widget>[
              Expanded(
                child: DsStatTile(value: formatKm(metres), label: 'Distance'),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: DsStatTile(
                  value: worked == null ? '–' : IstFormat.hoursMinutes(worked),
                  label: 'On duty',
                  status: DsStatus.present,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: DsStatTile(
                  value: visits.hasValue ? '${visits.value!.length}' : '–',
                  label: 'Visits',
                  status: DsStatus.leave,
                ),
              ),
            ],
          ),
          if (view.hasError && v == null) ...<Widget>[
            const SizedBox(height: DsSpace.sm),
            Text(
              'Could not load the route. It tries again in 2 minutes.',
              style: DsText.caption.copyWith(color: DsColors.dangerText),
            ),
          ],
          const SizedBox(height: DsSpace.md),
          Row(
            children: <Widget>[
              if (phone != null && phone.isNotEmpty) ...<Widget>[
                _CallButton(
                  name: row.name,
                  onTap: () => _call(context, ref, phone),
                ),
                const SizedBox(width: DsSpace.sm),
              ],
              Expanded(
                child: DsButton(
                  label: loading ? 'Stops' : 'Stops $stops',
                  kind: DsButtonKind.outline,
                  icon: DsIcons.pin,
                  onPressed: v == null
                      ? null
                      : () => showDsSheet<void>(
                          context: context,
                          builder: (BuildContext context) => _StopsSheet(
                            row: row,
                            view: v,
                            visits: visits.value ?? const <Visit>[],
                          ),
                        ),
                ),
              ),
              const SizedBox(width: DsSpace.sm),
              Expanded(
                child: DsButton(
                  label: 'Full route',
                  icon: DsIcons.route,
                  onPressed: () => context.push(Routes.adminDay(row.day.id)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// "● Live · 1 min ago · since 7:12 AM".
class _StateLine extends StatelessWidget {
  const _StateLine({required this.row, required this.now});

  final LiveRow row;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final DsStatus s = row.state.status;
    final String since = row.day.dutyOnAt == null
        ? ''
        : IstFormat.time(row.day.dutyOnAt!);
    final (String word, String rest) = switch (row.state) {
      LiveState.live => ('Live', '${liveLine(row, now)} · since $since'),
      LiveState.stale => (
        'No update',
        '${row.position == null ? 'no location yet' : IstFormat.duration(now.difference(row.position!.recordedAt))}'
            ' · since $since',
      ),
      LiveState.fake => (
        'Fake GPS',
        'at ${IstFormat.time(row.position!.recordedAt)} · since $since',
      ),
      LiveState.done => (
        'Finished',
        row.day.dutyOffAt == null
            ? row.day.status.label
            : '$since – ${IstFormat.time(row.day.dutyOffAt!)}',
      ),
    };
    return Row(
      children: <Widget>[
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: s.dot, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: <InlineSpan>[
                TextSpan(
                  text: word,
                  style: TextStyle(color: s.text, fontWeight: FontWeight.w700),
                ),
                TextSpan(text: ' · $rest'),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: DsText.caption.copyWith(color: DsColors.text2),
          ),
        ),
      ],
    );
  }
}

/// "Rahul's stops today": the day's timeline (the same as the Day route)
/// and a link to the full day route.
class _StopsSheet extends StatelessWidget {
  const _StopsSheet({
    required this.row,
    required this.view,
    required this.visits,
  });

  final LiveRow row;
  final DayView view;
  final List<Visit> visits;

  @override
  Widget build(BuildContext context) {
    final int stops = view.route?.stops.length ?? 0;
    final int metres = row.day.distanceM ?? view.route?.distanceM ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    "${row.firstName}'s stops today",
                    style: DsText.value.copyWith(fontSize: 17),
                  ),
                  Text(
                    '$stops ${stops == 1 ? 'stop' : 'stops'} · '
                    '${visits.length} ${visits.length == 1 ? 'visit' : 'visits'}'
                    ' · ${formatKm(metres)}',
                    style: DsText.caption.copyWith(color: DsColors.text2),
                  ),
                ],
              ),
            ),
            DsIconButton(
              icon: DsIcons.close,
              label: 'Close stops',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
        const SizedBox(height: DsSpace.md),
        DayTimeline(
          day: view.day ?? row.day,
          route: view.route,
          visits: visits,
          updatedAt: row.position?.recordedAt,
        ),
        const SizedBox(height: DsSpace.sm),
        Center(
          child: DsTextLink(
            label: 'See full day route',
            onPressed: () {
              Navigator.of(context).pop();
              context.push(Routes.adminDay(row.day.id));
            },
          ),
        ),
      ],
    );
  }
}

/// Zoom in, zoom out and "centre on" buttons on the right of the map.
class MapControls extends StatelessWidget {
  const MapControls({
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onCentre,
    required this.centreLabel,
    super.key,
  });

  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback? onCentre;
  final String centreLabel;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      Container(
        width: 48,
        decoration: const BoxDecoration(
          color: DsColors.white,
          borderRadius: BorderRadius.all(Radius.circular(24)),
          boxShadow: DsShadow.card,
        ),
        child: Column(
          children: <Widget>[
            IconButton(
              tooltip: 'Zoom in',
              icon: const Icon(DsIcons.add, size: 20, color: DsColors.ink),
              onPressed: onZoomIn,
            ),
            Container(
              height: 1,
              margin: const EdgeInsets.symmetric(horizontal: 10),
              color: DsColors.line,
            ),
            IconButton(
              tooltip: 'Zoom out',
              icon: const Icon(DsIcons.minus, size: 20, color: DsColors.ink),
              onPressed: onZoomOut,
            ),
          ],
        ),
      ),
      const SizedBox(height: 10),
      DsIconButton(
        icon: DsIcons.locate,
        label: centreLabel,
        onPressed: onCentre,
      ),
    ],
  );
}

/// A round green button that opens the phone's dialler.
class _CallButton extends StatelessWidget {
  const _CallButton({required this.name, required this.onTap});

  final String name;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Call $name',
    excludeSemantics: true,
    child: Material(
      color: DsColors.successTint,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: const SizedBox.square(
          dimension: 52,
          child: Icon(DsIcons.phone, size: 20, color: DsColors.successText),
        ),
      ),
    ),
  );
}

/// "64%" with a battery icon; red at 20% or less.
class BatteryChip extends StatelessWidget {
  const BatteryChip({required this.percent, super.key});

  final int percent;

  @override
  Widget build(BuildContext context) {
    final bool low = percent <= 20;
    final Color fg = low ? DsColors.dangerText : DsColors.slate;
    return Semantics(
      label: 'Battery $percent percent',
      excludeSemantics: true,
      child: Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: low ? DsColors.dangerTint : DsColors.disabled,
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
