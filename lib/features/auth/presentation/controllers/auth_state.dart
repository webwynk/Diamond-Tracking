import 'package:diamond_tracking/domain/entities/user_profile.dart';

/// Represents the distinct states of user authentication in Diamond Agritech Tracking.
sealed class AuthState {
  const AuthState();
}

/// Checking persistent session at app launch (Splash screen).
class AuthInitial extends AuthState {
  const AuthInitial();
}

/// No active session exists. User is on login screen.
class AuthUnauthenticated extends AuthState {
  final String? errorMessage;
  const AuthUnauthenticated({this.errorMessage});
}

/// Authentication action in flight (signing in, validating PIN, etc.).
class AuthLoading extends AuthState {
  final String? message;
  const AuthLoading({this.message});
}

/// Authenticated employee who is required to change their PIN on first login (Screen 04).
/// Unskippable per PRD F1.
class AuthMustChangePin extends AuthState {
  final UserProfile profile;
  const AuthMustChangePin(this.profile);
}

/// Fully authenticated and authorized user (admin or employee).
class AuthAuthenticated extends AuthState {
  final UserProfile profile;
  const AuthAuthenticated(this.profile);
}
