import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exceptions.dart';
import '../../../../core/services/tracker_engine.dart';
import '../../../../core/services/tracking_service.dart';
import '../../../../core/services/tracking_uploader.dart';
import '../../../../core/utils/duty_time_helper.dart';
import '../../../../core/utils/session_distance_estimator.dart';
import '../../../../data/local/drift_tracking_queue_store.dart';
import '../../../../data/local/tracking_database.dart';
import '../../../../data/repositories/supabase_duty_repository.dart';
import '../../../../domain/entities/duty_session.dart';
import '../../../../domain/repositories/duty_repository.dart';
import '../../../../domain/repositories/tracking_queue_store.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../auth/presentation/controllers/auth_state.dart';
import '../../../onboarding/presentation/controllers/permission_controller.dart';
import 'duty_state.dart';

/// Provider for the global [DutyRepository] dependency.
final dutyRepositoryProvider = Provider<DutyRepository>((ref) {
  return SupabaseDutyRepository();
});

/// Provider for the global [TrackingService] dependency.
final trackingServiceProvider = Provider<TrackingService>((ref) {
  final service = DeviceTrackingService(ref.watch(trackingQueueStoreProvider));
  ref.onDispose(service.dispose);
  return service;
});

/// Provider for the uploader that sends queued points to the server.
final trackingUploaderProvider = Provider<TrackingUploader>((ref) {
  final uploader = TrackingUploader(
    queue: ref.watch(trackingQueueStoreProvider),
    ingestor: ref.watch(dutyRepositoryProvider),
  );
  ref.onDispose(uploader.stop);
  return uploader;
});

/// The phone's own database (GPS queue, active session, pending duty-off,
/// waiting visits). Opened on first use, closed with the provider. One
/// connection per isolate, shared by everything that stores on the phone.
final trackingDatabaseProvider = Provider<TrackingDatabase>((ref) {
  final database = TrackingDatabase.onDevice();
  ref.onDispose(database.close);
  return database;
});

/// Provider for the phone's durable tracking queue (points, active session,
/// pending duty-off).
final trackingQueueStoreProvider = Provider<TrackingQueueStore>((ref) {
  return DriftTrackingQueueStore(ref.watch(trackingDatabaseProvider));
});

/// Global provider for managing and observing employee duty lifecycle.
final dutyControllerProvider = NotifierProvider<DutyNotifier, DutyScreenState>(
  DutyNotifier.new,
);

/// Notifier governing the duty lifecycle, background GPS tracking engine,
/// and telemetry counters adhering strictly to PRD F3, F4 and BR-1 through BR-8.
///
/// The server is the source of truth for whether duty is on, when it started
/// and ended, and the final distance. This notifier never invents any of them:
/// when the server cannot be reached the action fails with a message and the
/// screen keeps showing the real state.
class DutyNotifier extends Notifier<DutyScreenState> {
  /// Interim guard: how often the 23:00 auto-end is retried while offline.
  static const Duration _autoEndRetryInterval = Duration(seconds: 30);

  late final DutyRepository _dutyRepository;
  late final TrackingService _trackingService;

  Timer? _elapsedTimer;
  StreamSubscription? _pointSubscription;
  StreamSubscription<TrackerStopReason>? _stopSubscription;
  StreamSubscription<TrackerNotice>? _noticeSubscription;
  int _timerTicks = 0;
  SessionDistanceEstimator _distanceEstimator = SessionDistanceEstimator();
  DateTime? _lastAutoEndAttempt;

  @override
  DutyScreenState build() {
    _dutyRepository = ref.watch(dutyRepositoryProvider);
    _trackingService = ref.watch(trackingServiceProvider);

    // The tracker can stop by itself (23:00, the server closed the session):
    // re-read the server's state so the screen follows.
    _stopSubscription = _trackingService.stopStream.listen((_) {
      if (ref.mounted) refresh();
    });

    _noticeSubscription = _trackingService.noticeStream.listen((notice) {
      if (!ref.mounted) return;
      if (notice == TrackerNotice.needsSignIn) {
        state = state.copyWith(
          errorMessage:
              'Your sign-in has expired. Sign in again to send your points. '
              'Nothing is lost.',
        );
      }
    });

    ref.onDispose(() {
      _elapsedTimer?.cancel();
      _pointSubscription?.cancel();
      _stopSubscription?.cancel();
      _noticeSubscription?.cancel();
    });

    // Check operating window initially
    final isWindowOpen = DutyTimeHelper.isWithinDutyWindow();
    final initialState = isWindowOpen
        ? const DutyScreenState(isLoading: true)
        : DutyScreenState(
            status: DutyStatus.disabledWindow,
            disabledReason: DutyTimeHelper.getDutyDisabledReason(),
          );

    if (isWindowOpen) {
      Future.microtask(refresh);
    }

    return initialState;
  }

