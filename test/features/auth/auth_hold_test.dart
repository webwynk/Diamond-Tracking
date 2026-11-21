import 'dart:async';

import 'package:diamond_tracking/features/auth/application/auth_providers.dart';
import 'package:diamond_tracking/features/auth/domain/auth_status.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late StreamController<AuthStatus> auth;
  late ProviderContainer container;

  setUp(() {
    auth = StreamController<AuthStatus>();
    container = ProviderContainer(
      overrides: [authStatusStreamProvider.overrideWithValue(auth.stream)],
    );
    container.listen(authStatusProvider, (_, _) {});
  });
  tearDown(() {
    container.dispose();
    return auth.close();
  });

  AuthStatus status() => container.read(authStatusProvider);
  const SignedIn employee = SignedIn(
    userId: 'u',
    role: AppRole.employee,
    mustChangePassword: false,
  );

  test('a refused phone claim never shows the signed-in state', () async {
    auth.add(const SignedOut());
    await pumpEventQueue();
    final List<AuthStatus> seen = <AuthStatus>[];
    container.listen(authStatusProvider, (_, AuthStatus s) => seen.add(s));

    final Future<void> attempt = container
        .read(authStatusProvider.notifier)
        .holdWhile(() async {
          auth.add(employee); // session created
          await pumpEventQueue();
          auth.add(const SignedOut()); // claim refused, signed out again
          throw StateError('signed_in_elsewhere');
        });
    await expectLater(attempt, throwsStateError);

    expect(status(), const SignedOut());
    expect(seen.whereType<SignedIn>(), isEmpty);
  });

  test('a successful sign-in applies once the hold ends', () async {
    auth.add(const SignedOut());
    await pumpEventQueue();
    await container.read(authStatusProvider.notifier).holdWhile(() async {
      auth.add(employee);
      await pumpEventQueue();
      expect(status(), const SignedOut());
    });
    expect(status(), employee);
  });

  test('a sign-out the user did not ask for is marked, then cleared', () async {
    auth.add(employee);
    await pumpEventQueue();
    auth.add(const SignedOut()); // the admin reset the account
    await pumpEventQueue();
    expect(status(), const SignedOut(unexpected: true));

    container.read(authStatusProvider.notifier).acknowledgeSignOut();
    expect(status(), const SignedOut());
  });

  test('logging out yourself goes straight to sign-in', () async {
    auth.add(employee);
    await pumpEventQueue();
    await container
        .read(authStatusProvider.notifier)
        .signOutWith(() async => auth.add(const SignedOut()));
    expect(status(), const SignedOut());
  });

  test('a signed-out start is never marked', () async {
    auth.add(const SignedOut());
    await pumpEventQueue();
    expect(status(), const SignedOut());
  });
}
