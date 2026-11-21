import 'dart:io';
import 'dart:typed_data';

import 'package:diamond_tracking/core/supabase/supabase_providers.dart';
import 'package:diamond_tracking/core/time/clock_providers.dart';
import 'package:diamond_tracking/features/auth/domain/auth_status.dart';
import 'package:diamond_tracking/features/duty/application/duty_providers.dart';
import 'package:diamond_tracking/features/duty/domain/duty_day.dart';
import 'package:diamond_tracking/features/duty/presentation/home_page.dart';
import 'package:diamond_tracking/features/requests/application/requests_providers.dart';
import 'package:diamond_tracking/features/routes/application/route_providers.dart';
import 'package:diamond_tracking/features/routes/domain/geo_point.dart';
import 'package:diamond_tracking/features/routes/presentation/day_route_page.dart';
import 'package:diamond_tracking/features/visits/application/visit_sender.dart';
import 'package:diamond_tracking/features/visits/application/visits_providers.dart';
import 'package:diamond_tracking/features/visits/data/current_location.dart';
import 'package:diamond_tracking/features/visits/data/visit_outbox.dart';
import 'package:diamond_tracking/features/visits/domain/visit.dart';
import 'package:diamond_tracking/features/visits/domain/visit_failure.dart';
import 'package:diamond_tracking/features/visits/presentation/add_visit_page.dart';
import 'package:diamond_tracking/features/visits/presentation/visit_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../support/fakes.dart';
import '../../support/pump.dart';

