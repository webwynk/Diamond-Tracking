import 'package:flutter/material.dart';

import '../../../core/design/ds_colors.dart';
import '../../../core/design/ds_status.dart';
import '../../duty/domain/duty_day.dart';

/// The colours of the "last 30 days" squares (design v2).
abstract final class RecentDayColours {
  static const Color present = DsColors.primary;
  static const Color half = Color(0xFF7DD3FC);
  static const Color absent = Color(0xFFF87171);
  static const Color none = Color(0xFFE2E8F0);
  static const Color highlight = Color(0xFFF59E0B);
  static final Color leave = DsStatus.leave.dot;

  /// A day's colour: present (or on duty), half, absent, leave, waiting,
  /// or no duty.
  static Color of(DayStatus? s) => switch (s) {
    DayStatus.present || DayStatus.onDuty => present,
    DayStatus.halfDay => half,
    DayStatus.absent => absent,
    DayStatus.leave => leave,
    DayStatus.pending => highlight,
    null => none,
  };
}

/// The last [days] (oldest first) as small squares in rows of 15, coloured
/// by [byDay]. [ring] gets a ring in [ringColour] (and that colour, when
/// [fillRing]).
class RecentDaysGrid extends StatelessWidget {
  const RecentDaysGrid({
    required this.days,
    required this.byDay,
    this.ring,
    this.ringColour = RecentDayColours.highlight,
    this.fillRing = false,
    this.height = 16,
    super.key,
  });

  final List<DateTime> days;
  final Map<DateTime, DayStatus> byDay;
  final DateTime? ring;
  final Color ringColour;
  final bool fillRing;
  final double height;

  @override
  Widget build(BuildContext context) {
    final int rows = (days.length / 15).ceil();
    return ExcludeSemantics(
      child: Column(
        children: <Widget>[
          for (int row = 0; row < rows; row++) ...<Widget>[
            if (row > 0) const SizedBox(height: 4),
            Row(
              children: <Widget>[
                for (int i = 0; i < 15; i++) ...<Widget>[
                  if (i > 0) const SizedBox(width: 4),
                  Expanded(
                    child: row * 15 + i >= days.length
                        ? const SizedBox.shrink()
                        : _square(days[row * 15 + i]),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _square(DateTime d) {
    final bool ringed = d == ring;
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: ringed && fillRing ? ringColour : RecentDayColours.of(byDay[d]),
        borderRadius: BorderRadius.circular(4),
        boxShadow: ringed
            ? <BoxShadow>[
                const BoxShadow(color: DsColors.white, spreadRadius: 2),
                BoxShadow(color: ringColour, spreadRadius: 3),
              ]
            : null,
      ),
    );
  }
}
