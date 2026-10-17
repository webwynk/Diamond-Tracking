import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/errors/app_exceptions.dart';
import '../../../../../core/utils/phone_clock.dart';
import '../../../../../core/utils/time_ago.dart';
import '../../../../../data/repositories/supabase_live_location_repository.dart';
import '../../../../../domain/entities/live_position.dart';
import '../../../../../domain/repositories/live_location_repository.dart';
import '../../../employees/presentation/controllers/admin_employee_list_controller.dart';
import '../../../employees/presentation/controllers/admin_employee_list_state.dart';
import 'admin_live_map_state.dart';

/// Provider exposing the live position source.
final liveLocationRepositoryProvider = Provider<LiveLocationRepository>((ref) {
  return SupabaseLiveLocationRepository();
});

/// A request from elsewhere in the app (the Team profile's "Track live") to
/// show one employee on the live map. The map consumes it and clears it.
final liveMapFocusProvider = NotifierProvider<LiveMapFocusNotifier, String?>(
  LiveMapFocusNotifier.new,
);

class LiveMapFocusNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void request(String employeeId) => state = employeeId;

  void clear() => state = null;
}

/// Provider exposing the admin live map controller.
///
/// Auto-disposed: when the admin shell goes away (sign-out, or another login on
/// the same phone) the Realtime channel is closed and the timers stop, so one
/// admin's positions are never kept for the next person (docs/08 section 5).
final adminLiveMapControllerProvider =
    NotifierProvider.autoDispose<AdminLiveMapNotifier, AdminLiveMapState>(
      AdminLiveMapNotifier.new,
    );

/// Riverpod 3 Notifier behind the admin live map.
///
/// Where the data comes from, and why it is built this way (docs/07 section 3,
/// docs/08):
/// - The full list of on-duty positions is loaded once and replaced whenever
///   the connection (re)opens, and again every minute as a safety net, so a
///   missed change can never stay wrong for long.
/// - Changes arrive over Realtime and are collected, then applied once a second
///   in one batch, so 150 moving employees do not rebuild the map 150 times a
///   second.
/// - A change is applied only if it is newer than what is held, the same rule
///   the database uses, so a late message never moves someone backwards.
/// - "Stale" is judged against the server's clock, not the admin's phone.
/// - Nothing is invented: until the first load succeeds the map shows a loading
///   or error state, never an empty "nobody on duty".
class AdminLiveMapNotifier extends Notifier<AdminLiveMapState> {
  static const Duration _tick = Duration(seconds: 1);
  static const int _agesEveryTicks = 30;
  static const int _reconcileEveryTicks = 60;

  final Map<String, LivePosition> _positions = <String, LivePosition>{};
  final Map<String, AdminEmployeeItem> _roster = <String, AdminEmployeeItem>{};

  /// Changes waiting for the next batch. A null value means "went off duty".
  final Map<String, LivePosition?> _pending = <String, LivePosition?>{};

  /// Employees whose name was missing from the roster once already, so a
  /// roster that really does not contain them is not reloaded every second.
  final Set<String> _unknownTried = <String>{};

  Duration _clockOffset = Duration.zero;
  StreamSubscription<LiveLocationEvent>? _events;
  Timer? _timer;
  int _ticks = 0;
  bool _loading = false;
  bool _reloadAgain = false;
  bool _stopped = false;

  /// What the last full load did, and what the Realtime channel last said.
  /// Together they decide the connection indicator.
  bool _loadOk = true;
  bool _rosterLoaded = false;
  bool _realtimeSeen = false;
  bool _realtimeUp = false;

  @override
  AdminLiveMapState build() {
    ref.onDispose(_stop);
    Future<void>.microtask(_start);
    return const AdminLiveMapState();
  }

