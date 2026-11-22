import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show FutureProviderFamily;

import '../../../core/supabase/supabase_providers.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/domain/auth_status.dart';
import '../../duty/domain/duty_day.dart';
import '../../routes/application/route_providers.dart';
import '../data/current_location.dart';
import '../data/visit_outbox.dart';
import '../data/visits_repository.dart';
import '../domain/visit.dart';
import 'visit_sender.dart';

/// Overridden in tests.
final Provider<VisitsRepository> visitsRepositoryProvider =
    Provider<VisitsRepository>(
      (Ref ref) => SupabaseVisitsRepository(ref.watch(supabaseClientProvider)),
    );

/// Overridden in tests.
final Provider<CurrentLocation> currentLocationProvider =
    Provider<CurrentLocation>((Ref ref) => const GeolocatorLocation());

/// A day's visits, in time order.
final FutureProviderFamily<List<Visit>, int> dayVisitsProvider = FutureProvider
    .autoDispose
    .family<List<Visit>, int>(
      (Ref ref, int dayId) => ref.watch(visitsRepositoryProvider).forDay(dayId),
      retry: (int count, Object error) => null,
    );

/// Everyone's visits today, for the admin dashboard.
final FutureProvider<int> todayVisitsCountProvider =
    FutureProvider.autoDispose<int>((Ref ref) async {
      final List<DutyDay> days = await ref.watch(todayDaysProvider.future);
      return ref.watch(visitsRepositoryProvider).countForDays(<int>[
        for (final DutyDay d in days)
          if (d.dutyOnAt != null) d.id,
      ]);
    }, retry: (int count, Object error) => null);

/// Visits kept on the phone until sent (M10). Overridden in tests.
final Provider<VisitOutbox> visitOutboxProvider = Provider<VisitOutbox>(
  (Ref ref) => VisitOutbox.appFolder(),
);

final Provider<VisitSender> visitSenderProvider = Provider<VisitSender>(
  (Ref ref) => VisitSender(
    ref.watch(visitOutboxProvider),
    ref.watch(visitsRepositoryProvider),
  ),
);

/// The signed-in person's visits still waiting on the phone, oldest first.
final FutureProvider<List<PendingVisit>> pendingVisitsProvider =
    FutureProvider.autoDispose<List<PendingVisit>>((Ref ref) async {
      final AuthStatus status = ref.watch(authStatusProvider);
      if (status is! SignedIn) return const <PendingVisit>[];
      return ref.watch(visitOutboxProvider).pending(userId: status.userId);
    }, retry: (int count, Object error) => null);
