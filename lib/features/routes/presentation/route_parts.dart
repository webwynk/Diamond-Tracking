import 'package:flutter/material.dart';

import '../../../core/design/ds_layout.dart';
import '../../../shared/ds/ds_feedback.dart';

/// "12.4 km".
String formatKm(int metres) => '${(metres / 1000).toStringAsFixed(1)} km';

/// Shown when some of the day's points came from a fake-location app.
class FakeGpsWarning extends StatelessWidget {
  const FakeGpsWarning({required this.points, super.key});

  final int points;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: DsSpace.md),
    child: DsBanner(
      kind: DsBannerKind.danger,
      title: 'Fake GPS: $points ${points == 1 ? 'point' : 'points'}',
      message:
          'They came from a fake-location app and are not counted in the '
          'route or the distance.',
    ),
  );
}