  void setFilter(AdminMapFilter filter) {
    state = state.copyWith(selectedFilter: filter);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void clearFilters() {
    state = state.copyWith(selectedFilter: AdminMapFilter.all, searchQuery: '');
  }

  /// Opens the card of [employeeId], or closes it when null.
  void select(String? employeeId) {
    state = employeeId == null
        ? state.copyWith(clearSelected: true)
        : state.copyWith(selectedId: employeeId);
  }

  /// Tries the first load again after it failed.
  Future<void> retry() {
    state = state.copyWith(isLoading: true, clearError: true);
    return _reload();
  }

  /// Reloads everything without showing the loading state (pull to refresh).
  Future<void> refresh() => _reload();

  Future<void> _start() async {
    if (_stopped) return;
    try {
      _events = ref
          .read(liveLocationRepositoryProvider)
          .watch()
          .listen(_onEvent);
    } on Object {
      // The channel could not even be opened: show it as offline. The full
      // load below and the minute-by-minute reload still work.
      _realtimeSeen = true;
    }
    _timer = Timer.periodic(_tick, (_) => _onTick());
    await _reload();
  }

  void _stop() {
    _stopped = true;
    _timer?.cancel();
    _events?.cancel();
  }

  void _onEvent(LiveLocationEvent event) {
    switch (event) {
      case LivePositionChanged(:final position):
        _pending[position.employeeId] = position;
      case LivePositionRemoved(:final employeeId):
        _pending[employeeId] = null;
      case LiveConnectionChanged(:final connected):
        _realtimeSeen = true;
        _realtimeUp = connected;
        _syncConnection();
        // Changes may have been missed while it was down, or before it came
        // up: take the full list again.
        if (connected) unawaited(_reload());
    }
  }

  void _onTick() {
    _ticks++;
    var changed = _flush();
    // Ages ("3 min ago", stale) move with time even when nothing arrives.
    if (_ticks % _agesEveryTicks == 0) changed = true;
    if (_ticks % _reconcileEveryTicks == 0) unawaited(_reload());
    if (changed) _publish();
  }

  /// Applies the waiting changes. Returns whether anything was waiting.
  bool _flush({bool duringLoad = false}) {
    if ((_loading && !duringLoad) || _pending.isEmpty) return false;
    _pending.forEach((id, position) {
      if (position == null) {
        _positions.remove(id);
        return;
      }
      final held = _positions[id];
      if (held == null || position.recordedAt.isAfter(held.recordedAt)) {
        _positions[id] = position;
      }
    });
    _pending.clear();
    return true;
  }

  Future<void> _reload() async {
    if (_stopped) return;
    if (_loading) {
      _reloadAgain = true;
      return;
    }
    _loading = true;
    try {
      final repo = ref.read(liveLocationRepositoryProvider);
      final positionsRequest = repo.fetchAll();
      // The names and the clock are helpful but not essential: if either read
      // fails the map still shows positions.
      final rosterRequest = _tolerate(
        ref.read(employeeRepositoryProvider).getEmployees(),
      );
      final clockRequest = _tolerate(repo.getServerTime());

      final positions = await positionsRequest;
      final roster = await rosterRequest;
      final serverTime = await clockRequest;
      if (_stopped) return;

      if (serverTime != null) {
        _clockOffset = serverTime.difference(_phoneNow());
      }
      if (roster != null) {
        _rosterLoaded = true;
        _roster
          ..clear()
          ..addEntries(roster.map((e) => MapEntry(e.id, e)));
      }
      _positions
        ..clear()
        ..addEntries(positions.map((p) => MapEntry(p.employeeId, p)));
      _loadOk = true;
      state = state.copyWith(isLoading: false, clearError: true);
      _syncConnection();
      // Changes that arrived during the load are replayed on top of the fresh
      // list.
      _flush(duringLoad: true);
      _publish();
    } on AppException catch (e) {
      _failed(e.message);
    } catch (_) {
      _failed('Could not load the live map. Please try again.');
    } finally {
      _loading = false;
    }
    if (_reloadAgain && !_stopped) {
      _reloadAgain = false;
      await _reload();
    }
  }

  /// Keeps what is already on screen when a refresh fails; only a failed first
  /// load becomes an error screen.
  void _failed(String message) {
    if (_stopped) return;
    _loadOk = false;
    if (state.isLoading) {
      state = state.copyWith(isLoading: false, errorMessage: message);
    }
    _syncConnection();
  }

  void _syncConnection() {
    final connection = !_loadOk
        ? LiveConnection.offline
        : !_realtimeSeen
        ? LiveConnection.connecting
        : _realtimeUp
        ? LiveConnection.live
        : LiveConnection.offline;
    if (connection != state.connection) {
      state = state.copyWith(connection: connection);
    }
  }

  Future<T?> _tolerate<T>(Future<T> request) async {
    try {
      return await request;
    } catch (_) {
      return null;
    }
  }

  void _publish() {
    if (_stopped) return;
    final now = _phoneNow().add(_clockOffset);
    final officers = <LiveOfficer>[
      for (final position in _positions.values) _toOfficer(position, now),
    ]..sort(_byName);
    state = state.copyWith(
      officers: officers,
      offDutyCount: _rosterLoaded
          ? _roster.values
                .where((e) => e.isActive && !_positions.containsKey(e.id))
                .length
          : null,
    );
  }

  LiveOfficer _toOfficer(LivePosition position, DateTime now) {
    final person = _roster[position.employeeId];
    if (person == null && _unknownTried.add(position.employeeId)) {
      // Created after the roster was loaded: fetch the roster once more.
      unawaited(_reload());
    }
    final age = now.difference(position.recordedAt);
    return LiveOfficer(
      id: position.employeeId,
      name: person?.name ?? 'Employee',
      employeeCode: person?.employeeCode ?? '',
      phoneNumber: person?.phoneNumber ?? '',
      position: position,
      status: position.statusAt(now),
      lastSeen: TimeAgo.format(age),
    );
  }

  DateTime _phoneNow() => ref.read(phoneClockProvider)().toUtc();

  static int _byName(LiveOfficer a, LiveOfficer b) {
    final byName = a.name.toLowerCase().compareTo(b.name.toLowerCase());
    return byName != 0 ? byName : a.id.compareTo(b.id);
  }
}
