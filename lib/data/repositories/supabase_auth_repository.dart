import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/errors/app_exceptions.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/auth_repository.dart';

/// Supabase implementation of [AuthRepository].
///
/// Handles employee PIN-based authentication via internal synthetic emails,
/// admin email/password login, device binding checks, and PIN updates.
class SupabaseAuthRepository implements AuthRepository {
  final SupabaseClient _client;

  SupabaseAuthRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  /// Internal synthetic email format mapping employee codes to Supabase Auth accounts.
  static String formatEmployeeEmail(String code) {
    final clean = code.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '');
    return '$clean@staff.diamondagritech.internal';
  }

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

    final email = formatEmployeeEmail(cleanCode);

    try {
      // 1. Authenticate with Supabase Auth
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: cleanPin,
      );

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
      if (e.statusCode == '429' ||
          e.message.toLowerCase().contains('rate limit')) {
        throw const AccountLockedException();
      }
      throw const InvalidCredentialsException(
        'Incorrect employee code or PIN.',
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException('Sign-in failed: $e');
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
    } on AuthException {
      throw const InvalidCredentialsException('Incorrect email or password.');
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException('Admin sign-in failed: $e');
    }
  }

  @override
  Future<void> changePin({required String newPin}) async {
    try {
      // 1. Update Supabase Auth user password
      await _client.auth.updateUser(UserAttributes(password: newPin));

      // 2. Mark must_change_pin = false via secure RPC
      final success = await _client.rpc('complete_pin_change');
      if (success != true) {
        throw const ServerException(
          'Failed to complete PIN change on database.',
        );
      }
    } on AuthException catch (e) {
      throw ServerException('Failed to update PIN: ${e.message}');
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException('PIN change failed: $e');
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
