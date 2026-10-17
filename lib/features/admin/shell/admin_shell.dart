import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/live_position.dart';
import '../../../shared/widgets/app_bottom_navigation_bar.dart';
import '../../../shared/widgets/lazy_indexed_stack.dart';
import '../dashboard/presentation/admin_dashboard_page.dart';
import '../employees/presentation/admin_employee_list_page.dart';
import '../employees/presentation/controllers/admin_employee_list_controller.dart';
import '../map/presentation/admin_live_map_page.dart';
import '../map/presentation/controllers/admin_live_map_controller.dart';
import '../places/presentation/admin_places_page.dart';
import '../reports/presentation/admin_reports_page.dart';
import 'admin_tab.dart';

/// Admin app root: one bottom bar over the five tab screens.
///
/// Screens opened from a tab (detail pages, forms, notifications) are pushed on
/// top of this shell and therefore have no bottom bar.
class AdminShell extends ConsumerWidget {
  const AdminShell({super.key});

  static const List<AppNavItem> _items = <AppNavItem>[
    AppNavItem(
      label: 'Home',
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
    ),
    AppNavItem(
      label: 'Map',
      icon: Icons.map_outlined,
      activeIcon: Icons.map_rounded,
    ),
    AppNavItem(
      label: 'Team',
      icon: Icons.group_outlined,
      activeIcon: Icons.group_rounded,
    ),
    AppNavItem(
      label: 'Places',
      icon: Icons.domain_outlined,
      activeIcon: Icons.domain_rounded,
    ),
    AppNavItem(
      label: 'Reports',
      icon: Icons.bar_chart_outlined,
      activeIcon: Icons.bar_chart_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(adminTabProvider);
    final notifier = ref.read(adminTabProvider.notifier);

    // The Team list shows who is on duty as the live feed says it now, so it
    // never disagrees with the map. Skipped until the feed has loaded: unknown
    // is not "nobody is on duty".
    ref.listen(adminLiveMapControllerProvider, (_, live) {
      if (live.isLoading || live.errorMessage != null) return;
      ref.read(adminEmployeeListControllerProvider.notifier).applyLiveStatuses(
        <String, LiveStatus>{
          for (final officer in live.officers) officer.id: officer.status,
        },
      );
    });

    return PopScope(
      // Back on any other tab returns to Home before it leaves the app.
      canPop: tab == AdminTab.home,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) notifier.select(AdminTab.home);
      },
      child: Scaffold(
        body: LazyIndexedStack(
          index: tab.index,
          children: const <Widget>[
            AdminDashboardPage(),
            AdminLiveMapPage(),
            AdminEmployeeListPage(),
            AdminPlacesPage(),
            AdminReportsPage(),
          ],
        ),
        bottomNavigationBar: AppBottomNavigationBar(
          items: _items,
          currentIndex: tab.index,
          onTap: (index) => notifier.select(AdminTab.values[index]),
        ),
      ),
    );
  }
}
