import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// One bottom-navigation tab.
class NavTab {
  const NavTab({required this.label, required this.icon});
  final String label;
  final IconData icon;
}

/// Bottom navigation around a [StatefulNavigationShell]. Each tab keeps its
/// own navigation stack and scroll position when the user switches tabs.
class NavShell extends StatelessWidget {
  const NavShell({required this.shell, required this.tabs, super.key});

  final StatefulNavigationShell shell;
  final List<NavTab> tabs;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (int index) => shell.goBranch(
          index,
          // Tapping the current tab again returns to its first screen.
          initialLocation: index == shell.currentIndex,
        ),
        destinations: <NavigationDestination>[
          for (final NavTab tab in tabs)
            NavigationDestination(icon: Icon(tab.icon), label: tab.label),
        ],
      ),
    );
  }
}
