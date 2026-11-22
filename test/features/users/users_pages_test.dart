import 'package:diamond_tracking/core/links/open_link.dart';
import 'package:diamond_tracking/core/time/clock_providers.dart';
import 'package:diamond_tracking/features/auth/domain/auth_failure.dart';
import 'package:diamond_tracking/features/auth/domain/auth_status.dart';
import 'package:diamond_tracking/features/duty/domain/duty_day.dart';
import 'package:diamond_tracking/features/requests/domain/app_request.dart';
import 'package:diamond_tracking/features/routes/application/route_providers.dart';
import 'package:diamond_tracking/features/routes/domain/geo_point.dart';
import 'package:diamond_tracking/features/routes/domain/live_position.dart';
import 'package:diamond_tracking/features/users/data/users_repository.dart';
import 'package:diamond_tracking/features/users/domain/profile.dart';
import 'package:diamond_tracking/features/users/presentation/employee_profile_page.dart';
import 'package:diamond_tracking/features/users/presentation/user_form_page.dart';
import 'package:diamond_tracking/features/users/presentation/users_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../support/fakes.dart';
import '../../support/pump.dart';

void main() {
  // 13:30 IST on 20 Nov 2026.
  final DateTime now = DateTime.utc(2026, 11, 20, 8);
  late FakeRouteRepository routes;
  setUp(() => routes = FakeRouteRepository());
  List<Override> today() => <Override>[
    routeRepositoryProvider.overrideWithValue(routes),
    serverClockProvider.overrideWithValue(FixedClock(now).clock),
  ];
  DutyDay day(
    int id,
    String user, {
    DayStatus status = DayStatus.onDuty,
    LeaveType? leave,
    bool duty = true,
  }) => DutyDay(
    id: id,
    userId: user,
    day: DateTime.utc(2026, 11, 20),
    status: status,
    leaveType: leave,
    dutyOnAt: duty ? DateTime.utc(2026, 11, 20, 1, 30) : null,
    dutyOffAt: duty && status != DayStatus.onDuty
        ? DateTime.utc(2026, 11, 20, 7)
        : null,
    workedMinutes: duty && status != DayStatus.onDuty ? 330 : null,
  );
  LivePosition at(int dayId, String user, int minutesAgo, {int? battery}) =>
      LivePosition(
        userId: user,
        dutyDayId: dayId,
        point: const GeoPoint(22.7, 88.5),
        recordedAt: now.subtract(Duration(minutes: minutesAgo)),
        battery: battery,
      );
  const Profile withPhone = Profile(
    id: '1',
    userCode: 'EMP001',
    fullName: 'Asha Roy',
    role: AppRole.employee,
    isActive: true,
    phone: '9876543210',
    hasPhoneSignedIn: true,
  );

  group('team', () {
    testWidgets('groups by today, tiles count and filter, search, roles', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      routes.days[1] = day(1, '1');
      routes.days[2] = day(2, '2');
      routes.days[3] = day(
        3,
        '3',
        status: DayStatus.leave,
        leave: LeaveType.casual,
        duty: false,
      );
      routes.days[4] = day(4, '4', status: DayStatus.present);
      routes.initialLive = <LivePosition>[at(1, '1', 1), at(2, '2', 12)];
      await pumpPage(
        tester,
        const UsersPage(),
        users: FakeUsersRepository(<Profile>[
          withPhone,
          profile('2', code: 'EMP002', name: 'Bimal Das'),
          profile('3', code: 'EMP003', name: 'Chitra Sen'),
          profile('4', code: 'EMP004', name: 'Dipa Paul'),
          profile('5', code: 'EMP005', name: 'Esha Ghosh'),
          profile('6', code: 'EMP006', name: 'Faruk Ali', active: false),
          profile('admin1', code: 'ADMIN01', name: 'Boss', role: AppRole.admin),
        ]),
        overrides: today(),
      );
      expect(find.text('7 people · 6 staff, 1 admin'), findsOneWidget);
      expect(find.bySemanticsLabel('On duty, 2'), findsOneWidget);
      expect(find.bySemanticsLabel('No update, 1'), findsOneWidget);
      expect(find.bySemanticsLabel('On leave, 1'), findsOneWidget);
      expect(find.bySemanticsLabel('Not started, 1'), findsOneWidget);
      for (final String g in <String>[
        'Needs attention',
        'On duty',
        'Finished',
        'On leave',
        'Not started',
        'Admins',
        'Account off',
      ]) {
        expect(find.text(g), findsWidgets, reason: g);
      }
      expect(find.text('Live · since 7:00 AM'), findsOneWidget);
      expect(find.text('No update · 12 min'), findsOneWidget);
      expect(find.text('Casual leave today'), findsOneWidget);
      expect(find.text('Duty off 12:30 PM'), findsOneWidget);
      expect(find.text('No duty on yet'), findsOneWidget);
      expect(find.text('You'), findsOneWidget);
      expect(find.text('ADMIN'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('On leave, 1'));
      await tester.pumpAndSettle();
      expect(find.text('Chitra Sen'), findsOneWidget);
      expect(find.text('Asha Roy'), findsNothing);
      await tester.tap(find.bySemanticsLabel('On leave, 1'));
      await tester.pumpAndSettle();
      expect(find.text('Asha Roy'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Admin'));
      await tester.pumpAndSettle();
      expect(find.text('Boss'), findsOneWidget);
      expect(find.text('Asha Roy'), findsNothing);
      await tester.tap(find.bySemanticsLabel('All'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'emp005');
      await tester.pump();
      expect(find.text('Esha Ghosh'), findsOneWidget);
      expect(find.text('Asha Roy'), findsNothing);
      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pump();
      expect(find.text('No match'), findsOneWidget);
    });

    testWidgets('a person opens their profile; Call dials', (
      WidgetTester tester,
    ) async {
      final List<Uri> opened = <Uri>[];
      await pumpPage(
        tester,
        const UsersPage(),
        users: FakeUsersRepository(<Profile>[withPhone]),
        overrides: <Override>[
          ...today(),
          openLinkProvider.overrideWithValue((Uri uri) async {
            opened.add(uri);
            return true;
          }),
        ],
      );
      await tester.tap(find.bySemanticsLabel('Call Asha Roy'));
      await tester.pumpAndSettle();
      expect(opened.single.toString(), 'tel:9876543210');
      await tester.tap(find.text('Asha Roy'));
      await tester.pumpAndSettle();
      expect(find.text('route /admin/users/1'), findsOneWidget);
    });

    testWidgets('Add user opens the form', (WidgetTester tester) async {
      await pumpPage(tester, const UsersPage(), overrides: today());
      expect(find.text('No users yet'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Add user'));
      await tester.pumpAndSettle();
      expect(find.text('route /admin/users/new'), findsOneWidget);
    });

    for (final double width in <double>[360, 390, 430]) {
      testWidgets('team fits ${width.toInt()} wide', (
        WidgetTester tester,
      ) async {
        tester.view.physicalSize = Size(width * 3, 800 * 3);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);
        routes.days[1] = day(1, '1');
        routes.initialLive = <LivePosition>[at(1, '1', 30)];
        await pumpPage(
          tester,
          const UsersPage(),
          users: FakeUsersRepository(<Profile>[
            const Profile(
              id: '1',
              userCode: 'EMP0123456',
              fullName: 'Mohammad Hasanur Rahaman Chowdhury',
              role: AppRole.employee,
              isActive: true,
              phone: '9876543210',
            ),
            profile(
              'admin1',
              code: 'ADMIN01',
              name: 'Boss',
              role: AppRole.admin,
            ),
          ]),
          overrides: today(),
        );
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('employee profile', () {
    Future<FakeUsersRepository> open(
      WidgetTester tester, {
      Profile user = withPhone,
      bool tall = true,
    }) async {
      if (tall) {
        tester.view.physicalSize = const Size(1080, 4400);
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.reset);
      }
      final FakeUsersRepository users = FakeUsersRepository(<Profile>[user]);
      await pumpPage(
        tester,
        EmployeeProfilePage(userId: user.id),
        users: users,
        overrides: today(),
      );
      return users;
    }

    testWidgets('who, today, this month and the quick buttons', (
      WidgetTester tester,
    ) async {
      routes.days[1] = day(1, '1');
      routes.days[9] = DutyDay(
        id: 9,
        userId: '1',
        day: DateTime.utc(2026, 11, 18),
        status: DayStatus.halfDay,
      );
      routes.initialLive = <LivePosition>[at(1, '1', 1, battery: 55)];
      await open(tester);
      expect(find.text('Asha Roy'), findsOneWidget);
      expect(find.text('AR'), findsOneWidget);
      expect(find.text('EMP001 · Employee'), findsOneWidget);
      expect(find.text('Live · since 7:00 AM'), findsOneWidget);
      expect(find.bySemanticsLabel('On duty 6h 30m'), findsOneWidget);
      expect(find.bySemanticsLabel('Battery 55%'), findsOneWidget);
      expect(find.text('November'), findsOneWidget);
      expect(find.text('0.5'), findsOneWidget);
      expect(find.text('Signed in on one phone'), findsOneWidget);
      expect(find.text('Not added'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Route'));
      await tester.pumpAndSettle();
      expect(find.text('route /admin/days/1'), findsOneWidget);
    });

    testWidgets('History, Full history and Edit open their pages', (
      WidgetTester tester,
    ) async {
      await open(tester);
      // Not on duty today: no live map or route.
      expect(find.text('No duty on yet today.'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Live map'));
      await tester.pumpAndSettle();
      expect(find.textContaining('route /'), findsNothing);

      await tester.tap(find.bySemanticsLabel('History'));
      await tester.pumpAndSettle();
      expect(find.text('route /admin/users/1/days'), findsOneWidget);
    });

    testWidgets('Edit details opens the form', (WidgetTester tester) async {
      await open(tester);
      await tester.tap(find.text('Edit details'));
      await tester.pumpAndSettle();
      expect(find.text('route /admin/users/1/edit'), findsOneWidget);
    });

    testWidgets('release phone frees a lost phone (M6)', (
      WidgetTester tester,
    ) async {
      final FakeUsersRepository users = await open(tester);
      await tester.tap(find.text('Release phone'));
      await tester.pumpAndSettle();
      expect(find.text("Release Asha Roy's phone?"), findsOneWidget);
      await tester.tap(find.text('Release phone').last);
      await tester.pumpAndSettle();
      expect(users.calls, <String>['releasePhone:u1'.replaceAll('u1', '1')]);
      expect(
        find.text('Phone released. Asha Roy can log in on another phone.'),
        findsOneWidget,
      );
    });

    testWidgets('reset password shows a new PIN', (WidgetTester tester) async {
      final FakeUsersRepository users = await open(tester);
      await tester.tap(find.bySemanticsLabel(RegExp('^Reset password')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reset password').last);
      await tester.pumpAndSettle();
      expect(users.calls.single, startsWith('resetPin:1:'));
      expect(find.text('Password reset'), findsOneWidget);
    });

    testWidgets('turning the account off asks first', (
      WidgetTester tester,
    ) async {
      final FakeUsersRepository users = await open(tester);
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(find.text('Turn off Asha Roy?'), findsOneWidget);
      await tester.tap(find.text('Keep it on'));
      await tester.pumpAndSettle();
      expect(users.calls, isEmpty);
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Turn off'));
      await tester.pumpAndSettle();
      expect(users.calls, <String>['update:1:Asha Roy:false']);
    });

    testWidgets('allow late duty on with a note, then take it back', (
      WidgetTester tester,
    ) async {
      final FakeUsersRepository users = await open(tester);
      expect(find.text('Today only, until 9:00 PM'), findsOneWidget);
      await tester.tap(find.text('Allow'));
      await tester.pumpAndSettle();
      expect(find.text('Allow duty on for Asha Roy?'), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, 'Late start');
      await tester.tap(find.text('Allow').last);
      await tester.pumpAndSettle();
      expect(users.calls, contains('allowDutyOn:1:Late start'));
      expect(
        find.text('Allowed for today, until 9:00 PM. Not used yet.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Take back'));
      await tester.pumpAndSettle();
      expect(users.calls, contains('revokeDutyOn:1'));
    });

    testWidgets('a refused permit says why', (WidgetTester tester) async {
      final FakeUsersRepository users = await open(tester);
      users.failWith = const PostgrestException(
        message: 'day_already_recorded',
      );
      await tester.tap(find.text('Allow'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Allow').last);
      await tester.pumpAndSettle();
      expect(find.textContaining('already has a record for today'), findsOne);
    });

    testWidgets('no late duty on when today is recorded', (
      WidgetTester tester,
    ) async {
      routes.days[1] = day(1, '1', status: DayStatus.present);
      await open(tester);
      expect(
        find.text('Not needed, today is already recorded'),
        findsOneWidget,
      );
      expect(find.text('Allow'), findsNothing);
    });

    testWidgets('an admin sees only the account, not their own switch', (
      WidgetTester tester,
    ) async {
      await open(
        tester,
        user: profile(
          'admin1',
          code: 'ADMIN01',
          name: 'Boss',
          role: AppRole.admin,
        ),
      );
      expect(find.text('Today'), findsNothing);
      expect(find.byType(Switch), findsNothing);
      expect(find.text('Reset password'), findsNothing);
      expect(find.text('Allow late duty on'), findsNothing);
    });

    for (final double width in <double>[360, 390, 430]) {
      testWidgets('profile fits ${width.toInt()} wide', (
        WidgetTester tester,
      ) async {
        tester.view.physicalSize = Size(width * 3, 800 * 3);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);
        routes.days[1] = day(1, '1');
        routes.initialLive = <LivePosition>[at(1, '1', 1, battery: 9)];
        await open(
          tester,
          tall: false,
          user: const Profile(
            id: '1',
            userCode: 'EMP0123456',
            fullName: 'Mohammad Hasanur Rahaman Chowdhury',
            role: AppRole.employee,
            isActive: true,
            phone: '9876543210',
            contactEmail: 'a.very.long.email.address@example.com',
            hasPhoneSignedIn: true,
          ),
        );
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('add user', () {
    Finder input(int i) => find.byType(TextField).at(i);

    testWidgets('creates the user and shows the PIN once', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 3600);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final FakeUsersRepository users = FakeUsersRepository(<Profile>[
        profile('1', code: 'EMP001', name: 'Asha Roy'),
      ]);
      await pumpPushed(tester, const UserFormPage(), users: users);
      expect(find.text('Create user'), findsWidgets);
      final String pin = tester
          .getSemantics(find.bySemanticsLabel(RegExp('^Temporary PIN')))
          .label
          .replaceAll(RegExp('[^0-9]'), '');
      expect(pin, matches(RegExp(r'^[0-9]{6}$')));

      await tester.enterText(input(0), 'emp001');
      await tester.pump();
      expect(find.text('Taken'), findsOneWidget);
      await tester.enterText(input(0), 'EMP025');
      await tester.pump();
      expect(find.text('Free'), findsOneWidget);
      await tester.enterText(input(1), 'Bikash Halder');
      await tester.enterText(input(2), '98300 00000');
      await tester.tap(find.bySemanticsLabel(RegExp('^Admin')));
      await tester.tap(find.text('Create user').last);
      await tester.pumpAndSettle();

      expect(users.calls, <String>['create:EMP025:$pin']);
      expect(users.drafts.single.phone, '+919830000000');
      expect(users.drafts.single.role, AppRole.admin);
      expect(find.text('Bikash Halder added'), findsOneWidget);
      expect(
        find.text(
          'Give these to Bikash. On first sign-in they choose '
          'their own password.',
        ),
        findsOneWidget,
      );
      expect(find.text('This PIN is shown only once. Copy it now.'), findsOne);
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.text('below'), findsOneWidget);
    });

    testWidgets('New PIN changes it', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 3600);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await pumpPushed(tester, const UserFormPage());
      String shown() => tester
          .getSemantics(find.bySemanticsLabel(RegExp('^Temporary PIN')))
          .label;
      final Set<String> seen = <String>{shown()};
      for (int i = 0; i < 5; i++) {
        await tester.tap(find.bySemanticsLabel('New PIN'));
        await tester.pump();
        seen.add(shown());
      }
      expect(seen.length, greaterThan(1));
    });

    testWidgets('server field errors and a taken ID show on the fields', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 3600);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final FakeUsersRepository users = FakeUsersRepository()
        ..failWith = const FieldErrors(<String, String>{
          'phone': 'Phone looks wrong',
        });
      await pumpPushed(tester, const UserFormPage(), users: users);
      await tester.enterText(input(0), 'emp9');
      await tester.enterText(input(1), 'Chitra Sen');
      await tester.tap(find.text('Create user').last);
      await tester.pumpAndSettle();
      expect(find.text('Phone looks wrong'), findsOneWidget);

      users.failWith = AuthFailure.userCodeTaken;
      await tester.tap(find.text('Create user').last);
      await tester.pumpAndSettle();
      expect(find.text(AuthFailure.userCodeTaken.message), findsOneWidget);
    });

    testWidgets('checks the form first', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 3600);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final FakeUsersRepository users = FakeUsersRepository();
      await pumpPushed(tester, const UserFormPage(), users: users);
      await tester.enterText(input(0), 'x');
      await tester.enterText(input(3), 'not-an-email');
      await tester.tap(find.text('Create user').last);
      await tester.pumpAndSettle();
      expect(find.text('Use 2 to 20 letters, digits, - or _'), findsOneWidget);
      expect(find.text('Enter a name (up to 80)'), findsOneWidget);
      expect(find.text('Enter a valid email'), findsOneWidget);
      expect(users.calls, isEmpty);
    });

    for (final double width in <double>[360, 390, 430]) {
      testWidgets('create fits ${width.toInt()} wide', (
        WidgetTester tester,
      ) async {
        tester.view.physicalSize = Size(width * 3, 800 * 3);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);
        await pumpPushed(tester, const UserFormPage());
        await tester.enterText(input(0), 'EMP01234567890123456');
        await tester.pump();
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('edit user', () {
    Finder input(int i) => find.byType(TextField).at(i);

    testWidgets('saves changes and can turn the account off', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 3600);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final FakeUsersRepository users = FakeUsersRepository(<Profile>[
        const Profile(
          id: 'u1',
          userCode: 'EMP001',
          fullName: 'Asha Roy',
          role: AppRole.employee,
          isActive: true,
          phone: '+919830000000',
        ),
      ]);
      await pumpPushed(tester, const UserFormPage(userId: 'u1'), users: users);
      expect(find.text('Edit details'), findsOneWidget);
      expect(find.text("EMP001 · user ID can't change"), findsOneWidget);
      expect(
        find.text('Add it so Asha can reset a forgotten password.'),
        findsOneWidget,
      );
      expect(
        tester.widget<TextField>(input(1)).controller!.text,
        '9830000000',
        reason: '+91 is shown in front, not in the field',
      );
      await tester.enterText(input(0), 'Asha R.');
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(find.text("Can't sign in until turned back on"), findsOneWidget);
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      expect(users.calls, <String>['update:u1:Asha R.:false']);
      expect(users.drafts.single.phone, '+919830000000');
      expect(find.text('below'), findsOneWidget);
    });

    testWidgets('admins cannot turn off or demote themselves', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 3600);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await pumpPushed(
        tester,
        const UserFormPage(userId: 'admin1'),
        users: FakeUsersRepository(<Profile>[
          profile('admin1', name: 'Boss', role: AppRole.admin),
        ]),
      );
      expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNull);
      expect(find.text('You cannot change your own role.'), findsOneWidget);
      expect(
        find.text('You cannot turn off your own account.'),
        findsOneWidget,
      );
    });

    for (final double width in <double>[360, 390, 430]) {
      testWidgets('edit fits ${width.toInt()} wide', (
        WidgetTester tester,
      ) async {
        tester.view.physicalSize = Size(width * 3, 800 * 3);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);
        await pumpPushed(
          tester,
          const UserFormPage(userId: 'u1'),
          users: FakeUsersRepository(<Profile>[
            profile(
              'u1',
              code: 'EMP0123456789',
              name: 'Mohammad Hasanur Rahaman Chowdhury',
            ),
          ]),
        );
        expect(tester.takeException(), isNull);
      });
    }
  });

  test('phone is saved with +91 unless it has a country code', () {
    expect(phoneToSave(''), '');
    expect(phoneToSave('98300 00000'), '+919830000000');
    expect(phoneToSave('+447700900123'), '+447700900123');
    expect(phoneToEdit('+919830000000'), '9830000000');
    expect(phoneToEdit('+447700900123'), '+447700900123');
    expect(phoneToEdit(null), '');
  });
}
