import 'package:diamond_tracking/core/time/clock_providers.dart';
import 'package:diamond_tracking/features/auth/domain/auth_failure.dart';
import 'package:diamond_tracking/features/auth/domain/auth_status.dart';
import 'package:diamond_tracking/features/users/data/users_repository.dart';
import 'package:diamond_tracking/features/users/domain/profile.dart';
import 'package:diamond_tracking/features/users/presentation/user_form_page.dart';
import 'package:diamond_tracking/features/users/presentation/users_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../support/fakes.dart';
import '../../support/pump.dart';

Finder field(String label) => find.widgetWithText(TextFormField, label);

Future<void> tapButton(WidgetTester tester, String label) async {
  final Finder button = find.widgetWithText(ElevatedButton, label);
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void main() {
  group('users list', () {
    testWidgets('lists users and filters by name or ID', (
      WidgetTester tester,
    ) async {
      await pumpPage(
        tester,
        const UsersPage(),
        users: FakeUsersRepository(<Profile>[
          profile('1', code: 'emp1', name: 'Asha Roy', phone: true),
          profile('2', code: 'emp2', name: 'Bimal Das', active: false),
        ]),
      );
      expect(find.text('Asha Roy'), findsOneWidget);
      expect(find.text('emp1 · Signed in on a phone'), findsOneWidget);
      expect(find.text('Off'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'EMP2');
      await tester.pump();
      expect(find.text('Asha Roy'), findsNothing);
      expect(find.text('Bimal Das'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pump();
      expect(find.text('No match'), findsOneWidget);
    });

    testWidgets('Add user opens the form', (WidgetTester tester) async {
      await pumpPage(tester, const UsersPage());
      expect(find.text('No users yet'), findsOneWidget);
      await tester.tap(find.text('Add user'));
      await tester.pumpAndSettle();
      expect(find.text('route /admin/users/new'), findsOneWidget);
    });
  });

  group('add user', () {
    testWidgets('creates the user and shows the PIN once', (
      WidgetTester tester,
    ) async {
      final FakeUsersRepository users = FakeUsersRepository();
      await pumpPushed(tester, const UserFormPage(), users: users);
      final String pin = tester
          .widget<TextFormField>(field('Temporary PIN'))
          .controller!
          .text;
      expect(pin, matches(RegExp(r'^[0-9]{6}$')));

      await tester.enterText(field('User ID'), 'emp9');
      await tester.enterText(field('Full name'), 'Chitra Sen');
      await tapButton(tester, 'Add user');

      expect(users.calls, <String>['create:emp9:$pin']);
      expect(find.text('User added'), findsOneWidget);
      expect(
        find.descendant(of: find.byType(AlertDialog), matching: find.text(pin)),
        findsOneWidget,
      );
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.text('below'), findsOneWidget);
    });

    testWidgets('server field errors and a taken ID show on the fields', (
      WidgetTester tester,
    ) async {
      final FakeUsersRepository users = FakeUsersRepository()
        ..failWith = const FieldErrors(<String, String>{
          'phone': 'Phone looks wrong',
        });
      await pumpPushed(tester, const UserFormPage(), users: users);
      await tester.enterText(field('User ID'), 'emp9');
      await tester.enterText(field('Full name'), 'Chitra Sen');
      await tapButton(tester, 'Add user');
      expect(find.text('Phone looks wrong'), findsOneWidget);

      users.failWith = AuthFailure.userCodeTaken;
      await tapButton(tester, 'Add user');
      expect(find.text(AuthFailure.userCodeTaken.message), findsOneWidget);
    });

    testWidgets('checks the form first', (WidgetTester tester) async {
      final FakeUsersRepository users = FakeUsersRepository();
      await pumpPushed(tester, const UserFormPage(), users: users);
      await tester.enterText(field('User ID'), 'x');
      await tester.enterText(field('Email (optional)'), 'not-an-email');
      await tapButton(tester, 'Add user');
      expect(find.text('Use 2 to 20 letters, digits, - or _'), findsOneWidget);
      expect(find.text('Enter a name (up to 80)'), findsOneWidget);
      expect(find.text('Enter a valid email'), findsOneWidget);
      expect(users.calls, isEmpty);
    });
  });

  group('edit user', () {
    testWidgets('saves changes and can turn the account off', (
      WidgetTester tester,
    ) async {
      final FakeUsersRepository users = FakeUsersRepository(<Profile>[
        profile('u1', code: 'emp1', name: 'Asha Roy'),
      ]);
      await pumpPushed(tester, const UserFormPage(userId: 'u1'), users: users);
      expect(find.text('Edit user'), findsOneWidget);
      await tester.enterText(field('Full name'), 'Asha R.');
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      await tapButton(tester, 'Save');
      expect(users.calls, <String>['update:u1:Asha R.:false']);
      expect(find.text('below'), findsOneWidget);
    });

    testWidgets('reset password shows a new PIN', (WidgetTester tester) async {
      final FakeUsersRepository users = FakeUsersRepository(<Profile>[
        profile('u1', code: 'emp1', name: 'Asha Roy', phone: true),
      ]);
      await pumpPushed(tester, const UserFormPage(userId: 'u1'), users: users);
      expect(find.text('Signed in on a phone now.'), findsOneWidget);
      final Finder reset = find.widgetWithText(
        OutlinedButton,
        'Reset password',
      );
      await tester.ensureVisible(reset);
      await tester.tap(reset);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Reset'));
      await tester.pumpAndSettle();
      expect(users.calls.single, startsWith('resetPin:u1:'));
      expect(find.text('Password reset'), findsOneWidget);
    });

    testWidgets('release phone frees a lost phone (M6)', (
      WidgetTester tester,
    ) async {
      final FakeUsersRepository users = FakeUsersRepository(<Profile>[
        profile('u1', code: 'emp1', name: 'Asha Roy', phone: true),
      ]);
      await pumpPushed(tester, const UserFormPage(userId: 'u1'), users: users);
      final Finder release = find.widgetWithText(
        OutlinedButton,
        'Release phone',
      );
      await tester.ensureVisible(release);
      await tester.tap(release);
      await tester.pumpAndSettle();
      expect(find.text("Release Asha Roy's phone?"), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Release'));
      await tester.pumpAndSettle();
      expect(users.calls, <String>['releasePhone:u1']);
      expect(
        find.text('Phone released. Asha Roy can log in on another phone.'),
        findsOneWidget,
      );
    });

    testWidgets('release phone is only shown while a phone is logged in', (
      WidgetTester tester,
    ) async {
      final FakeUsersRepository users = FakeUsersRepository(<Profile>[
        profile('u1', code: 'emp1', name: 'Asha Roy'),
      ]);
      await pumpPushed(tester, const UserFormPage(userId: 'u1'), users: users);
      expect(find.text('Release phone'), findsNothing);
      expect(find.text('Reset password'), findsOneWidget);
    });

    group('allow duty on', () {
      Future<FakeUsersRepository> open(
        WidgetTester tester, {
        AppRole role = AppRole.employee,
        bool active = true,
      }) async {
        tester.view.physicalSize = const Size(1080, 4000);
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.reset);
        final FakeUsersRepository users = FakeUsersRepository(<Profile>[
          profile(
            'u1',
            code: 'emp1',
            name: 'Asha Roy',
            role: role,
            active: active,
          ),
        ]);
        await pumpPushed(
          tester,
          const UserFormPage(userId: 'u1'),
          users: users,
          overrides: <Override>[
            serverClockProvider.overrideWithValue(
              FixedClock(DateTime.utc(2026, 11, 20, 13)).clock,
            ),
          ],
        );
        return users;
      }

      testWidgets('allows with a note, then takes it back', (
        WidgetTester tester,
      ) async {
        final FakeUsersRepository users = await open(tester);
        expect(find.textContaining('Normally only 5:00 to 8:30 AM'), findsOne);
        await tester.tap(find.text('Allow duty on today'));
        await tester.pumpAndSettle();
        expect(find.text('Allow duty on for Asha Roy?'), findsOneWidget);
        await tester.enterText(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(TextField),
          ),
          'Late start',
        );
        await tester.tap(find.widgetWithText(TextButton, 'Allow'));
        await tester.pumpAndSettle();
        expect(users.calls, contains('allowDutyOn:u1:Late start'));
        expect(find.text('Allowed for today. Not used yet.'), findsOneWidget);

        await tester.tap(find.text('Take back permission'));
        await tester.pumpAndSettle();
        expect(users.calls, contains('revokeDutyOn:u1'));
        expect(find.text('Allow duty on today'), findsOneWidget);
      });

      testWidgets('cancelling asks nothing of the server', (
        WidgetTester tester,
      ) async {
        final FakeUsersRepository users = await open(tester);
        await tester.tap(find.text('Allow duty on today'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
        await tester.pumpAndSettle();
        expect(users.calls, isEmpty);
      });

      testWidgets('a day that is already recorded says so', (
        WidgetTester tester,
      ) async {
        final FakeUsersRepository users = await open(tester);
        users.failWith = const PostgrestException(
          message: 'day_already_recorded',
        );
        await tester.tap(find.text('Allow duty on today'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(TextButton, 'Allow'));
        await tester.pumpAndSettle();
        expect(find.textContaining('already has a record for today'), findsOne);
        expect(find.text('Allow duty on today'), findsOneWidget);
      });

      testWidgets('not shown for admins or accounts that are off', (
        WidgetTester tester,
      ) async {
        await open(tester, role: AppRole.admin);
        expect(find.text('Duty on today'), findsNothing);
      });
    });

    testWidgets('admins cannot turn off or demote themselves', (
      WidgetTester tester,
    ) async {
      await pumpPushed(
        tester,
        const UserFormPage(userId: 'admin1'),
        users: FakeUsersRepository(<Profile>[
          profile('admin1', name: 'Boss', role: AppRole.admin),
        ]),
      );
      expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNull);
      expect(
        tester
            .widget<SegmentedButton<AppRole>>(
              find.byType(SegmentedButton<AppRole>),
            )
            .onSelectionChanged,
        isNull,
      );
      expect(find.text('Reset password'), findsNothing);
    });
  });
}
