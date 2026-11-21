import 'dart:async';

import 'package:diamond_tracking/core/supabase/supabase_providers.dart';
import 'package:diamond_tracking/features/auth/application/auth_providers.dart';
import 'package:diamond_tracking/features/auth/domain/auth_status.dart';
import 'package:diamond_tracking/features/notifications/application/notifications_providers.dart';
import 'package:diamond_tracking/features/notifications/application/push_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';

// L100: how this phone signs up for push alerts, and stops on logout.
void main() {
  late StreamController<AuthStatus> auth;
  late FakeNotificationsRepository repo;

  const SignedIn employee = SignedIn(
    userId: 'u',
    role: AppRole.employee,
    mustChangePassword: false,
  );

  setUp(() {
    auth = StreamController<AuthStatus>();
    repo = FakeNotificationsRepository();
  });
  tearDown(() => auth.close());

  ProviderContainer start(PushService push) {
    final ProviderContainer c = ProviderContainer(
      overrides: [
        authStatusStreamProvider.overrideWithValue(auth.stream),
        pushServiceProvider.overrideWithValue(push),
        notificationsRepositoryProvider.overrideWithValue(repo),
        deviceIdStoreProvider.overrideWithValue(FakeDeviceIdStore()),
      ],
    );
    addTearDown(c.dispose);
    c.read(pushRegistrarProvider);
    return c;
  }

  test('sign-in signs the phone up; logout takes it off', () async {
    final ProviderContainer c = start(FakePushService());
    auth.add(employee);
    await pumpEventQueue();
    expect(repo.calls, <String>['set:test-device-0001:push-token-1']);

    await c.read(pushRegistrarProvider).clear();
    expect(repo.calls.last, 'clear:push-token-1');
  });

  test('a new token is saved, and is the one logout clears', () async {
    final FakePushService push = FakePushService();
    final ProviderContainer c = start(push);
    auth.add(employee);
    await pumpEventQueue();
    push.refreshController.add('push-token-2');
    await pumpEventQueue();
    expect(repo.calls.last, 'set:test-device-0001:push-token-2');

    await c.read(pushRegistrarProvider).clear();
    expect(repo.calls.last, 'clear:push-token-2');
  });

  test('no sign-up while the temporary PIN is still in use', () async {
    start(FakePushService());
    auth.add(
      const SignedIn(
        userId: 'u',
        role: AppRole.employee,
        mustChangePassword: true,
      ),
    );
    await pumpEventQueue();
    expect(repo.calls, isEmpty);
  });

  test('without Firebase no sign-up, and logout sends nothing', () async {
    final ProviderContainer c = start(FakePushService(tokenValue: null));
    auth.add(employee);
    await pumpEventQueue();
    await c.read(pushRegistrarProvider).clear();
    expect(repo.calls, isEmpty);
  });

  test('after sign-out a new token is not saved any more', () async {
    final FakePushService push = FakePushService();
    start(push);
    auth.add(employee);
    await pumpEventQueue();
    auth.add(const SignedOut());
    await pumpEventQueue();
    push.refreshController.add('push-token-3');
    await pumpEventQueue();
    expect(repo.calls, <String>['set:test-device-0001:push-token-1']);
  });
}
