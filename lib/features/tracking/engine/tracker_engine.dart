import '../../../core/logging/app_log.dart';
import '../../../core/rules/duty_rules.dart';
import '../data/point_queue.dart';
import '../data/track_uploader.dart';
import '../data/tracker_files.dart';
import '../domain/phone_off.dart';
import '../domain/point_filter.dart';
import '../domain/track_break.dart';
import '../domain/track_fix.dart';
import '../domain/tracker_status.dart';
import '../domain/tracking_session.dart';

/// What the service should be doing.
enum TrackerMode {
  /// On duty: GPS on, points recorded and uploaded.
  tracking,

  /// Duty is over (duty off, or 11:00 PM) but points or the duty off are
  /// still waiting for the internet: GPS off, keep trying to upload.
  finishing,

  /// Nothing left to do: stop the service.
  stop,
}

/// Facts about the phone that the engine needs to spot a restart.
abstract interface class SystemInfo {
  /// Time since the phone started.
  Duration uptime();

  /// Android's id for the current boot, or null if it cannot be read.
  String? bootId();
}

/// The tracker's logic, without any Android plugin, so it is unit-tested.
///
/// The foreground service feeds it GPS fixes ([onFix]) and calls [tick] once
/// a minute. The engine keeps the good fixes in the offline queue, uploads
/// them, writes the heartbeat, raises battery warnings and says when to stop
/// (duty off on the phone, or 11:00 PM).
class TrackerEngine {
  TrackerEngine({
    required this.files,
    required this.uploader,
    required this.now,
    required this.system,
    required this.onBatteryWarning,
    PointFilter? filter,
  }) : _filter = filter ?? PointFilter();

  final TrackerFiles files;
  final TrackUploader uploader;

  /// The trusted time (server time carried forward), in UTC.
  final DateTime Function() now;
  final SystemInfo system;

  /// Called with 20, 15 or 10 the first time the battery drops that low on a
  /// duty day.
  final void Function(int level) onBatteryWarning;

  final PointFilter _filter;

  /// No GPS fix for this long during the duty: GPS is silent, restart it.
  static const Duration gpsSilence = Duration(minutes: 5);

  /// A hole with a reason is reported from this length: the server shows a
  /// gap in the route after 15 minutes without a point.
  static const Duration reasonMinimum = Duration(minutes: 15);

  TrackingSession? _session;

  /// When this run of the tracker started recording, and when the last GPS
  /// fix arrived (kept or not): the watchdog measures silence from these.
  DateTime? _trackingSince;
  DateTime? _lastFixAt;

  /// GPS silent since (the last fix), until a fix arrives again.
  DateTime? _silentFrom;
  DateTime? _lastRestartAt;
  bool _restartDue = false;

  /// A problem the phone reported (location off, permission off, GPS error)
  /// and since when.
  TrackBreakKind? _problem;
  DateTime? _problemFrom;
  int? _battery;
  bool _uploading = false;
  DateTime? _lastUploadAt;
  DrainResult? _lastDrain;

  TrackingSession? get session => _session;
  DateTime? get lastUploadAt => _lastUploadAt;

  /// The last upload failed (no internet): points are waiting on the phone.
  bool get isOffline => _lastDrain?.failed ?? false;
  int get pendingCount => files.queue.pendingCount;

  /// Called when the service starts (by the app, after a phone restart, or
  /// after Android restarted a killed service). Records any break in
  /// tracking.
  Future<TrackerMode> start() async {
    final TrackingSession? session = files.readSession();
    _session = session;
    if (session == null) return _finishLeftovers();

    final DateTime at = now();
    final TrackerState state = files.readState();
    final TrackBreak? gap = breakSince(
      state.heartbeat,
      dayId: session.dayId,
      now: at,
      uptime: system.uptime(),
      bootId: system.bootId(),
    );
    if (gap != null) {
      AppLog.info('Tracker: ${gap.kind.wire} for ${gap.length.inMinutes} min');
      files.queue.addBreak(session.dayId, session.pass, gap);
    }
    if (session.isActiveAt(at)) {
      _trackingSince = at;
      _writeState(state, at);
    }
    return tick();
  }

