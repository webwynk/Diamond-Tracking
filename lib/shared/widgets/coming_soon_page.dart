import 'package:flutter/material.dart';

import '../../core/theme/app_dimens.dart';
import 'app_empty_state.dart';

/// A screen that exists in the navigation but is built in a later phase.
class ComingSoonPage extends StatelessWidget {
  const ComingSoonPage({
    required this.title,
    required this.phase,
    required this.icon,
    super.key,
    this.actions = const <Widget>[],
  });

  final String title;
  final String phase;
  final IconData icon;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: actions),
      body: Padding(
        padding: AppSpacing.screen,
        child: AppEmptyState(
          title: title,
          description: 'This screen is built in $phase.',
          icon: icon,
        ),
      ),
    );
  }
}
