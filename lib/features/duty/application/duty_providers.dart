import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logging/app_log.dart';
import '../../../core/rules/duty_rules.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../../../core/time/clock_providers.dart';
import '../../../core/time/ist.dart';
import '../../../core/time/server_clock.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/domain/auth_status.dart';
import '../../tracking/application/tracker_control.dart';
import '../../tracking/application/tracker_providers.dart';
import '../../tracking/domain/tracking_session.dart';
import '../data/duty_repository.dart';
import '../domain/duty_day.dart';
import '../domain/duty_failure.dart';
import '../domain/duty_home.dart';

/// Duty calls to the server. Overridden in tests.
final Provider<DutyRepository> dutyRepositoryProvider =
    Provider<DutyRepository>(
      (Ref ref) => SupabaseDutyRepository(ref.watch(supabaseClientProvider)),
    );

/// The employee's home screen state, with duty on and duty off.
final AsyncNotifierProvider<DutyHomeController, DutyHome> dutyHomeProvider =
    AsyncNotifierProvider.autoDispose<DutyHomeController, DutyHome>(
      DutyHomeController.new,
      // No automatic retry: offline is handled inside, and any other error
      // shows a Retry button instead of retrying in the background.
      retry: (int count, Object error) => null,
    );

class DutyHomeController extends AsyncNotifier<DutyHome> {
  DutyRepository get _repo => ref.read(dutyRepositoryProvider);
  TrackerControl get _tracker => ref.read(trackerControlProvider);
  ServerClock get _clock => ref.read(serverClockProvider);

  /// The server time is checked again when it is older than this.
  static const Duration _clockMaxAge = Duration(minutes: 10);

  late String _userId;

  @override
  Future<DutyHome> build() {
    final AuthStatus status = ref.watch(authStatusProvider);
    // Home is only shown signed in; wait until the status says so.
    if (status is! SignedIn) return Completer<DutyHome>().future;
    _userId = status.userId;
    return _load();
  }

  /// Reloads from the server and makes sure the tracker is in step.
  Future<void> refresh() async {
    final DutyHome next = await _load();
    if (ref.mounted) state = AsyncData<DutyHome>(next);
  }

  Future<DutyHome> _load() async {
    await _clock.syncIfStale(_clockMaxAge);
    final DateTime now = _clock.now();
    final DateTime today = Ist.dateOf(now);
    TrackingSession? session = await _tracker.session();
    if (session != null && Ist.dateOf(session.dutyOnAt) != today) {
      session = null;
    }

    DutyDay? day;
    try {
      day = await _repo.forDay(_userId, today);
    } on Object catch (e) {
      if (mapDutyError(e) != DutyFailure.noInternet) rethrow;
      // Offline: show what the phone knows.
      unawaited(_keepTrackerInStep());
      return DutyHome(
        today: session == null
            ? null
            : DutyDay(
                id: session.dayId,
                day: today,
                status: DayStatus.onDuty,
                dutyOnAt: session.dutyOnAt,
              ),
        session: session,
        loadedAt: now,
        serverReachable: false,
      );
    }

    String? problem;
    if (day != null && day.status == DayStatus.onDuty) {
      if (now.isBefore(DutyRules.autoDutyOffFor(day.dutyOnAt!)) &&
          (session == null ||
              session.dayId != day.id ||
              await _tracker.passRefused())) {
        // Duty is on but this phone lost its session (app data cleared) or
        // its upload pass (a password reset): get a new pass. Points waiting
        // on the phone go up with it.
        try {
          session = await _startTracker(await _resume());
        } on DutyException catch (e) {
          problem = e.failure.message;
        }
      }
    } else if (day != null &&
        session != null &&
        session.dayId == day.id &&
        !session.isOff) {
      // The server ended the day (11:00 PM, or the admin): stop recording.
      await _tracker.dutyOff(day.dutyOffAt ?? now, confirmed: true);
      session = await _tracker.session();
    }
    if (problem == null) unawaited(_keepTrackerInStep());
    var allowed = false;
    if (day == null && !DutyRules.canDutyOn(now)) {
      try {
        allowed = await _repo.dutyOnAllowed(_userId, today);
      } on Object catch (e, st) {
        // Without the answer the screen shows duty on as closed.
        AppLog.failure('DutyHome.dutyOnAllowed', e, st);
      }
    }
    return DutyHome(
      today: day,
      session: session,
      loadedAt: now,
      trackingProblem: problem,
      dutyOnAllowed: allowed,
    );
  }

