import 'package:flutter/material.dart';

import '../../core/design/ds_colors.dart';
import '../../core/design/ds_layout.dart';
import '../../core/design/ds_status.dart';
import '../../core/design/ds_text.dart';

/// A filter chip, 36 tall (design v2, section 06). Selected is ink; the
/// others are white with a line border. An optional [count] sits after the
/// label. The tap area is 48.
class DsFilterChip extends StatelessWidget {
  const DsFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
    this.dot,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int? count;

  /// A small coloured dot before the label (a status colour).
  final Color? dot;

  @override
  Widget build(BuildContext context) {
    final Color fg = selected ? DsColors.white : DsColors.ink;
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: DsSize.tap),
          child: Center(
            widthFactor: 1,
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: selected ? DsColors.ink : DsColors.white,
                borderRadius: DsRadius.pill,
                border: selected ? null : Border.all(color: DsColors.line),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (dot != null) ...<Widget>[
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: dot,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    label,
                    style: DsText.label.copyWith(color: fg, fontSize: 14),
                  ),
                  if (count != null) ...<Widget>[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0x33FFFFFF)
                            : DsColors.disabled,
                        borderRadius: DsRadius.pill,
                      ),
                      child: Text(
                        '$count',
                        style: DsText.micro.copyWith(color: fg),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A status pill, 26 tall: the status tint, text and dot (design v2,
/// section 06). Always from the one status colour set.
class DsStatusPill extends StatelessWidget {
  const DsStatusPill({required this.status, required this.label, super.key});

  final DsStatus status;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(color: status.tint, borderRadius: DsRadius.pill),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: status.dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            maxLines: 1,
            style: DsText.caption.copyWith(
              color: status.text,
              fontWeight: FontWeight.w700,
              fontVariations: const <FontVariation>[
                FontVariation('wght', 700),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A small tag: "Optional", "Required", "Recording".
class DsTag extends StatelessWidget {
  const DsTag({required this.label, this.status, super.key});

  final String label;

  /// Coloured with this status; grey without one.
  final DsStatus? status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: DsSpace.sm, vertical: 2),
      decoration: BoxDecoration(
        color: status?.tint ?? DsColors.disabled,
        borderRadius: DsRadius.pill,
      ),
      child: Text(
        label,
        style: DsText.micro.copyWith(color: status?.text ?? DsColors.text2),
      ),
    );
  }
}
