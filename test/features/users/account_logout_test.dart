import 'dart:typed_data';

import 'package:diamond_tracking/features/auth/domain/auth_status.dart';
import 'package:diamond_tracking/features/users/domain/profile.dart';
import 'package:diamond_tracking/features/users/presentation/profile_page.dart';
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
      const ProfilePage(),
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
      const ProfilePage(),
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
      const ProfilePage(),
      auth: auth,
      tracker: tracker,
      users: FakeUsersRepository(<Profile>[profile('u')]),
      status: employee,
    );
    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log out').last);
    await tester.pumpAndSettle();
    expect(auth.calls, contains('signOut'));
    expect(tracker.calls, contains('clear'));
  });

  testWidgets('profile shows the account and the waiting requests', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2600);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await pumpPage(
      tester,
      const ProfilePage(),
      users: FakeUsersRepository(<Profile>[profile('u', name: 'Rahul Das')]),
      status: employee,
    );
    expect(find.text('RD'), findsOneWidget);
    expect(find.text('Rahul Das'), findsOneWidget);
    expect(find.textContaining('Employee · '), findsOneWidget);
    expect(find.text('Reset email'), findsOneWidget);
    await tester.tap(find.text('My requests'));
    await tester.pumpAndSettle();
    expect(find.text('route /home/requests'), findsOneWidget);
  });

  for (final double width in <double>[360, 390, 430]) {
    testWidgets('profile fits a $width wide phone', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = Size(width * 3, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await pumpPage(
        tester,
        const ProfilePage(),
        users: FakeUsersRepository(<Profile>[
          profile('u', name: 'Mohammad Hasanur Rahaman Chowdhury'),
        ]),
        status: employee,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
