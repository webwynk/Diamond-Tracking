import 'package:diamond_tracking/features/auth/domain/auth_failure.dart';
import 'package:diamond_tracking/features/auth/domain/auth_status.dart';
import 'package:diamond_tracking/features/users/data/users_repository.dart';
import 'package:diamond_tracking/features/users/domain/profile.dart';
import 'package:diamond_tracking/features/users/presentation/user_form_page.dart';
import 'package:diamond_tracking/features/users/presentation/users_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
