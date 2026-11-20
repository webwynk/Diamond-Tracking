import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show FutureProviderFamily;

import '../../../core/supabase/supabase_providers.dart';
import '../data/current_location.dart';
import '../data/visits_repository.dart';
import '../domain/visit.dart';

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
