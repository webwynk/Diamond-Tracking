import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/errors/app_exceptions.dart';
import '../../core/utils/failure_log.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/auth_repository.dart';
import '../network_failure.dart';

/// Supabase implementation of [AuthRepository].
///
/// Employees sign in through the `employee-auth` Edge Function: the server
/// checks the PIN, counts wrong tries (5 lock the account for 15 minutes) and
/// hands back a session. The app never sends a PIN to Supabase Auth itself.
/// Admins sign in with email and password. Device binding is checked after
/// either, through a database function.
class SupabaseAuthRepository implements AuthRepository {
  final SupabaseClient _client;

  SupabaseAuthRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  @override
  Future<UserProfile?> getCurrentProfile() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return null;

      final res = await _client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (res == null) return null;
      return UserProfile.fromJson(res);
    } on AuthException catch (e) {
      throw InvalidCredentialsException(e.message);
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException('Failed to retrieve profile: $e');
    }
  }

  @override
  Future<UserProfile> signInEmployee({
    required String employeeCode,
    required String pin,
    required String deviceId,
  }) async {
    final cleanCode = employeeCode.trim();
    final cleanPin = pin.trim();

    if (cleanCode.isEmpty || cleanPin.isEmpty) {
      throw const InvalidCredentialsException(
        'Please enter both employee code and PIN.',
      );
    }

    try {
      // 1. The server checks the PIN and the lockout, and returns a session.
      final data = await _employeeAuth(<String, dynamic>{
        'action': 'login',
        'employee_code': cleanCode,
        'pin': cleanPin,
      });
      final session = data['session'];
      final refreshToken = session is Map ? session['refresh_token'] : null;
      if (refreshToken is! String || refreshToken.isEmpty) {
        throw const ServerException('Sign-in failed. Please try again.');
      }
      final response = await _client.auth.setSession(refreshToken);

      final user = response.user;
      if (user == null) {
        throw const InvalidCredentialsException(
          'Incorrect employee code or PIN.',
        );
      }

      // 2. Fetch profile from public.profiles
      final profileMap = await _client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (profileMap == null) {
        await _client.auth.signOut();
        throw const InvalidCredentialsException(
          'Employee profile record not found.',
        );
      }

      final profile = UserProfile.fromJson(profileMap);

      // 3. Enforce BR-6: Blocked employee check
      if (profile.isBlocked) {
        await _client.auth.signOut();
        throw const AccountBlockedException(
          'Your account has been blocked. Please contact the office.',
        );
      }

      // 4. Enforce BR-13: Device binding via database RPC
      final isBound = await _client.rpc(
        'bind_my_device',
        params: {'p_device_id': deviceId},
      );

      if (isBound != true) {
        await _client.auth.signOut();
        throw const DeviceBindingException(
          'This account is registered on another device. Contact office to reset binding.',
        );
      }

      // Return profile (refetched if device was newly bound)
      if (profile.deviceId == null) {
        return profile.copyWith(deviceId: deviceId);
      }

      return profile;
    } on AuthException catch (e) {
      if (e.code == 'user_banned') throw const AccountBlockedException();
      if (e.statusCode == '429') {
        throw const AccountLockedException(
          message: 'Too many sign-in tries. Wait a few minutes and try again.',
        );
      }
      throw const ServerException('Sign-in failed. Please try again.');
    } catch (e, st) {
      if (e is AppException) rethrow;
      final network = asNetworkFailure(e);
      if (network != null) throw network;
      logFailure('AuthRepository: employee sign-in failed', e, st);
      throw const ServerException('Sign-in failed. Please try again.');
    }
  }

  @override
  Future<UserProfile> signInAdmin({
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.trim();
    final cleanPassword = password.trim();

    if (cleanEmail.isEmpty || cleanPassword.isEmpty) {
      throw const InvalidCredentialsException(
        'Please enter email and password.',
      );
    }

    try {
      // 1. Authenticate with Supabase Auth
      final response = await _client.auth.signInWithPassword(
        email: cleanEmail,
        password: cleanPassword,
      );

      final user = response.user;
      if (user == null) {
        throw const InvalidCredentialsException('Incorrect email or password.');
      }

      // 2. Fetch profile
      final profileMap = await _client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (profileMap == null) {
        await _client.auth.signOut();
        throw const InvalidCredentialsException('Admin profile not found.');
      }

      final profile = UserProfile.fromJson(profileMap);

      // 3. Verify Admin role
      if (profile.role != UserRole.admin) {
        await _client.auth.signOut();
        throw const UnauthorizedRoleException(
          'Access denied. This login is reserved for office administrators.',
        );
      }

      // 4. Verify Active status
      if (profile.isBlocked) {
        await _client.auth.signOut();
        throw const AccountBlockedException(
          'Your administrator account has been blocked. Contact system admin.',
        );
      }

      return profile;
    } on AuthException catch (e) {
      if (e.code == 'user_banned') {
        throw const AccountBlockedException(
          'Your administrator account has been blocked. Contact system admin.',
        );
      }
      throw const InvalidCredentialsException('Incorrect email or password.');
    } catch (e, st) {
      if (e is AppException) rethrow;
      final network = asNetworkFailure(e);
      if (network != null) throw network;
      logFailure('AuthRepository: admin sign-in failed', e, st);
      throw const ServerException('Sign-in failed. Please try again.');
    }
  }

  @override
  Future<void> changePin({required String newPin}) async {
    try {
      // The server checks the PIN rules, stores the new PIN and clears
      // "must change PIN" in one step. Only allowed at the forced first change.
      await _employeeAuth(<String, dynamic>{
        'action': 'change_pin',
        'new_pin': newPin,
      });
    } catch (e, st) {
      if (e is AppException) rethrow;
      final network = asNetworkFailure(e);
      if (network != null) throw network;
      logFailure('AuthRepository: PIN change failed', e, st);
      throw const ServerException(
        'Could not change the PIN. Please try again.',
      );
    }
  }

  /// Calls the `employee-auth` function and turns its refusals into the app's
  /// own errors. Nothing from the server's reply is shown as it is.
  Future<Map<String, dynamic>> _employeeAuth(Map<String, dynamic> body) async {
    try {
      final response = await _client.functions.invoke(
        'employee-auth',
        body: body,
      );
      final data = response.data;
      if (data is Map) return Map<String, dynamic>.from(data);
      throw const ServerException('Sign-in failed. Please try again.');
    } on FunctionException catch (e) {
      throw _translateEmployeeAuth(e);
    }
  }

  AppException _translateEmployeeAuth(FunctionException e) {
    final details = e.details;
    final code = details is Map ? details['error'] : null;
    switch (e.status) {
      case 0:
        return const NetworkException();
      case 400:
        final fields = details is Map ? details['fields'] : null;
        if (fields is Map && fields['pin'] is String) {
          return ValidationException(fields['pin'] as String);
        }
        return const ValidationException(
          'Please check what you typed and try again.',
        );
      case 401:
        if (code == 'invalid_credentials') {
          return const InvalidCredentialsException(
            'Incorrect employee code or PIN.',
          );
        }
        return const UnauthorizedRoleException(
          'Your session has expired. Sign in again.',
        );
      case 403:
        if (code == 'account_blocked') return const AccountBlockedException();
        if (code == 'pin_change_not_allowed') {
          return const ValidationException(
            'Your PIN cannot be changed here. Contact the office.',
          );
        }
        return const UnauthorizedRoleException(
          'You do not have permission to do this.',
        );
      case 429:
        final seconds = details is Map ? details['retry_after_seconds'] : null;
        final wait = seconds is num && seconds > 0
            ? Duration(seconds: seconds.ceil())
            : const Duration(minutes: 15);
        final minutes = (wait.inSeconds / 60).ceil();
        return AccountLockedException(
          message:
              'Too many wrong tries. Try again in $minutes '
              '${minutes == 1 ? 'minute' : 'minutes'}.',
          lockedUntil: DateTime.now().add(wait),
        );
      default:
        return const ServerException('Sign-in failed. Please try again.');
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } catch (e) {
      throw ServerException('Failed to sign out cleanly: $e');
    }
  }

  @override
  Stream<UserProfile?> get authProfileChanges {
    return _client.auth.onAuthStateChange.asyncMap((event) async {
      final user = event.session?.user;
      if (user == null) return null;

      try {
        final res = await _client
            .from('profiles')
            .select()
            .eq('id', user.id)
            .maybeSingle();
        if (res == null) return null;
        return UserProfile.fromJson(res);
      } catch (_) {
        return null;
      }
    });
  }
}
