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
import 'package:diamond_tracking/features/tracking/application/tracker_control.dart';
import 'package:diamond_tracking/features/tracking/application/tracker_providers.dart';
import 'package:diamond_tracking/features/tracking/domain/tracking_session.dart';
import 'package:diamond_tracking/features/visits/application/visits_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../support/fakes.dart';

void main() {
  DateTime ist(int h, [int m = 0]) => Ist.instantAt(2026, 11, 20, h, m);

  late FakeDutyRepository repo;
  late FakeTrackerControl tracker;
  late FixedClock time;
  late FakeVisitsRepository visits;

  setUp(() {
    visits = FakeVisitsRepository();
    repo = FakeDutyRepository()..dutyOnTime = ist(7);
    tracker = FakeTrackerControl();
    time = FixedClock(ist(7));
  });

  Future<void> pumpHome(WidgetTester tester) async {
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
        ],
        child: MaterialApp(theme: AppTheme.light, home: const HomePage()),
      ),
    );
    await tester.pumpAndSettle();
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
    expect(find.text('Ready to start'), findsOneWidget);

    await tester.tap(find.text('Duty on'));
    await tester.pumpAndSettle();

    expect(repo.calls, contains('dutyOn'));
    expect(tracker.calls, contains('start:100'));
    expect(tracker.stored?.pass, 'pass-100');
    expect(tracker.stored?.autoOffAt, ist(23));
    expect(find.text('On duty'), findsOneWidget);
    expect(find.text('Since 7:00 AM'), findsOneWidget);
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
    expect(find.text('Before duty on'), findsOneWidget);
    expect(repo.calls, isNot(contains('dutyOn')));

    // Battery saver is optional; the other two are needed.
    await tester.tap(find.text('Allow').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Allow').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
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
    expect(find.text('Duty on is closed for today'), findsOneWidget);
    expect(find.text('Duty on'), findsNothing);
  });

  testWidgets('when the admin allowed it, duty on works after 8:30 AM', (
    WidgetTester tester,
  ) async {
    repo.allowed = true;
    time.at = ist(18);
    repo.dutyOnTime = ist(18);
    await pumpHome(tester);
    expect(find.text('Duty on is closed for today'), findsNothing);
    expect(find.textContaining('The admin allowed you'), findsOneWidget);
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
      expect(find.text('Duty on is closed for today'), findsOneWidget);
      expect(find.text('Duty on'), findsNothing);
      // The permission is only looked up when duty on is closed.
      time.at = ist(7);
      repo.calls.clear();
      await pumpHome(tester);
      expect(repo.calls, isNot(contains('dutyOnAllowed')));
    },
  );

  test('permission ends at 11:00 PM', () {
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
    expect(
      home.phaseAt(DateTime.utc(2026, 11, 20, 17, 29)),
      DutyPhase.allowedByAdmin,
    );
    expect(
      home.phaseAt(DateTime.utc(2026, 11, 20, 17, 31)),
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
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Ready to start'), findsOneWidget);
  });

  testWidgets('a short duty off warns, then says not eligible', (
    WidgetTester tester,
  ) async {
    repo.today = onDuty();
    tracker.stored = sessionFor(repo.today!);
    time.at = ist(15);
    await pumpHome(tester);
    expect(find.text('8 h 00 min'), findsOneWidget);

    await tester.tap(find.text('Duty off'));
    await tester.pumpAndSettle();
    expect(find.textContaining('less than 10 hours'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Duty off'));
    await tester.pumpAndSettle();

    expect(find.text('Not eligible for attendance'), findsOneWidget);
    expect(tracker.calls, contains('dutyOff:true'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('Waiting for admin'), findsOneWidget);
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
    expect(find.textContaining('less than 10 hours'), findsNothing);
    await tester.tap(find.widgetWithText(TextButton, 'Duty off'));
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
    await tester.tap(find.widgetWithText(TextButton, 'Duty off'));
    await tester.pumpAndSettle();

    expect(tracker.calls, contains('dutyOff:false'));
    expect(find.text('Duty off saved'), findsOneWidget);
    expect(find.text('No internet connection'), findsOneWidget);
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
}
