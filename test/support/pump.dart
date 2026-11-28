import 'dart:async';
import 'dart:io';

import 'package:diamond_tracking/core/theme/app_theme.dart';
import 'package:diamond_tracking/features/auth/application/auth_providers.dart';
import 'package:diamond_tracking/features/auth/domain/auth_status.dart';
import 'package:diamond_tracking/features/notifications/application/notifications_providers.dart';
import 'package:diamond_tracking/features/notifications/application/push_service.dart';
import 'package:diamond_tracking/features/tracking/application/tracker_providers.dart';
import 'package:diamond_tracking/features/users/application/users_providers.dart';
import 'package:diamond_tracking/features/visits/application/visits_providers.dart';
import 'package:diamond_tracking/features/visits/data/visit_outbox.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'fakes.dart';

/// A visit outbox in a fresh temporary folder.
VisitOutbox tempOutbox() {
  final Directory dir = Directory.systemTemp.createTempSync('outbox');
  addTearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });
  return VisitOutbox(() async => dir);
}

/// Pumps [page] alone, with fakes, under a tiny router so push/pop work.
/// Other routes show their path as text.
Future<void> pumpPage(
  WidgetTester tester,
  Widget page, {
  FakeAuthRepository? auth,
  FakeUsersRepository? users,
  FakeTrackerControl? tracker,
  List<Override> overrides = const <Override>[],
  FakeNotificationsRepository? notifications,
  FakeVisitsRepository? visits,
  VisitOutbox? outbox,
  AuthStatus status = const SignedIn(
    userId: 'admin1',
    role: AppRole.admin,
    mustChangePassword: false,
  ),
}) async {
  final GoRouter router = GoRouter(
    routes: <RouteBase>[
      GoRoute(path: '/', builder: (_, _) => page),
      GoRoute(
        path: '/:a/:b/:c/:d',
        builder: (_, GoRouterState s) =>
            Scaffold(body: Text('route ${s.uri.path}')),
      ),
      GoRoute(
        path: '/:a/:b/:c',
        builder: (_, GoRouterState s) =>
            Scaffold(body: Text('route ${s.uri.path}')),
      ),
      GoRoute(
        path: '/:a/:b',
        builder: (_, GoRouterState s) =>
            Scaffold(body: Text('route ${s.uri.path}')),
      ),
      GoRoute(
        path: '/:a',
        builder: (_, GoRouterState s) =>
            Scaffold(body: Text('route ${s.uri.path}')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authStatusStreamProvider.overrideWithValue(
          Stream<AuthStatus>.value(status),
        ),
        authRepositoryProvider.overrideWithValue(auth ?? FakeAuthRepository()),
        usersRepositoryProvider.overrideWithValue(
          users ?? FakeUsersRepository(),
        ),
        phoneSetupProvider.overrideWithValue(FakePhoneSetup()),
        trackerControlProvider.overrideWithValue(
          tracker ?? FakeTrackerControl(),
        ),
        notificationsRepositoryProvider.overrideWithValue(
          notifications ?? FakeNotificationsRepository(),
        ),
        pushServiceProvider.overrideWithValue(const NoPushService()),
        visitsRepositoryProvider.overrideWithValue(
          visits ?? FakeVisitsRepository(),
        ),
        visitOutboxProvider.overrideWithValue(outbox ?? tempOutbox()),
        ...overrides,
      ],
      child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

/// Opens [page] on top of a blank screen, so it can pop back.
Future<void> pumpPushed(
  WidgetTester tester,
  Widget page, {
  FakeAuthRepository? auth,
  FakeUsersRepository? users,
  FakeTrackerControl? tracker,
  List<Override> overrides = const <Override>[],
  FakeNotificationsRepository? notifications,
  FakeVisitsRepository? visits,
  VisitOutbox? outbox,
  AuthStatus status = const SignedIn(
    userId: 'admin1',
    role: AppRole.admin,
    mustChangePassword: false,
  ),
}) async {
  final GoRouter router = GoRouter(
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: Text('below')),
        routes: <RouteBase>[GoRoute(path: 'page', builder: (_, _) => page)],
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authStatusStreamProvider.overrideWithValue(
          Stream<AuthStatus>.value(status),
        ),
        authRepositoryProvider.overrideWithValue(auth ?? FakeAuthRepository()),
        usersRepositoryProvider.overrideWithValue(
          users ?? FakeUsersRepository(),
        ),
        phoneSetupProvider.overrideWithValue(FakePhoneSetup()),
        trackerControlProvider.overrideWithValue(
          tracker ?? FakeTrackerControl(),
        ),
        notificationsRepositoryProvider.overrideWithValue(
          notifications ?? FakeNotificationsRepository(),
        ),
        pushServiceProvider.overrideWithValue(const NoPushService()),
        visitsRepositoryProvider.overrideWithValue(
          visits ?? FakeVisitsRepository(),
        ),
        visitOutboxProvider.overrideWithValue(outbox ?? tempOutbox()),
        ...overrides,
      ],
      child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  unawaited(router.push('/page'));
  await tester.pumpAndSettle();
}
