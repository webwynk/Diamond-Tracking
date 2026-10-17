import 'package:diamond_tracking/core/errors/app_exceptions.dart';
import 'package:diamond_tracking/core/services/tracker_engine.dart';
import 'package:diamond_tracking/core/utils/duty_time_helper.dart';
import 'package:diamond_tracking/domain/entities/duty_session.dart';
import 'package:diamond_tracking/domain/entities/location_point.dart';
import 'package:diamond_tracking/domain/entities/user_profile.dart';
import 'package:diamond_tracking/features/auth/presentation/controllers/auth_controller.dart';
import 'package:diamond_tracking/features/auth/presentation/controllers/auth_state.dart';
import 'package:diamond_tracking/features/duty/presentation/controllers/duty_controller.dart';
import 'package:diamond_tracking/features/duty/presentation/controllers/duty_state.dart';
import 'package:diamond_tracking/features/onboarding/presentation/controllers/permission_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_duty.dart';
import 'support/fake_permission_service.dart';

class _SignedInAuth extends AuthNotifier {
  _SignedInAuth(this._state);
  final AuthState _state;

  @override
  AuthState build() => _state;
}

UserProfile _employee() => UserProfile(
  id: 'e1',
  role: UserRole.employee,
  status: UserStatus.active,
  fullName: 'Ramesh Kumar',
  mustChangePin: false,
  failedLoginAttempts: 0,
  createdAt: DateTime.utc(2026, 10, 1),
  updatedAt: DateTime.utc(2026, 10, 1),
  employeeCode: 'DA-014',
);

LocationPoint _point(double lat, int seconds) => LocationPoint(
  id: 'p-$seconds',
  sessionId: 'session_mock_1',
  latitude: lat,
  longitude: 73.0,
  accuracy: 5,
  speed: 5,
  recordedAt: DateTime.utc(2026, 10, 17, 4, 30).add(Duration(seconds: seconds)),
);

