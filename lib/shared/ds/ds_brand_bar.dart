import 'package:flutter/material.dart';

import '../../core/design/ds_colors.dart';
import '../../core/design/ds_layout.dart';
import '../../core/design/ds_text.dart';

/// The white bar at the top of both home screens (employee Home and admin
/// Dashboard): the logo in a blue tile, "Diamond Agritech", and [trailing]
/// (the bell). It sits under the phone's status bar and stays put while
/// the page scrolls under it.
class DsBrandBar extends StatelessWidget {
  const DsBrandBar({required this.trailing, super.key});

  final Widget trailing;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.fromLTRB(
      DsSpace.gutter,
      MediaQuery.paddingOf(context).top + DsSpace.sm,
      DsSpace.gutter,
      DsSpace.sm,
    ),
    decoration: const BoxDecoration(
      color: DsColors.white,
      border: Border(bottom: BorderSide(color: DsColors.line)),
    ),
    child: Row(
      children: <Widget>[
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: DsColors.primary,
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          child: Image.asset(
            'assets/image/white-logo.png',
            width: 28,
            excludeFromSemantics: true,
          ),
        ),
        const SizedBox(width: DsSpace.md),
        Expanded(
          child: Text(
            'Diamond Agritech',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: DsText.body.copyWith(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
              color: DsColors.primary,
            ),
          ),
        ),
        const SizedBox(width: DsSpace.sm),
        trailing,
      ],
    ),
  );
}
