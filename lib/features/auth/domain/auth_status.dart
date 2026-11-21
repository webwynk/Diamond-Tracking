/// Who is using the app right now, as far as routing is concerned.
sealed class AuthStatus {
  const AuthStatus();
}

/// Startup: the stored session has not been read yet.
final class AuthLoading extends AuthStatus {
  const AuthLoading();
}

final class SignedOut extends AuthStatus {
  const SignedOut({this.unexpected = false});

  /// Signed out without the user asking: the admin reset the account or
  /// released the phone, or it was used on another phone. The app then
  /// says so ("You were signed out") before the sign-in screen.
  final bool unexpected;

  @override
  bool operator ==(Object other) =>
      other is SignedOut && other.unexpected == unexpected;

  @override
  int get hashCode => unexpected.hashCode;
}

/// Signed in. [role] decides which side of the app opens.
final class SignedIn extends AuthStatus {
  const SignedIn({
    required this.userId,
    required this.role,
    required this.mustChangePassword,
  });

  final String userId;
  final AppRole role;

  /// True after the admin created the account (or reset it) with a temporary
  /// PIN: the user must set their own password before anything else.
  final bool mustChangePassword;
}

enum AppRole {
  employee,
  admin;

  /// Reads the role from the session's `app_metadata`.
  ///
  /// `app_metadata` can only be written with the service key (by the admin's
  /// Edge Function), never by the user, so a user cannot make themselves an
  /// admin. This claim only decides which screens the app shows: the
  /// database's security rules check the role in the profiles table instead
  /// (L73). Anything unknown is treated as the least-privileged role.
  static AppRole fromClaim(Object? value) =>
      value == 'admin' ? AppRole.admin : AppRole.employee;
}

/// Builds the status from a session's user fields.
AuthStatus authStatusFromUser({
  required String? userId,
  required Map<String, dynamic>? appMetadata,
}) {
  if (userId == null) {
    return const SignedOut();
  }
  final Map<String, dynamic> meta = appMetadata ?? const <String, dynamic>{};
  return SignedIn(
    userId: userId,
    role: AppRole.fromClaim(meta['role']),
    mustChangePassword: meta['must_change_password'] == true,
  );
}
