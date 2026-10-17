import 'package:diamond_tracking/core/errors/app_exceptions.dart';
import 'package:diamond_tracking/core/theme/app_theme.dart';
import 'package:diamond_tracking/core/utils/duty_time_helper.dart';
import 'package:diamond_tracking/domain/entities/location_point.dart';
import 'package:diamond_tracking/domain/entities/user_profile.dart';
import 'package:diamond_tracking/features/auth/presentation/controllers/auth_controller.dart';
import 'package:diamond_tracking/features/auth/presentation/controllers/auth_state.dart';
import 'package:diamond_tracking/features/duty/presentation/controllers/duty_controller.dart';
import 'package:diamond_tracking/features/duty/presentation/controllers/duty_state.dart';
import 'package:diamond_tracking/features/home/presentation/employee_home_page.dart';
import 'package:diamond_tracking/features/onboarding/presentation/controllers/permission_controller.dart';
import 'package:diamond_tracking/features/onboarding/presentation/permission_setup_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_duty.dart';
import 'support/fake_permission_service.dart';

void main() {
  group('DutyTimeHelper Unit Tests', () {
    test('toIst correctly adds 5 hours and 30 minutes to UTC', () {
      final utc = DateTime.utc(2026, 10, 15, 4, 30); // 04:30 UTC
      final ist = DutyTimeHelper.toIst(utc);
      expect(ist.year, 2026);
      expect(ist.month, 10);
      expect(ist.day, 15);
      expect(ist.hour, 10);
      expect(ist.minute, 0); // 04:30 + 05:30 = 10:00
    });

    test('isWithinDutyWindow enforces 08:00 to 23:00 IST boundary', () {
      // 07:59 IST -> false
      final before = DateTime.utc(2026, 10, 15, 2, 29); // 02:29 UTC = 07:59 IST
      expect(DutyTimeHelper.isWithinDutyWindow(before), isFalse);

      // 08:00 IST -> true
      final start = DateTime.utc(2026, 10, 15, 2, 30); // 02:30 UTC = 08:00 IST
      expect(DutyTimeHelper.isWithinDutyWindow(start), isTrue);

      // 22:59 IST -> true
      final lateEvening = DateTime.utc(
        2026,
        10,
        15,
        17,
        29,
      ); // 17:29 UTC = 22:59 IST
      expect(DutyTimeHelper.isWithinDutyWindow(lateEvening), isTrue);

      // 23:00 IST -> false
      final curfew = DateTime.utc(
        2026,
        10,
        15,
        17,
        30,
      ); // 17:30 UTC = 23:00 IST
      expect(DutyTimeHelper.isWithinDutyWindow(curfew), isFalse);
    });

    test('isCurfewWarningActive activates between 22:45 and 23:00 IST', () {
      final warning = DateTime.utc(
        2026,
        10,
        15,
        17,
        15,
      ); // 17:15 UTC = 22:45 IST
      expect(DutyTimeHelper.isCurfewWarningActive(warning), isTrue);

      final earlier = DateTime.utc(2026, 10, 15, 17, 14); // 22:44 IST
      expect(DutyTimeHelper.isCurfewWarningActive(earlier), isFalse);
    });

    test('formatElapsed formats duration cleanly', () {
      expect(DutyTimeHelper.formatElapsed(Duration.zero), '0h 0m');
      expect(
        DutyTimeHelper.formatElapsed(const Duration(hours: 8, minutes: 12)),
        '8h 12m',
      );
    });
  });

  group('LocationPoint Unit Tests', () {
    test('isOutlier detects invalid points per PRD BR-10', () {
      final now = DateTime.now().toUtc();
      // Valid point
      final valid = LocationPoint(
        id: 'pt-1',
        sessionId: 's-1',
        latitude: 18.5204,
        longitude: 73.8567,
        accuracy: 12.0,
        speed: 10.0, // 36 km/h
        recordedAt: now,
      );
      expect(valid.isOutlier(), isFalse);

      // Inaccurate point (> 100m)
      final inaccurate = valid.copyWith(accuracy: 120.0);
      expect(inaccurate.isOutlier(), isTrue);

      // Implausible speed (> 150 km/h = 41.67 m/s)
      final tooFast = valid.copyWith(speed: 45.0); // 162 km/h
      expect(tooFast.isOutlier(), isTrue);

      // Future timestamp
      final futurePoint = valid.copyWith(
        recordedAt: now.add(const Duration(minutes: 5)),
      );
      expect(futurePoint.isOutlier(), isTrue);
    });

    test('json serialization roundtrip preserves all fields', () {
      final now = DateTime.utc(2026, 10, 15, 10, 0);
      final point = LocationPoint(
        id: 'pt-100',
        sessionId: 's-200',
        latitude: 18.5,
        longitude: 73.8,
        accuracy: 8.5,
        speed: 5.0,
        heading: 180.0,
        altitude: 550.0,
        batteryLevel: 85,
        isMock: false,
        recordedAt: now,
      );

      final json = point.toJson();
      final reconstituted = LocationPoint.fromJson(json);

      expect(reconstituted, equals(point));
    });
  });

  group('DutyController & Presentation Tests', () {
    setUp(() {
      DutyTimeHelper.debugNow = DateTime.utc(2026, 10, 15, 4, 30);
    });

    tearDown(() {
      DutyTimeHelper.debugNow = null;
    });

    Widget buildTestWidget({
      required FakeDutyRepository mockRepo,
      required FakeTrackingService mockTracking,
      DutyScreenState? initialDutyState,
      FakePermissionService? permissions,
    }) {
      final testProfile = UserProfile(
        id: 'test_emp_014',
        role: UserRole.employee,
        status: UserStatus.active,
        fullName: 'Ramesh Kumar',
        mustChangePin: false,
        failedLoginAttempts: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        employeeCode: 'DA-014',
      );

      return ProviderScope(
        overrides: [
          dutyRepositoryProvider.overrideWithValue(mockRepo),
          trackingServiceProvider.overrideWithValue(mockTracking),
          permissionServiceProvider.overrideWithValue(
            permissions ?? FakePermissionService(),
          ),
          trackingUploaderProvider.overrideWithValue(FakeUploader()),
          authControllerProvider.overrideWith(
            () => TestAuthNotifier(AuthAuthenticated(testProfile)),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const EmployeeHomePage(),
        ),
      );
    }

    testWidgets(
      'Screen 06 renders Off Duty header, start duty toggle, and today stats',
      (tester) async {
        final mockRepo = FakeDutyRepository();
        final mockTracking = FakeTrackingService();

        await tester.pumpWidget(
          buildTestWidget(mockRepo: mockRepo, mockTracking: mockTracking),
        );
        await tester.pumpAndSettle();

        expect(find.text('Ramesh Kumar'), findsOneWidget);
        expect(find.text('DA-014'), findsOneWidget);
        expect(find.text('TODAY SO FAR'), findsOneWidget);
        expect(find.text('HOURS'), findsOneWidget);
        expect(find.text('DISTANCE'), findsOneWidget);
        expect(find.text('VISITS'), findsOneWidget);
        expect(find.text('Start duty'), findsOneWidget);
        expect(find.text('Tap to begin tracking'), findsOneWidget);
        expect(find.text('Yesterday'), findsOneWidget);
      },
    );

    testWidgets(
      'tapping Start Duty initiates tracking and switches to On Duty',
      (tester) async {
        final mockRepo = FakeDutyRepository();
        final mockTracking = FakeTrackingService();

        await tester.pumpWidget(
          buildTestWidget(mockRepo: mockRepo, mockTracking: mockTracking),
        );
        await tester.pumpAndSettle();

        // Tap the hero toggle
        await tester.tap(find.text('Start duty'));
        await tester.pumpAndSettle();

        // Tracking engine should have started
        expect(mockTracking.isTracking, isTrue);
        // Hero toggle should now display 'ON DUTY' and 'Tap to end duty'
        expect(find.text('ON DUTY'), findsOneWidget);
        expect(find.text('Tap to end duty'), findsOneWidget);
        expect(find.text('Tracking active'), findsOneWidget);
        expect(find.text('Current location'), findsOneWidget);
      },
    );

    testWidgets(
      'tapping Tap to end duty terminates tracking and returns to Off Duty',
      (tester) async {
        final mockRepo = FakeDutyRepository();
        final mockTracking = FakeTrackingService();

        await tester.pumpWidget(
          buildTestWidget(mockRepo: mockRepo, mockTracking: mockTracking),
        );
        await tester.pumpAndSettle();

        // Start duty
        await tester.tap(find.text('Start duty'));
        await tester.pumpAndSettle();
        expect(mockTracking.isTracking, isTrue);

        // End duty: tap pill, confirm in dialog, then dismiss summary dialog
        await tester.tap(find.text('Tap to end duty'));
        await tester.pumpAndSettle();

        final confirmBtn = find.byKey(const Key('confirm-end-duty-btn'));
        if (confirmBtn.evaluate().isNotEmpty) {
          await tester.tap(confirmBtn);
          await tester.pumpAndSettle();
        }

        final summaryDoneBtn = find.byKey(const Key('btn-summary-done'));
        if (summaryDoneBtn.evaluate().isNotEmpty) {
          await tester.tap(summaryDoneBtn);
          await tester.pumpAndSettle();
        }

        // Tracking should be stopped
        expect(mockTracking.isTracking, isFalse);
        expect(find.text('Start duty'), findsOneWidget);
        expect(find.text('Tap to begin tracking'), findsOneWidget);
      },
    );

    testWidgets(
      'Start duty without Allow-all-the-time opens the permission setup, creates no session',
      (tester) async {
        final mockRepo = FakeDutyRepository();
        final mockTracking = FakeTrackingService();

        await tester.pumpWidget(
          buildTestWidget(
            mockRepo: mockRepo,
            mockTracking: mockTracking,
            permissions: FakePermissionService(backgroundGranted: false),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Start duty'));
        await tester.pumpAndSettle();

        expect(find.byType(PermissionSetupPage), findsOneWidget);
        expect(mockRepo.calls, isEmpty);
        expect(mockTracking.isTracking, isFalse);
      },
    );

    testWidgets('a failed start tells the employee why and stays off duty', (
      tester,
    ) async {
      final mockRepo = FakeDutyRepository()
        ..startError = const NetworkException();
      final mockTracking = FakeTrackingService();

      await tester.pumpWidget(
        buildTestWidget(mockRepo: mockRepo, mockTracking: mockTracking),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Start duty'));
      await tester.pumpAndSettle();

      expect(find.text(const NetworkException().message), findsOneWidget);
      expect(find.text('Start duty'), findsOneWidget);
      expect(mockTracking.isTracking, isFalse);
    });
  });
}

class TestAuthNotifier extends AuthNotifier {
  TestAuthNotifier(this._initialState);
  final AuthState _initialState;

  @override
  AuthState build() => _initialState;
}
