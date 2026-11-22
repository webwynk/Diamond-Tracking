import 'package:diamond_tracking/core/links/open_link.dart';
import 'package:diamond_tracking/features/auth/domain/auth_status.dart';
import 'package:diamond_tracking/features/routes/domain/geo_point.dart';
import 'package:diamond_tracking/features/visits/domain/visit.dart';
import 'package:diamond_tracking/features/visits/presentation/visit_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';
import '../../support/pump.dart';

void main() {
  const SignedIn employee = SignedIn(
    userId: 'u',
    role: AppRole.employee,
    mustChangePassword: false,
  );

  // Sat 21 Nov 2026, 8:12 AM IST.
  final DateTime when = DateTime.utc(2026, 11, 21, 2, 42);

  Visit visit({
    GeoPoint? at = const GeoPoint(22.72514, 88.47213),
    String? note = 'Order taken: 20 bags urea.',
    bool mocked = false,
    int? accuracy,
    bool removed = false,
  }) => Visit(
    id: 'v1',
    storeName: 'Maa Tara Agro Store',
    fromGallery: at == null,
    capturedAt: when,
    location: at,
    note: note,
    mocked: mocked,
    accuracyM: accuracy,
    photoRemoved: removed,
  );

  late FakeVisitsRepository visits;
  late List<Uri> opened;
  setUp(() {
    visits = FakeVisitsRepository();
    opened = <Uri>[];
  });

  Future<void> show(
    WidgetTester tester,
    Visit v, {
    AuthStatus status = employee,
    bool canOpen = true,
  }) => pumpPage(
    tester,
    VisitDetailPage(visit: v),
    visits: visits,
    status: status,
    overrides: <Override>[
      openLinkProvider.overrideWithValue((Uri uri) async {
        opened.add(uri);
        return canOpen;
      }),
    ],
  );

  testWidgets('a camera visit: photo, store, date, note, place, Maps', (
    WidgetTester tester,
  ) async {
    await show(tester, visit());
    expect(find.text('Maa Tara Agro Store'), findsOneWidget);
    expect(find.text('Camera photo'), findsOneWidget);
    expect(find.text('Sat, 21 Nov'), findsOneWidget);
    expect(find.text('8:12 AM'), findsOneWidget);
    expect(find.text('Order taken: 20 bags urea.'), findsOneWidget);
    expect(find.text('Place saved'), findsOneWidget);
    expect(find.text('22.72514, 88.47213'), findsOneWidget);
    expect(find.textContaining('stays in your history'), findsOneWidget);
    // The full photo is loaded, not the small one.
    expect(visits.photosAsked, contains('v1'));

    await tester.tap(find.text('Maps'));
    await tester.pumpAndSettle();
    expect(opened.single.host, 'www.google.com');
    expect(opened.single.queryParameters['query'], '22.725140,88.472130');
  });

  testWidgets('Maps that cannot open says so', (WidgetTester tester) async {
    await show(tester, visit(), canOpen: false);
    await tester.tap(find.text('Maps'));
    await tester.pumpAndSettle();
    expect(find.text("Couldn't open Google Maps"), findsOneWidget);
  });

  testWidgets('a gallery visit has no place and no Maps; no note, no box', (
    WidgetTester tester,
  ) async {
    await show(tester, visit(at: null, note: '  '));
    expect(find.text('Gallery photo'), findsOneWidget);
    expect(find.text('No place saved'), findsOneWidget);
    expect(find.text('Maps'), findsNothing);
    expect(find.bySemanticsLabel(RegExp('^Note')), findsNothing);
  });

  testWidgets('a fake location and a weak one are marked', (
    WidgetTester tester,
  ) async {
    await show(tester, visit(mocked: true));
    expect(find.text('Fake GPS'), findsOneWidget);
    expect(find.textContaining('fake-location app'), findsOneWidget);

    await show(tester, visit(accuracy: 300));
    expect(find.text('Place saved, approximate'), findsOneWidget);
    expect(find.text('22.72514, 88.47213 · ±300 m'), findsOneWidget);
  });

  testWidgets('after 90 days the photo is gone and the visit stays', (
    WidgetTester tester,
  ) async {
    await show(tester, visit(removed: true));
    expect(find.text('Photo deleted after 90 days'), findsOneWidget);
    expect(find.bySemanticsLabel('View full screen'), findsNothing);
    expect(visits.photosAsked, isEmpty);
  });

  testWidgets('full screen shows the photo alone and closes', (
    WidgetTester tester,
  ) async {
    await show(tester, visit());
    await tester.tap(find.bySemanticsLabel('View full screen'));
    await tester.pumpAndSettle();
    expect(find.text('Maa Tara Agro Store'), findsNothing);
    await tester.tap(find.bySemanticsLabel('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Maa Tara Agro Store'), findsOneWidget);
  });

  testWidgets('the admin reads "the history"', (WidgetTester tester) async {
    await show(
      tester,
      visit(),
      status: const SignedIn(
        userId: 'a',
        role: AppRole.admin,
        mustChangePassword: false,
      ),
    );
    expect(find.textContaining('stays in the history'), findsOneWidget);
  });

  for (final double width in <double>[360, 390, 430]) {
    testWidgets('visit detail fits a $width wide phone', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = Size(width * 3, 760 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await show(
        tester,
        Visit(
          id: 'v1',
          storeName: 'Sri Sri Maa Annapurna Krishi Seva Kendra and Traders',
          fromGallery: false,
          capturedAt: when,
          location: const GeoPoint(22.72514, 88.47213),
          note: 'Order taken: 20 bags urea. ' * 6,
          accuracyM: 1200,
        ),
      );
      expect(tester.takeException(), isNull);
    });
  }
}
