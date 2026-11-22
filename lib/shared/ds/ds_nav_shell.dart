import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/ds_colors.dart';
import 'ds_frame.dart';

/// The tabs of an app side around a [StatefulNavigationShell], with the
/// floating [DsNavBar] at the bottom. Each tab keeps its own screens and
/// scroll position. Tapping the open tab again goes back to its first
/// screen.
class DsNavShell extends StatelessWidget {
  const DsNavShell({required this.shell, required this.items, super.key});

  final StatefulNavigationShell shell;
  final List<DsNavItem> items;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: DsColors.surface,
    body: shell,
    bottomNavigationBar: ColoredBox(
      color: DsColors.surface,
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: DsNavBar(
          items: items,
          current: shell.currentIndex,
          onTap: (int index) => shell.goBranch(
            index,
            initialLocation: index == shell.currentIndex,
          ),
        ),
      ),
    ),
  );
}