  /// Opened on first use, so nothing touches the on-phone database until an
  /// employee is signed in and the duty screen needs it.
  TrackingUploader get _uploader => ref.read(trackingUploaderProvider);

  /// The signed-in employee's id, or null when nobody is signed in.
  String? get _employeeId {
    final authState = ref.read(authControllerProvider);
    return authState is AuthAuthenticated ? authState.profile.id : null;
  }

  /// Refreshes operating window, active session, yesterday's shift, and telemetry queue.
  Future<void> refresh() async {
    // 1. Operating Window Check (PRD BR-1)
    if (!DutyTimeHelper.isWithinDutyWindow()) {
      _elapsedTimer?.cancel();
      if (await _trackingService.isTrackerRunning()) {
        await _trackingService.stopTracking();
      }
      if (ref.mounted) {
        state = state.copyWith(
          status: DutyStatus.disabledWindow,
          disabledReason: DutyTimeHelper.getDutyDisabledReason(),
          isLoading: false,
        );
      }
      return;
    }

    // 2. Fetch active session for current authenticated employee
    final employeeId = _employeeId;
    if (employeeId == null) {
      state = state.copyWith(isLoading: false);
      return;
    }

    try {
      final active = await _dutyRepository.getActiveDutySession(
        employeeId: employeeId,
      );
      final yesterday = await _dutyRepository.getYesterdayDutySession(
        employeeId: employeeId,
      );
      final queuedCount = await _trackingService.getQueuedPointsCount();
      final trackerRunning = await _trackingService.isTrackerRunning();

      // One uploader at a time: while the background tracker runs it uploads
      // from its own service; otherwise this screen sends whatever is still
      // waiting from an earlier shift.
      if (trackerRunning) {
        _uploader.stop();
      } else {
        _uploader.start();
      }

      if (!ref.mounted) return;

      if (active != null && trackerRunning) {
        // On duty and the background tracker is running (possibly since before
        // this screen was opened): attach to it.
        _startElapsedTimer();
        _listenToPointStream();

        state = state.copyWith(
          status: DutyStatus.onDuty,
          activeSession: active,
          yesterdaySession: yesterday,
          elapsedDuration: active.elapsedDuration,
          distanceKm: active.totalDistanceKm,
          visitsCount: active.visitsCount,
          queuedPointsCount: queuedCount,
          isLoading: false,
        );
      } else if (active != null) {
        // The server has this duty open but nothing is tracking on this phone
        // (it was switched off, the app was killed, the system stopped the
        // service). Starting duty again continues the SAME duty.
        _elapsedTimer?.cancel();
        state = state.copyWith(
          status: DutyStatus.offDuty,
          clearActiveSession: true,
          yesterdaySession: yesterday,
          elapsedDuration: Duration.zero,
          distanceKm: 0.0,
          visitsCount: 0,
          queuedPointsCount: queuedCount,
          isLoading: false,
          errorMessage:
              'Your duty is still open, but tracking stopped on this phone. '
              'Tap Start duty to continue.',
        );
      } else {
        _elapsedTimer?.cancel();
        if (trackerRunning) await _trackingService.stopTracking();
        state = state.copyWith(
          status: DutyStatus.offDuty,
          clearActiveSession: true,
          yesterdaySession: yesterday,
          elapsedDuration: Duration.zero,
          distanceKm: 0.0,
          visitsCount: 0,
          queuedPointsCount: queuedCount,
          isLoading: false,
        );
      }
    } on AppException catch (e) {
      if (ref.mounted) {
        state = state.copyWith(isLoading: false, errorMessage: e.message);
      }
    } catch (_) {
      // Anything unexpected (a platform call failing) must not leave the
      // screen loading forever.
      if (ref.mounted) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Could not load your duty status. Please try again.',
        );
      }
    }
  }

  /// Toggles duty state between On and Off, respecting the operating window.
  Future<void> toggleDuty() async {
    if (state.status == DutyStatus.disabledWindow) {
      return;
    }

    if (state.status == DutyStatus.onDuty) {
      await endDuty();
    } else if (state.status == DutyStatus.offDuty) {
      await startDuty();
    }
  }

  /// Initiates duty tracking session (Screen 06 -> Screen 07).
  ///
  /// Order matters: check the phone can track first, then create the server
  /// session, then start the tracker. A session is never left open with no
  /// tracker behind it.
  Future<bool> startDuty() async {
    if (state.status == DutyStatus.starting ||
        state.status == DutyStatus.onDuty ||
        state.status == DutyStatus.ending) {
      return false;
    }

    // Display-side check only; the server judges the window on its own clock.
    if (!DutyTimeHelper.isWithinDutyWindow()) {
      state = state.copyWith(
        status: DutyStatus.disabledWindow,
        disabledReason: DutyTimeHelper.getDutyDisabledReason(),
      );
      return false;
    }

    final employeeId = _employeeId;
    if (employeeId == null) {
      state = state.copyWith(
        errorMessage: 'Please sign in again to start duty.',
      );
      return false;
    }

    state = state.copyWith(status: DutyStatus.starting);

    try {
      final blocker = await _startBlocker();
      if (blocker != null) {
        state = state.copyWith(
          status: DutyStatus.offDuty,
          startBlocker: blocker,
          errorMessage: blocker == DutyStartBlocker.locationServicesOff
              ? 'Turn on Location (GPS) in your phone settings, then try again.'
              : 'Allow location access, "Allow all the time" and the battery '
                    'exemption before starting duty.',
        );
        return false;
      }

      final session = await _dutyRepository.startDutySession(
        employeeId: employeeId,
      );

      final tracking = await _trackingService.startTracking(
        session: ActiveTrackingSession(
          sessionId: session.id,
          employeeId: employeeId,
          startedAt: session.startedAt,
          clockOffset: await _serverClockOffset(),
        ),
      );
      if (!tracking) {
        await _closeUntrackedSession(session);
        if (ref.mounted) {
          state = state.copyWith(
            status: DutyStatus.offDuty,
            errorMessage:
                'GPS tracking could not start. Check your location and '
                'notification settings and try again.',
          );
        }
        return false;
      }

      _distanceEstimator = SessionDistanceEstimator();
      _uploader.stop(); // the background tracker uploads from now on
      _startElapsedTimer();
      _listenToPointStream();

      if (ref.mounted) {
        state = state.copyWith(
          status: DutyStatus.onDuty,
          activeSession: session,
          // A continued duty (battery died, app restarted) keeps its real start.
          elapsedDuration: session.elapsedDuration,
          distanceKm: 0.0,
          visitsCount: session.visitsCount,
          queuedPointsCount: await _trackingService.getQueuedPointsCount(),
          clearLastLocation: true,
        );
      }
      return true;
    } on AppException catch (e) {
      if (ref.mounted) {
        state = state.copyWith(
          status: DutyStatus.offDuty,
          errorMessage: e.message,
        );
      }
      return false;
    } catch (_) {
      if (ref.mounted) {
        state = state.copyWith(
          status: DutyStatus.offDuty,
          errorMessage: 'Could not start duty. Please try again.',
        );
      }
      return false;
    }
  }

  /// Terminates the active duty tracking session (Screen 07 -> Screen 06 / Screen 11).
  ///
  /// Returns the session as the server closed it, or null if it could not be
  /// closed. On failure the employee stays on duty and tracking keeps running:
  /// pretending duty ended would leave the server session open.
  Future<DutySession?> endDuty({
    String? notes,
    String reason = 'normal',
  }) async {
    final session = state.activeSession;
    if (session == null || state.status == DutyStatus.ending) return null;

    state = state.copyWith(status: DutyStatus.ending);

    try {
      // Send the latest points first so the server's distance includes them;
      // a slow connection waits at most a few seconds, and whatever is missed
      // is accepted later (late uploads are recounted by the server).
      await _uploader.flush();

      final finalSession = await _dutyRepository.endDutySession(
        sessionId: session.id,
        endReason: reason,
        notes: notes,
      );

      _elapsedTimer?.cancel();
      _pointSubscription?.cancel();
      _pointSubscription = null;
      await _trackingService.stopTracking();

      // Whatever could not be sent yet keeps going out from this screen.
      _uploader.start();
      final waiting = await _trackingService.getQueuedPointsCount();

      if (ref.mounted) {
        state = state.copyWith(
          status: DutyStatus.offDuty,
          clearActiveSession: true,
          clearLastLocation: true,
          queuedPointsCount: waiting,
        );
      }
      return finalSession;
    } on AppException catch (e) {
      if (ref.mounted) {
        state = state.copyWith(
          status: DutyStatus.onDuty,
          errorMessage: e is NetworkException
              ? 'No internet. You are still on duty; try ending duty again when you are back online.'
              : e.message,
        );
      }
      return null;
    } catch (_) {
      if (ref.mounted) {
        state = state.copyWith(
          status: DutyStatus.onDuty,
          errorMessage: 'Could not end duty. Please try again.',
        );
      }
      return null;
    }
  }

  /// What stops this phone from tracking right now, or null when it can (PRD F3).
  Future<DutyStartBlocker?> _startBlocker() async {
    final permissions = ref.read(permissionServiceProvider);
    final granted =
        await permissions.isLocationGranted() &&
        await permissions.isBackgroundLocationGranted() &&
        await permissions.isBatteryOptimizationIgnored();
    if (!granted) return DutyStartBlocker.permissionsMissing;
    if (!await permissions.isLocationServiceEnabled()) {
      return DutyStartBlocker.locationServicesOff;
    }
    return null;
  }

  /// Server time minus the phone's clock, so a wrong phone clock cannot shift
  /// point times or the 23:00 cutoff (docs/08 section 4). Zero when the server
  /// cannot be reached for this one call; the phone's clock is then used as is.
  Future<Duration> _serverClockOffset() async {
    try {
      final serverNow = await _dutyRepository.getServerTime();
      return serverNow.difference(DateTime.now().toUtc());
    } on AppException {
      return Duration.zero;
    }
  }

  /// Closes a session that was just opened but whose tracker would not start.
  Future<void> _closeUntrackedSession(DutySession session) async {
    try {
      await _dutyRepository.endDutySession(sessionId: session.id);
    } on AppException {
      // Could not reach the server to close it. The next refresh() re-reads the
      // server's session, so the screen cannot drift from the server for long.
    }
  }

  void _startElapsedTimer() {
    _elapsedTimer?.cancel();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!ref.mounted) {
        timer.cancel();
        return;
      }

      // Curfew boundary (23:00 IST, PRD BR-2). The server job is the real
      // enforcement; this ends the session promptly when the phone is online.
      if (!DutyTimeHelper.isWithinDutyWindow()) {
        _autoEndAtCurfew();
        return;
      }

      final active = state.activeSession;
      if (active != null) {
        state = state.copyWith(elapsedDuration: active.elapsedDuration);
      }

      // The service uploads in the background, so the waiting count changes
      // without this screen being told: re-read it every few seconds.
      if (++_timerTicks % 5 == 0) unawaited(_refreshQueueCount());
    });
  }

  Future<void> _refreshQueueCount() async {
    final waiting = await _trackingService.getQueuedPointsCount();
    if (ref.mounted && waiting != state.queuedPointsCount) {
      state = state.copyWith(queuedPointsCount: waiting);
    }
  }

  /// What signing out would cost right now. While on duty it is not allowed
  /// (tracking would stop); otherwise it tries to send what is waiting first,
  /// and reports how many points still could not be sent.
  Future<SignOutCheck> checkBeforeSignOut() async {
    if (state.status == DutyStatus.onDuty ||
        state.status == DutyStatus.starting ||
        state.status == DutyStatus.ending) {
      return const SignOutCheck(onDuty: true);
    }
    await _uploader.flush();
    return SignOutCheck(
      unsyncedPoints: await _trackingService.getQueuedPointsCount(),
    );
  }

  /// Signing out: stop uploading and delete everything recorded on this phone,
  /// so the next person who uses it never sees this employee's data.
  Future<void> clearLocalTrackingData() async {
    _uploader.stop();
    _elapsedTimer?.cancel();
    await _trackingService.clearLocalData();
  }

  void _autoEndAtCurfew() {
    final last = _lastAutoEndAttempt;
    final now = DateTime.now();
    if (last != null && now.difference(last) < _autoEndRetryInterval) return;
    _lastAutoEndAttempt = now;
    endDuty(notes: 'Duty ended automatically', reason: 'auto_curfew');
  }

  void _listenToPointStream() {
    _pointSubscription?.cancel();
    _pointSubscription = _trackingService.pointStream.listen((point) {
      if (!ref.mounted) return;
      final km = _distanceEstimator.add(point);

      state = state.copyWith(
        distanceKm: double.parse(km.toStringAsFixed(2)),
        queuedPointsCount: state.queuedPointsCount + 1,
        lastLocation: point,
      );
    });
  }
}
