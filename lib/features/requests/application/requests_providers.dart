import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show FutureProviderFamily;

import '../../../core/supabase/supabase_providers.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/domain/auth_status.dart';
import '../data/photo_picker.dart';
import '../data/requests_repository.dart';
import '../domain/app_request.dart';

/// Overridden in tests.
final Provider<RequestsRepository> requestsRepositoryProvider =
    Provider<RequestsRepository>(
      (Ref ref) =>
          SupabaseRequestsRepository(ref.watch(supabaseClientProvider)),
    );

final Provider<PhotoPicker> photoPickerProvider = Provider<PhotoPicker>(
  (Ref ref) => ImagePhotoPicker(),
);

/// The signed-in employee's requests.
final FutureProvider<List<AppRequest>> myRequestsProvider =
    FutureProvider.autoDispose<List<AppRequest>>((Ref ref) {
      final AuthStatus status = ref.watch(authStatusProvider);
      if (status is! SignedIn) return Future<List<AppRequest>>.value(const []);
      return ref.watch(requestsRepositoryProvider).mine(status.userId);
    }, retry: (int count, Object error) => null);

/// The admin's list: true for waiting requests, false for the latest of all.
final FutureProviderFamily<List<AppRequest>, bool> adminRequestsProvider =
    FutureProvider.autoDispose.family<List<AppRequest>, bool>(
      (Ref ref, bool pendingOnly) => ref
          .watch(requestsRepositoryProvider)
          .forAdmin(pendingOnly: pendingOnly),
      retry: (int count, Object error) => null,
    );

final FutureProviderFamily<AppRequest?, int> requestProvider = FutureProvider
    .autoDispose
    .family<AppRequest?, int>(
      (Ref ref, int id) => ref.watch(requestsRepositoryProvider).byId(id),
      retry: (int count, Object error) => null,
    );

/// After any change, every list and the request itself reload.
void refreshRequests(WidgetRef ref, [int? id]) {
  ref
    ..invalidate(myRequestsProvider)
    ..invalidate(adminRequestsProvider);
  if (id != null) ref.invalidate(requestProvider(id));
}
