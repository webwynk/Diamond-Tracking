import 'package:diamond_tracking/core/services/camera_service.dart';
import 'package:diamond_tracking/core/theme/app_theme.dart';
import 'package:diamond_tracking/domain/entities/duty_session.dart';
import 'package:diamond_tracking/domain/entities/location_point.dart';
import 'package:diamond_tracking/domain/entities/visit_record.dart';
import 'package:diamond_tracking/features/duty/presentation/controllers/duty_controller.dart';
import 'package:diamond_tracking/features/duty/presentation/controllers/duty_state.dart';
import 'package:diamond_tracking/features/map/presentation/employee_map_page.dart';
import 'package:diamond_tracking/features/visits/presentation/controllers/visit_capture_controller.dart';
import 'package:diamond_tracking/features/visits/presentation/visit_capture_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/local_visit_repository.dart';

/// Mock CameraService for test environment without real camera hardware.
class MockCameraService implements CameraService {
  MockCameraService({this.mockPath = '/data/user/0/mock_farm_photo.jpg'});

  String? mockPath;

  @override
  Future<String?> capturePhoto({
    double maxWidth = 1280,
    double maxHeight = 1280,
    int imageQuality = 85,
  }) async {
    return mockPath;
  }
}

class TestDutyNotifier extends DutyNotifier {
  TestDutyNotifier(this._initialState);
  final DutyScreenState _initialState;

  @override
  DutyScreenState build() => _initialState;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VisitRecord', () {
    final row = <String, dynamic>{
      'id': 'visit-101',
      'session_id': 'session-202',
      'employee_id': 'emp-303',
      'store_name': 'Shivpuri Farm',
      'note': 'Checked soil moisture',
      'latitude': 19.9975,
      'longitude': 73.7898,
      'accuracy': 3,
      'captured_at': '2026-10-18T04:00:00+00:00',
      'created_at': '2026-10-18T04:00:05+00:00',
      'photo_public_id': 'visit-abc',
      'photo_attached_at': '2026-10-18T04:01:00+00:00',
      'photo_removed_at': null,
    };

    test('reads a row of public.visits', () {
      final record = VisitRecord.fromMap(row);

      expect(record.id, 'visit-101');
      expect(record.sessionId, 'session-202');
      expect(record.employeeId, 'emp-303');
      expect(record.storeName, 'Shivpuri Farm');
      expect(record.note, 'Checked soil moisture');
      expect(record.latitude, 19.9975);
      expect(record.accuracy, 3.0);
      expect(record.capturedAt, DateTime.utc(2026, 10, 18, 4));
      expect(record.hasRemotePhoto, isTrue);
    });

    test('a row with no photo, store name or note is a plain visit', () {
      final record = VisitRecord.fromMap(<String, dynamic>{
        ...row,
        'store_name': null,
        'note': null,
        'photo_public_id': null,
        'photo_attached_at': null,
      });

      expect(record.storeName, isNull);
      expect(record.note, isNull);
      expect(record.hasRemotePhoto, isFalse);
      expect(record.localPhotoPath, isNull);
    });

    test('a removed photo is not a remote photo', () {
      final record = VisitRecord.fromMap(<String, dynamic>{
        ...row,
        'photo_public_id': null,
        'photo_removed_at': '2026-11-20T00:00:00+00:00',
      });

      expect(record.hasRemotePhoto, isFalse);
      expect(record.photoRemovedAt, isNotNull);
    });

