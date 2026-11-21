import 'package:flutter/material.dart';

import '../../../core/design/ds_colors.dart';
import '../../../core/design/ds_icons.dart';
import '../../../core/design/ds_layout.dart';
import '../../../core/design/ds_text.dart';
import '../../../core/time/ist_format.dart';
import '../data/visit_outbox.dart';
import '../domain/visit.dart';
import 'visit_widgets.dart';

/// The line under a visit's store name (design v2): "8:12 AM · camera
/// photo", "10:28 AM · gallery photo, no place", with fake GPS first.
String visitLine(Visit v) {
  final String time = IstFormat.time(v.capturedAt);
  if (v.location == null) return '$time · gallery photo, no place';
  if (v.mocked) return '$time · fake GPS';
  return '$time · camera photo';
}

/// One visit in a day's timeline (design v2): a dot on the line, the
/// photo, the store and [visitLine]. Tap for the whole visit.
class VisitTimelineRow extends StatelessWidget {
  const VisitTimelineRow({
    required this.visit,
    required this.isLast,
    this.onTap,
    super.key,
  });

  final Visit visit;

  /// The last row has no line below its dot.
  final bool isLast;

  /// Defaults to opening the visit's detail page.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => _TimelineRow(
    title: visit.storeName,
    line: visitLine(visit),
    isLast: isLast,
    faded: visit.location == null || visit.mocked,
    thumbnail: visit.showsPhoto
        ? VisitPhoto(visitId: visit.id, small: true)
        : const _ThumbIcon(icon: _storeIcon),
    onTap:
        onTap ??
        () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => VisitDetailPage(visit: visit),
          ),
        ),
  );
}

/// A visit kept on the phone without internet, not sent yet (M10).
class PendingVisitTimelineRow extends StatelessWidget {
  const PendingVisitTimelineRow({
    required this.visit,
    required this.isLast,
    super.key,
  });

  final PendingVisit visit;
  final bool isLast;

  @override
  Widget build(BuildContext context) => _TimelineRow(
    title: visit.storeName,
    line: '${IstFormat.time(visit.capturedAt)} · waiting to send',
    isLast: isLast,
    faded: true,
    thumbnail: const _ThumbIcon(icon: DsIcons.offline),
  );
}

const IconData _storeIcon = DsIcons.pin;

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.title,
    required this.line,
    required this.isLast,
    required this.faded,
    required this.thumbnail,
    this.onTap,
  });

  final String title;
  final String line;
  final bool isLast;

  /// A grey dot instead of brand blue (no place, or waiting to send).
  final bool faded;
  final Widget thumbnail;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Color dot = faded ? DsColors.text3 : DsColors.primary;
    final Color halo = faded ? DsColors.disabled : DsColors.primaryTint;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SizedBox(
            width: 18,
            child: Column(
              children: <Widget>[
                const SizedBox(height: 21),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: dot,
                    shape: BoxShape.circle,
                    boxShadow: <BoxShadow>[
                      BoxShadow(color: halo, spreadRadius: 4),
                    ],
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.only(top: 6),
                      color: DsColors.line,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: DsSpace.md),
          Expanded(
            child: InkWell(
              onTap: onTap,
              borderRadius: DsRadius.medium,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: DsSize.tap),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: DsSpace.sm),
                  child: Row(
                    children: <Widget>[
                      ClipRRect(
                        borderRadius: DsRadius.medium,
                        child: SizedBox.square(dimension: 48, child: thumbnail),
                      ),
                      const SizedBox(width: DsSpace.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: DsText.body.copyWith(
                                fontWeight: FontWeight.w700,
                                fontVariations: const <FontVariation>[
                                  FontVariation('wght', 700),
                                ],
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(line, style: DsText.caption),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThumbIcon extends StatelessWidget {
  const _ThumbIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: DsColors.line,
    child: Icon(icon, size: 20, color: DsColors.text2),
  );
}