  Future<void> _keepTrackerInStep() async {
    try {
      await _tracker.ensureRunning();
    } on Object catch (e, st) {
      AppLog.failure('DutyHome.ensureRunning', e, st);
    }
  }

  Future<DutyStart> _resume() async {
    try {
      return await _repo.resume(await ref.read(deviceIdStoreProvider).get());
    } on Object catch (e) {
      throw DutyException(mapDutyError(e));
    }
  }

  Future<TrackingSession> _startTracker(DutyStart start) async {
    final DateTime dutyOnAt = start.day.dutyOnAt!;
    final TrackingSession session = TrackingSession(
      dayId: start.day.id,
      pass: start.pass,
      dutyOnAt: dutyOnAt,
      autoOffAt: DutyRules.autoDutyOffFor(dutyOnAt),
    );
    try {
      await _tracker.start(session);
    } on TrackerStartFailed {
      throw const DutyException(DutyFailure.trackerFailed);
    }
    return session;
  }

  /// Requirements still missing before duty on.
  Future<List<TrackerRequirement>> missingRequirements() =>
      _tracker.missingRequirements();

  Future<void>? _dutyOnRun;

  /// Duty on. Throws [DutyException] with the reason when it is refused.
  ///
  /// A second call while one is running joins it, so a double press sends
  /// one request and both callers get the same result.
  Future<void> dutyOn() =>
      _dutyOnRun ??= _dutyOnOnce().whenComplete(() => _dutyOnRun = null);

  Future<void> _dutyOnOnce() async {
    if (!await _clock.sync()) {
      throw const DutyException(DutyFailure.noInternet);
    }
    // Outside the window only with the admin's permission; the server checks
    // it again.
    if (!DutyRules.canDutyOn(_clock.now()) &&
        !(state.value?.dutyOnAllowed ?? false)) {
      throw const DutyException(DutyFailure.closed);
    }
    final DutyStart start;
    try {
      start = await _repo.dutyOn(await ref.read(deviceIdStoreProvider).get());
    } on Object catch (e) {
      throw DutyException(mapDutyError(e));
    }
    try {
      await _startTracker(start);
    } finally {
      await refresh();
    }
  }

  /// Duty off. Works offline: the time is saved and sent later.
  Future<DutyOffOutcome> dutyOff() async {
    final DutyHome? home = state.value;
    final DutyDay? day = home?.today;
    if (day == null || day.dutyOnAt == null) {
      throw const DutyException(DutyFailure.notOnDuty);
    }
    final DateTime offAt = _clock.now();
    DutyDay? ended;
    bool offline = false;
    try {
      ended = await _repo.dutyOff(day.id, offAt);
    } on Object catch (e) {
      final DutyFailure failure = mapDutyError(e);
      if (failure == DutyFailure.noInternet) {
        offline = true;
      } else if (failure == DutyFailure.alreadyEnded) {
        ended = await _repo.forDay(_userId, day.day);
      } else {
        throw DutyException(failure);
      }
    }
    try {
      await _tracker.dutyOff(offAt, confirmed: !offline);
    } on Object catch (e, st) {
      AppLog.failure('DutyHome.dutyOff', e, st);
    }
    await refresh();
    final int? minutes = ended?.workedMinutes;
    return DutyOffOutcome(
      worked: minutes != null
          ? Duration(minutes: minutes)
          : offAt.difference(day.dutyOnAt!),
      savedOffline: offline,
      status: ended?.status,
    );
  }
}
