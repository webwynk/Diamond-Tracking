import 'dart:typed_data';

import 'package:diamond_tracking/app/routes.dart';
import 'package:diamond_tracking/features/auth/domain/auth_status.dart';
import 'package:diamond_tracking/features/users/domain/profile.dart';
import 'package:diamond_tracking/features/users/presentation/account_page.dart';
import 'package:diamond_tracking/features/visits/data/visit_outbox.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';
import '../../support/pump.dart';

void main() {
  const SignedIn employee = SignedIn(
    userId: 'u',
    role: AppRole.employee,
    mustChangePassword: false,
  );

  testWidgets('log out waits while duty is on or the route is unsent', (
    WidgetTester tester,
  ) async {
    final FakeAuthRepository auth = FakeAuthRepository();
    final FakeTrackerControl tracker = FakeTrackerControl()..unsent = true;
    await pumpPage(
      tester,
      const AccountPage(changePasswordRoute: Routes.userChangePassword),
      auth: auth,
      tracker: tracker,
      users: FakeUsersRepository(<Profile>[profile('u')]),
      status: employee,
    );
    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();
    expect(find.text('Not yet'), findsOneWidget);
    expect(auth.calls, isNot(contains('signOut')));
  });

  testWidgets('log out waits while visits are still on the phone (M10)', (
    WidgetTester tester,
  ) async {
    final FakeAuthRepository auth = FakeAuthRepository();
    final VisitOutbox outbox = tempOutbox();
    await outbox.add(
      PendingVisit(
        id: VisitOutbox.newId(),
        userId: 'u',
        storeName: 'Shop',
        capturedAt: DateTime.utc(2026, 11, 20, 6),
      ),
      Uint8List.fromList(<int>[1]),
    );
    await pumpPage(
      tester,
      const AccountPage(changePasswordRoute: Routes.userChangePassword),
      auth: auth,
      outbox: outbox,
      users: FakeUsersRepository(<Profile>[profile('u')]),
      status: employee,
    );
    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();
    expect(find.text('Not yet'), findsOneWidget);
    expect(
      find.textContaining('visits are still on this phone'),
      findsOneWidget,
    );
    expect(auth.calls, isNot(contains('signOut')));
  });

  testWidgets('log out clears the tracker files', (WidgetTester tester) async {
    final FakeAuthRepository auth = FakeAuthRepository();
    final FakeTrackerControl tracker = FakeTrackerControl();
    await pumpPage(
      tester,
      const AccountPage(changePasswordRoute: Routes.userChangePassword),
      auth: auth,
      tracker: tracker,
      users: FakeUsersRepository(<Profile>[profile('u')]),
      status: employee,
    );
    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Log out'));
    await tester.pumpAndSettle();
    expect(auth.calls, contains('signOut'));
    expect(tracker.calls, contains('clear'));
  });
}
