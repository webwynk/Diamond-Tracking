import 'package:flutter/material.dart';

import '../../core/design/ds_colors.dart';
import '../../core/design/ds_icons.dart';
import '../../core/design/ds_layout.dart';
import '../../core/design/ds_status.dart';
import '../../core/design/ds_text.dart';

/// A white list card, radius 24, with rows inside (design v2, section 07).
class DsListCard extends StatelessWidget {
  const DsListCard({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: const BoxDecoration(
        color: DsColors.white,
        borderRadius: DsRadius.large,
        boxShadow: DsShadow.card,
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}

/// A row in a list card: a round 42 icon, a title (15 bold), a caption and
/// a chevron or a [trailing] widget (a pill, a small button).
class DsListRow extends StatelessWidget {
  const DsListRow({
    required this.title,
    this.subtitle,
    this.icon,
    this.status,
    this.leading,
    this.trailing,
    this.onTap,
    super.key,
  });

  final String title;
  final String? subtitle;

  /// Drawn in a round 42 tile, in the [status] colours (or primary tint).
  final IconData? icon;
  final DsStatus? status;

  /// Instead of [icon], for example initials.
  final Widget? leading;

  /// Instead of the chevron.
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Widget? lead =
        leading ??
        (icon == null
            ? null
            : Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: status?.tint ?? DsColors.primaryTint,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: status?.text ?? DsColors.primary,
                ),
              ));
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: DsRadius.medium,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: DsSpace.sm,
            ),
            child: Row(
              children: <Widget>[
                if (lead != null) ...<Widget>[
                  lead,
                  const SizedBox(width: DsSpace.md),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: DsText.body.copyWith(
                          fontWeight: FontWeight.w700,
                          fontVariations: const <FontVariation>[
                            FontVariation('wght', 700),
                          ],
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: DsText.caption,
                        ),
                    ],
                  ),
                ),
                if (trailing != null) ...<Widget>[
                  const SizedBox(width: DsSpace.sm),
                  trailing!,
                ] else if (onTap != null)
                  const Icon(DsIcons.forward, size: 20, color: DsColors.text3),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The one deep hero card of a screen (duty card, summary). Radius 24.
class DsHeroCard extends StatelessWidget {
  const DsHeroCard({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: const BoxDecoration(
        color: DsColors.deep,
        borderRadius: DsRadius.large,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Color(0x4001425A),
            offset: Offset(0, 14),
            blurRadius: 32,
          ),
        ],
      ),
      child: DefaultTextStyle.merge(
        style: const TextStyle(color: DsColors.white),
        child: child,
      ),
    );
  }
}

/// A stat tile: a soft tint with a matching dark number ("52 km",
/// "Distance"). At most 3 in a row. On a deep card use [onDeep].
class DsStatTile extends StatelessWidget {
  const DsStatTile({
    required this.value,
    required this.label,
    this.status = DsStatus.onDuty,
    this.onDeep = false,
    super.key,
  });

  final String value;
  final String label;
  final DsStatus status;
  final bool onDeep;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DsSpace.md,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: onDeep ? DsColors.deepRaised : status.tint,
        borderRadius: DsRadius.medium,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: DsText.value.copyWith(
                color: onDeep ? DsColors.white : status.text,
              ),
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: DsText.micro.copyWith(
              color: onDeep ? DsColors.skyText : DsColors.text2,
            ),
          ),
        ],
      ),
    );
  }
}
