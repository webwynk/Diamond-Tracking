import 'package:diamond_tracking/core/theme/app_theme.dart';
import 'package:diamond_tracking/domain/entities/duty_session.dart';
import 'package:diamond_tracking/domain/entities/location_point.dart';
import 'package:diamond_tracking/domain/entities/user_profile.dart';
import 'package:diamond_tracking/domain/repositories/auth_repository.dart';
import 'package:diamond_tracking/domain/repositories/duty_repository.dart';
import 'package:diamond_tracking/features/auth/presentation/controllers/auth_controller.dart';
import 'package:diamond_tracking/features/duty/presentation/controllers/duty_controller.dart';
import 'package:diamond_tracking/features/profile/presentation/employee_profile_page.dart';
import 'package:diamond_tracking/features/profile/presentation/widgets/profile_details_card.dart';
import 'package:diamond_tracking/features/profile/presentation/widgets/profile_header_hero.dart';
import 'package:diamond_tracking/features/profile/presentation/widgets/profile_month_stats_grid.dart';
import 'package:diamond_tracking/features/profile/presentation/widgets/profile_security_actions_card.dart';
import 'package:diamond_tracking/features/profile/presentation/widgets/update_pin_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAuthRepository implements AuthRepository {
  UserProfile? mockProfile;
  bool signedOut = false;
  String? updatedPin;

  @override
  Future<UserProfile?> getCurrentProfile() async => mockProfile;

  @override
  Future<UserProfile> signInEmployee({
    required String employeeCode,
    required String pin,
    required String deviceId,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<UserProfile> signInAdmin({
    required String email,
    required String password,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<void> changePin({required String newPin}) async {
    updatedPin = newPin;
  }

  @override
  Future<void> signOut() async {
    signedOut = true;
    mockProfile = null;
  }

  @override
  Stream<UserProfile?> get authProfileChanges => const Stream.empty();
}

class _FakeDutyRepository implements DutyRepository {
  @override
  Future<DutySession?> getActiveDutySession({required String employeeId}) async => null;

  @override
  Future<DutySession> startDutySession({required String employeeId}) async => throw UnimplementedError();

  @override
  Future<DutySession> endDutySession({required String sessionId, String? endReason, String? notes}) async => throw UnimplementedError();

  @override
  Future<DutySession?> getYesterdayDutySession({required String employeeId}) async => null;

  @override
  Future<List<DutySession>> getDutyHistory({required String employeeId, DateTime? startDate, DateTime? endDate, int limit = 30, int offset = 0}) async => [];

  @override
  Future<void> uploadLocationPointsBatch({required List<LocationPoint> points}) async {}
}

void main() {
  final testProfile = UserProfile(
    id: 'emp_014',
    role: UserRole.employee,
    status: UserStatus.active,
    fullName: 'Ramesh Kumar',
    employeeCode: 'DA-014',
    phone: '+91 98765 43210',
    email: 'ramesh.k@diamondagritech.in',
    mustChangePin: false,
    failedLoginAttempts: 0,
    createdAt: DateTime(2026, 3, 4),
    updatedAt: DateTime(2026, 3, 4),
  );

  Widget buildTestWidget({
    _FakeAuthRepository? authRepo,
    VoidCallback? onBack,
  }) {
    final repo = authRepo ?? (_FakeAuthRepository()..mockProfile = testProfile);

    return ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(repo),
        dutyRepositoryProvider.overrideWithValue(_FakeDutyRepository()),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: EmployeeProfilePage(onBack: onBack),
      ),
    );
  }

  group('Screen 13 — EmployeeProfilePage Widget Tests', () {
    testWidgets('renders all visual elements matching HTML design specifications',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final authRepo = _FakeAuthRepository()..mockProfile = testProfile;
      await tester.pumpWidget(buildTestWidget(authRepo: authRepo));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 1. Hero Header
      expect(find.byType(ProfileHeaderHero), findsOneWidget);
      expect(find.text('Ramesh Kumar'), findsOneWidget);
      expect(find.text('DA-014'), findsOneWidget);
      expect(find.text('RK'), findsOneWidget); // Initials
      expect(find.byKey(const Key('profile-back-btn')), findsOneWidget);

      // 2. Card 1 — MY DETAILS
      expect(find.byType(ProfileDetailsCard), findsOneWidget);
      expect(find.text('MY DETAILS'), findsOneWidget);
      expect(find.text('+91 98765 43210'), findsOneWidget);
      expect(find.text('ramesh.k@diamondagritech.in'), findsOneWidget);
      expect(find.text('04 Mar 2026'), findsOneWidget);

      // 3. Card 2 — THIS MONTH
      expect(find.byType(ProfileMonthStatsGrid), findsOneWidget);
      expect(find.text('THIS MONTH'), findsOneWidget);
      expect(find.text('Days worked'), findsOneWidget);
      expect(find.text('Hours'), findsOneWidget);
      expect(find.text('Distance'), findsOneWidget);
      expect(find.text('Visits'), findsOneWidget);

      // 4. Card 3 — Security & Actions
      expect(find.byType(ProfileSecurityActionsCard), findsOneWidget);
      expect(find.text('Change PIN'), findsOneWidget);
      expect(find.text('Privacy and tracking'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget); // Status on duty / active badge

      // 5. Action 4 — Outlined Logout Button
      expect(find.byKey(const Key('btn-logout')), findsOneWidget);
      expect(find.text('Log out'), findsOneWidget);

      // 6. Footer
      expect(find.text('Diamond Agritech · v1.0.0'), findsOneWidget);
    });

    testWidgets('tapping Change PIN row opens UpdatePinDialog and allows PIN update',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final authRepo = _FakeAuthRepository()..mockProfile = testProfile;
      await tester.pumpWidget(buildTestWidget(authRepo: authRepo));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Tap Change PIN row
      await tester.tap(find.byKey(const Key('btn-change-pin-row')));
      await tester.pumpAndSettle();

      // Verify Dialog is presented
      expect(find.byType(UpdatePinDialog), findsOneWidget);
      expect(find.text('Update Security PIN'), findsOneWidget);
      expect(find.text('New 4-Digit PIN'), findsOneWidget);

      // Enter 4-digit PIN
      await tester.enterText(find.byKey(const Key('pin-input-field')), '4321');
      await tester.pump();

      // Tap Save New PIN
      await tester.tap(find.byKey(const Key('btn-save-pin')));
      await tester.pumpAndSettle();

      // Dialog should close and PIN should be updated in repository
      expect(find.byType(UpdatePinDialog), findsNothing);
      expect(authRepo.updatedPin, '4321');
    });

    testWidgets('tapping Privacy and Tracking row presents privacy modal',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Tap Privacy row
      await tester.tap(find.byKey(const Key('btn-privacy-tracking-row')));
      await tester.pumpAndSettle();

      expect(find.text('Privacy & Tracking'), findsOneWidget);
      expect(find.text('Understood'), findsOneWidget);

      await tester.tap(find.text('Understood'));
      await tester.pumpAndSettle();
      expect(find.text('Privacy & Tracking'), findsNothing);
    });

    testWidgets('tapping Log out shows confirmation dialog and confirms sign out',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final authRepo = _FakeAuthRepository()..mockProfile = testProfile;
      await tester.pumpWidget(buildTestWidget(authRepo: authRepo));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Tap Log out button
      await tester.tap(find.byKey(const Key('btn-logout')));
      await tester.pumpAndSettle();

      expect(find.text('Log out?'), findsOneWidget);
      expect(find.byKey(const Key('confirm-logout-btn')), findsOneWidget);

      // Tap Confirm Log out
      await tester.tap(find.byKey(const Key('confirm-logout-btn')));
      await tester.pumpAndSettle();

      expect(authRepo.signedOut, true);
    });

    testWidgets('tapping back button invokes onBack callback',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      bool backInvoked = false;
      await tester.pumpWidget(buildTestWidget(
        onBack: () => backInvoked = true,
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const Key('profile-back-btn')));
      await tester.pump();

      expect(backInvoked, true);
    });
  });
}
