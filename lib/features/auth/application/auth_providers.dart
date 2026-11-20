import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/auth_status.dart';

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
  @override
  AuthStatus build() {
    final StreamSubscription<AuthStatus> sub = ref
        .watch(authStatusStreamProvider)
        .listen((AuthStatus status) => state = status);
    ref.onDispose(sub.cancel);
    return const AuthLoading();
  }
}
