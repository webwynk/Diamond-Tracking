import 'dart:io';

import 'package:diamond_tracking/core/links/open_link.dart';
import 'package:diamond_tracking/core/time/clock_providers.dart';
import 'package:diamond_tracking/features/auth/domain/auth_status.dart';
import 'package:diamond_tracking/features/duty/application/duty_providers.dart';
import 'package:diamond_tracking/features/duty/domain/duty_day.dart';
import 'package:diamond_tracking/features/requests/application/requests_providers.dart';
import 'package:diamond_tracking/features/requests/data/photo_picker.dart';
import 'package:diamond_tracking/features/requests/domain/app_request.dart';
import 'package:diamond_tracking/features/requests/domain/request_failure.dart';
import 'package:diamond_tracking/features/requests/presentation/admin_requests_page.dart';
import 'package:diamond_tracking/features/requests/presentation/attendance_request_page.dart';
import 'package:diamond_tracking/features/requests/presentation/leave_request_page.dart';
import 'package:diamond_tracking/features/requests/presentation/my_request_detail_page.dart';
import 'package:diamond_tracking/features/requests/presentation/my_requests_page.dart';
import 'package:diamond_tracking/features/requests/presentation/request_detail_page.dart';
import 'package:diamond_tracking/features/routes/application/route_providers.dart';
import 'package:diamond_tracking/features/users/domain/profile.dart';
import 'package:diamond_tracking/shared/ds/ds_button.dart';
import 'package:diamond_tracking/shared/ds/ds_chips.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../support/fakes.dart';
import '../../support/pump.dart';

