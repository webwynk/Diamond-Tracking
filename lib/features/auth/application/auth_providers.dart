import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../data/auth_repository.dart';
import '../domain/auth_status.dart';

/// Account actions (sign in, passwords, sign out). Overridden in tests.
final Provider<AuthRepository> authRepositoryProvider =
    Provider<AuthRepository>(
      (Ref ref) => SupabaseAuthRepository(
        ref.watch(supabaseClientProvider),
        ref.watch(deviceIdStoreProvider),
      ),
    );

/// The live auth status. Overridden in tests.
///
/// Emits the current status first (from the stored session), then every
/// change: sign in, sign out, token refresh (which may carry a new role).
final Provider<Stream<AuthStatus>> authStatusStreamProvider =
    Provider<Stream<AuthStatus>>((Ref ref) {
      final GoTrueClient auth = Supabase.instance.client.auth;
      AuthStatus fromSession(Session? session) => authStatusFromUser(
        userId: session?.user.id,
        appMetadata: session?.user.appMetadata,
      );
      return Stream<AuthStatus>.multi((MultiStreamController<AuthStatus> out) {
        out.add(fromSession(auth.currentSession));
        final StreamSubscription<AuthState> sub = auth.onAuthStateChange.listen(
          (AuthState state) => out.add(fromSession(state.session)),
          onError: out.addError,
        );
        out.onCancel = sub.cancel;
      });
    });

/// The latest auth status, [AuthLoading] until the first value arrives.
final NotifierProvider<AuthStatusNotifier, AuthStatus> authStatusProvider =
    NotifierProvider<AuthStatusNotifier, AuthStatus>(AuthStatusNotifier.new);

class AuthStatusNotifier extends Notifier<AuthStatus> {
  int _holds = 0;
  AuthStatus? _held;

  @override
  AuthStatus build() {
    final StreamSubscription<AuthStatus> sub = ref
        .watch(authStatusStreamProvider)
        .listen(_receive);
    ref.onDispose(sub.cancel);
    return const AuthLoading();
  }

  void _receive(AuthStatus status) {
    if (_holds > 0) {
      _held = status;
    } else {
      state = status;
    }
  }

  /// Runs [action] without moving the app while it runs, then applies the
  /// latest status.
  ///
  /// Sign-in uses this: the session exists a moment before the phone is
  /// claimed, and if the claim is refused the app must stay on the login
  /// screen with the reason, not flash the home screen.
  Future<T> holdWhile<T>(Future<T> Function() action) async {
    _holds++;
    try {
      return await action();
    } finally {
      // Lets status events already sent by the action arrive first.
      await Future<void>.delayed(Duration.zero);
      _holds--;
      final AuthStatus? held = _held;
      if (_holds == 0 && held != null) {
        _held = null;
        state = held;
      }
    }
  }
}
