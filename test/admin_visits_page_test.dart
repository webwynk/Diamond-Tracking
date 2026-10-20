import 'dart:async';

import 'package:diamond_tracking/core/errors/app_exceptions.dart';
import 'package:diamond_tracking/core/theme/app_theme.dart';
import 'package:diamond_tracking/domain/entities/visit_record.dart';
import 'package:diamond_tracking/features/admin/visits/presentation/admin_visit_details_page.dart';
import 'package:diamond_tracking/features/admin/visits/presentation/admin_visit_photo_viewer.dart';
import 'package:diamond_tracking/features/admin/visits/presentation/admin_visits_page.dart';
import 'package:diamond_tracking/features/admin/visits/presentation/controllers/admin_visits_controller.dart';
import 'package:diamond_tracking/features/admin/visits/presentation/controllers/admin_visits_state.dart';
import 'package:diamond_tracking/features/admin/visits/presentation/controllers/visit_photo_source.dart';
import 'package:diamond_tracking/features/admin/visits/presentation/widgets/admin_visits_card.dart';
import 'package:diamond_tracking/shared/widgets/app_skeletons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_admin_visits.dart';

void main() {
  late FakeAdminVisitRepository repo;

  /// [tall] makes the screen big enough to show a whole page without scrolling.
  Future<void> pumpPage(WidgetTester tester, {bool tall = false}) async {
    tester.view.physicalSize = Size(1080, tall ? 20000 : 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adminVisitRepositoryProvider.overrideWithValue(repo),
          // Nobody signed in: a visit with a photo shows "unavailable".
          visitPhotoRequestProvider.overrideWithValue((_, _) => null),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const AdminVisitsPage(
            employeeId: 'emp-1',
            employeeName: 'Suresh Kumar',
            employeeCode: 'DA-001',
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  group('AdminVisitsPage', () {
    testWidgets('shows a skeleton while the first page loads', (tester) async {
      repo = FakeAdminVisitRepository([])..gate = Completer<void>();

      await pumpPage(tester);

      expect(find.byType(AppListSkeleton), findsOneWidget);
      expect(find.text('Visits'), findsOneWidget);
      expect(find.text('Suresh Kumar · DA-001'), findsOneWidget);
      repo.gate!.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('an employee with no visits sees an empty state', (
      tester,
    ) async {
      repo = FakeAdminVisitRepository([]);

      await pumpPage(tester);

      expect(find.text('No visits yet'), findsOneWidget);
    });

    testWidgets('a failed load is an error with Retry, not an empty list', (
      tester,
    ) async {
      repo = FakeAdminVisitRepository([adminVisit('a')])
        ..failure = const NetworkException();

      await pumpPage(tester);

      expect(find.text("Couldn't load visits"), findsOneWidget);
      expect(find.text('No visits yet'), findsNothing);

      repo.failure = null;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('visit-tile-a')), findsOneWidget);
    });

    testWidgets('each row says what it is, in IST, and why a photo is absent', (
      tester,
    ) async {
      repo = FakeAdminVisitRepository([
        adminVisit('with-photo', minute: 3, photoPublicId: 'visit-x'),
        adminVisit('no-photo', minute: 2, note: 'Seeds delivered'),
        adminVisit(
          'removed',
          minute: 1,
          storeName: null,
          photoRemovedAt: DateTime.utc(2027, 1, 20),
        ),
      ]);

      await pumpPage(tester);

      // 04:03 UTC is 9:33 AM in India.
      expect(find.text('18 Oct 2026 · 9:33 AM'), findsOneWidget);
      expect(find.text('Seeds delivered'), findsOneWidget);
      expect(find.byKey(const Key('visit-caption-no-photo')), findsOneWidget);
      expect(find.text('No photo'), findsOneWidget);
      expect(find.text('Photo removed after 90 days'), findsOneWidget);
      // No store name falls back to a plain label.
      expect(find.text('Visit'), findsOneWidget);
      // A row with a photo has no "no photo" caption.
      expect(find.byKey(const Key('visit-caption-with-photo')), findsNothing);
      expect(find.byKey(const Key('visit-photo-retry')), findsOneWidget);
    });

    testWidgets('scrolling to the end loads the next page by itself', (
      tester,
    ) async {
      repo = FakeAdminVisitRepository([
        for (var i = 24; i >= 0; i--) adminVisit('v$i', minute: i),
      ]);
      await pumpPage(tester);
      expect(repo.calls, hasLength(1));

      await tester.drag(
        find.byKey(const Key('visits-list')),
        const Offset(0, -4000),
      );
      await tester.pumpAndSettle();

      expect(repo.calls, hasLength(2));
      expect(repo.calls.last.afterId, 'v5');
      await tester.drag(
        find.byKey(const Key('visits-list')),
        const Offset(0, -4000),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('visit-tile-v0')), findsOneWidget);
      expect(find.byKey(const Key('btn-visits-load-more')), findsNothing);
    });

    testWidgets('when nothing needs scrolling a button loads older visits', (
      tester,
    ) async {
      repo = FakeAdminVisitRepository([
        for (var i = 24; i >= 0; i--) adminVisit('v$i', minute: i),
      ]);
      await pumpPage(tester, tall: true);
      expect(find.byKey(const Key('visit-tile-v5')), findsOneWidget);
      expect(find.byKey(const Key('visit-tile-v0')), findsNothing);

      await tester.tap(find.byKey(const Key('btn-visits-load-more')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('visit-tile-v0')), findsOneWidget);
      expect(find.byKey(const Key('btn-visits-load-more')), findsNothing);
    });

    testWidgets('a failed older page says so and offers Try again', (
      tester,
    ) async {
      repo = FakeAdminVisitRepository([
        for (var i = 24; i >= 0; i--) adminVisit('v$i', minute: i),
      ]);
      await pumpPage(tester, tall: true);
      repo.failure = const NetworkException();

      await tester.tap(find.byKey(const Key('btn-visits-load-more')));
      await tester.pumpAndSettle();

      expect(find.text("Couldn't load older visits."), findsOneWidget);
      expect(find.byKey(const Key('visit-tile-v24')), findsOneWidget);

      repo.failure = null;
      await tester.tap(find.byKey(const Key('btn-visits-retry-more')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('visit-tile-v0')), findsOneWidget);
      expect(find.text("Couldn't load older visits."), findsNothing);
    });

    testWidgets('a tap opens the visit with everything about it', (
      tester,
    ) async {
      repo = FakeAdminVisitRepository([
        adminVisit('a', note: 'Shop was closed, left a message'),
      ]);
      await pumpPage(tester);

      await tester.tap(find.byKey(const Key('visit-tile-a')));
      await tester.pumpAndSettle();

      expect(find.text('Visit details'), findsOneWidget);
      expect(find.text('Suresh Kumar'), findsOneWidget);
      expect(find.text('Kisan Kendra'), findsOneWidget);
      expect(find.text('18 Oct 2026 · 9:30 AM'), findsOneWidget);
      expect(find.text('Shop was closed, left a message'), findsOneWidget);
      expect(find.text('19.99750, 73.78980  (± 4 m)'), findsOneWidget);
      expect(find.byKey(const Key('visit-map-card')), findsOneWidget);
      expect(find.text('No photo'), findsOneWidget);

      await tester.tap(find.byKey(const Key('btn-visit-details-back')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('visits-list')), findsOneWidget);
    });

    testWidgets('a visit with no note says so', (tester) async {
      repo = FakeAdminVisitRepository([adminVisit('a')]);
      await pumpPage(tester);

      await tester.tap(find.byKey(const Key('visit-tile-a')));
      await tester.pumpAndSettle();

      expect(find.text('No note'), findsOneWidget);
    });

    testWidgets('a visit with no photo cannot be enlarged', (tester) async {
      repo = FakeAdminVisitRepository([adminVisit('plain')]);
      await pumpPage(tester);

      await tester.tap(find.byKey(const Key('visit-tile-plain')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('visit-photo-enlarge')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('btn-visit-photo-close')), findsNothing);
      expect(find.text('Visit details'), findsOneWidget);
    });

    testWidgets('a photo that cannot load is tap-to-retry, not a blank', (
      tester,
    ) async {
      repo = FakeAdminVisitRepository([
        adminVisit('pic', photoPublicId: 'visit-x'),
      ]);
      await pumpPage(tester);

      await tester.tap(find.byKey(const Key('visit-tile-pic')));
      await tester.pumpAndSettle();

      expect(find.text('Photo unavailable. Tap to try again.'), findsOneWidget);
      await tester.tap(find.byKey(const Key('visit-photo-retry')));
      await tester.pumpAndSettle();
      expect(find.text('Photo unavailable. Tap to try again.'), findsOneWidget);
      expect(find.byKey(const Key('btn-visit-photo-close')), findsNothing);
    });
  });

  group('AdminVisitPhotoViewer', () {
    testWidgets('opens full screen and closes', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            visitPhotoRequestProvider.overrideWithValue((_, _) => null),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: Builder(
              builder: (context) => TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => AdminVisitPhotoViewer(
                      visit: adminVisit('pic', photoPublicId: 'visit-x'),
                    ),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('btn-visit-photo-close')), findsOneWidget);

      await tester.tap(find.byKey(const Key('btn-visit-photo-close')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('btn-visit-photo-close')), findsNothing);
      expect(find.text('open'), findsOneWidget);
    });
  });

  group('AdminVisitsCard (employee profile)', () {
    Future<void> pumpCard(
      WidgetTester tester,
      AdminVisitsState state, {
      VoidCallback? onViewAll,
      ValueChanged<VisitRecord>? onSelect,
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            visitPhotoRequestProvider.overrideWithValue((_, _) => null),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: SingleChildScrollView(
                child: AdminVisitsCard(
                  state: state,
                  onViewAll: onViewAll ?? () {},
                  onVisitSelected: onSelect ?? (_) {},
                ),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('says loading, failed or none instead of staying blank', (
      tester,
    ) async {
      await pumpCard(tester, const AdminVisitsState());
      expect(find.text('Loading…'), findsOneWidget);

      await pumpCard(
        tester,
        const AdminVisitsState(load: AdminVisitsLoad.failed),
      );
      expect(find.text("Couldn't load visits."), findsOneWidget);

      await pumpCard(
        tester,
        const AdminVisitsState(load: AdminVisitsLoad.loaded),
      );
      expect(find.text('No visits yet.'), findsOneWidget);
    });

    testWidgets('shows only the latest three and opens the rest on View all', (
      tester,
    ) async {
      var viewAll = 0;
      VisitRecord? selected;
      await pumpCard(
        tester,
        AdminVisitsState(
          load: AdminVisitsLoad.loaded,
          visits: [for (var i = 4; i >= 0; i--) adminVisit('v$i', minute: i)],
          hasMore: true,
        ),
        onViewAll: () => viewAll++,
        onSelect: (v) => selected = v,
      );

      expect(find.byKey(const Key('visit-tile-v4')), findsOneWidget);
      expect(find.byKey(const Key('visit-tile-v2')), findsOneWidget);
      expect(find.byKey(const Key('visit-tile-v1')), findsNothing);

      await tester.tap(find.byKey(const Key('btn-visits-view-all')));
      expect(viewAll, 1);

      await tester.tap(find.byKey(const Key('visit-tile-v3')));
      expect(selected?.id, 'v3');
    });
  });

  group('AdminVisitDetailsPage', () {
    testWidgets('renders all visit details and map card safely with valid coordinates', (
      tester,
    ) async {
      final visit = adminVisit('visit-100', minute: 10, storeName: 'Kisan Krishi Kendra');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            visitPhotoRequestProvider.overrideWithValue((_, _) => null),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: AdminVisitDetailsPage(
              visit: visit,
              employeeName: 'Ramesh Patil',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Visit details'), findsOneWidget);
      expect(find.text('Ramesh Patil'), findsOneWidget);
      expect(find.text('Kisan Krishi Kendra'), findsOneWidget);
      expect(find.byKey(const Key('visit-map-card')), findsOneWidget);
    });

    testWidgets('handles zero/invalid GPS coordinates gracefully without crashing', (
      tester,
    ) async {
      final visit = VisitRecord(
        id: 'visit-zero',
        sessionId: 'session-zero',
        employeeId: 'emp-1',
        storeName: 'Test Center',
        latitude: 0.0,
        longitude: 0.0,
        capturedAt: DateTime.utc(2026, 10, 20, 10, 30),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            visitPhotoRequestProvider.overrideWithValue((_, _) => null),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: AdminVisitDetailsPage(
              visit: visit,
              employeeName: 'Ramesh Patil',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Visit details'), findsOneWidget);
      expect(find.text('Coordinates unavailable'), findsOneWidget);
      expect(find.byKey(const Key('visit-map-card-empty')), findsOneWidget);
    });
  });
}