void main() {
  // 21:30 IST on 20 Nov 2026.
  final DateTime now = DateTime.utc(2026, 11, 20, 16);
  const SignedIn employee = SignedIn(
    userId: 'u',
    role: AppRole.employee,
    mustChangePassword: false,
  );

  late FakeRequestsRepository repo;
  late FakePhotoPicker picker;
  setUp(() {
    repo = FakeRequestsRepository();
    picker = FakePhotoPicker();
  });

  List<Override> overrides({FakeDutyRepository? duty}) => <Override>[
    requestsRepositoryProvider.overrideWithValue(repo),
    photoPickerProvider.overrideWithValue(picker),
    serverClockProvider.overrideWithValue(FixedClock(now).clock),
    if (duty != null) dutyRepositoryProvider.overrideWithValue(duty),
  ];

  AppRequest attendance({
    int id = 5,
    RequestStatus status = RequestStatus.pending,
    DateTime? createdAt,
  }) => AppRequest(
    id: id,
    userId: 'u',
    kind: RequestKind.attendance,
    status: status,
    createdAt: createdAt ?? DateTime.utc(2026, 11, 20, 5),
    day: DateTime.utc(2026, 11, 19),
    dutyOnAt: DateTime.utc(2026, 11, 19, 3, 30),
    dutyOffAt: DateTime.utc(2026, 11, 19, 13, 30),
    message: 'Forgot to duty on',
    hasPhoto: true,
  );

  /// A card title as shown: the date part never breaks.
  String cardTitle(String t) {
    final int i = t.indexOf('· ') + 2;
    return t.substring(0, i) + t.substring(i).replaceAll(' ', '\u00A0');
  }

  /// A tall screen, so whole forms are built and tappable.
  void tall(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
  }

  Future<void> pickTime(WidgetTester tester, String tile) async {
    await tester.tap(find.text(tile));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
  }

  Finder button(String label) =>
      find.widgetWithText(DsButton, label, skipOffstage: false);

  testWidgets('attendance request: says what is missing, sends 2 photos', (
    WidgetTester tester,
  ) async {
    tall(tester);
    await pumpPushed(
      tester,
      const AttendanceRequestPage(),
      status: employee,
      overrides: overrides(),
    );
    expect(find.text('Friday, 20 Nov'), findsOneWidget);
    expect(button('Pick the duty times'), findsOneWidget);

    await pickTime(tester, 'DUTY ON'); // 9:00 AM
    await pickTime(tester, 'DUTY OFF'); // 7:00 PM
    expect(find.text('9:00 AM'), findsOneWidget);
    expect(find.text('7:00 PM'), findsOneWidget);
    expect(find.text('10h 00m'), findsOneWidget);
    expect(find.text('Full day'), findsOneWidget);
    expect(button('Write a message to send'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Phone battery died');
    await tester.pump();
    expect(button('Add a photo to send'), findsOneWidget);
    expect(repo.uploads, 0);

    await tester.tap(find.text('Take photo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('From gallery'));
    await tester.pumpAndSettle();
    expect(picker.picks.map((PhotoFrom f) => f.name), <String>[
      'camera',
      'gallery',
    ]);
    expect(find.text('Up to 3 photos · 2 added'), findsOneWidget);
    await tester.tap(button('Send request'));
    await tester.pumpAndSettle();

    expect(repo.uploads, 2);
    expect(
      repo.calls.single,
      matches(
        RegExp(
          r'^attendance:2026-11-20:540-1140:Phone battery died:req-\S+\+req-\S+$',
        ),
      ),
    );
    expect(find.text('below'), findsOneWidget);
    expect(find.text('Request sent. The admin will decide.'), findsOneWidget);
  });

  testWidgets('attendance: days with a duty or a request are faded', (
    WidgetTester tester,
  ) async {
    tall(tester);
    final FakeRouteRepository routes = FakeRouteRepository()
      ..days[1] = DutyDay(
        id: 1,
        day: DateTime.utc(2026, 11, 20),
        status: DayStatus.onDuty,
        dutyOnAt: DateTime.utc(2026, 11, 20, 3),
        userId: 'u',
      );
    repo.requests.add(attendance()); // waiting, for 19 Nov
    await pumpPushed(
      tester,
      const AttendanceRequestPage(),
      status: employee,
      overrides: <Override>[
        ...overrides(),
        routeRepositoryProvider.overrideWithValue(routes),
      ],
    );
    // Today and 19 Nov can't be asked for: 18 Nov is picked.
    expect(find.text('Wednesday, 18 Nov'), findsOneWidget);
    expect(
      find.text('Faded days already have a duty or a request.'),
      findsOneWidget,
    );
    await tester.tap(find.text('19'));
    await tester.pumpAndSettle();
    expect(find.text('Wednesday, 18 Nov'), findsOneWidget);
    await tester.tap(find.text('17'));
    await tester.pumpAndSettle();
    expect(find.text('Tuesday, 17 Nov'), findsOneWidget);
  });

  testWidgets('a server refusal shows its reason and keeps the form', (
    WidgetTester tester,
  ) async {
    tall(tester);
    repo.error = const PostgrestException(message: 'already_has_duty');
    await pumpPushed(
      tester,
      const AttendanceRequestPage(),
      status: employee,
      overrides: overrides(),
    );
    await pickTime(tester, 'DUTY ON');
    await pickTime(tester, 'DUTY OFF');
    await tester.enterText(find.byType(TextField), 'x');
    await tester.tap(find.text('From gallery'));
    await tester.pumpAndSettle();
    await tester.tap(button('Send request'));
    await tester.pumpAndSettle();
    expect(find.text(RequestFailure.alreadyHasDuty.message), findsOneWidget);
    expect(find.byType(AttendanceRequestPage), findsOneWidget);
  });

  for (final double width in <double>[360, 390, 430]) {
    testWidgets('attendance request fits a $width wide phone', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = Size(width * 3, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await pumpPushed(
        tester,
        const AttendanceRequestPage(),
        status: employee,
        overrides: overrides(),
      );
      await pickTime(tester, 'DUTY ON');
      await pickTime(tester, 'DUTY OFF');
      for (int i = 0; i < 3; i++) {
        await Scrollable.ensureVisible(
          tester.element(find.text('From gallery')),
          alignment: 0.5,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('From gallery'));
        await tester.pumpAndSettle();
      }
      expect(find.text('3 photos added, the most allowed'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('leave request: type, days, reason, note photos', (
    WidgetTester tester,
  ) async {
    tall(tester);
    await pumpPushed(
      tester,
      const LeaveRequestPage(),
      status: employee,
      overrides: overrides(),
    );
    expect(find.text('November 2026'), findsOneWidget);
    expect(button('Pick the type of leave'), findsOneWidget);
    await tester.tap(find.text('Sick leave'));
    await tester.pump();
    expect(button('Pick the days'), findsOneWidget);
    // 12 Nov is more than 7 days back: can't be picked.
    await tester.tap(find.text('12'));
    await tester.pump();
    expect(find.text('0 days'), findsOneWidget);
    for (final String d in <String>['24', '25', '26']) {
      await tester.tap(find.text(d));
    }
    await tester.tap(find.text('25'));
    await tester.pump();
    expect(find.text('2 days'), findsOneWidget);
    expect(button('Write the reason to send'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Fever');
    await tester.pump();

    await tester.tap(find.text('Attach'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('From gallery'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add more'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Take photo'));
    await tester.pumpAndSettle();
    expect(find.text('Up to 3 photos · 2 added'), findsOneWidget);

    await tester.tap(button('Send request · 2 days'));
    await tester.pumpAndSettle();
    expect(
      repo.calls.single,
      matches(
        RegExp(r'^leave:sick:2026-11-24,2026-11-26:Fever:req-\S+\+req-\S+$'),
      ),
    );
    expect(find.text('Leave request sent.'), findsOneWidget);
  });

  testWidgets('leave: days with a waiting request are faded', (
    WidgetTester tester,
  ) async {
    tall(tester);
    repo.requests.add(attendance()); // waiting, for 19 Nov
    await pumpPushed(
      tester,
      const LeaveRequestPage(),
      status: employee,
      overrides: overrides(),
    );
    await tester.tap(find.text('Casual leave'));
    await tester.tap(find.text('19'));
    await tester.pump();
    expect(find.text('0 days'), findsOneWidget);
    await tester.tap(find.text('20'));
    await tester.pump();
    expect(find.text('1 day'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Next month'));
    await tester.pumpAndSettle();
    expect(find.text('December 2026'), findsOneWidget);
  });

  for (final double width in <double>[360, 390, 430]) {
    testWidgets('leave request fits a $width wide phone', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = Size(width * 3, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await pumpPushed(
        tester,
        const LeaveRequestPage(),
        status: employee,
        overrides: overrides(),
      );
      await tester.tap(find.text('Casual leave'));
      await tester.tap(find.text('24'));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('my requests: short duty with hours, filters with counts', (
    WidgetTester tester,
  ) async {
    tall(tester);
    repo.requests
      ..add(attendance())
      ..add(
        AppRequest(
          id: 6,
          userId: 'u',
          kind: RequestKind.shortDuty,
          status: RequestStatus.pending,
          createdAt: DateTime.utc(2026, 11, 20, 13),
          day: DateTime.utc(2026, 11, 20),
        ),
      )
      ..add(
        AppRequest(
          id: 7,
          userId: 'u',
          kind: RequestKind.leave,
          status: RequestStatus.approved,
          createdAt: DateTime.utc(2026, 11, 12, 5),
          leaveType: LeaveType.casual,
          dates: <DateTime>[
            DateTime.utc(2026, 11, 24),
            DateTime.utc(2026, 11, 26),
          ],
          decision: DayStatus.leave,
        ),
      )
      ..add(
        AppRequest(
          id: 8,
          userId: 'u',
          kind: RequestKind.attendance,
          status: RequestStatus.rejected,
          createdAt: DateTime.utc(2026, 10, 28, 5),
          day: DateTime.utc(2026, 10, 28),
          decisionNote: 'No photo of work.',
        ),
      )
      // Older than 90 days: not listed.
      ..add(attendance(id: 9, createdAt: DateTime.utc(2026, 8, 1)));
    final FakeDutyRepository duty = FakeDutyRepository(
      today: DutyDay(
        id: 40,
        day: DateTime.utc(2026, 11, 20),
        status: DayStatus.pending,
        dutyOnAt: DateTime.utc(2026, 11, 20, 3, 30),
        dutyOffAt: DateTime.utc(2026, 11, 20, 11, 10),
        workedMinutes: 460,
      ),
    );
    await pumpPage(
      tester,
      const MyRequestsPage(),
      status: employee,
      overrides: overrides(duty: duty),
    );
    expect(find.text(cardTitle('Short duty · Fri, 20 Nov')), findsOneWidget);
    expect(find.text('7h 40m worked · sent by the app'), findsOneWidget);
    expect(find.text(cardTitle('Attendance · 19 Nov')), findsOneWidget);
    expect(find.text(cardTitle('Casual leave · 24 – 26 Nov')), findsOneWidget);
    expect(find.text('2 days · sent 12 Nov'), findsOneWidget);
    expect(find.text(cardTitle('Attendance · 28 Oct')), findsOneWidget);
    expect(find.textContaining('No photo of work.'), findsOneWidget);
    expect(find.text('Admin reviewing'), findsNWidgets(2));
    expect(find.byType(MyRequestCard), findsNWidgets(4));

    await tester.tap(find.widgetWithText(DsFilterChip, 'Waiting'));
    await tester.pumpAndSettle();
    expect(find.byType(MyRequestCard), findsNWidgets(2));
    // Test text is wider than real text, so the chips scroll.
    await tester.ensureVisible(find.widgetWithText(DsFilterChip, 'Rejected'));
    await tester.tap(find.widgetWithText(DsFilterChip, 'Rejected'));
    await tester.pumpAndSettle();
    expect(find.byType(MyRequestCard), findsOneWidget);

    await tester.tap(find.text(cardTitle('Attendance · 28 Oct')));
    await tester.pumpAndSettle();
    expect(find.text('route /home/requests/8'), findsOneWidget);
  });

  testWidgets('my requests tiles open the two forms', (
    WidgetTester tester,
  ) async {
    await pumpPage(
      tester,
      const MyRequestsPage(),
      status: employee,
      overrides: overrides(),
    );
    expect(find.text('No requests yet'), findsOneWidget);
    await tester.tap(find.text('Leave'));
    await tester.pumpAndSettle();
    expect(find.text('route /home/requests/leave'), findsOneWidget);
  });

  for (final double width in <double>[360, 390, 430]) {
    testWidgets('my requests fits a $width wide phone', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = Size(width * 3, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      repo.requests
        ..add(attendance())
        ..add(
          AppRequest(
            id: 8,
            userId: 'u',
            kind: RequestKind.attendance,
            status: RequestStatus.approved,
            createdAt: DateTime.utc(2026, 11, 6, 5),
            day: DateTime.utc(2026, 11, 6),
            decision: DayStatus.halfDay,
            decisionNote: 'Approved as half day because the photo was late.',
          ),
        );
      await pumpPage(
        tester,
        const MyRequestsPage(),
        status: employee,
        overrides: overrides(),
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the employee sees progress and cancels a waiting request', (
    WidgetTester tester,
  ) async {
    tall(tester);
    repo.requests.add(attendance());
    await pumpPage(
      tester,
      const MyRequestDetailPage(requestId: 5),
      status: employee,
      overrides: overrides(),
    );
    expect(find.text('Attendance'), findsOneWidget);
    expect(find.text('Thu, 19 Nov'), findsOneWidget);
    expect(find.text('Forgot to duty on'), findsOneWidget);
    expect(find.text('9:00 AM – 7:00 PM'), findsOneWidget);
    expect(find.text('With admin'), findsOneWidget);
    expect(find.text("You'll get a notification"), findsOneWidget);

    await tester.tap(button('Cancel request'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yes, cancel it'));
    await tester.pumpAndSettle();
    expect(repo.calls, <String>['cancel:5']);
    expect(find.text('Cancelled'), findsWidgets);
    expect(button('Cancel request'), findsNothing);
  });

  testWidgets('a decided leave shows the decision, note and every photo', (
    WidgetTester tester,
  ) async {
    tall(tester);
    repo.requests.add(
      AppRequest(
        id: 9,
        userId: 'u',
        kind: RequestKind.leave,
        status: RequestStatus.rejected,
        createdAt: DateTime.utc(2026, 11, 18, 5),
        leaveType: LeaveType.sick,
        dates: <DateTime>[
          DateTime.utc(2026, 11, 24),
          DateTime.utc(2026, 11, 25),
          DateTime.utc(2026, 11, 26),
        ],
        message: 'Fever',
        hasPhoto: true,
        extraPhotos: 1,
        decision: DayStatus.absent,
        decisionNote: 'Too many days.',
        decidedAt: DateTime.utc(2026, 11, 19, 6),
      ),
    );
    await pumpPage(
      tester,
      const MyRequestDetailPage(requestId: 9),
      status: employee,
      overrides: overrides(),
    );
    expect(find.text('Sick leave'), findsOneWidget);
    expect(find.text('Tue 24 – Thu 26 Nov · 3 days'), findsOneWidget);
    expect(find.text('Rejected'), findsWidgets);
    expect(find.textContaining('Too many days.'), findsOneWidget);
    expect(find.text('Photo 1 of 2'), findsOneWidget);
    expect(find.text('Photo 2 of 2'), findsOneWidget);
    expect(button('Cancel request'), findsNothing);
  });

  for (final double width in <double>[360, 390, 430]) {
    testWidgets('request detail fits a $width wide phone', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = Size(width * 3, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      repo.requests.add(attendance());
      await pumpPage(
        tester,
        const MyRequestDetailPage(requestId: 5),
        status: employee,
        overrides: overrides(),
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('a retry sends the photo already uploaded (L68)', (
    WidgetTester tester,
  ) async {
    tall(tester);
    repo.sendError = const SocketException('offline');
    await pumpPushed(
      tester,
      const AttendanceRequestPage(),
      status: employee,
      overrides: overrides(),
    );
    await pickTime(tester, 'DUTY ON');
    await pickTime(tester, 'DUTY OFF');
    await tester.enterText(find.byType(TextField), 'x');
    await tester.tap(find.text('From gallery'));
    await tester.pumpAndSettle();
    await tester.tap(button('Send request'));
    await tester.pumpAndSettle();
    expect(repo.uploads, 1);
    expect(repo.calls, isEmpty);

    repo.sendError = null;
    await tester.tap(button('Send request'));
    await tester.pumpAndSettle();
    expect(repo.uploads, 1, reason: 'not uploaded again');
    expect(
      repo.calls.single,
      contains('req-00000000-0000-0000-0000-000000000500'),
    );
  });

  testWidgets('a photo removed after 90 days says so (L69)', (
    WidgetTester tester,
  ) async {
    repo.requests.add(
      AppRequest.fromRow(<String, dynamic>{
        'id': 5,
        'user_id': 'u',
        'kind': 'attendance',
        'status': 'approved',
        'day': '2026-08-01',
        'message': 'm',
        'photo_id': 'req-x',
        'photo_removed_at': '2026-11-01T00:00:00Z',
        'created_at': '2026-08-01T05:00:00Z',
      }),
    );
    await pumpPage(
      tester,
      const MyRequestDetailPage(requestId: 5),
      status: employee,
      overrides: overrides(),
    );
    expect(find.text('Photo removed after 90 days.'), findsOneWidget);
    expect(find.text('The photo could not be loaded.'), findsNothing);
  });

  group('admin', () {
    late FakeRouteRepository routes;
    setUp(() => routes = FakeRouteRepository());
    List<Override> admin({FakeDutyRepository? duty}) => <Override>[
      ...overrides(duty: duty),
      routeRepositoryProvider.overrideWithValue(routes),
    ];
    FakeUsersRepository asha() => FakeUsersRepository(<Profile>[
      const Profile(
        id: 'u',
        userCode: 'EMP011',
        fullName: 'Asha Roy',
        role: AppRole.employee,
        isActive: true,
        phone: '9876543210',
      ),
    ]);
    AppRequest leave({int id = 9, RequestStatus s = RequestStatus.pending}) =>
        AppRequest(
          id: id,
          userId: 'u',
          kind: RequestKind.leave,
          status: s,
          createdAt: DateTime.utc(2026, 11, 20, 2),
          leaveType: LeaveType.sick,
          dates: <DateTime>[
            DateTime.utc(2026, 11, 24),
            DateTime.utc(2026, 11, 25),
            DateTime.utc(2026, 11, 26),
          ],
          message: 'Fever',
          hasPhoto: true,
          extraPhotos: 1,
        );
    AppRequest short() => AppRequest(
      id: 7,
      userId: 'u',
      kind: RequestKind.shortDuty,
      status: RequestStatus.pending,
      createdAt: DateTime.utc(2026, 11, 20, 13),
      day: DateTime.utc(2026, 11, 20),
    );
    FakeDutyRepository shortDay() => FakeDutyRepository(
      today: DutyDay(
        id: 42,
        day: DateTime.utc(2026, 11, 20),
        status: DayStatus.pending,
        dutyOnAt: DateTime.utc(2026, 11, 20, 1, 30),
        dutyOffAt: DateTime.utc(2026, 11, 20, 8),
        workedMinutes: 390,
      ),
    );

    testWidgets('list: waiting count, kinds, cards, Decided', (
      WidgetTester tester,
    ) async {
      tall(tester);
      repo.requests
        ..add(attendance())
        ..add(short())
        ..add(leave())
        ..add(attendance(id: 8, status: RequestStatus.approved));
      await pumpPage(
        tester,
        const AdminRequestsPage(),
        users: asha(),
        overrides: admin(duty: shortDay()),
      );
      expect(find.text('3 waiting for you'), findsOneWidget);
      expect(find.bySemanticsLabel('All, 3'), findsOneWidget);
      expect(find.bySemanticsLabel('Short, 1'), findsOneWidget);
      expect(find.text('Asha Roy'), findsNothing, reason: 'name · time');
      expect(find.textContaining('Asha Roy'), findsNWidgets(3));
      expect(find.text('Attendance request'), findsOneWidget);
      expect(find.text('Sick leave'), findsOneWidget);
      expect(find.text('"Forgot to duty on"'), findsOneWidget);
      expect(find.textContaining('6h 30m'), findsOneWidget);
      expect(find.text('24 – 26 Nov · 3 days'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Leave, 1'));
      await tester.pumpAndSettle();
      expect(find.text('Attendance request'), findsNothing);
      expect(find.text('Sick leave'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Decided'));
      await tester.pumpAndSettle();
      expect(find.text('Sick leave'), findsNothing);
      await tester.tap(find.bySemanticsLabel('All, 1'));
      await tester.pumpAndSettle();
      expect(find.text('Approved'), findsOneWidget);
      await tester.tap(find.text('Attendance request'));
      await tester.pumpAndSettle();
      expect(find.text('route /admin/requests/8'), findsOneWidget);
    });

    testWidgets('list: quick Present, and Absent asks first', (
      WidgetTester tester,
    ) async {
      tall(tester);
      repo.requests
        ..add(short())
        ..add(leave());
      await pumpPage(
        tester,
        const AdminRequestsPage(),
        users: asha(),
        overrides: admin(duty: shortDay()),
      );
      await tester.tap(find.bySemanticsLabel('Absent'));
      await tester.pumpAndSettle();
      expect(find.text('Mark Asha Roy absent?'), findsOneWidget);
      await tester.tap(find.text('Go back'));
      await tester.pumpAndSettle();
      expect(repo.calls, isEmpty);

      await tester.tap(find.bySemanticsLabel('Present'));
      await tester.pumpAndSettle();
      expect(repo.calls, <String>['decide:7:present:']);
      expect(find.text('Saved: Present.'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Approve'));
      await tester.pumpAndSettle();
      expect(repo.calls.last, 'decide:9:leave:');
    });

    testWidgets('when names cannot load, the list says so (L71)', (
      WidgetTester tester,
    ) async {
      repo.requests.add(attendance());
      final FakeUsersRepository users = asha()
        ..listError = const SocketException('offline');
      await pumpPage(
        tester,
        const AdminRequestsPage(),
        users: users,
        overrides: admin(),
      );
      expect(find.text('Names could not load'), findsOneWidget);
      expect(find.textContaining('Unknown'), findsNothing);
      users.listError = null;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('Names could not load'), findsNothing);
      expect(find.textContaining('Asha Roy'), findsOneWidget);
    });

    testWidgets('detail: facts, last 30 days, half day with a note', (
      WidgetTester tester,
    ) async {
      tall(tester);
      repo.requests.add(attendance());
      routes.days[1] = DutyDay(
        id: 1,
        userId: 'u',
        day: DateTime.utc(2026, 11, 18),
        status: DayStatus.present,
      );
      final List<Uri> opened = <Uri>[];
      await pumpPage(
        tester,
        const RequestDetailPage(requestId: 5),
        users: asha(),
        overrides: <Override>[
          ...admin(),
          openLinkProvider.overrideWithValue((Uri uri) async {
            opened.add(uri);
            return true;
          }),
        ],
      );
      expect(find.text('Asha Roy'), findsOneWidget);
      expect(find.text('AR'), findsOneWidget);
      expect(find.text('Attendance request · EMP011'), findsOneWidget);
      expect(find.text('Thu, 19 Nov 2026'), findsOneWidget);
      expect(find.text('9:00 AM → 7:00 PM'), findsOneWidget);
      expect(find.text('10h 00m'), findsOneWidget);
      expect(find.text('✓ 10h met'), findsOneWidget);
      expect(find.text('Today, 10:30 AM'), findsOneWidget);
      expect(find.text('Forgot to duty on'), findsOneWidget);
      expect(find.text('1 / 1'), findsOneWidget);
      expect(find.text('1 present · 0 half · 0 absent'), findsOneWidget);
      expect(find.text('Confirm · Present'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Call Asha Roy'));
      await tester.pumpAndSettle();
      expect(opened.single.toString(), 'tel:9876543210');

      await tester.tap(find.bySemanticsLabel('Half day'));
      await tester.tap(find.bySemanticsLabel('Add note'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Next time do duty on');
      await tester.tap(find.text('Confirm · Half day'));
      await tester.pumpAndSettle();
      expect(repo.calls, <String>['decide:5:half_day:Next time do duty on']);
      expect(find.text('Approved: Half day'), findsOneWidget);
      expect(find.text('Note: Next time do duty on'), findsOneWidget);
      expect(find.text('Your decision'), findsNothing);
    });

    testWidgets('detail: a short duty shows the day and links the route', (
      WidgetTester tester,
    ) async {
      tall(tester);
      repo.requests.add(short());
      await pumpPage(
        tester,
        const RequestDetailPage(requestId: 7),
        users: asha(),
        overrides: admin(duty: shortDay()),
      );
      expect(find.text('7:00 AM → 1:30 PM'), findsOneWidget);
      expect(find.text('6h 30m'), findsOneWidget);
      expect(find.text('Under 10h'), findsOneWidget);
      for (final String b in <String>['Present', 'Half day', 'Absent']) {
        expect(find.bySemanticsLabel(b), findsOneWidget);
      }
      await tester.tap(find.text('View route'));
      await tester.pumpAndSettle();
      expect(find.text('route /admin/days/42'), findsOneWidget);
    });

    testWidgets('detail: leave days, two photos, approve', (
      WidgetTester tester,
    ) async {
      tall(tester);
      repo.requests.add(leave());
      await pumpPage(
        tester,
        const RequestDetailPage(requestId: 9),
        users: asha(),
        overrides: admin(),
      );
      expect(find.text('Sick leave · EMP011'), findsOneWidget);
      expect(find.text('24 – 26 Nov'), findsOneWidget);
      expect(find.text('3 days'), findsOneWidget);
      expect(
        find.text('Sent today, 7:30 AM · starts in 4 days'),
        findsOneWidget,
      );
      expect(find.text('1 / 2'), findsOneWidget);
      expect(find.text('Last 30 days'), findsNothing);
      expect(find.text('Approve 3 days sick leave'), findsOneWidget);
      expect(
        find.text(
          'The 3 days are marked as sick leave. Asha gets a notification.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.bySemanticsLabel('Next photo'));
      await tester.pumpAndSettle();
      expect(find.text('2 / 2'), findsOneWidget);

      await tester.tap(find.text('Approve 3 days sick leave'));
      await tester.pumpAndSettle();
      expect(repo.calls, <String>['decide:9:leave:']);
    });

    testWidgets('detail: going to the duty history', (
      WidgetTester tester,
    ) async {
      repo.requests.add(attendance());
      await pumpPage(
        tester,
        const RequestDetailPage(requestId: 5),
        users: asha(),
        overrides: admin(),
      );
      await tester.tap(find.bySemanticsLabel('Duty history'));
      await tester.pumpAndSettle();
      expect(find.text('route /admin/users/u/days'), findsOneWidget);
    });

    for (final double width in <double>[360, 390, 430]) {
      testWidgets('list and detail fit ${width.toInt()} wide', (
        WidgetTester tester,
      ) async {
        tester.view.physicalSize = Size(width * 3, 800 * 3);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);
        repo.requests
          ..add(attendance())
          ..add(short())
          ..add(leave());
        final FakeUsersRepository users = FakeUsersRepository(<Profile>[
          profile('u', name: 'Mohammad Hasanur Rahaman Chowdhury'),
        ]);
        await pumpPage(
          tester,
          const AdminRequestsPage(),
          users: users,
          overrides: admin(duty: shortDay()),
        );
        expect(tester.takeException(), isNull);
        for (final int id in <int>[5, 7, 9]) {
          await pumpPage(
            tester,
            RequestDetailPage(requestId: id),
            users: users,
            overrides: admin(duty: shortDay()),
          );
          expect(tester.takeException(), isNull, reason: 'request $id');
        }
      });
    }
  });

  test('request rows and error mapping', () {
    final AppRequest r = AppRequest.fromRow(<String, dynamic>{
      'id': 3,
      'user_id': 'u',
      'kind': 'leave',
      'status': 'approved',
      'leave_type': 'sick',
      'dates': <String>['2026-11-21', '2026-11-22'],
      'message': 'Fever',
      'photo_id': null,
      'decision': 'leave',
      'created_at': '2026-11-20T05:00:00+00:00',
    });
    expect(r.leaveType, LeaveType.sick);
    expect(r.dates.last, DateTime.utc(2026, 11, 22));
    expect(r.hasPhoto, isFalse);
    expect(r.cancellable, isFalse);
    expect(r.choices, <DayStatus>[DayStatus.leave, DayStatus.absent]);
    expect(decisionLabel(RequestKind.leave, DayStatus.leave), 'Approve');
    expect(
      mapRequestError(const PostgrestException(message: 'photo_required')),
      RequestFailure.photoRequired,
    );
    expect(
      mapRequestError(
        const FunctionException(
          status: 503,
          details: <String, String>{'error': 'photos_not_configured'},
        ),
      ),
      RequestFailure.photosNotReady,
    );
    expect(
      mapRequestError(const PostgrestException(message: 'day_has_duty')),
      RequestFailure.dayHasDuty,
    );
    expect(
      mapRequestError(const PostgrestException(message: 'note_too_long')),
      RequestFailure.noteTooLong,
    );
    expect(
      mapRequestError(const PostgrestException(message: 'signed_in_elsewhere')),
      RequestFailure.signedInElsewhere,
    );
    expect(
      mapRequestError(
        const FunctionException(
          status: 429,
          details: <String, String>{'error': 'photo_limit'},
        ),
      ),
      RequestFailure.photoLimit,
    );
    expect(mapRequestError(Exception('?')), RequestFailure.unknown);
  });
}
