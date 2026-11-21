import 'package:diamond_tracking/core/app_version.dart';
import 'package:diamond_tracking/features/auth/domain/auth_failure.dart';
import 'package:diamond_tracking/features/auth/presentation/change_password_page.dart';
import 'package:diamond_tracking/features/auth/presentation/forgot_password_page.dart';
import 'package:diamond_tracking/features/auth/presentation/login_page.dart';
import 'package:diamond_tracking/features/auth/presentation/set_password_page.dart';
import 'package:diamond_tracking/features/auth/presentation/splash_page.dart';
import 'package:diamond_tracking/shared/ds/ds_auth_frame.dart';
import 'package:diamond_tracking/shared/ds/ds_button.dart';
import 'package:diamond_tracking/shared/ds/ds_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';
import '../../support/pump.dart';

/// The text box of the field labelled [label].
Finder field(String label) => find.descendant(
  of: find.widgetWithText(DsTextField, label),
  matching: find.byType(TextField),
);

Finder codeBoxes() => find.descendant(
  of: find.byType(DsCodeBoxes),
  matching: find.byType(TextField),
);

Future<void> tapButton(WidgetTester tester, String label) async {
  final Finder button = find.widgetWithText(DsButton, label);
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
}

/// Phone widths the screens must fit: small, common and large (design v2).
const List<Size> phones = <Size>[
  Size(360, 740),
  Size(390, 844),
  Size(430, 932),
];

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
      expect(find.text('Enter your password or PIN'), findsOneWidget);
      expect(auth.calls, isEmpty);
    });

    testWidgets('shows why sign-in was refused', (WidgetTester tester) async {
      final FakeAuthRepository auth = FakeAuthRepository()
        ..failWith = AuthFailure.signedInElsewhere;
      await pumpPage(tester, const LoginPage(), auth: auth);
      await tester.enterText(field('User ID'), 'emp1');
      await tester.enterText(field('Password or PIN'), 'abcd1234');
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

    testWidgets('no "Field team" tag (owner, 2026-11-21)', (
      WidgetTester tester,
    ) async {
      await pumpPage(tester, const LoginPage());
      expect(find.text('Field team'), findsNothing);
      expect(find.text('One phone per account'), findsOneWidget);
    });
  });

  group('choose password after a PIN', () {
    testWidgets('greets by first name and ticks the rules', (
      WidgetTester tester,
    ) async {
      final FakeAuthRepository auth = FakeAuthRepository(
        userCode: 'emp1',
        firstName: 'Rahul',
      );
      await pumpPage(tester, const SetPasswordPage(), auth: auth);
      expect(find.textContaining('Welcome, Rahul.'), findsOneWidget);
      expect(find.bySemanticsLabel('8+ characters, not yet'), findsOneWidget);
      await tester.enterText(field('New password'), 'river2026');
      await tester.pump();
      expect(find.bySemanticsLabel('8+ characters, done'), findsOneWidget);
      expect(find.bySemanticsLabel('Letter and digit, done'), findsOneWidget);
      expect(find.bySemanticsLabel('Not your user ID, done'), findsOneWidget);
    });

    testWidgets('rejects a mismatch and the user ID inside', (
      WidgetTester tester,
    ) async {
      final FakeAuthRepository auth = FakeAuthRepository(userCode: 'emp1');
      await pumpPage(tester, const SetPasswordPage(), auth: auth);
      expect(find.textContaining('Welcome.'), findsOneWidget);
      await tester.enterText(field('New password'), 'myemp1pass');
      await tester.enterText(field('Repeat new password'), 'other123');
      await tapButton(tester, 'Save and continue');
      await tester.pumpAndSettle();
      expect(
        find.text('Do not use your user ID in the password'),
        findsOneWidget,
      );
      expect(find.text('The passwords do not match'), findsOneWidget);
      expect(auth.calls, isEmpty);

      await tester.enterText(field('New password'), 'river2026');
      await tester.enterText(field('Repeat new password'), 'river2026');
      await tapButton(tester, 'Save and continue');
      await tester.pumpAndSettle();
      expect(auth.calls, <String>['setFirstPassword']);
    });

    testWidgets('"Not you? Log out" signs out', (WidgetTester tester) async {
      final FakeAuthRepository auth = FakeAuthRepository();
      await pumpPage(tester, const SetPasswordPage(), auth: auth);
      await tester.ensureVisible(find.text('Not you? Log out'));
      await tester.tap(find.text('Not you? Log out'));
      await tester.pumpAndSettle();
      expect(auth.calls, <String>['signOut']);
    });
  });

  group('forgot password', () {
    testWidgets('3 steps: user ID, code and new password, done', (
      WidgetTester tester,
    ) async {
      final FakeAuthRepository auth = FakeAuthRepository();
      await pumpPage(tester, const ForgotPasswordPage(), auth: auth);
      expect(find.text('1/3'), findsOneWidget);
      await tester.enterText(field('User ID'), 'emp1');
      await tapButton(tester, 'Send code');
      await tester.pump();
      expect(auth.calls, <String>['requestResetCode:emp1']);
      expect(find.text('2/3'), findsOneWidget);
      expect(find.text('Resend in 0:60'), findsOneWidget);

      await tester.enterText(codeBoxes(), '123456');
      await tester.enterText(field('New password'), 'river2026');
      await tester.enterText(field('Repeat new password'), 'river2026');
      await tapButton(tester, 'Set new password');
      await tester.pumpAndSettle();
      expect(auth.calls.last, 'resetWithCode:emp1:123456');
      expect(find.text('3/3'), findsOneWidget);
      expect(find.widgetWithText(DsButton, 'Back to sign in'), findsOneWidget);
    });

    testWidgets('a new code can be asked for after a minute', (
      WidgetTester tester,
    ) async {
      final FakeAuthRepository auth = FakeAuthRepository();
      await pumpPage(tester, const ForgotPasswordPage(), auth: auth);
      await tester.enterText(field('User ID'), 'emp1');
      await tapButton(tester, 'Send code');
      await tester.pump();
      expect(find.text('Send a new code'), findsNothing);
      await tester.pump(const Duration(seconds: 61));
      expect(find.text('Send a new code'), findsOneWidget);
      await tester.tap(find.text('Send a new code'));
      await tester.pump();
      expect(auth.calls, <String>[
        'requestResetCode:emp1',
        'requestResetCode:emp1',
      ]);
      await tester.pump(const Duration(seconds: 61));
    });

    testWidgets('a wrong code says so and stays', (WidgetTester tester) async {
      final FakeAuthRepository auth = FakeAuthRepository();
      await pumpPage(tester, const ForgotPasswordPage(), auth: auth);
      await tester.enterText(field('User ID'), 'emp1');
      await tapButton(tester, 'Send code');
      await tester.pump();
      auth.failWith = AuthFailure.invalidCode;
      await tester.enterText(codeBoxes(), '000000');
      await tester.enterText(field('New password'), 'river2026');
      await tester.enterText(field('Repeat new password'), 'river2026');
      await tapButton(tester, 'Set new password');
      await tester.pump();
      expect(find.text(AuthFailure.invalidCode.message), findsOneWidget);
      expect(find.text('2/3'), findsOneWidget);
      await tester.pump(const Duration(seconds: 61));
    });

    testWidgets('a short code is caught before the server', (
      WidgetTester tester,
    ) async {
      final FakeAuthRepository auth = FakeAuthRepository();
      await pumpPage(tester, const ForgotPasswordPage(), auth: auth);
      await tester.enterText(field('User ID'), 'emp1');
      await tapButton(tester, 'Send code');
      await tester.pump();
      await tester.enterText(codeBoxes(), '123');
      await tester.enterText(field('New password'), 'river2026');
      await tester.enterText(field('Repeat new password'), 'river2026');
      await tapButton(tester, 'Set new password');
      await tester.pump();
      expect(find.text('Enter the 6 digits from the email'), findsOneWidget);
      expect(auth.calls, <String>['requestResetCode:emp1']);
      await tester.pump(const Duration(seconds: 61));
    });
  });

  group('change password', () {
    testWidgets('a wrong current password shows on that field', (
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
      expect(find.text("That's not your current password."), findsOneWidget);
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

    testWidgets('the back button goes back', (WidgetTester tester) async {
      await pumpPushed(tester, const ChangePasswordPage());
      await tester.tap(find.bySemanticsLabel('Back'));
      await tester.pumpAndSettle();
      expect(find.text('below'), findsOneWidget);
    });
  });

  group('fits every phone', () {
    for (final Size phone in phones) {
      testWidgets('${phone.width.toInt()} wide, with and without keyboard', (
        WidgetTester tester,
      ) async {
        tester.view.physicalSize = phone;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        for (final Widget page in <Widget>[
          const LoginPage(),
          const ForgotPasswordPage(),
          const SetPasswordPage(),
        ]) {
          await pumpPage(tester, page);
          expect(tester.takeException(), isNull);
          expect(find.byType(DsLogoMark), findsOneWidget);
          // The keyboard takes about 40% of the screen.
          tester.view.viewInsets = FakeViewPadding(bottom: phone.height * 0.4);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final Finder main = find.byType(DsButton).first;
          await tester.ensureVisible(main);
          await tester.pumpAndSettle();
          expect(
            tester.getBottomLeft(main).dy,
            lessThanOrEqualTo(phone.height * 0.6),
          );
          tester.view.resetViewInsets();
          await tester.pumpAndSettle();
        }
      });
    }
  });

  testWidgets('splash shows the name, the loading bar and the version', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appVersionProvider.overrideWith((Ref ref) async => '2.0.0 (46)'),
        ],
        child: const MaterialApp(home: SplashPage()),
      ),
    );
    await tester.pump();
    expect(find.text('Diamond Agritech'), findsOneWidget);
    expect(find.bySemanticsLabel('Loading'), findsOneWidget);
    expect(find.text('Version 2.0.0 (46)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
