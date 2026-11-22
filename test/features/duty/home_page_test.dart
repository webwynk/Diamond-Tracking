import 'dart:async';
import 'dart:io';

import 'package:diamond_tracking/core/supabase/supabase_providers.dart';
import 'package:diamond_tracking/core/theme/app_theme.dart';
import 'package:diamond_tracking/core/time/clock_providers.dart';
import 'package:diamond_tracking/core/time/ist.dart';
import 'package:diamond_tracking/features/auth/application/auth_providers.dart';
import 'package:diamond_tracking/features/auth/domain/auth_status.dart';
import 'package:diamond_tracking/features/duty/application/duty_providers.dart';
import 'package:diamond_tracking/features/duty/domain/duty_day.dart';
import 'package:diamond_tracking/features/duty/domain/duty_home.dart';
import 'package:diamond_tracking/features/duty/presentation/home_page.dart';
import 'package:diamond_tracking/features/requests/application/requests_providers.dart';
import 'package:diamond_tracking/features/requests/domain/app_request.dart';
import 'package:diamond_tracking/features/tracking/application/tracker_control.dart';
import 'package:diamond_tracking/features/tracking/application/tracker_providers.dart';
import 'package:diamond_tracking/features/tracking/domain/tracker_status.dart';
import 'package:diamond_tracking/features/tracking/domain/tracking_session.dart';
import 'package:diamond_tracking/features/tracking/presentation/duty_setup_page.dart';
import 'package:diamond_tracking/features/users/application/users_providers.dart';
import 'package:diamond_tracking/features/users/domain/profile.dart';
import 'package:diamond_tracking/features/visits/application/visits_providers.dart';
import 'package:diamond_tracking/features/visits/domain/visit.dart';
import 'package:diamond_tracking/shared/ds/ds_brand_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../support/fakes.dart';

