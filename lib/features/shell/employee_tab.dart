import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The three employee tabs, in bottom-bar order.
enum EmployeeTab { duty, map, history }

/// The selected employee tab. Any page can switch tabs through this provider.
final employeeTabProvider =
    NotifierProvider.autoDispose<EmployeeTabNotifier, EmployeeTab>(
      EmployeeTabNotifier.new,
    );

class EmployeeTabNotifier extends Notifier<EmployeeTab> {
  @override
  EmployeeTab build() => EmployeeTab.duty;

  void select(EmployeeTab tab) => state = tab;
}
