import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/tracking_service.dart';
import '../../../../core/utils/duty_time_helper.dart';
import '../../../../data/repositories/supabase_duty_repository.dart';
import '../../../../domain/entities/duty_session.dart';
import '../../../../domain/repositories/duty_repository.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../auth/presentation/controllers/auth_state.dart';
import 'duty_state.dart';

/// Provider for the global [DutyRepository] dependency.
final dutyRepositoryProvider = Provider<DutyRepository>((ref) {
  return SupabaseDutyRepository();
});

/// Provider for the global [TrackingService] dependency.
final trackingServiceProvider = Provider<TrackingService>((ref) {
  return DeviceTrackingService();
});

/// Global provider for managing and observing employee duty lifecycle.
final dutyControllerProvider =
    NotifierProvider<DutyNotifier, DutyScreenState>(DutyNotifier.new);

/// Notifier governing the duty lifecycle, background GPS tracking engine,
/// and telemetry counters adhering strictly to PRD F3, F4 and BR-1 through BR-8.
class DutyNotifier extends Notifier<DutyScreenState> {
  late final DutyRepository _dutyRepository;
  late final TrackingService _trackingService;

  Timer? _elapsedTimer;
  StreamSubscription? _pointSubscription;

  @override
  DutyScreenState build() {
    _dutyRepository = ref.watch(dutyRepositoryProvider);
    _trackingService = ref.watch(trackingServiceProvider);

    ref.onDispose(() {
      _elapsedTimer?.cancel();
      _pointSubscription?.cancel();
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

  /// Refreshes operating window, active session, yesterday's shift, and telemetry queue.
  Future<void> refresh() async {
    // 1. Operating Window Check (PRD BR-1)
    if (!DutyTimeHelper.isWithinDutyWindow()) {
      _elapsedTimer?.cancel();
      if (_trackingService.isTracking) {
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
    final authState = ref.read(authControllerProvider);
    String employeeId = 'emp_current';
    if (authState is AuthAuthenticated) {
      employeeId = authState.profile.id;
    }

    try {
      final active = await _dutyRepository.getActiveDutySession(
        employeeId: employeeId,
      );
      final yesterday = await _dutyRepository.getYesterdayDutySession(
        employeeId: employeeId,
      );
      final queuedCount = await _trackingService.getQueuedPointsCount();

      if (!ref.mounted) return;

      if (active != null) {
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
      } else {
        _elapsedTimer?.cancel();
        state = state.copyWith(
          status: DutyStatus.offDuty,
          activeSession: null,
          yesterdaySession: yesterday,
          elapsedDuration: Duration.zero,
          distanceKm: 0.0,
          visitsCount: 0,
          queuedPointsCount: queuedCount,
          isLoading: false,
        );
      }
    } catch (_) {
      if (ref.mounted) {
        state = state.copyWith(isLoading: false);
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
  Future<bool> startDuty() async {
    if (!DutyTimeHelper.isWithinDutyWindow()) {
      state = state.copyWith(
        status: DutyStatus.disabledWindow,
        disabledReason: DutyTimeHelper.getDutyDisabledReason(),
      );
      return false;
    }

    state = state.copyWith(status: DutyStatus.starting);

    try {
      final authState = ref.read(authControllerProvider);
      final employeeId = authState is AuthAuthenticated
          ? authState.profile.id
          : 'emp_current';

      final session = await _dutyRepository.startDutySession(
        employeeId: employeeId,
      );

      // Start foreground service tracking with persistent notification
      await _trackingService.startTracking(sessionId: session.id);

      _startElapsedTimer();
      _listenToPointStream();

      if (ref.mounted) {
        state = state.copyWith(
          status: DutyStatus.onDuty,
          activeSession: session,
          elapsedDuration: Duration.zero,
          distanceKm: 0.0,
          visitsCount: 0,
        );
      }
      return true;
    } catch (e) {
      if (ref.mounted) {
        state = state.copyWith(
          status: DutyStatus.offDuty,
          errorMessage: e.toString(),
        );
      }
      return false;
    }
  }

  /// Terminates the active duty tracking session (Screen 07 -> Screen 06 / Screen 11).
  Future<DutySession?> endDuty({String? notes}) async {
    final session = state.activeSession;
    state = state.copyWith(status: DutyStatus.ending);

    _elapsedTimer?.cancel();
    await _trackingService.stopTracking();

    DutySession? finalSession;
    if (session != null) {
      try {
        finalSession = await _dutyRepository.endDutySession(
          sessionId: session.id,
          endReason: 'normal',
          notes: notes,
        );
      } catch (_) {
        finalSession = session.copyWith(
          status: DutySessionStatus.completed,
          endedAt: DateTime.now().toUtc(),
        );
      }
    }

    if (ref.mounted) {
      state = state.copyWith(
        status: DutyStatus.offDuty,
        activeSession: null,
      );
    }

    return finalSession;
  }

  void _startElapsedTimer() {
    _elapsedTimer?.cancel();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!ref.mounted) {
        timer.cancel();
        return;
      }

      // Check curfew boundary (23:00 IST per PRD BR-2)
      if (!DutyTimeHelper.isWithinDutyWindow()) {
        endDuty();
        return;
      }

      final active = state.activeSession;
      if (active != null) {
        state = state.copyWith(
          elapsedDuration: active.elapsedDuration,
        );
      }
    });
  }

  void _listenToPointStream() {
    _pointSubscription?.cancel();
    _pointSubscription = _trackingService.pointStream.listen((point) {
      if (!ref.mounted) return;
      // Increment distance locally while moving
      final currentKm = state.distanceKm;
      final newKm = point.speedKmh != null && point.speedKmh! > 1.0
          ? currentKm + 0.02
          : currentKm;

      state = state.copyWith(
        distanceKm: double.parse(newKm.toStringAsFixed(2)),
        queuedPointsCount: state.queuedPointsCount + 1,
      );
    });
  }
}
