import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show FutureProviderFamily;

import '../../../core/supabase/supabase_providers.dart';
import '../../../core/time/clock_providers.dart';
import '../../../core/time/ist.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/domain/auth_status.dart';
import '../data/users_repository.dart';
import '../domain/profile.dart';

/// User accounts. Overridden in tests.
final Provider<UsersRepository> usersRepositoryProvider =
    Provider<UsersRepository>(
      (Ref ref) => SupabaseUsersRepository(ref.watch(supabaseClientProvider)),
    );

/// All users, for the admin. Invalidate after a change.
final FutureProvider<List<Profile>> usersListProvider =
    FutureProvider.autoDispose<List<Profile>>(
      (Ref ref) => ref.watch(usersRepositoryProvider).list(),
    );

/// One user, for the admin's edit screen.
final FutureProviderFamily<Profile?, String> userByIdProvider = FutureProvider
    .autoDispose
    .family<Profile?, String>(
      (Ref ref, String id) => ref.watch(usersRepositoryProvider).byId(id),
    );

/// The signed-in user's own profile.
final FutureProvider<Profile?> myProfileProvider =
    FutureProvider.autoDispose<Profile?>((Ref ref) {
      final AuthStatus status = ref.watch(authStatusProvider);
      if (status is! SignedIn) return Future<Profile?>.value();
      return ref.watch(usersRepositoryProvider).byId(status.userId);
    });

/// Whether the admin has allowed this user to do duty on today (not used yet).
final FutureProviderFamily<bool, String> dutyOnAllowedProvider = FutureProvider
    .autoDispose
    .family<bool, String>(
      (Ref ref, String userId) => ref
          .watch(usersRepositoryProvider)
          .dutyOnAllowed(
            userId,
            Ist.dateOf(ref.watch(serverClockProvider).now()),
          ),
      retry: (int count, Object error) => null,
    );
