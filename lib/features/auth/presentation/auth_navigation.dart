import 'package:flutter/material.dart';

import '../../../domain/entities/user_profile.dart';
import '../../admin/shell/admin_shell.dart';
import '../../shell/employee_shell.dart';
import 'employee_login_page.dart';

/// Single place that decides where a signed-in or signed-out user lands.
///
/// Every call replaces the whole back stack so the user can never navigate
/// "back" into a login, PIN-change or previous-session screen.
abstract final class AuthNavigation {
  /// The first screen a signed-in [profile] sees.
  static Widget landingFor(UserProfile profile) {
    return profile.role == UserRole.admin
        ? const AdminShell()
        : const EmployeeShell();
  }

  /// Replaces the stack with the landing screen for [profile].
  static void goToLanding(NavigatorState navigator, UserProfile profile) {
    navigator.pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => landingFor(profile)),
      (route) => false,
    );
  }

  /// Replaces the stack with the employee login screen (after sign-out).
  static void goToLogin(NavigatorState navigator) {
    navigator.pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const EmployeeLoginPage()),
      (route) => false,
    );
  }
}
