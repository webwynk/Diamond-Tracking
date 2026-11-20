import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show FutureProviderFamily;

import '../../../core/logging/app_log.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../../../core/time/clock_providers.dart';
import '../../../core/time/ist.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/domain/auth_status.dart';
import '../../duty/application/duty_providers.dart';
import '../../duty/domain/duty_day.dart';
import '../data/route_repository.dart';
import '../domain/day_route.dart';
import '../domain/live_position.dart';

/// Overridden in tests.
final Provider<RouteRepository> routeRepositoryProvider =
    Provider<RouteRepository>(
      (Ref ref) => SupabaseRouteRepository(ref.watch(supabaseClientProvider)),
    );

/// Whether to draw the real Google map. Tests turn it off (the map is a
/// native view that does not run in widget tests).
final Provider<bool> showGoogleMapProvider = Provider<bool>((Ref ref) => true);

/// History goes back this far (routes are kept 90 days).
const int historyDays = 90;

/// A day and its route. Missing stop addresses are looked up once in the
/// background, then the route reloads with them.
final FutureProviderFamily<DayView, int> dayViewProvider = FutureProvider
    .autoDispose
    .family<DayView, int>((Ref ref, int dayId) async {
      final RouteRepository repo = ref.watch(routeRepositoryProvider);
      final List<Object?> both = await Future.wait(<Future<Object?>>[
        repo.day(dayId),
        repo.dayRoute(dayId),
      ]);
      final DutyDay? day = both[0] as DutyDay?;
      final DayRoute? route = both[1] as DayRoute?;
      final Set<int> asked = ref.read(_askedProvider);
      if (route != null && route.needsAddresses && !asked.contains(dayId)) {
        asked.add(dayId);
        repo
            .requestAddresses(dayId)
            .then((int found) {
              if (found > 0 && ref.mounted) ref.invalidateSelf();
            })
            .catchError((Object e) {
              AppLog.failure('requestAddresses', e);
            });
      }
      return DayView(day: day, route: route);
    }, retry: (int count, Object error) => null);

/// Days whose addresses were already requested in this app session.
final Provider<Set<int>> _askedProvider = Provider<Set<int>>(
  (Ref ref) => <int>{},
);

/// A day and its route (either may be missing).
class DayView {
  const DayView({required this.day, required this.route});

  final DutyDay? day;
  final DayRoute? route;
}

/// A user's days, newest first.
final FutureProviderFamily<List<DutyDay>, String> historyProvider =
    FutureProvider.autoDispose.family<List<DutyDay>, String>((
      Ref ref,
      String userId,
    ) {
      final DateTime today = Ist.dateOf(ref.watch(serverClockProvider).now());
      return ref
          .watch(routeRepositoryProvider)
          .history(userId, today.subtract(const Duration(days: historyDays)));
    }, retry: (int count, Object error) => null);

/// Everyone's record for today (admin's live map).
final FutureProvider<List<DutyDay>> todayDaysProvider =
    FutureProvider.autoDispose<List<DutyDay>>((Ref ref) {
      final DateTime today = Ist.dateOf(ref.watch(serverClockProvider).now());
      return ref.watch(routeRepositoryProvider).daysOn(today);
    }, retry: (int count, Object error) => null);

/// Latest positions, live.
final StreamProvider<List<LivePosition>> livePositionsProvider =
    StreamProvider.autoDispose<List<LivePosition>>(
      (Ref ref) => ref.watch(routeRepositoryProvider).livePositions(),
    );

/// The signed-in employee's record for today, for the My map tab.
final FutureProvider<DutyDay?> myTodayProvider =
    FutureProvider.autoDispose<DutyDay?>((Ref ref) {
      final AuthStatus status = ref.watch(authStatusProvider);
      if (status is! SignedIn) return Future<DutyDay?>.value();
      final DateTime today = Ist.dateOf(ref.watch(serverClockProvider).now());
      return ref.watch(dutyRepositoryProvider).forDay(status.userId, today);
    }, retry: (int count, Object error) => null);
