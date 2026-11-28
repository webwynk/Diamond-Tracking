import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart'
    show FutureProviderFamily, NotifierProviderFamily;

import '../../../core/supabase/supabase_providers.dart';
import '../../../core/time/clock_providers.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/domain/auth_status.dart';
import '../../duty/application/duty_providers.dart';
import '../../duty/domain/duty_day.dart';
import '../../routes/application/route_providers.dart';
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

/// How many requests a list shows; "Show more" adds a page (L70).
class RequestLimit extends Notifier<int> {
  @override
  int build() => requestPageSize;

  void more() => state += requestPageSize;
}

/// Per admin list: true for waiting requests, false for all.
final NotifierProviderFamily<RequestLimit, int, bool>
adminRequestsLimitProvider = NotifierProvider.autoDispose
    .family<RequestLimit, int, bool>((bool _) => RequestLimit());

/// The signed-in employee's requests of the last 90 days.
final FutureProvider<List<AppRequest>> myRequestsProvider =
    FutureProvider.autoDispose<List<AppRequest>>((Ref ref) {
      final AuthStatus status = ref.watch(authStatusProvider);
      if (status is! SignedIn) return Future<List<AppRequest>>.value(const []);
      final DateTime now = ref.read(serverClockProvider).now();
      return ref
          .watch(requestsRepositoryProvider)
          .mine(status.userId, since: now.subtract(myRequestsWindow));
    }, retry: (int count, Object error) => null);

/// A user's record for a day: the hours and km behind a duty review.
final FutureProviderFamily<DutyDay?, (String, DateTime)> requestDayProvider =
    FutureProvider.autoDispose.family<DutyDay?, (String, DateTime)>(
      (Ref ref, (String, DateTime) key) =>
          ref.watch(dutyRepositoryProvider).forDay(key.$1, key.$2),
      retry: (int count, Object error) => null,
    );

/// Why a day can't get an attendance request.
enum BlockedDay {
  /// Duty was on that day.
  hadDuty,

  /// A request for that day is already waiting.
  asked,
}

/// Days that already have a request waiting (the server allows one waiting
/// request per day). Empty while loading.
final Provider<Set<DateTime>> waitingRequestDaysProvider =
    Provider.autoDispose<Set<DateTime>>(
      (Ref ref) => <DateTime>{
        for (final AppRequest r
            in ref.watch(myRequestsProvider).value ?? const <AppRequest>[])
          if (r.isPending)
            ...switch (r.kind) {
              RequestKind.leave => r.dates,
              RequestKind.attendance => <DateTime>[r.day!],
              RequestKind.dutyReview => const <DateTime>[],
            },
      },
    );

/// Days of the attendance window that the server would refuse, so the form
/// greys them out. Empty while loading or when the lists can't load; the
/// server still checks.
final Provider<Map<DateTime, BlockedDay>> attendanceBlockedDaysProvider =
    Provider.autoDispose<Map<DateTime, BlockedDay>>((Ref ref) {
      final AuthStatus status = ref.watch(authStatusProvider);
      if (status is! SignedIn) return const <DateTime, BlockedDay>{};
      final Map<DateTime, BlockedDay> blocked = <DateTime, BlockedDay>{
        for (final DateTime d in ref.watch(waitingRequestDaysProvider))
          d: BlockedDay.asked,
      };
      for (final DutyDay d
          in ref.watch(historyProvider(status.userId)).value ??
              const <DutyDay>[]) {
        if (d.dutyOnAt != null) blocked[d.day] = BlockedDay.hadDuty;
      }
      return blocked;
    });

/// The admin's list: true for waiting requests, false for the latest of all.
final FutureProviderFamily<List<AppRequest>, bool> adminRequestsProvider =
    FutureProvider.autoDispose.family<List<AppRequest>, bool>(
      (Ref ref, bool pendingOnly) => ref
          .watch(requestsRepositoryProvider)
          .forAdmin(
            pendingOnly: pendingOnly,
            limit: ref.watch(adminRequestsLimitProvider(pendingOnly)),
          ),
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
