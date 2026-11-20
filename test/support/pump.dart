import 'dart:async';

import 'package:diamond_tracking/core/theme/app_theme.dart';
import 'package:diamond_tracking/features/auth/application/auth_providers.dart';
import 'package:diamond_tracking/features/auth/domain/auth_status.dart';
import 'package:diamond_tracking/features/users/application/users_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'fakes.dart';

/// Pumps [page] alone, with fakes, under a tiny router so push/pop work.
/// Other routes show their path as text.
Future<void> pumpPage(
  WidgetTester tester,
  Widget page, {
  FakeAuthRepository? auth,
  FakeUsersRepository? users,
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
      ],
      child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  unawaited(router.push('/page'));
  await tester.pumpAndSettle();
}
