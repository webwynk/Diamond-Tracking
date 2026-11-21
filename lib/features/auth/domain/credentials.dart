/// Sign-in identity and password rules. The same rules are checked again on
/// the server (supabase/functions/_shared/rules.ts); these give instant
/// feedback in the form.
library;

import 'dart:convert';

/// Sign-in emails are built from the user ID. The domain never receives mail;
/// real contact emails are kept separately on the profile.
const String loginEmailDomain = 'staff.diamondagritech.internal';

/// The sign-in email for what the user typed: an email as is (only for the
/// first admin, whose account was made in Supabase with a real email),
/// otherwise the user ID's sign-in email. Accounts added in the app always
/// sign in with their user ID.
String loginEmailFor(String loginId) {
  final String id = loginId.trim();
  return id.contains('@')
      ? id.toLowerCase()
      : '${id.toLowerCase()}@$loginEmailDomain';
}

/// The user ID inside a sign-in email, or null for any other email.
String? userCodeFromLoginEmail(String? email) {
  const String suffix = '@$loginEmailDomain';
  if (email == null || !email.endsWith(suffix)) return null;
  return email.substring(0, email.length - suffix.length);
}

final RegExp _userCode = RegExp(r'^[A-Za-z0-9][A-Za-z0-9_-]{1,19}$');

String? userCodeProblem(String code) => _userCode.hasMatch(code.trim())
    ? null
    : 'Use 2 to 20 letters, digits, - or _';

String? loginIdProblem(String value) {
  final String v = value.trim();
  if (v.isEmpty) return 'Enter your user ID';
  if (v.contains('@')) return null;
  return userCodeProblem(v);
}

/// Shown when a password is 72 characters or fewer but over 72 bytes. Same
/// text on the server (supabase/functions/_shared/rules.ts).
const String passwordTooLong = 'Too long: use fewer non-English letters';

/// The user's own password: 8 to 72 characters with a letter and a digit,
/// not containing the user ID. Supabase Auth refuses more than 72 bytes
/// (bcrypt's limit), and a Hindi or Bengali letter is 3 bytes, so a shorter
/// password can still be too long.
String? passwordProblem(String password, {String userCode = ''}) {
  if (password.length < 8 || password.length > 72) {
    return 'Use 8 to 72 characters';
  }
  if (utf8.encode(password).length > 72) return passwordTooLong;
  if (!RegExp('[A-Za-z]').hasMatch(password) ||
      !RegExp('[0-9]').hasMatch(password)) {
    return 'Use at least one letter and one digit';
  }
  if (userCode.isNotEmpty &&
      password.toLowerCase().contains(userCode.toLowerCase())) {
    return 'Do not use your user ID in the password';
  }
  return null;
}

/// The admin's temporary PIN: 6 digits, not all the same.
String? pinProblem(String pin) {
  if (!RegExp(r'^[0-9]{6}$').hasMatch(pin)) {
    return 'The temporary PIN must be 6 digits';
  }
  if (RegExp(r'^(\d)\1{5}$').hasMatch(pin)) {
    return 'Do not use the same digit 6 times';
  }
  return null;
}
