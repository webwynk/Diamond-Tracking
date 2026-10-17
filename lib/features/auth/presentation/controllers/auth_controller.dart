import 'package:diamond_tracking/core/utils/device_id_service.dart';
import 'package:diamond_tracking/data/repositories/supabase_auth_repository.dart';
import 'package:diamond_tracking/domain/repositories/auth_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_state.dart';

/// Provider for the global [AuthRepository] instance.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return SupabaseAuthRepository();
});

/// Global provider for managing and observing user authentication state.
final authControllerProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);

/// Notifier responsible for all authentication mutations and session lifecycle.
class AuthNotifier extends Notifier<AuthState> {
  late final AuthRepository _repository;

  @override
  AuthState build() {
    _repository = ref.watch(authRepositoryProvider);
    return const AuthInitial();
  }

  /// Checks whether an existing authenticated session is stored on device.
  Future<void> checkSession() async {
    try {
      final profile = await _repository.getCurrentProfile();
      if (profile == null) {
        state = const AuthUnauthenticated();
        return;
      }

      if (profile.isBlocked) {
        await _repository.signOut();
        state = const AuthUnauthenticated(
          errorMessage: 'Your account has been blocked. Contact the office.',
        );
        return;
      }

      if (profile.mustChangePin) {
        state = AuthMustChangePin(profile);
      } else {
        state = AuthAuthenticated(profile);
      }
    } catch (_) {
      state = const AuthUnauthenticated();
    }
  }

  /// Authenticates an employee with their employee code and 6-digit PIN.
  Future<bool> signInEmployee({
    required String employeeCode,
    required String pin,
  }) async {
    state = const AuthLoading(message: 'Signing in...');
    try {
      final deviceId = await DeviceIdService.getDeviceId();
      final profile = await _repository.signInEmployee(
        employeeCode: employeeCode,
        pin: pin,
        deviceId: deviceId,
      );

      if (profile.mustChangePin) {
        state = AuthMustChangePin(profile);
      } else {
        state = AuthAuthenticated(profile);
      }
      return true;
    } catch (e) {
      state = AuthUnauthenticated(errorMessage: e.toString());
      return false;
    }
  }

  /// Authenticates an administrator with email and password.
  Future<bool> signInAdmin({
    required String email,
    required String password,
  }) async {
    state = const AuthLoading(message: 'Signing in admin...');
    try {
      final profile = await _repository.signInAdmin(
        email: email,
        password: password,
      );

      state = AuthAuthenticated(profile);
      return true;
    } catch (e) {
      state = AuthUnauthenticated(errorMessage: e.toString());
      return false;
    }
  }

  /// Submits the new 6-digit PIN on Screen 04.
  Future<bool> completePinChange({required String newPin}) async {
    final current = state;
    state = const AuthLoading(message: 'Updating PIN...');
    try {
      await _repository.changePin(newPin: newPin);
      final profile = await _repository.getCurrentProfile();
      if (profile != null) {
        state = AuthAuthenticated(profile.copyWith(mustChangePin: false));
      } else if (current is AuthMustChangePin) {
        state = AuthAuthenticated(
          current.profile.copyWith(mustChangePin: false),
        );
      } else {
        state = const AuthUnauthenticated();
      }
      return true;
    } catch (e) {
      if (current is AuthMustChangePin) {
        state = AuthMustChangePin(current.profile);
      } else {
        state = AuthUnauthenticated(errorMessage: e.toString());
      }
      return false;
    }
  }

  /// Signs the current user out.
  Future<void> signOut() async {
    state = const AuthLoading(message: 'Signing out...');
    try {
      await _repository.signOut();
    } finally {
      state = const AuthUnauthenticated();
    }
  }

  /// Clears any persistent error banner.
  void clearError() {
    if (state is AuthUnauthenticated) {
      state = const AuthUnauthenticated();
    }
  }
}
