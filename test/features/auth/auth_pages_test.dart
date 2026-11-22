import 'package:diamond_tracking/core/app_version.dart';
import 'package:diamond_tracking/features/auth/domain/auth_failure.dart';
import 'package:diamond_tracking/features/auth/domain/auth_status.dart';
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
  // As a person does: close the keyboard first. A focused field keeps
  // scrolling itself back into view, which can hide the button.
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump();
  final Finder button = find.widgetWithText(DsButton, label);
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  // Then to the end of the sheet, as a thumb would: the button is last.
  final Finder sheet = find.byType(SingleChildScrollView).first;
  if (sheet.evaluate().isNotEmpty) {
    await tester.drag(sheet, const Offset(0, -600));
    await tester.pumpAndSettle();
  }
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
    testWidgets('greets by first name and ticks each rule while typing', (
      WidgetTester tester,
    ) async {
      final FakeAuthRepository auth = FakeAuthRepository(
        userCode: 'emp1',
        firstName: 'Rahul',
      );
      await pumpPage(tester, const SetPasswordPage(), auth: auth);
      expect(find.textContaining('Welcome, Rahul.'), findsOneWidget);
      expect(find.textContaining('Example: Mango@2025'), findsOneWidget);
      expect(
        find.bySemanticsLabel('8+ characters, still needed'),
        findsOneWidget,
      );
      await tester.enterText(field('New password'), 'river2026');
      await tester.pump();
      for (final String done in <String>[
        '8+ characters',
        'A letter',
        'A digit',
        'Not your user ID',
      ]) {
        expect(find.bySemanticsLabel('$done, done'), findsOneWidget);
      }
      expect(
        find.bySemanticsLabel(r'A symbol like @ # $ !, still needed'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Looks good'), findsNothing);

      await tester.enterText(field('New password'), 'river@2026');
      await tester.pump();
      expect(
        find.bySemanticsLabel(r'A symbol like @ # $ !, done'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Looks good'), findsOneWidget);
      await tester.enterText(field('Repeat new password'), 'river@2026');
      await tester.pump();
      expect(find.text('Passwords match'), findsOneWidget);
      expect(find.bySemanticsLabel('Looks good'), findsNWidgets(2));
    });

    testWidgets('red only after Save, and gone at the next edit', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final FakeAuthRepository auth = FakeAuthRepository(userCode: 'emp1');
      await pumpPage(tester, const SetPasswordPage(), auth: auth);
      expect(find.textContaining('Welcome.'), findsOneWidget);
      await tester.enterText(field('New password'), 'river2026');
      await tester.enterText(field('Repeat new password'), 'river2025');
      await tester.pump();
      expect(find.text(r'Add a symbol, like @ # $ !'), findsNothing);
      await tapButton(tester, 'Save and continue');
      await tester.pumpAndSettle();
      expect(find.text(r'Add a symbol, like @ # $ !'), findsOneWidget);
      expect(find.text("Passwords don't match"), findsOneWidget);
      expect(auth.calls, isEmpty);

      await tester.enterText(field('New password'), 'river20266');
      await tester.pump();
      expect(find.text(r'Add a symbol, like @ # $ !'), findsNothing);
      expect(find.text("Passwords don't match"), findsNothing);

      for (final (String pw, String why) in <(String, String)>[
        ('myemp1pass!', 'Do not use your user ID in the password'),
        ('Mango@2025', 'Do not use the example password'),
      ]) {
        await tester.enterText(field('New password'), pw);
        await tester.enterText(field('Repeat new password'), pw);
        await tapButton(tester, 'Save and continue');
        await tester.pumpAndSettle();
        expect(find.text(why), findsOneWidget);
      }
      expect(auth.calls, isEmpty);
    });

    testWidgets('saved: the popup, then Go to Home', (
      WidgetTester tester,
    ) async {
      final FakeAuthRepository auth = FakeAuthRepository(
        userCode: 'emp1',
        firstName: 'Rahul',
      );
      await pumpPage(tester, const SetPasswordPage(), auth: auth);
      await tester.enterText(field('New password'), 'river@2026');
      await tester.enterText(field('Repeat new password'), 'river@2026');
      await tapButton(tester, 'Save and continue');
      await tester.pumpAndSettle();
      expect(auth.calls, <String>['setFirstPassword']);
      expect(find.text('Password saved'), findsOneWidget);
      expect(
        find.text(
          "You're all set, Rahul. Use this password every time you sign in.",
        ),
        findsOneWidget,
      );
      // Only the button closes it.
      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();
      expect(find.text('Password saved'), findsOneWidget);
      await tester.tap(find.text('Go to Home'));
      await tester.pumpAndSettle();
      expect(find.text('Password saved'), findsNothing);
    });

    testWidgets('saved but not signed in again: off to sign in, saying so', (
      WidgetTester tester,
    ) async {
      final FakeAuthRepository auth = FakeAuthRepository()
        ..failWith = AuthFailure.passwordSavedSignIn;
      await pumpPage(tester, const SetPasswordPage(), auth: auth);
      await tester.enterText(field('New password'), 'river@2026');
      await tester.enterText(field('Repeat new password'), 'river@2026');
      await tapButton(tester, 'Save and continue');
      await tester.pumpAndSettle();
      expect(auth.calls, <String>['setFirstPassword', 'signOut']);
      expect(
        find.text(AuthFailure.passwordSavedSignIn.message),
        findsOneWidget,
      );
      expect(find.text('Password saved'), findsNothing);
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
    Future<void> toCodeStep(
      WidgetTester tester,
      FakeAuthRepository auth,
    ) async {
      await pumpPage(tester, const ForgotPasswordPage(), auth: auth);
      expect(find.text('1/3'), findsOneWidget);
      await tester.enterText(field('User ID'), 'emp1');
      await tapButton(tester, 'Send code');
      await tester.pump();
      expect(find.text('2/3'), findsOneWidget);
    }

    testWidgets('code and new password, then signed in with the popup', (
      WidgetTester tester,
    ) async {
      final FakeAuthRepository auth = FakeAuthRepository();
      await toCodeStep(tester, auth);
      expect(auth.calls, <String>['requestResetCode:emp1']);
      expect(find.text('Resend in 0:60'), findsOneWidget);

      await tester.enterText(codeBoxes(), '123456');
      await tester.enterText(field('New password'), 'river@2026');
      await tester.enterText(field('Repeat new password'), 'river@2026');
      await tapButton(tester, 'Set new password');
      await tester.pumpAndSettle();
      expect(auth.calls, <String>[
        'requestResetCode:emp1',
        'resetWithCode:emp1:123456',
        'signIn:emp1',
      ]);
      expect(find.text('Password reset'), findsOneWidget);
      await tester.tap(find.text('Go to Home'));
      await tester.pumpAndSettle();
      expect(find.text('Password reset'), findsNothing);
    });

    testWidgets('reset but not signed in: the old "sign in now" step', (
      WidgetTester tester,
    ) async {
      final FakeAuthRepository auth = FakeAuthRepository()
        ..signInFailWith = AuthFailure.network;
      await toCodeStep(tester, auth);
      await tester.enterText(codeBoxes(), '123456');
      await tester.enterText(field('New password'), 'river@2026');
      await tester.enterText(field('Repeat new password'), 'river@2026');
      await tapButton(tester, 'Set new password');
      await tester.pumpAndSettle();
      expect(find.text('3/3'), findsOneWidget);
      expect(find.widgetWithText(DsButton, 'Back to sign in'), findsOneWidget);
      expect(find.text('Password reset'), findsNothing);
    });

    testWidgets('the new password follows the same rules', (
      WidgetTester tester,
    ) async {
      final FakeAuthRepository auth = FakeAuthRepository();
      await toCodeStep(tester, auth);
      expect(find.text('Example: Mango@2025'), findsOneWidget);
      await tester.enterText(codeBoxes(), '123456');
      await tester.enterText(field('New password'), 'river2026');
      await tester.enterText(field('Repeat new password'), 'river2026');
      await tapButton(tester, 'Set new password');
      await tester.pump();
      expect(find.text(r'Add a symbol, like @ # $ !'), findsOneWidget);
      expect(auth.calls, <String>['requestResetCode:emp1']);
      await tester.pump(const Duration(seconds: 61));
    });

    testWidgets('a new code can be asked for after a minute', (
      WidgetTester tester,
    ) async {
      final FakeAuthRepository auth = FakeAuthRepository();
      await toCodeStep(tester, auth);
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
      await toCodeStep(tester, auth);
      auth.failWith = AuthFailure.invalidCode;
      await tester.enterText(codeBoxes(), '000000');
      await tester.enterText(field('New password'), 'river@2026');
      await tester.enterText(field('Repeat new password'), 'river@2026');
      await tapButton(tester, 'Set new password');
      // The hold lets go on the next tick of the clock.
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 1));
      expect(find.text(AuthFailure.invalidCode.message), findsOneWidget);
      expect(find.text('2/3'), findsOneWidget);
      await tester.pump(const Duration(seconds: 61));
    });

    testWidgets('a short code is caught before the server', (
      WidgetTester tester,
    ) async {
      final FakeAuthRepository auth = FakeAuthRepository();
      await toCodeStep(tester, auth);
      await tester.enterText(codeBoxes(), '123');
      await tester.enterText(field('New password'), 'river@2026');
      await tester.enterText(field('Repeat new password'), 'river@2026');
      await tapButton(tester, 'Set new password');
      await tester.pump();
      expect(find.text('Enter the 6 digits from the email'), findsOneWidget);
      expect(auth.calls, <String>['requestResetCode:emp1']);
      await tester.pump(const Duration(seconds: 61));
    });
  });

  group('change password', () {
    Future<void> fill(WidgetTester tester, String current) async {
      await tester.enterText(field('Current password'), current);
      await tester.enterText(field('New password'), 'river@2026');
      await tester.enterText(field('Repeat new password'), 'river@2026');
      await tapButton(tester, 'Change password');
      await tester.pumpAndSettle();
    }

    testWidgets('a wrong current password shows on that field', (
      WidgetTester tester,
    ) async {
      final FakeAuthRepository auth = FakeAuthRepository()
        ..failWith = AuthFailure.invalidCredentials;
      await pumpPushed(tester, const ChangePasswordPage(), auth: auth);
      await fill(tester, 'old12345');
      expect(find.text("That's not your current password."), findsOneWidget);
    });

    testWidgets('the new one must differ from the current one', (
      WidgetTester tester,
    ) async {
      final FakeAuthRepository auth = FakeAuthRepository();
      await pumpPushed(tester, const ChangePasswordPage(), auth: auth);
      await fill(tester, 'river@2026');
      expect(find.text('The new password must be different'), findsOneWidget);
      expect(auth.calls, isEmpty);
    });

    testWidgets('success: the popup, then Home', (WidgetTester tester) async {
      final FakeAuthRepository auth = FakeAuthRepository();
      await pumpPage(
        tester,
        const ChangePasswordPage(),
        auth: auth,
        status: const SignedIn(
          userId: 'u1',
          role: AppRole.employee,
          mustChangePassword: false,
        ),
      );
      await fill(tester, 'old12345');
      expect(auth.calls, <String>['changePassword']);
      expect(find.text('Password changed'), findsOneWidget);
      await tester.tap(find.text('Go to Home'));
      await tester.pumpAndSettle();
      expect(find.text('route /home'), findsOneWidget);
    });

    testWidgets('an admin goes to the dashboard', (WidgetTester tester) async {
      await pumpPage(tester, const ChangePasswordPage());
      await fill(tester, 'old12345');
      await tester.tap(find.text('Go to Home'));
      await tester.pumpAndSettle();
      expect(find.text('route /admin'), findsOneWidget);
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
