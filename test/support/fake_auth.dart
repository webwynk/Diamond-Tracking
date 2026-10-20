import 'package:diamond_tracking/domain/entities/user_profile.dart';
import 'package:diamond_tracking/features/auth/presentation/controllers/auth_controller.dart';
import 'package:diamond_tracking/features/auth/presentation/controllers/auth_state.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

/// An [AuthNotifier] that starts in a fixed state, so a test never builds the
/// real auth repository (which needs a Supabase client).
class FixedAuthNotifier extends AuthNotifier {
  FixedAuthNotifier(this._initial);

  final AuthState _initial;

  @override
  AuthState build() => _initial;
}

/// An active admin profile for tests.
UserProfile testAdmin({String fullName = 'Operations Administrator'}) =>
    UserProfile(
      id: 'admin-123',
      role: UserRole.admin,
      status: UserStatus.active,
      fullName: fullName,
      email: 'admin@diamondagritech.in',
      mustChangePin: false,
      failedLoginAttempts: 0,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

/// Signs the test in as an admin named [fullName].
Override signedInAdminOverride({
  String fullName = 'Operations Administrator',
}) => authControllerProvider.overrideWith(
  () => FixedAuthNotifier(AuthAuthenticated(testAdmin(fullName: fullName))),
);
