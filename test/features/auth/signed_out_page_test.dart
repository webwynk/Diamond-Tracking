import 'package:diamond_tracking/features/auth/application/auth_providers.dart';
import 'package:diamond_tracking/features/auth/domain/auth_status.dart';
import 'package:diamond_tracking/features/auth/presentation/signed_out_page.dart';
import 'package:diamond_tracking/shared/ds/ds_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final Size phone in const <Size>[Size(360, 740), Size(430, 932)]) {
    testWidgets('says why, and "Sign in again" moves on '
        '(${phone.width.toInt()} wide)', (WidgetTester tester) async {
      tester.view.physicalSize = phone;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final ProviderContainer container = ProviderContainer(
        overrides: [
          authStatusStreamProvider.overrideWithValue(
            Stream<AuthStatus>.fromIterable(const <AuthStatus>[
              SignedIn(
                userId: 'u',
                role: AppRole.employee,
                mustChangePassword: false,
              ),
              SignedOut(),
            ]),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.listen(authStatusProvider, (_, _) {});
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: SignedOutPage()),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        container.read(authStatusProvider),
        const SignedOut(unexpected: true),
      );
      expect(find.textContaining('You were signed out.'), findsOneWidget);
      expect(find.textContaining('Tell your admin'), findsOneWidget);
      expect(tester.takeException(), isNull);

      final Finder again = find.widgetWithText(DsButton, 'Sign in again');
      await tester.ensureVisible(again);
      await tester.pumpAndSettle();
      await tester.tap(again);
      await tester.pump();
      expect(container.read(authStatusProvider), const SignedOut());
    });
  }
}
