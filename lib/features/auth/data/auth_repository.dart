import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/logging/app_log.dart';
import '../../../core/supabase/device_id.dart';
import '../domain/auth_failure.dart';
import '../domain/credentials.dart';

/// Every account action the app performs. Screens depend on this interface,
/// so tests use a fake.
abstract interface class AuthRepository {
  /// The signed-in user's ID, or null for the first admin, whose account was
  /// made in Supabase with a real email.
  String? get currentUserCode;

  /// The signed-in user's first name, from the name the admin gave when
  /// adding them; null when there is none.
  String? get currentFirstName;

  /// Signs in and claims this phone. Throws [AuthFailure].
  Future<void> signIn({required String loginId, required String password});

  /// First password after a temporary PIN. Throws [AuthFailure].
  Future<void> setFirstPassword(String newPassword);

  /// Changes the password, checking the current one. Throws [AuthFailure].
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });

  /// Asks for a reset code by email. Throws [AuthFailure].
  Future<void> requestResetCode(String userCode);

  /// Sets a new password with the emailed code. Throws [AuthFailure].
  Future<void> resetWithCode({
    required String userCode,
    required String code,
    required String newPassword,
  });

  /// Frees this phone and signs out.
  Future<void> signOut();
}

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client, this._deviceIds);

  final SupabaseClient _client;
  final DeviceIdStore _deviceIds;

  @override
  String? get currentUserCode =>
      userCodeFromLoginEmail(_client.auth.currentUser?.email);

  @override
  String? get currentFirstName =>
      firstNameOf(_client.auth.currentUser?.userMetadata?['full_name']);

  @override
  Future<void> signIn({
    required String loginId,
    required String password,
  }) async {
    await _guard('signIn', () async {
      await _client.auth.signInWithPassword(
        email: loginEmailFor(loginId),
        password: password,
      );
      try {
        await _client.rpc<void>(
          'claim_device',
          params: <String, Object?>{'p_device_id': await _deviceIds.get()},
        );
      } on Object {
        // Never stay signed in on a phone the account may not use.
        await _client.auth.signOut(scope: SignOutScope.local);
        rethrow;
      }
    });
  }

  @override
  Future<void> setFirstPassword(String newPassword) async {
    await _guard('setFirstPassword', () async {
      await _client.functions.invoke(
        'account',
        body: <String, Object?>{
          'action': 'set_password',
          'new_password': newPassword,
        },
      );
      // Picks up the cleared "must change password" claim, which moves the
      // app on to the home screen.
      await _client.auth.refreshSession();
    });
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _guard('changePassword', () async {
      final String? email = _client.auth.currentUser?.email;
      if (email == null) throw AuthFailure.invalidCredentials;
      // Proves the current password before changing it.
      await _client.auth.signInWithPassword(
        email: email,
        password: currentPassword,
      );
      await _client.auth.updateUser(UserAttributes(password: newPassword));
    });
  }

  @override
  Future<void> requestResetCode(String userCode) async {
    await _guard('requestResetCode', () async {
      await _client.functions.invoke(
        'password-reset',
        body: <String, Object?>{
          'action': 'request',
          'user_code': userCode.trim(),
        },
      );
    });
  }

  @override
  Future<void> resetWithCode({
    required String userCode,
    required String code,
    required String newPassword,
  }) async {
    await _guard('resetWithCode', () async {
      await _client.functions.invoke(
        'password-reset',
        body: <String, Object?>{
          'action': 'confirm',
          'user_code': userCode.trim(),
          'code': code.trim(),
          'new_password': newPassword,
        },
      );
    });
  }

  @override
  Future<void> signOut() async {
    try {
      await _client.rpc<void>(
        'release_device',
        params: <String, Object?>{'p_device_id': await _deviceIds.get()},
      );
    } on Object catch (e, st) {
      // Offline: the phone keeps the lock until the next sign-in here or an
      // admin reset. Signing out locally must still work.
      AppLog.failure('AuthRepository.releaseDevice', e, st);
    }
    await _client.auth.signOut(scope: SignOutScope.local);
  }

  Future<void> _guard(String where, Future<void> Function() action) async {
    try {
      await action();
    } on AuthFailure {
      rethrow;
    } on Object catch (e, st) {
      final AuthFailure failure = mapAuthError(e);
      if (failure == AuthFailure.unknown) {
        AppLog.failure('AuthRepository.$where', e, st);
      }
      throw failure;
    }
  }
}

/// Turns a Supabase or network error into an [AuthFailure].
AuthFailure mapAuthError(Object e) {
  if (e is SocketException || e is AuthRetryableFetchException) {
    return AuthFailure.network;
  }
  if (e is AuthApiException) {
    switch (e.code) {
      case 'invalid_credentials':
        return AuthFailure.invalidCredentials;
      case 'over_request_rate_limit':
      case 'over_email_send_rate_limit':
        return AuthFailure.tooManyAttempts;
      case 'user_banned':
        return AuthFailure.accountInactive;
      case 'weak_password':
      case 'same_password':
        return AuthFailure.weakPassword;
    }
    return e.statusCode == '429'
        ? AuthFailure.tooManyAttempts
        : AuthFailure.unknown;
  }
  if (e is PostgrestException) {
    if (e.message.contains('signed_in_elsewhere')) {
      return AuthFailure.signedInElsewhere;
    }
    if (e.message.contains('account_inactive')) {
      return AuthFailure.accountInactive;
    }
    return AuthFailure.unknown;
  }
  if (e is FunctionException) {
    final Object? details = e.details;
    final String code = details is Map ? '${details['error']}' : '';
    switch (code) {
      case 'email_not_configured':
        return AuthFailure.emailNotConfigured;
      case 'daily_email_limit':
        return AuthFailure.dailyEmailLimit;
      case 'invalid_code':
        return AuthFailure.invalidCode;
      case 'validation_failed':
        return AuthFailure.weakPassword;
      case 'account_inactive':
        return AuthFailure.accountInactive;
      case 'user_code_taken':
        return AuthFailure.userCodeTaken;
      case 'cannot_change_own_access':
        return AuthFailure.cannotChangeOwnAccess;
      case 'user_not_found':
        return AuthFailure.userNotFound;
      case 'reset_incomplete':
        return AuthFailure.resetIncomplete;
      case 'not_admin':
      case 'not_required':
        return AuthFailure.notAllowed;
    }
    return e.status == 429 ? AuthFailure.tooManyAttempts : AuthFailure.unknown;
  }
  return AuthFailure.unknown;
}
