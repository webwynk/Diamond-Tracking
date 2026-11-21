import 'dart:io';

import 'package:diamond_tracking/core/time/clock_providers.dart';
import 'package:diamond_tracking/features/auth/domain/auth_status.dart';
import 'package:diamond_tracking/features/duty/application/duty_providers.dart';
import 'package:diamond_tracking/features/duty/domain/duty_day.dart';
import 'package:diamond_tracking/features/requests/application/requests_providers.dart';
import 'package:diamond_tracking/features/requests/data/requests_repository.dart';
import 'package:diamond_tracking/features/requests/domain/app_request.dart';
import 'package:diamond_tracking/features/requests/domain/request_failure.dart';
import 'package:diamond_tracking/features/requests/presentation/admin_requests_page.dart';
import 'package:diamond_tracking/features/requests/presentation/attendance_request_page.dart';
import 'package:diamond_tracking/features/requests/presentation/leave_request_page.dart';
import 'package:diamond_tracking/features/requests/presentation/my_requests_page.dart';
import 'package:diamond_tracking/features/requests/presentation/request_detail_page.dart';
import 'package:diamond_tracking/features/users/domain/profile.dart';
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
  }) => AppRequest(
    id: id,
    userId: 'u',
    kind: RequestKind.attendance,
    status: status,
    createdAt: DateTime.utc(2026, 11, 20, 5),
    day: DateTime.utc(2026, 11, 19),
    dutyOnAt: DateTime.utc(2026, 11, 19, 3, 30),
    dutyOffAt: DateTime.utc(2026, 11, 19, 13, 30),
    message: 'Forgot to duty on',
    hasPhoto: true,
  );

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

  testWidgets('attendance request: checks, uploads the photo, sends', (
    WidgetTester tester,
  ) async {
    tall(tester);
    await pumpPushed(
      tester,
      const AttendanceRequestPage(),
      status: employee,
      overrides: overrides(),
    );
    expect(find.text('20 Nov 2026'), findsOneWidget);

    await tester.tap(find.text('Send request'));
    await tester.pumpAndSettle();
    expect(find.text('Pick the duty on and duty off times.'), findsOneWidget);

    await pickTime(tester, 'Duty on'); // 9:00 AM
    await pickTime(tester, 'Duty off'); // 7:00 PM
    expect(find.text('9:00 AM'), findsOneWidget);
    expect(find.text('7:00 PM'), findsOneWidget);
    await tester.tap(find.text('Send request'));
    await tester.pumpAndSettle();
    expect(find.text('Write a message.'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Phone battery died');
    await tester.tap(find.text('Send request'));
    await tester.pumpAndSettle();
    expect(find.text('Add a photo.'), findsOneWidget);
    expect(repo.uploads, 0);

    await tester.tap(find.text('Camera'));
    await tester.pumpAndSettle();
    expect(picker.picks.single.name, 'camera');
    await tester.ensureVisible(find.text('Send request'));
    await tester.tap(find.text('Send request'));
    await tester.pumpAndSettle();

    expect(repo.uploads, 1);
    expect(
      repo.calls.single,
      startsWith('attendance:2026-11-20:540-1140:Phone battery died:req-'),
    );
    expect(find.text('below'), findsOneWidget);
    expect(find.text('Request sent. The admin will decide.'), findsOneWidget);
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
    await pickTime(tester, 'Duty on');
    await pickTime(tester, 'Duty off');
    await tester.enterText(find.byType(TextField), 'x');
    await tester.tap(find.text('Gallery'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Send request'));
    await tester.tap(find.text('Send request'));
    await tester.pumpAndSettle();
    expect(find.text(RequestFailure.alreadyHasDuty.message), findsOneWidget);
    expect(find.byType(AttendanceRequestPage), findsOneWidget);
  });

  testWidgets('leave request needs dates and a message', (
    WidgetTester tester,
  ) async {
    tall(tester);
    await pumpPushed(
      tester,
      const LeaveRequestPage(),
      status: employee,
      overrides: overrides(),
    );
    expect(find.text('Casual leave'), findsOneWidget);
    await tester.tap(find.text('Sick leave'));
    await tester.ensureVisible(find.text('Send request'));
    await tester.tap(find.text('Send request'));
    await tester.pumpAndSettle();
    expect(find.text('Add the leave dates.'), findsOneWidget);
    expect(repo.calls, isEmpty);
  });

  testWidgets('my requests list opens a request', (WidgetTester tester) async {
    repo.requests.add(attendance());
    repo.requests.add(
      AppRequest(
        id: 6,
        userId: 'u',
        kind: RequestKind.shortDuty,
        status: RequestStatus.pending,
        createdAt: DateTime.utc(2026, 11, 20, 5),
        day: DateTime.utc(2026, 11, 18),
      ),
    );
    await pumpPage(
      tester,
      const MyRequestsPage(),
      status: employee,
      overrides: overrides(),
    );
    expect(find.text('Attendance · 19 Nov 2026'), findsOneWidget);
    expect(find.text('Waiting'), findsOneWidget);
    // Short-duty reviews are the admin's, not the employee's requests.
    expect(find.textContaining('Short duty'), findsNothing);
    await tester.tap(find.text('Attendance · 19 Nov 2026'));
    await tester.pumpAndSettle();
    expect(find.text('route /home/requests/5'), findsOneWidget);
  });

  testWidgets('the employee cancels a waiting request', (
    WidgetTester tester,
  ) async {
    repo.requests.add(attendance());
    await pumpPage(
      tester,
      const RequestDetailPage(requestId: 5, admin: false),
      status: employee,
      overrides: overrides(),
    );
    expect(find.text('Forgot to duty on'), findsOneWidget);
    expect(find.textContaining('9:00 AM to 7:00 PM'), findsOneWidget);
    expect(find.text('Present'), findsNothing);

    await tester.ensureVisible(find.text('Cancel request'));
    await tester.tap(find.text('Cancel request'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Cancel request'));
    await tester.pumpAndSettle();
    expect(repo.calls, <String>['cancel:5']);
    expect(find.text('Cancelled'), findsWidgets);
    expect(find.text('Cancel request'), findsNothing);
  });

  testWidgets('the admin approves as half day with a note', (
    WidgetTester tester,
  ) async {
    tall(tester);
    repo.requests.add(attendance());
    await pumpPage(
      tester,
      const RequestDetailPage(requestId: 5, admin: true),
      users: FakeUsersRepository(<Profile>[profile('u', name: 'Asha Roy')]),
      overrides: overrides(),
    );
    expect(find.text('Asha Roy'), findsOneWidget);
    expect(find.text('Cancel request'), findsNothing);
    await tester.enterText(find.byType(TextField), 'Next time do duty on');
    await tester.ensureVisible(find.text('Half day'));
    await tester.tap(find.text('Half day'));
    await tester.pumpAndSettle();
    expect(repo.calls, <String>['decide:5:half_day:Next time do duty on']);
    expect(find.text('Approved: Half day'), findsOneWidget);
    expect(find.text('Next time do duty on'), findsOneWidget);
  });

  testWidgets('a short duty shows the worked time and links the route', (
    WidgetTester tester,
  ) async {
    repo.requests.add(
      AppRequest(
        id: 7,
        userId: 'u',
        kind: RequestKind.shortDuty,
        status: RequestStatus.pending,
        createdAt: DateTime.utc(2026, 11, 20, 5),
        day: DateTime.utc(2026, 11, 20),
      ),
    );
    final FakeDutyRepository duty = FakeDutyRepository(
      today: DutyDay(
        id: 42,
        day: DateTime.utc(2026, 11, 20),
        status: DayStatus.pending,
        dutyOnAt: DateTime.utc(2026, 11, 20, 1, 30),
        dutyOffAt: DateTime.utc(2026, 11, 20, 8),
        workedMinutes: 390,
      ),
    );
    await pumpPage(
      tester,
      const RequestDetailPage(requestId: 7, admin: true),
      overrides: overrides(duty: duty),
    );
    expect(find.textContaining('6 h 30 min'), findsOneWidget);
    for (final String b in <String>['Present', 'Half day', 'Absent']) {
      expect(find.text(b), findsOneWidget);
    }
    await tester.tap(find.text('View route'));
    await tester.pumpAndSettle();
    expect(find.text('route /admin/days/42'), findsOneWidget);
  });

  testWidgets('the admin list shows names, waiting and all', (
    WidgetTester tester,
  ) async {
    repo.requests
      ..add(attendance())
      ..add(attendance(id: 8, status: RequestStatus.approved));
    await pumpPage(
      tester,
      const AdminRequestsPage(),
      users: FakeUsersRepository(<Profile>[profile('u', name: 'Asha Roy')]),
      overrides: overrides(),
    );
    expect(find.text('Asha Roy'), findsOneWidget);
    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();
    expect(find.text('Asha Roy'), findsNWidgets(2));
    await tester.tap(find.text('Approved'));
    await tester.pumpAndSettle();
    expect(find.text('route /admin/requests/8'), findsOneWidget);
  });

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
    await pickTime(tester, 'Duty on');
    await pickTime(tester, 'Duty off');
    await tester.enterText(find.byType(TextField), 'x');
    await tester.tap(find.text('Gallery'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Send request'));
    await tester.tap(find.text('Send request'));
    await tester.pumpAndSettle();
    expect(repo.uploads, 1);
    expect(repo.calls, isEmpty);

    repo.sendError = null;
    await tester.tap(find.text('Send request'));
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
      const RequestDetailPage(requestId: 5, admin: false),
      status: employee,
      overrides: overrides(),
    );
    expect(find.text('Photo removed after 90 days.'), findsOneWidget);
    expect(find.text('The photo could not be loaded.'), findsNothing);
  });

  testWidgets('long lists show more on request (L70)', (
    WidgetTester tester,
  ) async {
    tall(tester);
    for (int i = 0; i < requestPageSize + 5; i++) {
      repo.requests.add(attendance(id: 1000 + i));
    }
    await pumpPage(
      tester,
      const MyRequestsPage(),
      status: employee,
      overrides: overrides(),
    );
    final Finder more = find.text('Show more');
    await tester.scrollUntilVisible(more, 500);
    expect(find.text('Attendance · 19 Nov 2026'), findsWidgets);
    await tester.tap(more);
    await tester.pumpAndSettle();
    expect(find.text('Show more'), findsNothing);
  });

  testWidgets('when names cannot load, the admin list says so (L71)', (
    WidgetTester tester,
  ) async {
    repo.requests.add(attendance());
    final FakeUsersRepository users = FakeUsersRepository(<Profile>[
      profile('u', name: 'Asha Roy'),
    ])..listError = const SocketException('offline');
    await pumpPage(
      tester,
      const AdminRequestsPage(),
      users: users,
      overrides: overrides(),
    );
    expect(find.text('Names could not load'), findsOneWidget);
    expect(find.text('Unknown'), findsNothing);
    users.listError = null;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Names could not load'), findsNothing);
    expect(find.text('Asha Roy'), findsOneWidget);
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
