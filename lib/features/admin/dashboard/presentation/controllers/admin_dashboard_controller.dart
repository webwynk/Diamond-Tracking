import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/errors/app_exceptions.dart';
import '../../../../../core/utils/phone_clock.dart';
import '../../../../../core/utils/time_ago.dart';
import '../../../../../data/repositories/supabase_admin_activity_repository.dart';
import '../../../../../domain/entities/admin_activity_event.dart';
import '../../../../../domain/repositories/admin_activity_repository.dart';
import '../../../map/presentation/controllers/admin_live_map_controller.dart';
import 'admin_dashboard_state.dart';

/// Provider exposing the source of the Recent activity feed.
final adminActivityRepositoryProvider = Provider<AdminActivityRepository>((
  ref,
) {
  return SupabaseAdminActivityRepository();
});

/// Global provider for observing the Admin Dashboard.
///
/// Auto-disposed with the admin shell, so the timer stops on sign-out.
final adminDashboardControllerProvider =
    NotifierProvider.autoDispose<AdminDashboardNotifier, AdminDashboardState>(
      AdminDashboardNotifier.new,
    );

/// Loads the Recent activity feed from the server.
///
/// It reloads every minute, and straight away when someone starts or ends duty
/// (the live feed's on-duty list changes). A failed first load is an error with
/// Retry, never an empty "no activity yet"; a failed refresh keeps what is
/// shown. Nothing is invented.
class AdminDashboardNotifier extends Notifier<AdminDashboardState> {
  static const Duration _refreshEvery = Duration(minutes: 1);
  static const int _rows = 10;

  Timer? _timer;
  bool _loading = false;
  bool _loadAgain = false;
  bool _stopped = false;

  @override
  AdminDashboardState build() {
    ref.onDispose(() {
      _stopped = true;
      _timer?.cancel();
    });
    // Someone started or ended duty: the feed has a new line.
    ref.listen(
      adminLiveMapControllerProvider.select(
        (s) => s.officers.map((o) => o.id).join(','),
      ),
      (_, _) => unawaited(_load()),
    );
    Future<void>.microtask(() {
      if (_stopped) return;
      _timer = Timer.periodic(_refreshEvery, (_) => unawaited(_load()));
      unawaited(_load());
    });
    return const AdminDashboardState();
  }

  /// Tries the first load again after it failed.
  Future<void> retry() {
    state = state.copyWith(isLoading: true, clearError: true);
    return _load();
  }

  /// Reloads without showing the loading state (pull to refresh).
  Future<void> refresh() => _load();

  Future<void> _load() async {
    if (_stopped) return;
    if (_loading) {
      // A change arrived mid-load: load once more when this one ends.
      _loadAgain = true;
      return;
    }
    _loading = true;
    try {
      final events = await ref
          .read(adminActivityRepositoryProvider)
          .fetchRecent(limit: _rows);
      if (_stopped) return;
      final now = ref.read(phoneClockProvider)().toUtc();
      state = state.copyWith(
        activities: [for (final event in events) _toItem(event, now)],
        isLoading: false,
        clearError: true,
      );
    } on AppException catch (e) {
      _failed(e.message);
    } catch (_) {
      _failed('Could not load recent activity. Please try again.');
    } finally {
      _loading = false;
    }
    if (_loadAgain && !_stopped) {
      _loadAgain = false;
      await _load();
    }
  }

  /// Keeps what is already shown when a refresh fails; only a failed first
  /// load becomes an error.
  void _failed(String message) {
    if (_stopped) return;
    if (state.isLoading) {
      state = state.copyWith(isLoading: false, errorMessage: message);
    }
  }

  AdminActivityItem _toItem(AdminActivityEvent event, DateTime now) {
    final name = event.personName;
    final code = event.employeeCode;
    final (String title, String subtitle) = switch (event.kind) {
      AdminActivityKind.dutyStarted => ('$name started duty', code ?? ''),
      AdminActivityKind.dutyEnded => (
        '$name ended duty',
        event.detail ?? code ?? '',
      ),
      AdminActivityKind.dutyAutoEnded => (
        'Duty ended automatically',
        [name, ?code].join(' · '),
      ),
      AdminActivityKind.employeeCreated => (
        '$name was added',
        [?code, ?event.detail].join(' · '),
      ),
      AdminActivityKind.employeeBlocked => (
        '$name was blocked',
        event.detail ?? '',
      ),
      AdminActivityKind.employeeUnblocked => (
        '$name was unblocked',
        event.detail ?? '',
      ),
    };
    return AdminActivityItem(
      id: event.id,
      kind: event.kind,
      title: title,
      subtitle: subtitle,
      timeAgo: TimeAgo.format(now.difference(event.occurredAt)),
    );
  }
}
