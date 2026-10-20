import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../data/repositories/supabase_admin_visit_repository.dart';
import '../../../../../domain/repositories/admin_visit_repository.dart';
import 'admin_visits_state.dart';

/// Provider exposing where admins read visits from.
final adminVisitRepositoryProvider = Provider<AdminVisitRepository>((ref) {
  return SupabaseAdminVisitRepository();
});

/// Provider for one employee's visits. Auto-disposed with the screens that show
/// them; the profile card and the full list share one instance, so opening the
/// list shows what the card already loaded.
final adminVisitsControllerProvider = NotifierProvider.autoDispose
    .family<AdminVisitsNotifier, AdminVisitsState, String>(
      AdminVisitsNotifier.new,
    );

/// Loads one employee's visits, newest first, a page at a time (PRD F10).
///
/// Nothing is invented: until the first page is in the list shows loading, and
/// a failure is an error with Retry, never an empty "no visits". An older page
/// that fails keeps the visits already shown.
class AdminVisitsNotifier extends Notifier<AdminVisitsState> {
  AdminVisitsNotifier(this.employeeId);

  static const int pageSize = 20;

  final String employeeId;

  int _ticket = 0;
  bool _stopped = false;

  AdminVisitRepository get _repo => ref.read(adminVisitRepositoryProvider);

  @override
  AdminVisitsState build() {
    ref.onDispose(() => _stopped = true);
    Future<void>.microtask(refresh);
    return const AdminVisitsState();
  }

  /// Reads the newest page again. A load overtaken by a newer one is dropped.
  Future<void> refresh() async {
    final ticket = ++_ticket;
    if (state.visits.isEmpty) {
      state = state.copyWith(load: AdminVisitsLoad.loading);
    }
    try {
      final page = await _repo.fetchPage(
        employeeId: employeeId,
        limit: pageSize,
      );
      if (_stopped || ticket != _ticket) return;
      state = AdminVisitsState(
        visits: page.visits,
        load: AdminVisitsLoad.loaded,
        hasMore: page.hasMore,
      );
    } on Object {
      if (_stopped || ticket != _ticket) return;
      // Keep what is on screen; only a screen with nothing to show fails.
      state = state.visits.isEmpty
          ? state.copyWith(load: AdminVisitsLoad.failed)
          : state.copyWith(load: AdminVisitsLoad.loaded);
    }
  }

  /// Reads the next, older page. Does nothing while one is already loading.
  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoadingMore) return;
    if (state.load != AdminVisitsLoad.loaded || state.visits.isEmpty) return;
    final ticket = _ticket;
    state = state.copyWith(isLoadingMore: true, loadMoreFailed: false);
    try {
      final page = await _repo.fetchPage(
        employeeId: employeeId,
        after: state.visits.last,
        limit: pageSize,
      );
      if (_stopped || ticket != _ticket) return;
      final known = <String>{for (final v in state.visits) v.id};
      state = state.copyWith(
        visits: [
          ...state.visits,
          ...page.visits.where((v) => !known.contains(v.id)),
        ],
        hasMore: page.hasMore,
        isLoadingMore: false,
      );
    } on Object {
      if (_stopped || ticket != _ticket) return;
      state = state.copyWith(isLoadingMore: false, loadMoreFailed: true);
    }
  }
}