  /// A new GPS fix.
  void onFix(TrackFix fix) {
    final TrackingSession? session = _session;
    if (session == null) return;
    // Fixes arrive live, so each one is stamped with the trusted clock when it
    // arrives (L43). The fix's own time is not used: on some phones it is the
    // satellites' (right) time, on others the phone's (maybe wrong) clock, so
    // correcting it could move the point twice.
    final DateTime at = now();
    final DateTime end = session.offAt ?? session.autoOffAt;
    if (at.isBefore(session.dutyOnAt) || !at.isBefore(end)) {
      return;
    }
    _lastFixAt = at;
    _closeSilence(session, at);
    final TrackFix shifted = TrackFix(
      time: at,
      latitude: fix.latitude,
      longitude: fix.longitude,
      accuracyM: fix.accuracyM,
      mocked: fix.mocked,
    );
    if (!_filter.accept(shifted)) return;
    files.queue.addPoint(session.dayId, session.pass, <String, Object?>{
      't': at.toIso8601String(),
      'la': (fix.latitude * 1e6).round(),
      'lo': (fix.longitude * 1e6).round(),
      'a': fix.accuracyM.round(),
      'b': ?_battery,
      // Only sent when true: the server reads a missing mark as "not fake".
      if (fix.mocked) 'm': true,
    });
  }

  /// Once a minute, and right after [start].
  Future<TrackerMode> tick({int? batteryLevel}) async {
    // The app may have ended the duty, or resumed it with a new pass.
    final TrackingSession? session = files.readSession();
    if (session == null) {
      _session = null;
      return _finishLeftovers();
    }
    if (_session?.dayId != session.dayId) _filter.reset();
    _session = session;

    final DateTime at = now();
    TrackerState state = files.readState();
    if (batteryLevel != null && batteryLevel >= 0 && batteryLevel <= 100) {
      _battery = batteryLevel;
      if (session.isActiveAt(at)) {
        state = _checkBattery(state, session.dayId, batteryLevel);
      }
    }

    if (session.isActiveAt(at)) {
      _checkFrozen(session, state, at);
      _writeState(state, at);
      _checkSilence(at);
      if (files.queue.pendingCount > 0) await upload();
      return TrackerMode.tracking;
    }

    // Duty is over: close any open reason at the end of the duty, send what
    // is left, then stop.
    final DateTime end = session.offAt ?? session.autoOffAt;
    final DateTime closeAt = at.isBefore(end) ? at : end;
    _closeSilence(session, closeAt);
    _closeProblem(session, closeAt);
    files.writeState(state);
    await upload();
    if (session.isOff &&
        !session.offConfirmed &&
        state.dutyOffSentFor != session.dayId &&
        !isOffline) {
      if (await _sendDutyOff(session)) {
        files.writeState(state.copyWith(dutyOffSentFor: session.dayId));
      } else {
        return TrackerMode.finishing;
      }
    }
    return files.queue.pendingCount == 0
        ? TrackerMode.stop
        : TrackerMode.finishing;
  }

  /// Whether GPS should be restarted now (the watchdog found it silent).
  /// Answers true once per restart.
  bool takeGpsRestart() {
    final bool due = _restartDue;
    _restartDue = false;
    return due;
  }

  /// The service's view of GPS: [problem] is why it cannot record (location
  /// off, permission off, GPS error), or null once it records again. The
  /// time it lasted is reported as the reason for the hole.
  void onProblem(TrackerProblem? problem) {
    final TrackingSession? session = _session;
    if (session == null) return;
    final DateTime at = now();
    final TrackBreakKind? kind = switch (problem) {
      TrackerProblem.locationOff => TrackBreakKind.locationOff,
      TrackerProblem.permissionOff => TrackBreakKind.permissionOff,
      TrackerProblem.gps => TrackBreakKind.gpsSilent,
      null => null,
    };
    if (kind == _problem) return;
    _closeProblem(session, at);
    if (kind != null && session.isActiveAt(at)) {
      // The problem explains the silence from where it began.
      _problemFrom = _silentFrom ?? at;
      _problem = kind;
      _silentFrom = null;
    }
  }

  /// The tick itself did not run for a while: Android froze or stopped the
  /// tracker without restarting it. The same check as at a restart.
  void _checkFrozen(TrackingSession session, TrackerState state, DateTime at) {
    final Heartbeat? last = state.heartbeat;
    final Duration uptime = system.uptime();
    final TrackBreak? gap = breakSince(
      last,
      dayId: session.dayId,
      now: at,
      uptime: uptime,
      bootId: system.bootId(),
    );
    if (gap == null || last == null) return;
    // The phone's uptime cannot jump: if it moved less than the clock, the
    // clock was corrected (first server time), the tracker did not freeze.
    if (gap.kind == TrackBreakKind.trackingStopped &&
        uptime - last.uptime < const Duration(minutes: 5)) {
      return;
    }
    AppLog.info('Tracker: ${gap.kind.wire} for ${gap.length.inMinutes} min');
    files.queue.addBreak(session.dayId, session.pass, gap);
    // The freeze explains the silence; measure GPS again from now.
    _silentFrom = null;
    _lastFixAt = at;
  }

