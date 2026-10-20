import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The four admin tabs, in bottom-bar order.
enum AdminTab { home, map, team, reports }

/// The selected admin tab. Any page can switch tabs through this provider.
final adminTabProvider =
    NotifierProvider.autoDispose<AdminTabNotifier, AdminTab>(
      AdminTabNotifier.new,
    );

class AdminTabNotifier extends Notifier<AdminTab> {
  @override
  AdminTab build() => AdminTab.home;

  void select(AdminTab tab) => state = tab;
}
