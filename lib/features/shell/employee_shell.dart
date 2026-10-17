import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/widgets/app_bottom_navigation_bar.dart';
import '../../shared/widgets/lazy_indexed_stack.dart';
import '../history/presentation/my_duty_history_page.dart';
import '../home/presentation/employee_home_page.dart';
import '../map/presentation/employee_map_page.dart';
import 'employee_tab.dart';

/// Employee app root: one bottom bar over Duty, Map and History.
///
/// Profile is pushed on top of this shell from the Duty header.
class EmployeeShell extends ConsumerWidget {
  const EmployeeShell({super.key});

  static const List<AppNavItem> _items = <AppNavItem>[
    AppNavItem(
      label: 'Duty',
      icon: Icons.shield_outlined,
      activeIcon: Icons.shield_rounded,
    ),
    AppNavItem(
      label: 'Map',
      icon: Icons.map_outlined,
      activeIcon: Icons.map_rounded,
    ),
    AppNavItem(label: 'History', icon: Icons.history_rounded),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(employeeTabProvider);
    final notifier = ref.read(employeeTabProvider.notifier);

    return PopScope(
      // Back on any other tab returns to Duty before it leaves the app.
      canPop: tab == EmployeeTab.duty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) notifier.select(EmployeeTab.duty);
      },
      child: Scaffold(
        body: LazyIndexedStack(
          index: tab.index,
          children: const <Widget>[
            EmployeeHomePage(),
            EmployeeMapPage(),
            MyDutyHistoryPage(),
          ],
        ),
        bottomNavigationBar: AppBottomNavigationBar(
          items: _items,
          currentIndex: tab.index,
          onTap: (index) => notifier.select(EmployeeTab.values[index]),
        ),
      ),
    );
  }
}
