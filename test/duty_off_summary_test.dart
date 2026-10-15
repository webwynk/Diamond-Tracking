import 'package:diamond_tracking/core/theme/app_theme.dart';
import 'package:diamond_tracking/core/utils/duty_time_helper.dart';
import 'package:diamond_tracking/domain/entities/duty_session.dart';
import 'package:diamond_tracking/domain/entities/user_profile.dart';
import 'package:diamond_tracking/features/auth/presentation/controllers/auth_controller.dart';
import 'package:diamond_tracking/features/auth/presentation/controllers/auth_state.dart';
import 'package:diamond_tracking/features/duty/presentation/controllers/duty_controller.dart';
import 'package:diamond_tracking/features/duty/presentation/controllers/duty_state.dart';
import 'package:diamond_tracking/features/duty/presentation/duty_off_summary_dialog.dart';
import 'package:diamond_tracking/features/home/presentation/employee_home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class TestDutyNotifier extends DutyNotifier {
  TestDutyNotifier(this._initialState);
  final DutyScreenState _initialState;

  bool endDutyCalled = false;

  @override
  DutyScreenState build() => _initialState;

  @override
  Future<DutySession?> endDuty({String? notes}) async {
    endDutyCalled = true;
    final ended = _initialState.activeSession?.copyWith(
      status: DutySessionStatus.completed,
      endedAt: DateTime.now().toUtc(),
    );
    state = state.copyWith(status: DutyStatus.offDuty, activeSession: null);
    return ended ??
        DutySession(
          id: 'test-ended-session',
          employeeId: 'emp-100',
          startedAt: DateTime.now().subtract(const Duration(hours: 8)).toUtc(),
          endedAt: DateTime.now().toUtc(),
          totalDistanceKm: 52.1,
          visitsCount: 6,
        );
  }
}

class TestAuthNotifier extends AuthNotifier {
  TestAuthNotifier(this._initialState);
  final AuthState _initialState;

  @override
  AuthState build() => _initialState;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testProfile = UserProfile(
    id: 'emp-014',
    role: UserRole.employee,
    status: UserStatus.active,
    fullName: 'Ramesh Kumar',
    mustChangePin: false,
    failedLoginAttempts: 0,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
    email: 'rkumar@diamondagritech.com',
    employeeCode: 'DA-014',
  );

  final testSession = DutySession(
    id: 'session-777',
    employeeId: 'emp-014',
    startedAt: DateTime.utc(2026, 10, 12, 2, 34), // 8:04 AM IST
    endedAt: DateTime.utc(2026, 10, 12, 10, 58),  // 4:28 PM IST
    totalDistanceKm: 52.1,
    visitsCount: 6,
  );

  group('DutyTimeHelper Formatting Tests', () {
    test('formatTime correctly converts UTC to IST standard format', () {
      final utcTime = DateTime.utc(2026, 10, 12, 2, 34); // 8:04 AM IST
      expect(DutyTimeHelper.formatTime(utcTime), '8:04 AM');

      final eveningUtc = DateTime.utc(2026, 10, 12, 10, 58); // 4:28 PM IST
      expect(DutyTimeHelper.formatTime(eveningUtc), '4:28 PM');
    });

    test('formatShiftInterval returns formatted date and time interval', () {
      final start = DateTime.utc(2026, 10, 12, 2, 34);
      final end = DateTime.utc(2026, 10, 12, 10, 58);
      final interval = DutyTimeHelper.formatShiftInterval(start, end);
      expect(interval, '12 Oct 2026 · 8:04 AM to 4:28 PM');
    });
  });

  group('Screen 11 DutyOffSummaryDialog Widget Tests', () {
    testWidgets('renders all visual elements matching HTML design reference',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      bool donePressed = false;
      bool routePressed = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: DutyOffSummaryDialog(
              session: testSession,
              onDone: () => donePressed = true,
              onViewRoute: () => routePressed = true,
              isSyncComplete: true,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Accomplishment check badge & Title
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(find.text('Duty ended'), findsOneWidget);
      expect(find.text('12 Oct 2026 · 8:04 AM to 4:28 PM'), findsOneWidget);

      // Warm completion note
      expect(find.text('SHIFT COMPLETE · REST WELL'), findsOneWidget);
      expect(find.byIcon(Icons.sentiment_satisfied), findsOneWidget);

      // 3-Metric Recessed Panel
      expect(find.text('Total hours'), findsOneWidget);
      expect(find.text('8h 24m'), findsOneWidget);

      expect(find.text('Distance'), findsOneWidget);
      expect(find.text('52.1 km'), findsOneWidget);

      expect(find.text('Visits'), findsOneWidget);
      expect(find.text('6'), findsOneWidget);

      // Sync indicator
      expect(find.text('All data synced'), findsOneWidget);

      // Actions
      final doneBtn = find.byKey(const Key('btn-summary-done'));
      expect(doneBtn, findsOneWidget);
      await tester.tap(doneBtn);
      expect(donePressed, isTrue);

      final viewRouteBtn = find.byKey(const Key('btn-summary-view-route'));
      expect(viewRouteBtn, findsOneWidget);
      await tester.tap(viewRouteBtn);
      expect(routePressed, isTrue);
    });

    testWidgets('displays queued points indicator when sync is pending',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: DutyOffSummaryDialog(
              session: testSession,
              isSyncComplete: false,
              pendingSyncPoints: 14,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Queued for sync (14 points)'), findsOneWidget);
      expect(find.byIcon(Icons.sync), findsOneWidget);
    });
  });

  group('EmployeeHomePage End-Duty Integration Tests', () {
    testWidgets('tapping on-duty hero pill prompts confirmation and opens summary dialog',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final dutyNotifier = TestDutyNotifier(
        DutyScreenState(
          status: DutyStatus.onDuty,
          activeSession: testSession,
          elapsedDuration: const Duration(hours: 8, minutes: 24),
          distanceKm: 52.1,
          visitsCount: 6,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(
              () => TestAuthNotifier(AuthAuthenticated(testProfile)),
            ),
            dutyControllerProvider.overrideWith(() => dutyNotifier),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const EmployeeHomePage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap active on-duty toggle button
      final onDutyPill = find.byKey(const Key('btn-toggle-duty-active'));
      expect(onDutyPill, findsOneWidget);
      await tester.tap(onDutyPill);
      await tester.pumpAndSettle();

      // Confirmation dialog appears
      expect(find.text('End duty?'), findsOneWidget);
      expect(find.textContaining('This will stop background location tracking'), findsOneWidget);

      // Confirm ending duty
      final confirmBtn = find.byKey(const Key('confirm-end-duty-btn'));
      expect(confirmBtn, findsOneWidget);
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      // Verify DutyOffSummaryDialog appears immediately
      expect(find.text('Duty ended'), findsOneWidget);
      expect(find.text('Total hours'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(DutyOffSummaryDialog),
          matching: find.text('52.1 km'),
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('btn-summary-done')), findsOneWidget);

      // Tap Done on summary dialog
      await tester.tap(find.byKey(const Key('btn-summary-done')));
      await tester.pumpAndSettle();

      // Summary dialog is closed, home page is back in off-duty state
      expect(find.text('Start duty'), findsOneWidget);
    });
  });
}