    test('copyWith changes what it is given and keeps the rest', () {
      final record = VisitRecord(
        id: 'visit-1',
        sessionId: 'sess-1',
        employeeId: 'emp-1',
        storeName: 'Farm A',
        latitude: 20.0,
        longitude: 74.0,
        capturedAt: DateTime.now(),
      );

      final updated = record.copyWith(synced: true, note: 'Left samples');

      expect(updated.synced, isTrue);
      expect(updated.note, 'Left samples');
      expect(updated.storeName, 'Farm A');
      expect(updated.sessionId, 'sess-1');
    });
  });

  group('LocalVisitRepository Tests', () {
    test('records visit, retrieves by session, and marks synced', () async {
      final repo = LocalVisitRepository();
      final record = VisitRecord(
        id: 'v1',
        sessionId: 'session-alpha',
        employeeId: 'emp-1',
        storeName: 'Nashik Vineyard',
        latitude: 20.0,
        longitude: 73.8,
        capturedAt: DateTime.now(),
      );

      await repo.recordVisit(record);

      final sessionVisits = await repo.getVisitsForSession('session-alpha');
      expect(sessionVisits.length, 1);
      expect(sessionVisits.first.id, 'v1');

      final unsynced = await repo.getUnsyncedVisits();
      expect(unsynced.length, 1);

      await repo.markVisitSynced('v1');
      final afterSync = await repo.getUnsyncedVisits();
      expect(afterSync.isEmpty, true);
    });
  });

  group('VisitCaptureController Notifier Tests', () {
    test('initializes visit state with store name and coordinate metadata', () {
      final container = ProviderContainer(
        overrides: [
          cameraServiceProvider.overrideWithValue(MockCameraService()),
          visitRepositoryProvider.overrideWithValue(LocalVisitRepository()),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(visitCaptureControllerProvider.notifier);
      notifier.initVisit(
        storeName: 'Sinnar Dealer Hub',
        latitude: 19.8500,
        longitude: 73.9900,
      );

      final state = container.read(visitCaptureControllerProvider);
      expect(state.storeName, 'Sinnar Dealer Hub');
      expect(state.latitude, 19.8500);
      expect(state.longitude, 73.9900);
      expect(state.geotagCoordinates.contains('19.8500° N'), true);
    });

    test('takePhoto calls CameraService and updates photoPath', () async {
      final container = ProviderContainer(
        overrides: [
          cameraServiceProvider.overrideWithValue(
            MockCameraService(mockPath: '/test/photos/field_img.jpg'),
          ),
          visitRepositoryProvider.overrideWithValue(LocalVisitRepository()),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(visitCaptureControllerProvider.notifier);
      await notifier.takePhoto();

      final state = container.read(visitCaptureControllerProvider);
      expect(state.photoPath, '/test/photos/field_img.jpg');
    });

    test('skipPhoto drops a taken photo, with no reason and no flag', () async {
      final repo = LocalVisitRepository();
      final container = ProviderContainer(
        overrides: [
          cameraServiceProvider.overrideWithValue(
            MockCameraService(mockPath: '/test/photos/field_img.jpg'),
          ),
          visitRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(visitCaptureControllerProvider.notifier)
        ..initVisit(latitude: 20.5, longitude: 73.25);
      await notifier.takePhoto();
      expect(
        container.read(visitCaptureControllerProvider).photoPath,
        '/test/photos/field_img.jpg',
      );

      notifier.skipPhoto();
      expect(container.read(visitCaptureControllerProvider).photoPath, isNull);

      expect(
        await notifier.saveVisit(dutySessionId: 's3', employeeId: 'e3'),
        isTrue,
      );
      final stored = await repo.getVisitsForSession('s3');
      expect(stored.single.localPhotoPath, isNull);

      await notifier.takePhoto();
      expect(
        container.read(visitCaptureControllerProvider).photoPath,
        '/test/photos/field_img.jpg',
        reason: 'a photo can be taken again after skipping',
      );
    });

    test('saveVisit persists record to repository and marks isSaved', () async {
      final repo = LocalVisitRepository();
      final container = ProviderContainer(
        overrides: [
          cameraServiceProvider.overrideWithValue(MockCameraService()),
          visitRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(visitCaptureControllerProvider.notifier);
      notifier.initVisit(
        storeName: 'Shivpuri Farm',
        latitude: 19.9975,
        longitude: 73.7898,
      );

      final saved = await notifier.saveVisit(
        dutySessionId: 'sess-active',
        employeeId: 'emp-rk',
      );

      expect(saved, true);
      final state = container.read(visitCaptureControllerProvider);
      expect(state.isSaved, true);
      expect(state.isSaving, false);

      final stored = await repo.getVisitsForSession('sess-active');
      expect(stored.length, 1);
      expect(stored.first.storeName, 'Shivpuri Farm');
    });
  });

  group('Screen 10 VisitCaptureSheet Widget Tests', () {
    testWidgets('the GPS accuracy given to the sheet is saved with the visit', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = LocalVisitRepository();
      late ProviderContainer container;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            cameraServiceProvider.overrideWithValue(MockCameraService()),
            visitRepositoryProvider.overrideWithValue(repo),
          ],
          child: Consumer(
            builder: (context, ref, _) {
              container = ProviderScope.containerOf(context);
              return MaterialApp(
                theme: AppTheme.light,
                home: const Scaffold(
                  body: VisitCaptureSheet(
                    dutySessionId: 'sess-acc',
                    employeeId: 'emp-014',
                    latitude: 19.9975,
                    longitude: 73.7898,
                    accuracy: 12.5,
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(container.read(visitCaptureControllerProvider).accuracy, 12.5);

      final saved = await container
          .read(visitCaptureControllerProvider.notifier)
          .saveVisit(dutySessionId: 'sess-acc', employeeId: 'emp-014');

      expect(saved, isTrue);
      expect(
        (await repo.getVisitsForSession('sess-acc')).single.accuracy,
        12.5,
      );
    });

    testWidgets('renders all visual elements matching HTML design reference', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final mockCamera = MockCameraService();
      final mockRepo = LocalVisitRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            cameraServiceProvider.overrideWithValue(mockCamera),
            visitRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const Scaffold(
              body: VisitCaptureSheet(
                storeName: 'Shivpuri Farm',
                dutySessionId: 'sess-100',
                employeeId: 'emp-014',
                latitude: 19.9975,
                longitude: 73.7898,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Header row
      expect(find.text('Add visit'), findsOneWidget);
      expect(find.byKey(const Key('close-visit-sheet-btn')), findsOneWidget);

      // Store strip (the name is also in the store field, so two matches)
      expect(find.text('Shivpuri Farm'), findsNWidgets(2));
      expect(find.textContaining('Recorded at'), findsOneWidget);

      // Photo section: no photo yet, so no "verified" claim
      expect(find.text('PHOTO'), findsOneWidget);
      expect(find.text('Verified In-situ'), findsNothing);
      expect(find.byKey(const Key('retake-photo-btn')), findsOneWidget);

      // Note Section & Counter
      expect(find.text('NOTE (OPTIONAL)'), findsOneWidget);
      expect(find.byKey(const Key('visit-notes-input')), findsOneWidget);
      expect(find.textContaining('/200'), findsOneWidget);

      // Actions
      expect(find.byKey(const Key('save-visit-btn')), findsOneWidget);
      expect(find.byKey(const Key('skip-photo-btn')), findsOneWidget);
    });

    testWidgets('the "verified" badge appears only after a photo is taken', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            cameraServiceProvider.overrideWithValue(MockCameraService()),
            visitRepositoryProvider.overrideWithValue(LocalVisitRepository()),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const Scaffold(
              body: VisitCaptureSheet(
                dutySessionId: 'sess-badge',
                employeeId: 'emp-014',
                latitude: 19.9975,
                longitude: 73.7898,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Verified In-situ'), findsNothing);

      await tester.tap(find.byKey(const Key('retake-photo-btn')));
      await tester.pumpAndSettle();

      expect(find.text('Verified In-situ'), findsOneWidget);

      await tester.tap(find.byKey(const Key('skip-photo-btn')));
      await tester.pumpAndSettle();
    });

    testWidgets('typing note updates character counter and controller state', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final mockCamera = MockCameraService();
      final mockRepo = LocalVisitRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            cameraServiceProvider.overrideWithValue(mockCamera),
            visitRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const Scaffold(
              body: VisitCaptureSheet(
                storeName: 'Shivpuri Farm',
                dutySessionId: 'sess-100',
                employeeId: 'emp-014',
                latitude: 19.9975,
                longitude: 73.7898,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final inputFinder = find.byKey(const Key('visit-notes-input'));
      await tester.enterText(inputFinder, 'Observed drip irrigation');
      await tester.pumpAndSettle();

      expect(find.text('Observed drip irrigation'), findsOneWidget);
      expect(find.text('24/200'), findsOneWidget);
    });

    testWidgets('Skip photo saves the visit at once, asking for no reason', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final mockRepo = LocalVisitRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            cameraServiceProvider.overrideWithValue(MockCameraService()),
            visitRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const Scaffold(
              body: VisitCaptureSheet(
                storeName: 'Shivpuri Farm',
                dutySessionId: 'sess-100',
                employeeId: 'emp-014',
                latitude: 19.9975,
                longitude: 73.7898,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // A photo was taken, then the employee changes their mind.
      await tester.tap(find.byKey(const Key('retake-photo-btn')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('skip-photo-btn')));
      await tester.pumpAndSettle();

      // No dialog, no reason list, no "skipped" notice.
      expect(find.text('Confirm skip'), findsNothing);
      expect(find.textContaining('reason'), findsNothing);
      expect(find.textContaining('Photo Skipped'), findsNothing);

      final stored = await mockRepo.getVisitsForSession('sess-100');
      expect(stored, hasLength(1));
      expect(stored.single.storeName, 'Shivpuri Farm');
      expect(stored.single.localPhotoPath, isNull);
    });

    testWidgets('tapping Save visit records visit and closes sheet', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final mockCamera = MockCameraService();
      final mockRepo = LocalVisitRepository();
      bool savedCallbackTriggered = false;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            cameraServiceProvider.overrideWithValue(mockCamera),
            visitRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: VisitCaptureSheet(
                storeName: 'Shivpuri Farm',
                dutySessionId: 'sess-100',
                employeeId: 'emp-014',
                latitude: 19.9975,
                longitude: 73.7898,
                onSaved: () {
                  savedCallbackTriggered = true;
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('save-visit-btn')));
      await tester.pumpAndSettle();

      expect(savedCallbackTriggered, true);
      final recorded = await mockRepo.getVisitsForSession('sess-100');
      expect(recorded.length, 1);
      expect(recorded.first.storeName, 'Shivpuri Farm');
    });
  });

  group('Map to VisitCaptureSheet Flow Test', () {
    Widget mapWith(DutyScreenState dutyState) {
      return ProviderScope(
        overrides: [
          dutyControllerProvider.overrideWith(
            () => TestDutyNotifier(dutyState),
          ),
          cameraServiceProvider.overrideWithValue(MockCameraService()),
          visitRepositoryProvider.overrideWithValue(LocalVisitRepository()),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const EmployeeMapPage(),
        ),
      );
    }

    void tall(WidgetTester tester) {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }

    testWidgets('Add visit opens the sheet with the real session and GPS fix', (
      tester,
    ) async {
      tall(tester);

      final dutyState = DutyScreenState(
        status: DutyStatus.onDuty,
        elapsedDuration: const Duration(hours: 3),
        distanceKm: 12.4,
        visitsCount: 1,
        activeSession: DutySession(
          id: 'sess-live',
          employeeId: 'emp-live',
          startedAt: DateTime(2026, 10, 16, 8),
        ),
        lastLocation: LocationPoint(
          id: 'p1',
          sessionId: 'sess-live',
          latitude: 20.1234,
          longitude: 73.5678,
          accuracy: 7,
          recordedAt: DateTime(2026, 10, 16, 9),
        ),
      );

      await tester.pumpWidget(mapWith(dutyState));
      await tester.pumpAndSettle();

      expect(find.text('GPS accuracy ±7 m'), findsOneWidget);

      await tester.tap(find.byKey(const Key('btn-add-visit')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('close-visit-sheet-btn')), findsOneWidget);
      expect(find.byKey(const Key('visit-notes-input')), findsOneWidget);
      // No invented store name, coordinates or note
      expect(find.text('Shivpuri Farm'), findsNothing);
      expect(find.text('Field location'), findsOneWidget);
      expect(find.textContaining('20.1234'), findsWidgets);
      expect(
        find.text('Met owner, discussed kharif seed order.'),
        findsNothing,
      );
    });

    testWidgets(
      'Add visit without an active session or GPS fix explains and opens nothing',
      (tester) async {
        tall(tester);

        await tester.pumpWidget(
          mapWith(const DutyScreenState(status: DutyStatus.onDuty)),
        );
        await tester.pumpAndSettle();

        expect(find.text('Waiting for GPS…'), findsOneWidget);
        expect(find.textContaining('Sinnar'), findsNothing);

        await tester.tap(find.byKey(const Key('btn-add-visit')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('close-visit-sheet-btn')), findsNothing);
        expect(
          find.text('Start duty and wait for a GPS fix to add a visit.'),
          findsOneWidget,
        );
      },
    );
  });

  group('VisitCaptureNotifier without invented defaults', () {
    test('starts blank: no store name, note, time or position', () {
      final container = ProviderContainer(
        overrides: [
          cameraServiceProvider.overrideWithValue(MockCameraService()),
          visitRepositoryProvider.overrideWithValue(LocalVisitRepository()),
        ],
      );
      addTearDown(container.dispose);

      final state = container.read(visitCaptureControllerProvider);
      expect(state.storeName, isEmpty);
      expect(state.note, isEmpty);
      expect(state.arrivalTime, isEmpty);
      expect(state.geotagCoordinates, isEmpty);
      expect(state.latitude, isNull);
      expect(state.longitude, isNull);
    });

    test('a visit cannot be saved without a GPS position', () async {
      final repo = LocalVisitRepository();
      final container = ProviderContainer(
        overrides: [
          cameraServiceProvider.overrideWithValue(MockCameraService()),
          visitRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      final saved = await container
          .read(visitCaptureControllerProvider.notifier)
          .saveVisit(dutySessionId: 's1', employeeId: 'e1');

      expect(saved, isFalse);
      expect(
        container.read(visitCaptureControllerProvider).errorMessage,
        contains('No GPS position'),
      );
      expect(await repo.getVisitsForSession('s1'), isEmpty);
    });

    test(
      'a visit saved without a store name has none, and none is invented',
      () async {
        final repo = LocalVisitRepository();
        final container = ProviderContainer(
          overrides: [
            cameraServiceProvider.overrideWithValue(MockCameraService()),
            visitRepositoryProvider.overrideWithValue(repo),
          ],
        );
        addTearDown(container.dispose);

        final notifier = container.read(visitCaptureControllerProvider.notifier)
          ..initVisit(latitude: 20.5, longitude: 73.25);
        expect(
          await notifier.saveVisit(dutySessionId: 's2', employeeId: 'e2'),
          isTrue,
        );

        final stored = await repo.getVisitsForSession('s2');
        expect(stored.single.storeName, isNull);
        expect(stored.single.latitude, 20.5);
        expect(stored.single.note, isNull);
      },
    );
  });
}
