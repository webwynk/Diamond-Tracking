import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/ds_icons.dart';
import '../../../shared/ds/ds_frame.dart';
import '../../../shared/ds/ds_nav_shell.dart';
import '../../requests/application/requests_providers.dart';

/// The admin's tabs (design v2): Home, Live, Requests, Team, Reports, on the
/// floating bar. Requests shows a red dot while something waits.
class AdminNavShell extends ConsumerWidget {
  const AdminNavShell({required this.shell, super.key});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool waiting =
        ref.watch(adminRequestsProvider(true)).value?.isNotEmpty ?? false;
    return DsNavShell(
      shell: shell,
      items: <DsNavItem>[
        const DsNavItem(icon: DsIcons.home, label: 'Home'),
        const DsNavItem(icon: DsIcons.live, label: 'Live'),
        DsNavItem(icon: DsIcons.requests, label: 'Requests', dot: waiting),
        const DsNavItem(icon: DsIcons.team, label: 'Team'),
        const DsNavItem(icon: DsIcons.reports, label: 'Reports'),
      ],
    );
  }
}
