import 'package:diamond_tracking/core/app_version.dart';
import 'package:diamond_tracking/features/auth/domain/auth_status.dart';
import 'package:diamond_tracking/features/users/domain/profile.dart';
import 'package:diamond_tracking/features/users/presentation/account_page.dart';
import 'package:flutter/material.dart' show Size;
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';
import '../../support/pump.dart';

void main() {
  final FakeUsersRepository users = FakeUsersRepository(<Profile>[
    profile('admin1', code: 'ADMIN01', name: 'Arjun Sen', role: AppRole.admin),
  ]);
  final List<Override> version = <Override>[
    appVersionProvider.overrideWith((_) async => '2.0.0 (45)'),
  ];

  testWidgets('who, security, app and log out', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 3000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await pumpPage(
      tester,
      const AccountPage(),
      users: users,
      overrides: version,
    );
    expect(find.text('My account'), findsOneWidget);
    expect(find.text('Arjun Sen'), findsOneWidget);
    expect(find.text('AS'), findsOneWidget);
    expect(find.text('ADMIN01'), findsOneWidget);
    expect(find.text('Admin'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);
    // No Firebase values in tests: phone alerts are off.
    expect(find.text('Phone alerts are off in this build'), findsOneWidget);
    expect(find.text('2.0.0 (45)'), findsOneWidget);
    expect(find.text('Log out'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel(RegExp('^Change password')));
    await tester.pumpAndSettle();
    expect(find.text('route /admin/account/password'), findsOneWidget);
  });

  testWidgets('Notifications opens the list', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 3000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await pumpPage(
      tester,
      const AccountPage(),
      users: users,
      overrides: version,
    );
    await tester.tap(find.bySemanticsLabel(RegExp('^Notifications')));
    await tester.pumpAndSettle();
    expect(find.text('route /admin/notifications'), findsOneWidget);
  });

  for (final double width in <double>[360, 390, 430]) {
    testWidgets('fits ${width.toInt()} wide', (WidgetTester tester) async {
      tester.view.physicalSize = Size(width * 3, 800 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await pumpPage(
        tester,
        const AccountPage(),
        users: FakeUsersRepository(<Profile>[
          profile(
            'admin1',
            code: 'ADMIN0123456789',
            name: 'Mohammad Hasanur Rahaman Chowdhury',
            role: AppRole.admin,
          ),
        ]),
        overrides: version,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