void main() {
  DateTime ist(int h, [int m = 0]) => Ist.instantAt(2026, 11, 20, h, m);

  late FakeDutyRepository repo;
  late FakeTrackerControl tracker;
  late FixedClock time;
  late FakeVisitsRepository visits;
  late FakeUsersRepository users;
  late FakeRequestsRepository requests;

  setUp(() {
    visits = FakeVisitsRepository();
    users = FakeUsersRepository(<Profile>[profile('u1', name: 'Rahul Das')]);
    requests = FakeRequestsRepository();
    repo = FakeDutyRepository()..dutyOnTime = ist(7);
    tracker = FakeTrackerControl();
    time = FixedClock(ist(7));
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
  });

  Future<void> pumpHome(WidgetTester tester, {bool settle = true}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStatusStreamProvider.overrideWithValue(
            Stream<AuthStatus>.value(
              const SignedIn(
                userId: 'u1',
                role: AppRole.employee,
                mustChangePassword: false,
              ),
            ),
          ),
          dutyRepositoryProvider.overrideWithValue(repo),
          trackerControlProvider.overrideWithValue(tracker),
          serverClockProvider.overrideWithValue(time.clock),
          deviceIdStoreProvider.overrideWithValue(FakeDeviceIdStore()),
          visitsRepositoryProvider.overrideWithValue(visits),
          usersRepositoryProvider.overrideWithValue(users),
          requestsRepositoryProvider.overrideWithValue(requests),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const HomePage()),
      ),
    );
    if (settle) await tester.pumpAndSettle();
  }

  DutyDay onDuty() => DutyDay(
    id: 5,
    day: DateTime.utc(2026, 11, 20),
    status: DayStatus.onDuty,
    dutyOnAt: ist(7),
  );

  TrackingSession sessionFor(DutyDay d) => TrackingSession(
    dayId: d.id,
    pass: 'pass',
    dutyOnAt: d.dutyOnAt!,
    autoOffAt: ist(23),
  );

  testWidgets('duty on in the morning starts the tracker', (
    WidgetTester tester,
  ) async {
    await pumpHome(tester);
    expect(find.text('Ready to start?'), findsOneWidget);

    await tester.tap(find.text('Duty on'));
    await tester.pumpAndSettle();

    expect(repo.calls, contains('dutyOn'));
    expect(tracker.calls, contains('start:100'));
    expect(tracker.stored?.pass, 'pass-100');
    expect(tracker.stored?.autoOffAt, ist(23));
    expect(find.text('On duty'), findsOneWidget);
    expect(find.text('Started 7:00 AM'), findsOneWidget);
  });

  testWidgets('a quick double tap on duty on sends one request (L6)', (
    WidgetTester tester,
  ) async {
    await pumpHome(tester);
    // Two taps before the button can show its spinner.
    await tester.tap(find.text('Duty on'));
    await tester.tap(find.text('Duty on'));
    await tester.pumpAndSettle();

    expect(repo.calls.where((String c) => c == 'dutyOn'), hasLength(1));
    expect(tracker.calls.where((String c) => c.startsWith('start:')), <String>[
      'start:100',
    ]);
    expect(find.text('On duty'), findsOneWidget);
    expect(find.text('You have already done duty on today.'), findsNothing);
  });

  testWidgets('two duty on calls at once share one request (L6)', (
    WidgetTester tester,
  ) async {
    await pumpHome(tester);
    final ProviderContainer container = ProviderScope.containerOf(
      tester.element(find.byType(HomePage)),
    );
    final DutyHomeController c = container.read(dutyHomeProvider.notifier);
    final Future<void> first = c.dutyOn();
    final Future<void> second = c.dutyOn();
    await tester.pumpAndSettle();
    await expectLater(Future.wait(<Future<void>>[first, second]), completes);

    expect(repo.calls.where((String c) => c == 'dutyOn'), hasLength(1));
    expect(tracker.calls.where((String c) => c.startsWith('start:')), <String>[
      'start:100',
    ]);
  });

  testWidgets('missing permissions are asked for first', (
    WidgetTester tester,
  ) async {
    tracker.missing = <TrackerRequirement>[
      TrackerRequirement.locationPermission,
      TrackerRequirement.backgroundLocation,
      TrackerRequirement.batteryOptimization,
    ];
    await pumpHome(tester);
    await tester.tap(find.text('Duty on'));
    await tester.pumpAndSettle();
    expect(find.text('Get ready for duty'), findsOneWidget);
    expect(find.text('2 of 5 done'), findsOneWidget);
    expect(find.text('Allow 2 more to start'), findsOneWidget);
    expect(repo.calls, isNot(contains('dutyOn')));

    // Battery saver is optional; the other two are needed.
    await tester.tap(find.text('Allow').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Allow').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start duty'));
    await tester.pumpAndSettle();

    expect(tracker.calls.where((String c) => c != 'ensureRunning'), <String>[
      'request:locationPermission',
      'request:backgroundLocation',
      'start:100',
    ]);
    expect(find.text('On duty'), findsOneWidget);
  });

  testWidgets('after 8:30 AM duty on is closed', (WidgetTester tester) async {
    time.at = ist(9);
    await pumpHome(tester);
    expect(find.text('Duty on is closed'), findsOneWidget);
    expect(find.text('Duty on'), findsNothing);
  });

  testWidgets('when the admin allowed it, duty on works after 8:30 AM', (
    WidgetTester tester,
  ) async {
    repo.allowed = true;
    time.at = ist(18);
    repo.dutyOnTime = ist(18);
    await pumpHome(tester);
    expect(find.text('Duty on is closed'), findsNothing);
    expect(find.text('Allowed by your admin'), findsOneWidget);
    await tester.tap(find.text('Duty on'));
    await tester.pumpAndSettle();
    expect(tracker.calls, contains('start:100'));
    expect(find.text('On duty'), findsOneWidget);
  });

  testWidgets(
    'without permission duty on stays closed, and is only looked up then',
    (WidgetTester tester) async {
      time.at = ist(18);
      await pumpHome(tester);
      expect(find.text('Duty on is closed'), findsOneWidget);
      expect(find.text('Duty on'), findsNothing);
      // The permission is only looked up when duty on is closed.
      time.at = ist(7);
      repo.calls.clear();
      await pumpHome(tester);
      expect(repo.calls, isNot(contains('dutyOnAllowed')));
    },
  );

  test('permission ends at 9:00 PM (L28)', () {
    final DutyHome home = DutyHome(
      today: null,
      session: null,
      loadedAt: DateTime.utc(2026, 11, 20, 12),
      dutyOnAllowed: true,
    );
    expect(
      home.phaseAt(DateTime.utc(2026, 11, 20, 12)),
      DutyPhase.allowedByAdmin,
    );
    // 8:59 PM IST: still usable.
    expect(
      home.phaseAt(DateTime.utc(2026, 11, 20, 15, 29)),
      DutyPhase.allowedByAdmin,
    );
    // 9:00 PM and 10:50 PM IST: too late, a duty would end at 11:00 PM.
    expect(
      home.phaseAt(DateTime.utc(2026, 11, 20, 15, 30)),
      DutyPhase.windowClosed,
    );
    expect(
      home.phaseAt(DateTime.utc(2026, 11, 20, 17, 20)),
      DutyPhase.windowClosed,
    );
    // 3:30 AM IST, before the window.
    expect(
      home.phaseAt(DateTime.utc(2026, 11, 19, 22)),
      DutyPhase.allowedByAdmin,
    );
  });

  testWidgets('a refused duty on shows why', (WidgetTester tester) async {
    repo.dutyOnError = const PostgrestException(message: 'on_leave_today');
    await pumpHome(tester);
    await tester.tap(find.text('Duty on'));
    await tester.pumpAndSettle();
    expect(
      find.text('You are on leave today, so duty on is not allowed.'),
      findsOneWidget,
    );
    expect(tracker.calls, isNot(contains(startsWith('start'))));
  });

  testWidgets('a load error offers retry', (WidgetTester tester) async {
    repo.error = const PostgrestException(message: 'boom');
    await pumpHome(tester);
    repo.error = null;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Ready to start?'), findsOneWidget);
  });

  testWidgets('a short duty off warns, then waits for the admin', (
    WidgetTester tester,
  ) async {
    repo.today = onDuty();
    tracker.stored = sessionFor(repo.today!);
    time.at = ist(15);
    await pumpHome(tester);
    expect(find.text('8h 00m'), findsOneWidget);

    await tester.tap(find.text('Duty off'));
    await tester.pumpAndSettle();
    expect(find.text('End your duty?'), findsOneWidget);
    expect(find.text('2h 00m short'), findsOneWidget);
    expect(find.textContaining("Won't count for attendance"), findsOneWidget);
    await tester.tap(find.text('Yes, duty off'));
    await tester.pumpAndSettle();

    expect(
      find.text('Duty off done. The admin will decide your day.'),
      findsOneWidget,
    );
    expect(tracker.calls, contains('dutyOff:true'));
    expect(find.text('Waiting for admin'), findsOneWidget);
  });

  testWidgets('Keep working closes the sheet and duty stays on', (
    WidgetTester tester,
  ) async {
    repo.today = onDuty();
    tracker.stored = sessionFor(repo.today!);
    time.at = ist(15);
    await pumpHome(tester);
    await tester.tap(find.text('Duty off'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keep working'));
    await tester.pumpAndSettle();
    expect(find.text('End your duty?'), findsNothing);
    expect(tracker.calls, isNot(contains(startsWith('dutyOff'))));
    expect(find.text('Started 7:00 AM'), findsOneWidget);
  });

  testWidgets('a full day duty off just says done', (
    WidgetTester tester,
  ) async {
    repo.today = onDuty();
    tracker.stored = sessionFor(repo.today!);
    time.at = ist(18);
    await pumpHome(tester);
    await tester.tap(find.text('Duty off'));
    await tester.pumpAndSettle();
    expect(find.text('10 h done'), findsWidgets);
    expect(find.textContaining("Won't count for attendance"), findsNothing);
    await tester.tap(find.text('Yes, duty off'));
    await tester.pumpAndSettle();
    expect(find.text('Duty off done. Thank you.'), findsOneWidget);
    expect(find.text('Present'), findsOneWidget);
  });

  testWidgets('duty off without internet is saved for later', (
    WidgetTester tester,
  ) async {
    repo.today = onDuty();
    tracker.stored = sessionFor(repo.today!);
    time.at = ist(18);
    await pumpHome(tester);
    repo.error = const SocketException('offline');
    await tester.tap(find.text('Duty off'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yes, duty off'));
    await tester.pumpAndSettle();

    expect(tracker.calls, contains('dutyOff:false'));
    expect(find.text('Duty off saved'), findsOneWidget);
    expect(find.text("You're offline"), findsOneWidget);
  });

  testWidgets('duty on elsewhere: a lost session is resumed', (
    WidgetTester tester,
  ) async {
    repo.today = onDuty();
    time.at = ist(12);
    await pumpHome(tester);
    expect(repo.calls, contains('resume'));
    expect(tracker.stored?.pass, 'pass-resumed');
    expect(find.text('On duty'), findsOneWidget);
  });

  testWidgets('a pass refused after a password reset is replaced', (
    WidgetTester tester,
  ) async {
    repo.today = onDuty();
    tracker.stored = sessionFor(repo.today!);
    tracker.refused = true;
    time.at = ist(12);
    await pumpHome(tester);
    expect(repo.calls, contains('resume'));
    expect(tracker.stored?.pass, 'pass-resumed');
  });

  testWidgets('a working pass is left alone', (WidgetTester tester) async {
    repo.today = onDuty();
    tracker.stored = sessionFor(repo.today!);
    time.at = ist(12);
    await pumpHome(tester);
    expect(repo.calls, isNot(contains('resume')));
  });

  testWidgets('the tracker failing to start is shown', (
    WidgetTester tester,
  ) async {
    repo.today = onDuty();
    tracker.failStart = true;
    time.at = ist(12);
    await pumpHome(tester);
    expect(find.text('Route is not being recorded'), findsOneWidget);
  });

  testWidgets('a battery warning pops up', (WidgetTester tester) async {
    repo.today = onDuty();
    tracker.stored = sessionFor(repo.today!);
    time.at = ist(12);
    await pumpHome(tester);
    tracker.battery.add(15);
    await tester.pumpAndSettle();
    expect(find.text('Battery 15%'), findsOneWidget);
  });

  testWidgets('on leave shows sick leave', (WidgetTester tester) async {
    repo.today = DutyDay(
      id: 6,
      day: DateTime.utc(2026, 11, 20),
      status: DayStatus.leave,
      leaveType: LeaveType.sick,
    );
    time.at = ist(9);
    await pumpHome(tester);
    expect(find.text('On leave today'), findsOneWidget);
    expect(find.text('Sick leave · approved. Get well soon.'), findsOneWidget);
  });

  testWidgets('on duty shows km from the server and today\'s visits', (
    WidgetTester tester,
  ) async {
    repo.today = DutyDay(
      id: 5,
      day: DateTime.utc(2026, 11, 20),
      status: DayStatus.onDuty,
      dutyOnAt: ist(7, 12),
      distanceM: 38400,
    );
    tracker.stored = sessionFor(repo.today!);
    visits.byDay[5] = <Visit>[
      for (int i = 0; i < 3; i++)
        Visit(
          id: 'v$i',
          storeName: 'Store $i',
          fromGallery: true,
          capturedAt: ist(8 + i),
          hasPhoto: false,
        ),
    ];
    time.at = ist(11, 24);
    await pumpHome(tester);
    expect(find.text('4h 12m'), findsOneWidget);
    expect(find.text('5h 48m'), findsOneWidget);
    expect(find.text('42% of the day'), findsOneWidget);
    expect(find.text('Auto off 11:00 PM'), findsOneWidget);
    expect(find.text('38 km'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('duty on closed offers Request attendance', (
    WidgetTester tester,
  ) async {
    time.at = ist(10);
    await pumpHome(tester);
    expect(find.text('Request attendance'), findsOneWidget);
  });

  testWidgets('the header greets the employee by first name', (
    WidgetTester tester,
  ) async {
    await pumpHome(tester);
    expect(find.text('Hello, Rahul'), findsOneWidget);
    expect(find.text('Diamond Agritech'), findsOneWidget);
    expect(find.byType(DsBrandBar), findsOneWidget);
    expect(find.text('RD'), findsOneWidget);
    expect(find.text('Friday, 20 Nov'), findsOneWidget);
  });

  testWidgets('offline on duty shows the points waiting on the phone', (
    WidgetTester tester,
  ) async {
    repo.today = onDuty();
    tracker.stored = sessionFor(repo.today!);
    time.at = ist(12);
    await pumpHome(tester);
    expect(find.text("You're offline"), findsNothing);
    tracker.status.add(const TrackerStatus(pendingPoints: 214, offline: true));
    await tester.pumpAndSettle();
    expect(find.text("You're offline"), findsOneWidget);
    expect(find.textContaining('214 points waiting to upload'), findsOneWidget);
    tracker.status.add(const TrackerStatus());
    await tester.pumpAndSettle();
    expect(find.text("You're offline"), findsNothing);
  });

  testWidgets('location turned off on duty shows since when, and the fix', (
    WidgetTester tester,
  ) async {
    repo.today = onDuty();
    tracker.stored = sessionFor(repo.today!);
    time.at = ist(12);
    await pumpHome(tester);
    tracker.status.add(
      TrackerStatus(
        problem: TrackerProblem.locationOff,
        problemSince: ist(11, 5),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Tracking stopped'), findsOneWidget);
    expect(find.textContaining('since 11:05 AM'), findsOneWidget);
    await tester.tap(find.text('Turn on location'));
    await tester.pumpAndSettle();
    expect(tracker.calls, contains('request:locationService'));
  });

  testWidgets('tracker problems are not shown when not on duty', (
    WidgetTester tester,
  ) async {
    await pumpHome(tester);
    tracker.status.add(
      const TrackerStatus(problem: TrackerProblem.locationOff, offline: true),
    );
    await tester.pumpAndSettle();
    expect(find.text('Tracking stopped'), findsNothing);
    expect(find.text("You're offline"), findsNothing);
  });

  testWidgets('the Requests tile counts requests still waiting', (
    WidgetTester tester,
  ) async {
    AppRequest request(int id, RequestStatus status) => AppRequest(
      id: id,
      userId: 'u1',
      kind: RequestKind.leave,
      status: status,
      createdAt: DateTime.utc(2026, 11, 20, 2),
      day: DateTime.utc(2026, 11, 24),
    );
    requests.requests.addAll(<AppRequest>[
      request(1, RequestStatus.pending),
      request(2, RequestStatus.approved),
    ]);
    await pumpHome(tester);
    expect(find.bySemanticsLabel('Requests, 1 waiting'), findsOneWidget);
  });

  testWidgets('Add visit shows only on duty, with today\'s visits', (
    WidgetTester tester,
  ) async {
    await pumpHome(tester);
    expect(find.text('Add visit'), findsNothing);
    expect(find.text('My route'), findsOneWidget);
    repo.today = onDuty();
    tracker.stored = sessionFor(repo.today!);
    visits.byDay[5] = <Visit>[
      Visit(
        id: 'v1',
        storeName: 'Maa Tara Agro Store',
        fromGallery: true,
        capturedAt: ist(8, 12),
        hasPhoto: false,
      ),
    ];
    time.at = ist(12);
    await pumpHome(tester);
    expect(find.text('Add visit'), findsOneWidget);
    // Below the brand bar the list starts lower: bring the visits in.
    await tester.scrollUntilVisible(find.text('1 of the day'), 200);
    expect(find.text('1 of the day'), findsOneWidget);
    expect(find.text('Maa Tara Agro Store'), findsOneWidget);
    expect(find.text('8:12 AM · gallery photo, no place'), findsOneWidget);
  });

  testWidgets(
    'a silent server: the phone view and "No internet" show at once (L55)',
    (WidgetTester tester) async {
      repo.today = onDuty();
      tracker.stored = sessionFor(repo.today!);
      time.at = ist(9);
      final Completer<void> gate = repo.forDayGate = Completer<void>();
      await pumpHome(tester, settle: false);
      await tester.pump(DutyHomeController.showPhoneViewAfter);
      await tester.pump();
      expect(find.text("You're offline"), findsOneWidget);
      expect(find.text('On duty'), findsOneWidget);
      expect(find.text('Started 7:00 AM'), findsOneWidget);

      // The server answers: the banner goes.
      gate.complete();
      await tester.pumpAndSettle();
      expect(find.text("You're offline"), findsNothing);
      expect(find.text('On duty'), findsOneWidget);
    },
  );

  testWidgets('a server that never answers gives up after 10 seconds (L55)', (
    WidgetTester tester,
  ) async {
    repo.forDayGate = Completer<void>();
    await pumpHome(tester, settle: false);
    await tester.pump(DutyHomeController.showPhoneViewAfter);
    expect(find.text("You're offline"), findsOneWidget);
    await tester.pump(DutyHomeController.serverTimeout);
    await tester.pump();
    expect(find.text("You're offline"), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('a quick server answer shows no banner (L55)', (
    WidgetTester tester,
  ) async {
    await pumpHome(tester);
    expect(find.text("You're offline"), findsNothing);
    expect(find.text('Ready to start?'), findsOneWidget);
  });

  testWidgets('a failed reload after duty off shows no error (L54)', (
    WidgetTester tester,
  ) async {
    repo.today = onDuty();
    tracker.stored = sessionFor(repo.today!);
    time.at = ist(18);
    await pumpHome(tester);
    repo.forDayError = const PostgrestException(message: 'boom');
    await tester.tap(find.text('Duty off'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yes, duty off'));
    await tester.pumpAndSettle();
    expect(find.text('Duty off done. Thank you.'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
    expect(find.textContaining('went wrong'), findsNothing);
  });

  testWidgets('a failed reload after duty on shows no error (L54)', (
    WidgetTester tester,
  ) async {
    await pumpHome(tester);
    repo.forDayError = const PostgrestException(message: 'boom');
    await tester.tap(find.text('Duty on'));
    await tester.pumpAndSettle();
    expect(find.text('Duty on. Your route is being recorded.'), findsOneWidget);
    expect(find.text('On duty'), findsOneWidget);
    expect(find.textContaining('went wrong'), findsNothing);
  });

  group('the battery question (L52)', () {
    setUp(() {
      tracker.missing = <TrackerRequirement>[
        TrackerRequirement.batteryOptimization,
      ];
    });

    Future<int> asksAfterDutyOn(WidgetTester tester) async {
      await pumpHome(tester);
      await tester.tap(find.text('Duty on'));
      await tester.pumpAndSettle();
      expect(repo.calls, contains('dutyOn'));
      return tracker.calls
          .where((String c) => c == 'request:batteryOptimization')
          .length;
    }

    testWidgets('asked the first time', (WidgetTester tester) async {
      expect(await asksAfterDutyOn(tester), 1);
    });

    testWidgets('not asked again within a week', (WidgetTester tester) async {
      FlutterSecureStorage.setMockInitialValues(<String, String>{
        'battery_prompt_at': ist(7)
            .subtract(const Duration(days: 6))
            .toIso8601String(),
      });
      expect(await asksAfterDutyOn(tester), 0);
    });

    testWidgets('asked again after a week', (WidgetTester tester) async {
      FlutterSecureStorage.setMockInitialValues(<String, String>{
        'battery_prompt_at': ist(7)
            .subtract(const Duration(days: 7))
            .toIso8601String(),
      });
      expect(await asksAfterDutyOn(tester), 1);
    });
  });

  for (final double width in <double>[360, 390, 430]) {
    testWidgets('home, duty off sheet and setup fit a $width wide phone', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = Size(width * 3, 800 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      repo.today = DutyDay(
        id: 5,
        day: DateTime.utc(2026, 11, 20),
        status: DayStatus.onDuty,
        dutyOnAt: ist(7, 5),
        distanceM: 152000,
      );
      tracker.stored = sessionFor(repo.today!);
      time.at = ist(14, 45);
      await pumpHome(tester);
      tracker.status.add(
        TrackerStatus(
          pendingPoints: 1214,
          offline: true,
          problem: TrackerProblem.locationOff,
          problemSince: ist(11, 5),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Duty off'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Duty off'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Keep working'));
      await tester.pumpAndSettle();
      tracker.missing = List<TrackerRequirement>.of(TrackerRequirement.values);
      unawaited(showTrackingSetup(tester.element(find.byType(HomePage))));
      await tester.pumpAndSettle();
      expect(find.text('0 of 5 done'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