  /// The watchdog: no fix for [gpsSilence] means GPS is silent. Asks for a
  /// GPS restart, at most once every [gpsSilence].
  void _checkSilence(DateTime at) {
    _trackingSince ??= at;
    if (_problem != null) return;
    final DateTime since = _lastFixAt ?? _trackingSince!;
    if (at.difference(since) < gpsSilence) return;
    _silentFrom ??= since;
    final DateTime? last = _lastRestartAt;
    if (last == null || at.difference(last) >= gpsSilence) {
      _lastRestartAt = at;
      _restartDue = true;
    }
  }

  void _closeSilence(TrackingSession session, DateTime at) {
    final DateTime? from = _silentFrom;
    _silentFrom = null;
    if (from != null) _addReason(session, from, at, TrackBreakKind.gpsSilent);
  }

  void _closeProblem(TrackingSession session, DateTime at) {
    final DateTime? from = _problemFrom;
    final TrackBreakKind? kind = _problem;
    _problem = null;
    _problemFrom = null;
    if (from == null || kind == null) return;
    _addReason(session, from, at, kind);
    // The problem explained the time until now; measure GPS again from now.
    _lastFixAt = at;
  }

  void _addReason(
    TrackingSession session,
    DateTime from,
    DateTime to,
    TrackBreakKind kind,
  ) {
    if (to.difference(from) < reasonMinimum) return;
    AppLog.info(
      'Tracker: ${kind.wire} for ${to.difference(from).inMinutes} min',
    );
    files.queue.addBreak(
      session.dayId,
      session.pass,
      TrackBreak(from: from, to: to, kind: kind),
    );
  }

  /// No session (signed out): only old batches can be left.
  Future<TrackerMode> _finishLeftovers() async {
    if (files.queue.pendingCount == 0) return TrackerMode.stop;
    await upload();
    return files.queue.pendingCount == 0
        ? TrackerMode.stop
        : TrackerMode.finishing;
  }

  Future<bool> _sendDutyOff(TrackingSession session) async {
    try {
      await uploader.dutyOff(session.dayId, session.pass, session.offAt!);
      return true;
    } on UploadRejected catch (e) {
      // The pass expired or was replaced: the server can no longer take it.
      AppLog.failure('TrackerEngine.dutyOff', e);
      return true;
    } on Object catch (e, st) {
      AppLog.failure('TrackerEngine.dutyOff', e, st);
      return false;
    }
  }

  /// Uploads the queue. Safe to call at any time; overlapping calls are
  /// skipped.
  Future<void> upload() async {
    if (_uploading) return;
    _uploading = true;
    try {
      final TrackingSession? session = _session;
      final bool running = session != null && session.isActiveAt(now());
      TrackerState state = files.readState();
      // The server refused this pass (password reset). Wait for the app to
      // bring a new one instead of asking the server again every minute.
      if (running && state.refusedPass == session.pass) return;
      final DrainResult result = await files.queue.drain(
        uploader,
        passFor: (int dayId) =>
            session != null && session.dayId == dayId ? session.pass : null,
        keepOnRefusedPass: running,
      );
      _lastDrain = result;
      if (!result.failed) _lastUploadAt = now();
      state = files.readState();
      if (result.passRefused && running) {
        files.writeState(state.copyWith(refusedPass: session.pass));
      } else if (state.refusedPass != null) {
        files.writeState(state.copyWith(refusedPass: null));
      }
    } finally {
      _uploading = false;
    }
  }

  /// The service is being destroyed: keep everything on disk.
  void shutdown() => files.queue.seal();

  TrackerState _checkBattery(TrackerState state, int dayId, int level) {
    final Set<int> warned = state.warnedFor(dayId);
    final int? warning = DutyRules.batteryWarningFor(level, warned);
    if (warning == null) return state;
    onBatteryWarning(warning);
    return state.copyWith(
      batteryDayId: dayId,
      batteryWarned: <int>{...warned, ...DutyRules.thresholdsReached(level)},
    );
  }

  void _writeState(TrackerState state, DateTime at) {
    final TrackingSession? session = _session;
    if (session == null) return;
    files.writeState(
      state.copyWith(
        heartbeat: Heartbeat(
          dayId: session.dayId,
          at: at,
          uptime: system.uptime(),
          bootId: system.bootId(),
        ),
      ),
    );
  }
}