void main() {
  // 13:30 IST on 20 Nov 2026.
  final DateTime now = DateTime.utc(2026, 11, 20, 8);
  const SignedIn employee = SignedIn(
    userId: 'u',
    role: AppRole.employee,
    mustChangePassword: false,
  );

  late FakeVisitsRepository visits;
  late FakePhotoPicker picker;
  late FakeLocation location;
  late VisitOutbox outbox;
  setUp(() {
    visits = FakeVisitsRepository();
    picker = FakePhotoPicker();
    location = FakeLocation();
    outbox = tempOutbox();
  });

  List<Override> overrides() => <Override>[
    photoPickerProvider.overrideWithValue(picker),
    currentLocationProvider.overrideWithValue(location),
    serverClockProvider.overrideWithValue(FixedClock(now).clock),
  ];

  void tall(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
  }

  Future<void> openAddVisit(WidgetTester tester) async {
    tall(tester);
    await pumpPushed(
      tester,
      const AddVisitPage(dayId: 5),
      status: employee,
      visits: visits,
      outbox: outbox,
      overrides: overrides(),
    );
  }

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.text('Save visit'));
    await tester.pumpAndSettle();
  }

  testWidgets('a camera photo saves the place it was taken', (
    WidgetTester tester,
  ) async {
    await openAddVisit(tester);

    await save(tester);
    expect(find.text(VisitFailure.storeNameRequired.message), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'Krishi Kendra');
    await save(tester);
    expect(find.text(VisitFailure.photoRequired.message), findsOneWidget);

    await tester.tap(find.text('Camera'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Location found: 22.50000, 88.30000'), findsOne);
    await tester.enterText(find.byType(TextField).at(1), 'Order taken');
    await save(tester);

    expect(visits.uploads, 1);
    expect(visits.lastLocation, const GeoPoint(22.5, 88.3));
    final Visit saved = visits.byDay[5]!.single;
    expect(saved.storeName, 'Krishi Kendra');
    expect(saved.note, 'Order taken');
    expect(find.text('below'), findsOneWidget); // closed
  });

  testWidgets('a fake camera location is saved as fake', (
    WidgetTester tester,
  ) async {
    location.mocked = true;
    await openAddVisit(tester);
    await tester.enterText(find.byType(TextField).first, 'Krishi Kendra');
    await tester.tap(find.text('Camera'));
    await tester.pumpAndSettle();
    await save(tester);
    expect(visits.lastMocked, isTrue);
    expect(
      visitPlace(visits.byDay[5]!.single),
      'Fake GPS: camera photo at 22.50000, 88.30000',
    );
  });

  testWidgets('a real camera location is not marked', (
    WidgetTester tester,
  ) async {
    await openAddVisit(tester);
    await tester.enterText(find.byType(TextField).first, 'Krishi Kendra');
    await tester.tap(find.text('Camera'));
    await tester.pumpAndSettle();
    await save(tester);
    expect(visits.lastMocked, isFalse);
  });

  testWidgets('a poor location is saved with its accuracy (L59)', (
    WidgetTester tester,
  ) async {
    location.accuracyM = 300;
    await openAddVisit(tester);
    await tester.enterText(find.byType(TextField).first, 'Krishi Kendra');
    await tester.tap(find.text('Camera'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('22.50000, 88.30000 (approximate, ±300 m)'),
      findsOneWidget,
    );
    await save(tester);
    expect(visits.lastAccuracyM, 300);
    expect(
      visitPlace(visits.byDay[5]!.single),
      'Camera photo at 22.50000, 88.30000 (approximate, ±300 m)',
    );
  });

  testWidgets('a good location is not marked approximate (L59)', (
    WidgetTester tester,
  ) async {
    location.accuracyM = 12;
    await openAddVisit(tester);
    await tester.enterText(find.byType(TextField).first, 'Krishi Kendra');
    await tester.tap(find.text('Camera'));
    await tester.pumpAndSettle();
    await save(tester);
    expect(visits.lastAccuracyM, 12);
    expect(
      visitPlace(visits.byDay[5]!.single),
      'Camera photo at 22.50000, 88.30000',
    );
  });

  test('a last known location counts only for 2 minutes (L59)', () {
    final DateTime now = DateTime.utc(2026, 11, 20, 6);
    expect(
      lastKnownIsFresh(now.subtract(const Duration(seconds: 90)), now),
      isTrue,
    );
    expect(
      lastKnownIsFresh(now.subtract(const Duration(minutes: 2)), now),
      isFalse,
    );
    expect(
      lastKnownIsFresh(now.subtract(const Duration(minutes: 4)), now),
      isFalse,
    );
  });

  testWidgets('a gallery photo saves no place', (WidgetTester tester) async {
    await openAddVisit(tester);
    await tester.enterText(find.byType(TextField).first, 'Agro Store');
    await tester.tap(find.text('Gallery'));
    await tester.pumpAndSettle();
    expect(find.text('Gallery photo: no location is saved.'), findsOneWidget);
    await save(tester);

    expect(location.calls, 0);
    expect(visits.lastLocation, isNull);
    expect(visits.byDay[5]!.single.fromGallery, isTrue);
  });

  testWidgets('a camera photo without a location cannot be saved until found', (
    WidgetTester tester,
  ) async {
    location = FakeLocation(<GeoPoint?>[null, const GeoPoint(22.6, 88.4)]);
    await openAddVisit(tester);
    await tester.enterText(find.byType(TextField).first, 'Agro Store');
    await tester.tap(find.text('Camera'));
    await tester.pumpAndSettle();
    expect(find.text('Location not found.'), findsOneWidget);
    await save(tester);
    expect(find.text(VisitFailure.noLocation.message), findsOneWidget);
    expect(visits.uploads, 0);

    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    await save(tester);
    expect(visits.lastLocation, const GeoPoint(22.6, 88.4));
  });

  Future<void> fillGalleryVisit(WidgetTester tester) async {
    await openAddVisit(tester);
    await tester.enterText(find.byType(TextField).first, 'Agro Store');
    await tester.tap(find.text('Gallery'));
    await tester.pumpAndSettle();
  }

  VisitSender sender() => VisitSender(outbox, visits);

  testWidgets('with no internet the visit is kept on the phone, then sent '
      'later without a second upload (M10)', (WidgetTester tester) async {
    visits.addError = const SocketException('offline');
    await fillGalleryVisit(tester);
    await save(tester);

    expect(find.text('below'), findsOneWidget); // closed
    expect(find.textContaining('kept on the phone'), findsOneWidget);
    final PendingVisit kept = (await outbox.pending()).single;
    expect(kept.storeName, 'Agro Store');
    expect(kept.photoId, isNotNull); // uploaded before the save failed
    expect(visits.uploads, 1);

    visits.addError = null;
    expect(await sender().sendAll('u'), 1);
    expect(visits.uploads, 1);
    expect(visits.byDay[5], hasLength(1));
    expect(await outbox.pending(), isEmpty);
  });

  testWidgets('a photo that did not upload waits on the phone too (M10)', (
    WidgetTester tester,
  ) async {
    visits.uploadError = const SocketException('offline');
    await fillGalleryVisit(tester);
    await save(tester);

    expect(find.text('below'), findsOneWidget);
    expect((await outbox.pending()).single.photoId, isNull);

    visits.uploadError = null;
    expect(await sender().sendAll('u'), 1);
    expect(visits.uploads, 1);
    expect(await outbox.pending(), isEmpty);
  });

  testWidgets('a detail to fix keeps the page and the uploaded photo', (
    WidgetTester tester,
  ) async {
    visits.addError = const PostgrestException(message: 'note_too_long');
    await fillGalleryVisit(tester);
    await save(tester);
    expect(find.text(VisitFailure.noteTooLong.message), findsOneWidget);
    expect(await outbox.pending(), isEmpty);

    visits.addError = null;
    await save(tester);
    expect(visits.uploads, 1);
    expect(visits.byDay[5], hasLength(1));
  });

  test(
    'sending stops while offline, and drops a visit refused for good',
    () async {
      Future<void> keep(String store, DateTime at) => outbox.add(
        PendingVisit(
          id: VisitOutbox.newId(),
          userId: 'u',
          storeName: store,
          capturedAt: at,
        ),
        Uint8List.fromList(<int>[1, 2, 3]),
      );
      await keep('First', DateTime.utc(2026, 11, 20, 5));
      await keep('Second', DateTime.utc(2026, 11, 20, 6));

      visits.uploadError = const SocketException('offline');
      expect(await sender().sendAll('u'), 0);
      expect(await outbox.pending(), hasLength(2));

      visits.uploadError = null;
      visits.addError = const PostgrestException(message: 'not_on_duty');
      expect(await sender().sendAll('u'), 0);
      expect(await outbox.pending(), isEmpty);
    },
  );

  test('a waiting visit keeps its accuracy until sent (L59)', () async {
    await outbox.add(
      PendingVisit(
        id: VisitOutbox.newId(),
        userId: 'u',
        storeName: 'Shop',
        location: const GeoPoint(22.5, 88.3),
        accuracyM: 250,
        capturedAt: DateTime.utc(2026, 11, 20, 5),
      ),
      Uint8List.fromList(<int>[1, 2, 3]),
    );
    expect((await outbox.pending()).single.accuracyM, 250);
    expect(await sender().sendAll('u'), 1);
    expect(visits.lastAccuracyM, 250);
  });

  test('over the daily photo limit a visit waits for tomorrow (L62)', () async {
    await outbox.add(
      PendingVisit(
        id: VisitOutbox.newId(),
        userId: 'u',
        storeName: 'Shop',
        capturedAt: DateTime.utc(2026, 11, 20, 5),
      ),
      Uint8List.fromList(<int>[1]),
    );
    visits.uploadError = const FunctionException(
      status: 429,
      details: <String, String>{'error': 'photo_limit'},
    );
    expect(await sender().sendAll('u'), 0);
    expect(await outbox.pending(), hasLength(1));
    visits.uploadError = null;
    expect(await sender().sendAll('u'), 1);
    expect(await outbox.pending(), isEmpty);
  });

  test('only the signed-in person\'s waiting visits are sent', () async {
    await outbox.add(
      PendingVisit(
        id: VisitOutbox.newId(),
        userId: 'someone-else',
        storeName: 'Shop',
        capturedAt: DateTime.utc(2026, 11, 20, 5),
      ),
      Uint8List.fromList(<int>[1]),
    );
    expect(await sender().sendAll('u'), 0);
    expect(visits.uploads, 0);
    expect(await outbox.pending(), hasLength(1));
  });

  test('server errors read as plain words', () {
    expect(
      mapVisitError(const PostgrestException(message: 'not_on_duty')),
      VisitFailure.notOnDuty,
    );
    expect(
      mapVisitError(const PostgrestException(message: 'location_required')),
      VisitFailure.noLocation,
    );
    expect(
      mapVisitError(const PostgrestException(message: 'signed_in_elsewhere')),
      VisitFailure.signedInElsewhere,
    );
    expect(
      mapVisitError(
        const FunctionException(
          status: 429,
          details: <String, String>{'error': 'photo_limit'},
        ),
      ),
      VisitFailure.photoLimit,
    );
    expect(mapVisitError(Exception('x')), VisitFailure.unknown);
  });

  test('a visit row reads its place and photo state', () {
    final Visit v = Visit.fromRow(<String, dynamic>{
      'id': 'a',
      'store_name': 'Shop',
      'note': null,
      'from_gallery': false,
      'lat_e6': 22572610,
      'lng_e6': 88363890,
      'photo_id': 'visit-a',
      'photo_removed_at': '2026-11-20T00:00:00Z',
      'captured_at': '2026-08-20T05:00:00Z',
      'accuracy_m': 150,
    });
    expect(formatPoint(v.location!), '22.57261, 88.36389');
    expect(v.showsPhoto, isFalse);
    expect(v.accuracyM, 150);
    expect(v.isApproximate, isTrue);
  });

  group('lists', () {
    Visit visit(String id, String store, {GeoPoint? at}) => Visit(
      id: id,
      storeName: store,
      fromGallery: at == null,
      location: at,
      capturedAt: DateTime.utc(2026, 11, 20, 6),
    );

    testWidgets('home shows today\'s visits and Add visit while on duty', (
      WidgetTester tester,
    ) async {
      tall(tester);
      final FakeDutyRepository duty = FakeDutyRepository()
        ..today = DutyDay(
          id: 5,
          day: DateTime.utc(2026, 11, 20),
          status: DayStatus.onDuty,
          dutyOnAt: DateTime.utc(2026, 11, 20, 1, 30),
        );
      visits.byDay[5] = <Visit>[visit('v1', 'Krishi Kendra')];
      await pumpPage(
        tester,
        const HomePage(),
        status: employee,
        visits: visits,
        outbox: outbox,
        overrides: <Override>[
          ...overrides(),
          dutyRepositoryProvider.overrideWithValue(duty),
          deviceIdStoreProvider.overrideWithValue(FakeDeviceIdStore()),
        ],
      );

      expect(find.text('Visits today'), findsOneWidget);
      expect(find.text('Krishi Kendra'), findsOneWidget);
      await tester.tap(find.text('Add visit'));
      await tester.pumpAndSettle();
      expect(find.text('route /home/visit/5'), findsOneWidget);
    });

    testWidgets('home shows a waiting visit and sends it once online (M10)', (
      WidgetTester tester,
    ) async {
      tall(tester);
      final FakeDutyRepository duty = FakeDutyRepository()
        ..today = DutyDay(
          id: 5,
          day: DateTime.utc(2026, 11, 20),
          status: DayStatus.onDuty,
          dutyOnAt: DateTime.utc(2026, 11, 20, 1, 30),
        );
      await outbox.add(
        PendingVisit(
          id: VisitOutbox.newId(),
          userId: 'u',
          storeName: 'Agro Store',
          capturedAt: DateTime.utc(2026, 11, 20, 6),
        ),
        Uint8List.fromList(<int>[1, 2, 3]),
      );
      visits.uploadError = const SocketException('offline');
      await pumpPage(
        tester,
        const HomePage(),
        status: employee,
        visits: visits,
        outbox: outbox,
        overrides: <Override>[
          ...overrides(),
          dutyRepositoryProvider.overrideWithValue(duty),
          deviceIdStoreProvider.overrideWithValue(FakeDeviceIdStore()),
        ],
      );
      expect(find.textContaining('waiting to send'), findsOneWidget);

      // Online again: the next try (once a minute) sends it.
      visits.uploadError = null;
      await tester.pump(const Duration(seconds: 61));
      await tester.pumpAndSettle();
      expect(find.textContaining('waiting to send'), findsNothing);
      expect(find.text('Agro Store'), findsOneWidget);
      expect(await outbox.pending(), isEmpty);
    });

    testWidgets('a day\'s page lists visits and opens one', (
      WidgetTester tester,
    ) async {
      tall(tester);
      final FakeRouteRepository routes = FakeRouteRepository();
      routes.days[7] = DutyDay(
        id: 7,
        userId: 'u',
        day: DateTime.utc(2026, 11, 20),
        status: DayStatus.present,
        dutyOnAt: DateTime.utc(2026, 11, 20, 1, 30),
      );
      visits.byDay[7] = <Visit>[
        visit('v1', 'Krishi Kendra', at: const GeoPoint(22.5, 88.3)),
        visit('v2', 'Agro Store'),
      ];
      await pumpPage(
        tester,
        const DayRoutePage(dayId: 7, personName: 'Asha Roy'),
        visits: visits,
        overrides: <Override>[
          routeRepositoryProvider.overrideWithValue(routes),
          showGoogleMapProvider.overrideWithValue(false),
          serverClockProvider.overrideWithValue(FixedClock(now).clock),
        ],
      );

      expect(find.text('Visits (2)'), findsOneWidget);
      expect(find.textContaining('no location'), findsOneWidget);
      // The list asks for small photos only (L57).
      expect(visits.photosAsked.toSet(), <String>{'v1:small', 'v2:small'});
      await tester.tap(find.text('Krishi Kendra'));
      await tester.pumpAndSettle();
      expect(find.text('Camera photo at 22.50000, 88.30000'), findsOneWidget);
      // The visit page shows the full photo.
      expect(visits.photosAsked, contains('v1'));
    });
  });
}
