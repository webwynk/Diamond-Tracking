import '../features/auth/domain/auth_status.dart';

/// Every route path in one place.
abstract final class Routes {
  const Routes._();

  static const String splash = '/';
  static const String login = '/login';
  static const String setPassword = '/set-password';

  static const String userHome = '/home';
  static const String userMap = '/map';
  static const String userHistory = '/history';
  static const String userProfile = '/profile';

  static const String adminDashboard = '/admin';
  static const String adminLiveMap = '/admin/live';
  static const String adminRequests = '/admin/requests';
  static const String adminUsers = '/admin/users';
  static const String adminReports = '/admin/reports';

  static bool isAdminPath(String path) =>
      path == adminDashboard || path.startsWith('$adminDashboard/');

  static bool isUserPath(String path) =>
      path == userHome ||
      path == userMap ||
      path == userHistory ||
      path == userProfile;
}

/// Where the app must go for [status] when the user tries to open [path].
/// Returns null to stay. Pure, so every case is unit-tested.
String? resolveRedirect(AuthStatus status, String path) {
  switch (status) {
    case AuthLoading():
      return path == Routes.splash ? null : Routes.splash;
    case SignedOut():
      return path == Routes.login ? null : Routes.login;
    case SignedIn(mustChangePassword: true):
      return path == Routes.setPassword ? null : Routes.setPassword;
    case SignedIn(role: AppRole.admin):
      return Routes.isAdminPath(path) ? null : Routes.adminDashboard;
    case SignedIn(role: AppRole.employee):
      return Routes.isUserPath(path) ? null : Routes.userHome;
  }
}
