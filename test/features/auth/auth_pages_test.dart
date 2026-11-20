import 'package:diamond_tracking/features/auth/domain/auth_failure.dart';
import 'package:diamond_tracking/features/auth/presentation/change_password_page.dart';
import 'package:diamond_tracking/features/auth/presentation/forgot_password_page.dart';
import 'package:diamond_tracking/features/auth/presentation/login_page.dart';
import 'package:diamond_tracking/features/auth/presentation/set_password_page.dart';
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
}

void main() {
  group('sign in', () {
    testWidgets('checks the form before calling the server', (
      WidgetTester tester,
    ) async {
      final FakeAuthRepository auth = FakeAuthRepository();
      await pumpPage(tester, const LoginPage(), auth: auth);
      await tapButton(tester, 'Sign in');
      await tester.pumpAndSettle();
      expect(find.text('Enter your user ID'), findsOneWidget);
      expect(find.text('Enter your password'), findsOneWidget);
      expect(auth.calls, isEmpty);
    });

    testWidgets('shows why sign-in was refused', (WidgetTester tester) async {
      final FakeAuthRepository auth = FakeAuthRepository()
        ..failWith = AuthFailure.signedInElsewhere;
      await pumpPage(tester, const LoginPage(), auth: auth);
      await tester.enterText(field('User ID'), 'emp1');
      await tester.enterText(field('Password'), 'abcd1234');
      await tapButton(tester, 'Sign in');
      await tester.pumpAndSettle();
      expect(auth.calls, <String>['signIn:emp1']);
      expect(find.text(AuthFailure.signedInElsewhere.message), findsOneWidget);
    });

    testWidgets('opens forgot password', (WidgetTester tester) async {
      await pumpPage(tester, const LoginPage());
      await tester.tap(find.text('Forgot password?'));
      await tester.pumpAndSettle();
      expect(find.text('route /forgot-password'), findsOneWidget);
    });
  });

  group('choose password after a PIN', () {
    testWidgets('rejects a mismatch and the user ID inside', (
      WidgetTester tester,
    ) async {
      final FakeAuthRepository auth = FakeAuthRepository(userCode: 'emp1');
      await pumpPage(tester, const SetPasswordPage(), auth: auth);
      await tester.enterText(field('New password'), 'myemp1pass');
      await tester.enterText(field('Repeat new password'), 'other123');
      await tapButton(tester, 'Save password');
      await tester.pumpAndSettle();
      expect(
        find.text('Do not use your user ID in the password'),
        findsOneWidget,
      );
      expect(find.text('The passwords do not match'), findsOneWidget);
      expect(auth.calls, isEmpty);

      await tester.enterText(field('New password'), 'river2026');
      await tester.enterText(field('Repeat new password'), 'river2026');
      await tapButton(tester, 'Save password');
      await tester.pumpAndSettle();
      expect(auth.calls, <String>['setFirstPassword']);
    });
  });

  group('forgot password', () {
    testWidgets('sends a code, then resets with it', (
      WidgetTester tester,
    ) async {
      final FakeAuthRepository auth = FakeAuthRepository();
      await pumpPage(tester, const ForgotPasswordPage(), auth: auth);
      await tester.enterText(field('User ID'), 'emp1');
      await tapButton(tester, 'Send code');
      await tester.pumpAndSettle();
      expect(auth.calls, <String>['requestResetCode:emp1']);
      expect(find.text('Enter the code'), findsOneWidget);

      await tester.enterText(field('6-digit code'), '123456');
      await tester.enterText(field('New password'), 'river2026');
      await tester.enterText(field('Repeat new password'), 'river2026');
      await tapButton(tester, 'Set new password');
      await tester.pumpAndSettle();
      expect(auth.calls.last, 'resetWithCode:emp1:123456');
      expect(find.text('Password changed'), findsOneWidget);
    });

    testWidgets('a wrong code says so and stays', (WidgetTester tester) async {
      final FakeAuthRepository auth = FakeAuthRepository();
      await pumpPage(tester, const ForgotPasswordPage(), auth: auth);
      await tester.enterText(field('User ID'), 'emp1');
      await tapButton(tester, 'Send code');
      await tester.pumpAndSettle();
      auth.failWith = AuthFailure.invalidCode;
      await tester.enterText(field('6-digit code'), '000000');
      await tester.enterText(field('New password'), 'river2026');
      await tester.enterText(field('Repeat new password'), 'river2026');
      await tapButton(tester, 'Set new password');
      await tester.pumpAndSettle();
      expect(find.text(AuthFailure.invalidCode.message), findsOneWidget);
      expect(find.text('Enter the code'), findsOneWidget);
    });
  });

  group('change password', () {
    testWidgets('a wrong current password is named as such', (
      WidgetTester tester,
    ) async {
      final FakeAuthRepository auth = FakeAuthRepository()
        ..failWith = AuthFailure.invalidCredentials;
      await pumpPushed(tester, const ChangePasswordPage(), auth: auth);
      await tester.enterText(field('Current password'), 'old12345');
      await tester.enterText(field('New password'), 'river2026');
      await tester.enterText(field('Repeat new password'), 'river2026');
      await tapButton(tester, 'Change password');
      await tester.pumpAndSettle();
      expect(
        find.text(AuthFailure.wrongCurrentPassword.message),
        findsOneWidget,
      );
    });

    testWidgets('success goes back with a note', (WidgetTester tester) async {
      final FakeAuthRepository auth = FakeAuthRepository();
      await pumpPushed(tester, const ChangePasswordPage(), auth: auth);
      await tester.enterText(field('Current password'), 'old12345');
      await tester.enterText(field('New password'), 'river2026');
      await tester.enterText(field('Repeat new password'), 'river2026');
      await tapButton(tester, 'Change password');
      await tester.pumpAndSettle();
      expect(auth.calls, <String>['changePassword']);
      expect(find.text('below'), findsOneWidget);
      expect(find.text('Password changed'), findsOneWidget);
    });
  });
}
