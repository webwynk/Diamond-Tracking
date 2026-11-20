import '../features/auth/domain/auth_status.dart';

/// Every route path in one place.
abstract final class Routes {
  const Routes._();

  static const String splash = '/';
  static const String login = '/login';
  static const String setPassword = '/set-password';
  static const String forgotPassword = '/forgot-password';

  static const String userHome = '/home';
  static const String userMap = '/map';
  static const String userHistory = '/history';
  static const String userProfile = '/profile';
  static const String userChangePassword = '/profile/password';

  static const String adminDashboard = '/admin';
  static const String adminLiveMap = '/admin/live';
  static const String adminRequests = '/admin/requests';
  static const String adminUsers = '/admin/users';
  static const String adminReports = '/admin/reports';
  static const String adminUserNew = '/admin/users/new';
  static String adminUserEdit(String id) => '/admin/users/$id';
  static const String adminAccount = '/admin/account';
  static const String adminChangePassword = '/admin/account/password';

  static bool isAdminPath(String path) =>
      path == adminDashboard || path.startsWith('$adminDashboard/');

  static bool isUserPath(String path) =>
      path == userHome ||
      path == userMap ||
      path == userHistory ||
      path == userProfile ||
      path.startsWith('$userProfile/');

  /// Screens for signed-out users.
  static bool isPublicPath(String path) =>
      path == login || path == forgotPassword;
}

/// Where the app must go for [status] when the user tries to open [path].
/// Returns null to stay. Pure, so every case is unit-tested.
String? resolveRedirect(AuthStatus status, String path) {
  switch (status) {
    case AuthLoading():
      return path == Routes.splash ? null : Routes.splash;
    case SignedOut():
      return Routes.isPublicPath(path) ? null : Routes.login;
    case SignedIn(mustChangePassword: true):
      return path == Routes.setPassword ? null : Routes.setPassword;
    case SignedIn(role: AppRole.admin):
      return Routes.isAdminPath(path) ? null : Routes.adminDashboard;
    case SignedIn(role: AppRole.employee):
      return Routes.isUserPath(path) ? null : Routes.userHome;
  }
}
