import 'dart:async';

import 'package:diamond_tracking/app/app.dart';
import 'package:diamond_tracking/features/auth/application/auth_providers.dart';
import 'package:diamond_tracking/features/auth/domain/auth_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late StreamController<AuthStatus> auth;

  setUp(() => auth = StreamController<AuthStatus>());
  tearDown(() => auth.close());

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authStatusStreamProvider.overrideWithValue(auth.stream)],
        child: const DiamondApp(),
      ),
    );
    await tester.pump();
  }

  testWidgets('splash, then login when signed out', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    auth.add(const SignedOut());
    await tester.pumpAndSettle();
    expect(find.text('Sign in'), findsWidgets);
  });

  testWidgets('an employee gets the 4 user tabs', (WidgetTester tester) async {
    await pumpApp(tester);
    auth.add(
      const SignedIn(
        userId: 'u',
        role: AppRole.employee,
        mustChangePassword: false,
      ),
    );
    await tester.pumpAndSettle();
    for (final String tab in <String>['Home', 'Map', 'History', 'Profile']) {
      expect(find.widgetWithText(NavigationDestination, tab), findsOneWidget);
    }
    expect(find.text('Dashboard'), findsNothing);

    await tester.tap(find.widgetWithText(NavigationDestination, 'Map'));
    await tester.pumpAndSettle();
    expect(find.text('My map'), findsWidgets);
  });

  testWidgets('an admin gets the admin tabs, and sign-out returns to login', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);
    auth.add(
      const SignedIn(
        userId: 'a',
        role: AppRole.admin,
        mustChangePassword: false,
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.widgetWithText(NavigationDestination, 'Requests'),
      findsOneWidget,
    );

    auth.add(const SignedOut());
    await tester.pumpAndSettle();
    expect(find.text('Sign in'), findsWidgets);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('a temporary PIN opens the set-password screen', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);
    auth.add(
      const SignedIn(
        userId: 'u',
        role: AppRole.employee,
        mustChangePassword: true,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Set your password'), findsWidgets);
  });
}
