import '../entities/user_profile.dart';

/// Contract for authentication operations in Diamond Agritech Tracking.
///
/// Implemented by [SupabaseAuthRepository] in the data layer.
abstract class AuthRepository {
  /// Returns the currently authenticated user's profile, or null if no session exists.
  Future<UserProfile?> getCurrentProfile();

  /// Authenticates an employee using employee code (e.g. "DA-014") and 6-digit PIN.
  ///
  /// Enforces BR-6 (blocked check) and BR-13 (single-device binding).
  Future<UserProfile> signInEmployee({
    required String employeeCode,
    required String pin,
    required String deviceId,
  });

  /// Authenticates an office administrator using email and password.
  ///
  /// Verifies the profile possesses the 'admin' role.
  Future<UserProfile> signInAdmin({
    required String email,
    required String password,
  });

  /// Completes the forced or user-initiated PIN change, updating auth credentials
  /// and clearing `must_change_pin`.
  Future<void> changePin({
    required String newPin,
  });

  /// Terminates the current authenticated session.
  Future<void> signOut();

  /// Stream of the current user profile state. Emits null on sign-out.
  Stream<UserProfile?> get authProfileChanges;
}
