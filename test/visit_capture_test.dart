import 'package:diamond_tracking/core/services/camera_service.dart';
import 'package:diamond_tracking/core/theme/app_theme.dart';
import 'package:diamond_tracking/data/repositories/local_visit_repository.dart';
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

  group('VisitRecord Domain Entity & Serialization', () {
    test('instantiates with required fields and serializes to/from map', () {
      final now = DateTime.now().toUtc();
      final record = VisitRecord(
        id: 'visit-101',
        dutySessionId: 'session-202',
        employeeId: 'emp-303',
        placeName: 'Shivpuri Farm',
        placeId: 'place-404',
        latitude: 19.9975,
        longitude: 73.7898,
        accuracy: 3.5,
        distanceMeters: 450.0,
        photoPath: '/mock/path.jpg',
        photoSkipped: false,
        notes: 'Checked soil moisture',
        capturedAt: now,
        synced: false,
      );

      final map = record.toMap();
      expect(map['id'], 'visit-101');
      expect(map['place_name'], 'Shivpuri Farm');
      expect(map['photo_skipped'], false);
      expect(map['notes'], 'Checked soil moisture');

      final deserialized = VisitRecord.fromMap(map);
      expect(deserialized.id, record.id);
      expect(deserialized.placeName, record.placeName);
      expect(deserialized.latitude, record.latitude);
      expect(deserialized.longitude, record.longitude);
      expect(deserialized.photoSkipped, false);
      expect(deserialized.notes, record.notes);
    });

    test('copyWith updates specified fields correctly', () {
      final record = VisitRecord(
        id: 'visit-1',
        dutySessionId: 'sess-1',
        employeeId: 'emp-1',
        placeName: 'Farm A',
        latitude: 20.0,
        longitude: 74.0,
        capturedAt: DateTime.now(),
      );

      final updated = record.copyWith(
        photoSkipped: true,
        photoSkipReason: 'Extreme rain',
        synced: true,
      );

      expect(updated.photoSkipped, true);
      expect(updated.photoSkipReason, 'Extreme rain');
      expect(updated.synced, true);
      expect(updated.placeName, 'Farm A');
    });
  });

  group('LocalVisitRepository Tests', () {
    test('records visit, retrieves by session, and marks synced', () async {
      final repo = LocalVisitRepository();
      final record = VisitRecord(
        id: 'v1',
        dutySessionId: 'session-alpha',
        employeeId: 'emp-1',
        placeName: 'Nashik Vineyard',
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
    test('initializes visit state with place and coordinate metadata', () {
      final container = ProviderContainer(
        overrides: [
          cameraServiceProvider.overrideWithValue(MockCameraService()),
          visitRepositoryProvider.overrideWithValue(LocalVisitRepository()),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(visitCaptureControllerProvider.notifier);
      notifier.initVisit(
        placeName: 'Sinnar Dealer Hub',
        placeId: 'hub-1',
        latitude: 19.8500,
        longitude: 73.9900,
        distanceMeters: 320.0,
      );

      final state = container.read(visitCaptureControllerProvider);
      expect(state.placeName, 'Sinnar Dealer Hub');
      expect(state.latitude, 19.8500);
      expect(state.longitude, 73.9900);
      expect(state.distanceMeters, 320.0);
      expect(state.geotagCoordinates.contains('19.8500° N'), true);
      expect(state.photoSkipped, false);
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
      expect(state.photoSkipped, false);
    });

    test('skipPhoto marks photoSkipped and records skip reason per BR-12', () {
      final container = ProviderContainer(
        overrides: [
          cameraServiceProvider.overrideWithValue(MockCameraService()),
          visitRepositoryProvider.overrideWithValue(LocalVisitRepository()),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(visitCaptureControllerProvider.notifier);
      notifier.skipPhoto('Biosecurity quarantine protocol');

      final state = container.read(visitCaptureControllerProvider);
      expect(state.photoSkipped, true);
      expect(state.photoSkipReason, 'Biosecurity quarantine protocol');
      expect(state.photoPath, isNull);
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
        placeName: 'Shivpuri Farm',
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
      expect(stored.first.placeName, 'Shivpuri Farm');
    });
  });

  group('Screen 10 VisitCaptureSheet Widget Tests', () {
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
                placeName: 'Shivpuri Farm',
                dutySessionId: 'sess-100',
                employeeId: 'emp-014',
                latitude: 19.9975,
                longitude: 73.7898,
                distanceMeters: 500,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Header row
      expect(find.text('Add visit'), findsOneWidget);
      expect(find.byKey(const Key('close-visit-sheet-btn')), findsOneWidget);

      // Geofence Arrival Strip
      expect(find.text('Shivpuri Farm'), findsOneWidget);
      expect(find.textContaining('within 500 m'), findsOneWidget);

      // Photo Section & Verified in-situ badge
      expect(find.text('PHOTO'), findsOneWidget);
      expect(find.text('Verified In-situ'), findsOneWidget);
      expect(find.byKey(const Key('retake-photo-btn')), findsOneWidget);

      // Note Section & Counter
      expect(find.text('NOTE (OPTIONAL)'), findsOneWidget);
      expect(find.byKey(const Key('visit-notes-input')), findsOneWidget);
      expect(find.textContaining('/200'), findsOneWidget);

      // Actions
      expect(find.byKey(const Key('save-visit-btn')), findsOneWidget);
      expect(find.byKey(const Key('skip-photo-btn')), findsOneWidget);
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
                placeName: 'Shivpuri Farm',
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

    testWidgets('skip photo flow shows reason dialog and confirms skip', (
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
                placeName: 'Shivpuri Farm',
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

      // Tap Skip photo
      await tester.tap(find.byKey(const Key('skip-photo-btn')));
      await tester.pumpAndSettle();

      // Verify skip photo dialog appears with reasons
      expect(find.text('Skip photo'), findsWidgets);
      expect(
        find.textContaining('BR-12 requires a mandatory reason'),
        findsOneWidget,
      );
      expect(find.text('Camera hardware malfunction'), findsOneWidget);

      // Confirm skip
      await tester.tap(find.text('Confirm skip'));
      await tester.pumpAndSettle();

      // Photo area now shows Photo Skipped (BR-12)
      expect(find.text('Photo Skipped (BR-12)'), findsOneWidget);
      expect(find.text('Camera hardware malfunction'), findsOneWidget);
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
                placeName: 'Shivpuri Farm',
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
      expect(recorded.first.placeName, 'Shivpuri Farm');
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
      // No invented place, coordinates or note
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
    test('starts blank: no place, note, time or position', () {
      final container = ProviderContainer(
        overrides: [
          cameraServiceProvider.overrideWithValue(MockCameraService()),
          visitRepositoryProvider.overrideWithValue(LocalVisitRepository()),
        ],
      );
      addTearDown(container.dispose);

      final state = container.read(visitCaptureControllerProvider);
      expect(state.placeName, isEmpty);
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

    test('initVisit without a place records it as a field location', () async {
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
      expect(stored.single.placeName, 'Field location');
      expect(stored.single.latitude, 20.5);
      expect(stored.single.notes, isNull);
    });
  });
}
