import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../core/design/ds_colors.dart';
import '../../../core/design/ds_layout.dart';
import '../../../core/design/ds_status.dart';
import '../../../core/design/ds_text.dart';
import '../../duty/domain/duty_day.dart';
import '../domain/report.dart';

/// "1 – 21 Nov", "28 Oct – 3 Nov", or with [withYear] "1 – 21 Nov 2026".
String rangeLabel(ReportRange r, {bool withYear = false}) {
  final String y = withYear ? ' ${r.to.year}' : '';
  final DateFormat dm = DateFormat('d MMM');
  if (r.from == r.to) return '${dm.format(r.from)}$y';
  if (r.from.month == r.to.month && r.from.year == r.to.year) {
    return '${r.from.day} – ${dm.format(r.to)}$y';
  }
  if (r.from.year != r.to.year) {
    return '${DateFormat('d MMM yyyy').format(r.from)} – '
        '${DateFormat('d MMM yyyy').format(r.to)}';
  }
  return '${dm.format(r.from)} – ${dm.format(r.to)}$y';
}

/// A grey pill with an icon: the dates, the person, which days.
class ReportChip extends StatelessWidget {
  const ReportChip({
    required this.icon,
    required this.label,
    this.onTap,
    this.height = 34,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final double height;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    button: onTap != null,
    label: label,
    excludeSemantics: true,
    child: Material(
      color: const Color(0xFFEEF2F6),
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 14, color: DsColors.primary),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DsText.caption.copyWith(
                    color: DsColors.ink,
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

/// The four status tiles: Present, Half day, Leave, Absent.
class StatusTotals extends StatelessWidget {
  const StatusTotals({
    required this.present,
    required this.halfDay,
    required this.leave,
    required this.absent,
    this.big = false,
    super.key,
  });

  final int present;
  final int halfDay;
  final int leave;
  final int absent;
  final bool big;

  @override
  Widget build(BuildContext context) {
    Widget tile(int n, String label, Color bg, Color fg) => Expanded(
      child: Semantics(
        container: true,
        label: '$label $n',
        excludeSemantics: true,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: big ? 10 : 8, vertical: 10),
          decoration: BoxDecoration(color: bg, borderRadius: DsRadius.medium),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '$n',
                style: (big ? DsText.title : DsText.section).copyWith(
                  color: fg,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                style: DsText.micro.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return Row(
      children: <Widget>[
        tile(present, 'Present', DsColors.primaryTint, DsColors.deep),
        const SizedBox(width: 6),
        tile(halfDay, 'Half day', DsStatus.halfDay.tint, DsStatus.halfDay.text),
        const SizedBox(width: 6),
        tile(leave, 'Leave', DsStatus.leave.tint, const Color(0xFF4C1D95)),
        const SizedBox(width: 6),
        tile(absent, 'Absent', DsColors.dangerTint, const Color(0xFF991B1B)),
      ],
    );
  }
}

/// Totals of [days] by status.
({int present, int halfDay, int leave, int absent}) statusCounts(
  Iterable<DayStatus> days,
) {
  int p = 0, h = 0, l = 0, a = 0;
  for (final DayStatus s in days) {
    switch (s) {
      case DayStatus.present:
        p++;
      case DayStatus.halfDay:
        h++;
      case DayStatus.leave:
        l++;
      case DayStatus.absent:
        a++;
      case DayStatus.onDuty || DayStatus.pending:
        break;
    }
  }
  return (present: p, halfDay: h, leave: l, absent: a);
}
