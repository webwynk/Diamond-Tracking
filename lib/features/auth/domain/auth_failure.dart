/// Why an account action failed, in words the user can act on.
enum AuthFailure implements Exception {
  invalidCredentials('Wrong user ID or password.'),
  wrongCurrentPassword('Your current password is not right.'),
  signedInElsewhere(
    'Already logged in on another phone. Log out there first, or ask your '
    'admin to release the phone.',
  ),
  accountInactive('This account is turned off. Please contact your admin.'),
  tooManyAttempts(
    'Too many attempts. Please wait a few minutes and try again.',
  ),
  dailyEmailLimit(
    'Too many reset emails today. Try again tomorrow, or ask your admin to '
    'reset your password.',
  ),
  network('No internet connection. Please try again.'),
  emailNotConfigured(
    'Password reset by email is not set up. Please ask your admin to reset '
    'your password.',
  ),
  invalidCode('That code is wrong or has expired.'),
  weakPassword('Choose a stronger password.'),
  userCodeTaken('This user ID is already used.'),
  cannotChangeOwnAccess(
    'You cannot turn off your own account or remove your own admin access.',
  ),
  userNotFound('This user no longer exists.'),
  resetIncomplete(
    'The reset did not finish: their old phone is still signed in. Press '
    'Reset again to finish.',
  ),
  notAllowed('You are not allowed to do this.'),
  unknown('Something went wrong. Please try again.');

  const AuthFailure(this.message);

  final String message;
}
