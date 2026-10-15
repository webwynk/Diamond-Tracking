/// Base class for all domain and operational exceptions in Diamond Agritech Tracking.
abstract class AppException implements Exception {
  final String message;
  final String? code;

  const AppException(this.message, {this.code});

  @override
  String toString() => message;
}

/// Thrown when login fails due to incorrect credentials (employee code, PIN, or password).
/// Security rule: must not reveal whether an employee code or email exists.
class InvalidCredentialsException extends AppException {
  final int? attemptsRemaining;

  const InvalidCredentialsException([
    super.message = 'Invalid credentials. Please verify your details.',
    this.attemptsRemaining,
  ]) : super(code: 'invalid_credentials');
}

/// Thrown when an account has been marked as blocked.
class AccountBlockedException extends AppException {
  const AccountBlockedException([
    super.message = 'Your account has been blocked. Please contact the office.',
  ]) : super(code: 'account_blocked');
}

/// Thrown when rate limiting locks an account after 5 failed attempts.
class AccountLockedException extends AppException {
  final DateTime? lockedUntil;

  const AccountLockedException({
    String message = 'Account locked due to multiple failed attempts. Try again later.',
    this.lockedUntil,
  }) : super(message, code: 'account_locked');
}

/// Thrown when an employee attempts to log in from an unapproved / second device.
class DeviceBindingException extends AppException {
  const DeviceBindingException([
    super.message = 'This account is registered on another device. Contact office to reset binding.',
  ]) : super(code: 'device_binding_rejected');
}

/// Thrown when an authenticated user has insufficient role permissions (e.g. employee trying admin route).
class UnauthorizedRoleException extends AppException {
  const UnauthorizedRoleException([
    super.message = 'Access denied. You do not have permission for this section.',
  ]) : super(code: 'unauthorized_role');
}

/// Thrown when an employee is required to complete first-login PIN change before accessing features.
class MustChangePinException extends AppException {
  const MustChangePinException([
    super.message = 'You must change your PIN before proceeding.',
  ]) : super(code: 'must_change_pin');
}

/// Thrown on network timeout or lack of internet connectivity.
class NetworkException extends AppException {
  const NetworkException([
    super.message = 'Network error. Please check your internet connection.',
  ]) : super(code: 'network_error');
}

/// Generic unexpected server failure.
class ServerException extends AppException {
  const ServerException([
    super.message = 'An unexpected server error occurred. Please try again later.',
  ]) : super(code: 'server_error');
}
