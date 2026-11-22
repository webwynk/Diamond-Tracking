import 'package:flutter/material.dart';

import '../../../core/design/ds_colors.dart';
import '../../../core/design/ds_layout.dart';
import '../../../core/design/ds_text.dart';

/// A white round button floating on a map ("Show my position").
class MapRoundButton extends StatelessWidget {
  const MapRoundButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    super.key,
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
class MapZoomButtons extends StatelessWidget {
  const MapZoomButtons({required this.onIn, required this.onOut, super.key});

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