void main() {
  late FakeDutyRepository repository;
  late FakeTrackingService tracking;
  late FakePermissionService permissions;
  late FakeUploader uploader;

  setUp(() {
    // 10:00 IST: inside the 08:00-23:00 window.
    DutyTimeHelper.debugNow = DateTime.utc(2026, 10, 17, 4, 30);
    repository = FakeDutyRepository();
    tracking = FakeTrackingService();
    permissions = FakePermissionService();
    uploader = FakeUploader(log: repository.calls);
  });

  tearDown(() => DutyTimeHelper.debugNow = null);

  /// What was sent to the server, without the uploader's own entries.
  List<String> serverCalls() =>
      repository.calls.where((c) => !c.startsWith('uploader.')).toList();

  Future<ProviderContainer> buildContainer({AuthState? auth}) async {
    final container = ProviderContainer(
      overrides: [
        dutyRepositoryProvider.overrideWithValue(repository),
        trackingServiceProvider.overrideWithValue(tracking),
        permissionServiceProvider.overrideWithValue(permissions),
        trackingUploaderProvider.overrideWithValue(uploader),
        authControllerProvider.overrideWith(
          () => _SignedInAuth(auth ?? AuthAuthenticated(_employee())),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.read(dutyControllerProvider); // build and start the first refresh
    await Future<void>.delayed(Duration.zero);
    return container;
  }

  DutyScreenState stateOf(ProviderContainer c) =>
      c.read(dutyControllerProvider);
  DutyNotifier notifierOf(ProviderContainer c) =>
      c.read(dutyControllerProvider.notifier);

  group('starting duty (PRD F3)', () {
    test(
      'missing permissions block the start before any session is created',
      () async {
        permissions.backgroundGranted = false;
        final container = await buildContainer();

        final started = await notifierOf(container).startDuty();

        expect(started, isFalse);
        expect(stateOf(container).status, DutyStatus.offDuty);
        expect(
          stateOf(container).startBlocker,
          DutyStartBlocker.permissionsMissing,
        );
        expect(serverCalls(), isEmpty);
        expect(tracking.isTracking, isFalse);
      },
    );

    test('the battery exemption is required too', () async {
      permissions.batteryIgnored = false;
      final container = await buildContainer();

      await notifierOf(container).startDuty();

      expect(
        stateOf(container).startBlocker,
        DutyStartBlocker.permissionsMissing,
      );
      expect(serverCalls(), isEmpty);
    });

    test(
      'location switched off is reported separately and creates no session',
      () async {
        permissions.locationEnabled = false;
        final container = await buildContainer();

        await notifierOf(container).startDuty();

        expect(
          stateOf(container).startBlocker,
          DutyStartBlocker.locationServicesOff,
        );
        expect(stateOf(container).errorMessage, contains('Location'));
        expect(serverCalls(), isEmpty);
      },
    );

    test(
      'no internet: duty stays off, with a message, and no tracker runs',
      () async {
        repository.startError = const NetworkException();
        final container = await buildContainer();

        final started = await notifierOf(container).startDuty();

        expect(started, isFalse);
        expect(stateOf(container).status, DutyStatus.offDuty);
        expect(stateOf(container).activeSession, isNull);
        expect(stateOf(container).errorMessage, isNotNull);
        expect(tracking.isTracking, isFalse);
      },
    );

    test(
      'a tracker that cannot start closes the session it just opened',
      () async {
        tracking.startResult = false;
        final container = await buildContainer();

        final started = await notifierOf(container).startDuty();

        expect(started, isFalse);
        expect(serverCalls(), <String>[
          'startDutySession',
          'getServerTime',
          'endDutySession',
        ]);
        expect(stateOf(container).status, DutyStatus.offDuty);
        expect(stateOf(container).errorMessage, contains('GPS'));
      },
    );

    test(
      'nobody signed in: no session is created for a made-up employee',
      () async {
        final container = await buildContainer(
          auth: const AuthUnauthenticated(),
        );

        final started = await notifierOf(container).startDuty();

        expect(started, isFalse);
        expect(serverCalls(), isEmpty);
        expect(stateOf(container).errorMessage, isNotNull);
      },
    );

    test('a double tap starts one session', () async {
      final container = await buildContainer();
      final notifier = notifierOf(container);

      final results = await Future.wait([
        notifier.startDuty(),
        notifier.startDuty(),
      ]);

      expect(results.where((r) => r).length, 1);
      expect(serverCalls().where((c) => c == 'startDutySession').length, 1);
    });
  });

  group('while on duty', () {
    test(
      'distance comes from the recorded points, not a fixed step per point',
      () async {
        final container = await buildContainer();
        await notifierOf(container).startDuty();

        tracking
          ..emitPoint(_point(20.000, 0))
          ..emitPoint(_point(20.001, 60))
          ..emitPoint(_point(20.002, 120));
        await Future<void>.delayed(Duration.zero);

        expect(stateOf(container).distanceKm, closeTo(0.22, 0.01));
        expect(stateOf(container).queuedPointsCount, 3);
        expect(stateOf(container).lastLocation?.latitude, 20.002);
      },
    );

    test('a stationary employee does not accumulate distance', () async {
      final container = await buildContainer();
      await notifierOf(container).startDuty();

      tracking
        ..emitPoint(_point(20.0, 0))
        ..emitPoint(_point(20.0, 180))
        ..emitPoint(_point(20.0, 360));
      await Future<void>.delayed(Duration.zero);

      expect(stateOf(container).distanceKm, 0.0);
    });
  });

  group('continuing a duty after the phone stopped tracking', () {
    DutySession openOnServer({
      Duration startedAgo = const Duration(hours: 2),
    }) => DutySession(
      id: 'existing',
      employeeId: 'e1',
      startedAt: DateTime.now().toUtc().subtract(startedAgo),
    );

    test(
      'the server has a duty open but nothing tracks here: it says so and offers to continue',
      () async {
        repository.mockActiveSession = openOnServer();

        final container = await buildContainer();

        expect(stateOf(container).status, DutyStatus.offDuty);
        expect(stateOf(container).errorMessage, contains('Start duty'));
        expect(tracking.isTracking, isFalse);
      },
    );

    test(
      'starting again continues the SAME duty, with its real start time',
      () async {
        repository.mockActiveSession = openOnServer();
        final container = await buildContainer();

        final started = await notifierOf(container).startDuty();

        expect(started, isTrue);
        expect(stateOf(container).activeSession?.id, 'existing');
        expect(tracking.startedWith?.sessionId, 'existing');
        expect(
          stateOf(container).elapsedDuration,
          greaterThan(const Duration(hours: 1, minutes: 59)),
          reason: 'the duty did not restart from zero',
        );
      },
    );

    test('a running tracker is re-attached when the app opens', () async {
      repository.mockActiveSession = openOnServer();
      tracking.tracking = true;

      final container = await buildContainer();

      expect(stateOf(container).status, DutyStatus.onDuty);
      expect(stateOf(container).activeSession?.id, 'existing');
    });

    test(
      'a tracker still running after the server closed the duty is stopped',
      () async {
        repository.mockActiveSession = null;
        tracking.tracking = true;

        final container = await buildContainer();

        expect(stateOf(container).status, DutyStatus.offDuty);
        expect(tracking.isTracking, isFalse);
      },
    );

    test(
      'when the tracker stops by itself the screen follows the server',
      () async {
        final container = await buildContainer();
        await notifierOf(container).startDuty();
        expect(stateOf(container).status, DutyStatus.onDuty);

        // The server closed the duty (for example the employee was blocked).
        repository.mockActiveSession = null;
        tracking.emitStop(TrackerStopReason.sessionClosedByServer);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(stateOf(container).status, DutyStatus.offDuty);
      },
    );
  });

  group('server clock', () {
    test(
      'the tracker is told the real start and how far the phone clock is off',
      () async {
        repository.serverClockAhead = const Duration(minutes: 10);
        final container = await buildContainer();

        await notifierOf(container).startDuty();

        final started = tracking.startedWith!;
        expect(started.employeeId, 'e1');
        expect(started.sessionId, 'session_mock_1');
        expect(
          started.clockOffset.inSeconds,
          inInclusiveRange(9 * 60 + 55, 10 * 60 + 5),
        );
      },
    );

    test('with an accurate phone clock the offset is about zero', () async {
      final container = await buildContainer();

      await notifierOf(container).startDuty();

      expect(tracking.startedWith!.clockOffset.inSeconds.abs(), lessThan(5));
    });
  });

  group('uploading points', () {
    test(
      'off duty the screen uploads leftovers; on duty the background tracker takes over',
      () async {
        final container = await buildContainer();
        expect(
          uploader.isRunning,
          isTrue,
          reason: 'nothing tracks, so the screen sends what is waiting',
        );

        await notifierOf(container).startDuty();
        expect(
          uploader.isRunning,
          isFalse,
          reason: 'the tracker uploads from its own service now',
        );

        await notifierOf(container).endDuty();
        expect(
          uploader.isRunning,
          isTrue,
          reason: 'anything still waiting keeps going out',
        );
      },
    );

    test(
      'with a tracker already running, the screen does not upload too',
      () async {
        tracking.tracking = true;
        repository.mockActiveSession = DutySession(
          id: 'existing',
          employeeId: 'e1',
          startedAt: DateTime.now().toUtc().subtract(const Duration(hours: 1)),
        );

        await buildContainer();

        expect(uploader.isRunning, isFalse);
      },
    );

    test(
      'the latest points are sent BEFORE the server is told duty ended',
      () async {
        final container = await buildContainer();
        final notifier = notifierOf(container);
        await notifier.startDuty();
        repository.calls.clear();

        await notifier.endDuty();

        expect(repository.calls.take(2), <String>[
          'uploader.flush',
          'endDutySession',
        ]);
      },
    );

    test('points that could not be sent are counted for the summary', () async {
      final container = await buildContainer();
      final notifier = notifierOf(container);
      await notifier.startDuty();
      tracking.queuedCount = 7;

      await notifier.endDuty();

      expect(stateOf(container).queuedPointsCount, 7);
    });

    test('an expired sign-in is explained, and nothing is lost', () async {
      final container = await buildContainer();
      await notifierOf(container).startDuty();

      tracking.emitNotice(TrackerNotice.needsSignIn);
      await Future<void>.delayed(Duration.zero);

      expect(stateOf(container).errorMessage, contains('Sign in again'));
      expect(stateOf(container).errorMessage, contains('Nothing is lost'));
    });
  });

  group('signing out', () {
    test('while on duty it is refused: end duty first', () async {
      final container = await buildContainer();
      await notifierOf(container).startDuty();

      final check = await notifierOf(container).checkBeforeSignOut();

      expect(check.onDuty, isTrue);
      expect(tracking.localDataCleared, isFalse);
    });

    test(
      'off duty it tries to send what is waiting, then reports what is left',
      () async {
        final container = await buildContainer();
        tracking.queuedCount = 4;

        final check = await notifierOf(container).checkBeforeSignOut();

        expect(uploader.calls, contains('uploader.flush'));
        expect(check.onDuty, isFalse);
        expect(check.unsyncedPoints, 4);
      },
    );

    test('with nothing waiting it is clean', () async {
      final container = await buildContainer();

      final check = await notifierOf(container).checkBeforeSignOut();

      expect(check.onDuty, isFalse);
      expect(check.unsyncedPoints, 0);
    });

    test('clearing wipes the phone and stops uploading', () async {
      final container = await buildContainer();
      tracking.queuedCount = 3;

      await notifierOf(container).clearLocalTrackingData();

      expect(tracking.localDataCleared, isTrue);
      expect(tracking.queuedCount, 0);
      expect(uploader.isRunning, isFalse);
    });
  });

  group('ending duty', () {
    test(
      'success stops the tracker and clears the session and last location',
      () async {
        final container = await buildContainer();
        final notifier = notifierOf(container);
        await notifier.startDuty();
        tracking.emitPoint(_point(20.0, 0));
        await Future<void>.delayed(Duration.zero);

        final ended = await notifier.endDuty();

        expect(ended?.endedAt, isNotNull);
        expect(tracking.isTracking, isFalse);
        expect(stateOf(container).status, DutyStatus.offDuty);
        expect(stateOf(container).activeSession, isNull);
        expect(stateOf(container).lastLocation, isNull);
      },
    );

    test('no internet: still on duty, still tracking, and told why', () async {
      final container = await buildContainer();
      final notifier = notifierOf(container);
      await notifier.startDuty();
      repository.endError = const NetworkException();

      final ended = await notifier.endDuty();

      expect(ended, isNull);
      expect(stateOf(container).status, DutyStatus.onDuty);
      expect(stateOf(container).activeSession, isNotNull);
      expect(tracking.isTracking, isTrue);
      expect(stateOf(container).errorMessage, contains('internet'));
    });

    test('ending when nothing is open does nothing', () async {
      final container = await buildContainer();

      expect(await notifierOf(container).endDuty(), isNull);
      expect(serverCalls(), isEmpty);
    });
  });

  group('refresh', () {
    test(
      'a failed status check shows the error instead of pretending all is well',
      () async {
        repository.readError = const NetworkException();

        final container = await buildContainer();

        expect(stateOf(container).errorMessage, isNotNull);
        expect(stateOf(container).isLoading, isFalse);
      },
    );
  });
}
