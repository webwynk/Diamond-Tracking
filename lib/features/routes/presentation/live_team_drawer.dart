import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/design/ds_colors.dart';
import '../../../core/design/ds_icons.dart';
import '../../../core/design/ds_layout.dart';
import '../../../core/design/ds_status.dart';
import '../../../core/design/ds_text.dart';
import '../../../shared/ds/ds_button.dart';
import '../../../shared/ds/ds_chips.dart';
import '../../../shared/ds/ds_field.dart';
import 'live_map_page.dart';
import 'route_parts.dart';

/// "Today's team" (design v2): the side list of everyone on today's live
/// map, grouped Needs attention / Live / Finished, with a search (name or
/// employee ID) and filters. Tapping a name shows that person on the map.
class LiveTeamDrawer extends StatefulWidget {
  const LiveTeamDrawer({
    required this.rows,
    required this.now,
    required this.onPick,
    super.key,
  });

  final List<LiveRow> rows;
  final DateTime now;
  final ValueChanged<LiveRow> onPick;

  @override
  State<LiveTeamDrawer> createState() => _LiveTeamDrawerState();
}

class _LiveTeamDrawerState extends State<LiveTeamDrawer> {
  LiveFilter? _filter;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final List<LiveRow> rows = widget.rows;
    final String q = _query.trim().toLowerCase();
    final int onDuty = rows.where((LiveRow r) => r.onDuty).length;
    final int done = rows.length - onDuty;
    final List<(LiveFilter, List<LiveRow>)> groups =
        <(LiveFilter, List<LiveRow>)>[
          for (final LiveFilter f in LiveFilter.values)
            if (_filter == null || _filter == f)
              (
                f,
                <LiveRow>[
                  for (final LiveRow r in rows)
                    if (f.matches(r) && (q.isEmpty || r.matches(q))) r,
                ],
              ),
        ];
    final bool none = groups.every(
      ((LiveFilter, List<LiveRow>) g) => g.$2.isEmpty,
    );
    final double width = math.min(322, MediaQuery.sizeOf(context).width * 0.86);
    return Drawer(
      width: width,
      backgroundColor: DsColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            DsSpace.lg,
            DsSpace.lg,
            DsSpace.lg,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Text("Today's team", style: DsText.title),
                        Text(
                          '$onDuty on duty, $done finished · tap a name',
                          style: DsText.caption.copyWith(color: DsColors.text2),
                        ),
                      ],
                    ),
                  ),
                  DsIconButton(
                    icon: DsIcons.close,
                    label: 'Close team list',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: DsSpace.md),
              DsSearchField(
                hint: 'Search name or ID',
                onChanged: (String v) => setState(() => _query = v),
              ),
              const SizedBox(height: DsSpace.xs),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: <Widget>[
                    DsFilterChip(
                      label: 'All',
                      count: rows.length,
                      selected: _filter == null,
                      onTap: () => setState(() => _filter = null),
                    ),
                    for (final LiveFilter f in LiveFilter.values) ...<Widget>[
                      const SizedBox(width: 6),
                      DsFilterChip(
                        label: f.label,
                        count: rows.where(f.matches).length,
                        selected: _filter == f,
                        onTap: () => setState(() => _filter = f),
                      ),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: none
                    ? Padding(
                        padding: const EdgeInsets.only(top: DsSpace.xl),
                        child: Text(
                          rows.isEmpty
                              ? 'Nobody has done duty on today yet.'
                              : 'Nobody matches.',
                          textAlign: TextAlign.center,
                          style: DsText.body.copyWith(color: DsColors.text2),
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.only(bottom: DsSpace.xl),
                        children: <Widget>[
                          for (final (LiveFilter f, List<LiveRow> people)
                              in groups)
                            if (people.isNotEmpty) ...<Widget>[
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  DsSpace.xs,
                                  DsSpace.md,
                                  DsSpace.xs,
                                  DsSpace.xs,
                                ),
                                child: Text(
                                  '${f == LiveFilter.attention ? 'NEEDS ATTENTION' : f.label.toUpperCase()}'
                                  ' · ${people.length}',
                                  style: DsText.micro.copyWith(
                                    color: f.status.text,
                                    letterSpacing: 0.7,
                                  ),
                                ),
                              ),
                              for (final LiveRow r in people)
                                LiveTeamRow(
                                  row: r,
                                  now: widget.now,
                                  onTap: () => widget.onPick(r),
                                ),
                            ],
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A person's square initials in their state's colours, with a status dot.
class LiveAvatar extends StatelessWidget {
  const LiveAvatar({
    required this.row,
    this.size = 38,
    this.dot = true,
    super.key,
  });

  final LiveRow row;
  final double size;
  final bool dot;

  @override
  Widget build(BuildContext context) {
    final DsStatus s = row.state.status;
    return SizedBox.square(
      dimension: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Positioned.fill(
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: s.tint,
                borderRadius: DsRadius.medium,
              ),
              child: Text(
                row.initials,
                style: DsText.label.copyWith(
                  color: s.text,
                  fontWeight: FontWeight.w700,
                  fontSize: size > 40 ? 15 : 12,
                ),
              ),
            ),
          ),
          if (dot)
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: s.dot,
                  shape: BoxShape.circle,
                  border: Border.all(color: DsColors.white, width: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// One name in the team list: initials, the short line, battery.
class LiveTeamRow extends StatelessWidget {
  const LiveTeamRow({
    required this.row,
    required this.now,
    required this.onTap,
    super.key,
  });

  final LiveRow row;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool alert = row.needsAttention;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: alert
            ? DsColors.warningTint.withValues(alpha: 0.55)
            : Colors.transparent,
        borderRadius: DsRadius.medium,
        child: InkWell(
          borderRadius: DsRadius.medium,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            child: Row(
              children: <Widget>[
                LiveAvatar(row: row),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        row.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: DsText.body.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        liveLine(row, now),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: DsText.caption.copyWith(
                          color: alert ? row.state.status.text : DsColors.text2,
                          fontWeight: alert ? FontWeight.w700 : null,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: DsSpace.sm),
                Semantics(
                  label: 'Battery ${row.battery}',
                  excludeSemantics: true,
                  child: Text(
                    row.battery,
                    style: DsText.caption.copyWith(
                      fontWeight: FontWeight.w700,
                      color: row.lowBattery
                          ? DsColors.dangerText
                          : DsColors.slate,
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

/// "Needs attention" over the bottom of the map: a swipeable card per
/// person with no update or fake GPS.
class AttentionCards extends StatefulWidget {
  const AttentionCards({
    required this.rows,
    required this.now,
    required this.onPick,
    super.key,
  });

  final List<LiveRow> rows;
  final DateTime now;
  final ValueChanged<LiveRow> onPick;

  @override
  State<AttentionCards> createState() => _AttentionCardsState();
}

class _AttentionCardsState extends State<AttentionCards> {
  final PageController _pages = PageController(viewportFraction: 0.9);
  int _page = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<LiveRow> rows = widget.rows;
    final int page = math.min(_page, rows.length - 1);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: DsSpace.gutter),
          child: Row(
            children: <Widget>[
              Container(
                height: 30,
                padding: const EdgeInsets.only(left: 12, right: 6),
                decoration: const BoxDecoration(
                  color: DsColors.ink,
                  borderRadius: DsRadius.pill,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        'Needs attention',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: DsText.micro.copyWith(color: DsColors.white),
                      ),
                    ),
                    const SizedBox(width: 6),
                    DsCountBadge(count: rows.length, waiting: true),
                  ],
                ),
              ),
              const SizedBox(width: DsSpace.sm),
              Expanded(
                child: rows.length < 2
                    ? const SizedBox.shrink()
                    : Align(
                        alignment: Alignment.centerRight,
                        child: Container(
                          height: 30,
                          padding: const EdgeInsets.symmetric(horizontal: 10),

                          decoration: const BoxDecoration(
                            color: DsColors.white,
                            borderRadius: DsRadius.pill,
                          ),
                          child: Center(
                            widthFactor: 1,
                            child: Text(
                              'Swipe for more',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: DsText.micro.copyWith(
                                color: DsColors.text2,
                              ),
                            ),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
        const SizedBox(height: DsSpace.sm),
        SizedBox(
          height: 82,
          child: PageView.builder(
            controller: _pages,
            padEnds: false,
            itemCount: rows.length,
            onPageChanged: (int i) => setState(() => _page = i),
            itemBuilder: (BuildContext context, int i) => Padding(
              padding: EdgeInsets.only(
                left: i == 0 ? DsSpace.gutter : 5,
                right: i == rows.length - 1 ? DsSpace.gutter : 5,
              ),
              child: _AttentionCard(
                row: rows[i],
                now: widget.now,
                onTap: () => widget.onPick(rows[i]),
              ),
            ),
          ),
        ),
        if (rows.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: DsSpace.sm),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                for (int i = 0; i < rows.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == page ? 20 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: i == page ? DsColors.ink : DsColors.text3,
                      borderRadius: DsRadius.pill,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _AttentionCard extends StatelessWidget {
  const _AttentionCard({
    required this.row,
    required this.now,
    required this.onTap,
  });

  final LiveRow row;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final int km = row.day.distanceM ?? 0;
    final String third = row.state == LiveState.fake
        ? 'Location may be false · ${formatKm(km)}'
        : '${row.battery} battery · ${formatKm(km)}';
    return Material(
      color: DsColors.white,
      borderRadius: DsRadius.large,
      elevation: 6,
      shadowColor: const Color(0x330F172A),
      child: InkWell(
        borderRadius: DsRadius.large,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(DsSpace.md),
          child: Row(
            children: <Widget>[
              LiveAvatar(row: row, size: 44, dot: false),
              const SizedBox(width: DsSpace.md),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      row.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DsText.body.copyWith(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      liveLine(row, now),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DsText.caption.copyWith(
                        color: row.state.status.text,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      third,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DsText.caption.copyWith(
                        color: row.lowBattery && row.state != LiveState.fake
                            ? DsColors.dangerText
                            : DsColors.text2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: DsSpace.sm),
              Semantics(
                button: true,
                label: "View ${row.name}'s route",
                excludeSemantics: true,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: DsColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    DsIcons.route,
                    size: 18,
                    color: DsColors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
