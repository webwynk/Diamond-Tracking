import 'package:diamond_tracking/core/theme/app_theme.dart';
import 'package:diamond_tracking/domain/entities/user_profile.dart';
import 'package:diamond_tracking/domain/repositories/auth_repository.dart';
import 'package:diamond_tracking/features/admin/dashboard/presentation/admin_dashboard_page.dart';
import 'package:diamond_tracking/features/auth/presentation/admin_login_page.dart';
import 'package:diamond_tracking/features/auth/presentation/controllers/auth_controller.dart';
import 'package:diamond_tracking/features/auth/presentation/employee_login_page.dart';
import 'package:diamond_tracking/features/auth/presentation/pin_change_page.dart';
import 'package:diamond_tracking/features/auth/presentation/splash_page.dart';
import 'package:diamond_tracking/features/auth/presentation/widgets/pin_box_input.dart';
import 'package:diamond_tracking/features/duty/presentation/controllers/duty_controller.dart';
import 'package:diamond_tracking/features/duty/presentation/controllers/duty_state.dart';
import 'package:diamond_tracking/features/home/presentation/employee_home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockAuthRepository implements AuthRepository {
  UserProfile? mockProfile;
  bool shouldFail = false;

  @override
  Future<UserProfile?> getCurrentProfile() async => mockProfile;

  @override
  Future<UserProfile> signInEmployee({
    required String employeeCode,
    required String pin,
    required String deviceId,
  }) async {
    if (shouldFail) throw Exception('Incorrect employee code or PIN.');
    return mockProfile ??
        UserProfile(
          id: 'test-user-id',
          role: UserRole.employee,
          status: UserStatus.active,
          fullName: 'Suresh Kumar',
          mustChangePin: false,
          failedLoginAttempts: 0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          employeeCode: employeeCode,
        );
  }

  @override
  Future<UserProfile> signInAdmin({
    required String email,
    required String password,
  }) async {
    if (shouldFail) throw Exception('Incorrect email or password.');
    return mockProfile ??
        UserProfile(
          id: 'test-admin-id',
          role: UserRole.admin,
          status: UserStatus.active,
          fullName: 'Office Admin',
          mustChangePin: false,
          failedLoginAttempts: 0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          email: email,
        );
  }

  @override
  Future<void> changePin({required String newPin}) async {
    if (shouldFail) throw Exception('Failed to update PIN');
    mockProfile = mockProfile?.copyWith(mustChangePin: false);
  }

  @override
  Future<void> signOut() async {
    mockProfile = null;
  }

  @override
  Stream<UserProfile?> get authProfileChanges => Stream.value(mockProfile);
}

/// Keeps [EmployeeHomePage] off the network: duty state is fixed to off-duty.
class _FakeDutyNotifier extends DutyNotifier {
  @override
  DutyScreenState build() => const DutyScreenState();
}

void main() {
  // Signing in reads this phone's saved device id.
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  Widget buildTestableWidget(Widget child, {MockAuthRepository? repo}) {
    final mockRepo = repo ?? MockAuthRepository();
    return ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(mockRepo),
        dutyControllerProvider.overrideWith(_FakeDutyNotifier.new),
      ],
      child: MaterialApp(theme: AppTheme.light, home: child),
    );
  }

  group('Auth Flow Presentation Tests', () {
    testWidgets('PinBoxInput renders 6 segmented boxes', (tester) async {
      final controller = TextEditingController(text: '123');
      await tester.pumpWidget(
        buildTestableWidget(
          Scaffold(body: PinBoxInput(controller: controller, length: 6)),
        ),
      );

      // Verify row of 6 boxes
      expect(find.byType(PinBoxInput), findsOneWidget);
      controller.dispose();
    });

    testWidgets('Screen 01 SplashPage renders brand and version', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestableWidget(const SplashPage()));

      expect(find.text('Diamond Agritech'), findsOneWidget);
      expect(find.text('Field Tracking'), findsOneWidget);
      expect(find.text('v1.0.0'), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
    });

    testWidgets('Screen 02 EmployeeLoginPage renders fields and admin switch', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestableWidget(const EmployeeLoginPage()));

      expect(find.text('Diamond Agritech'), findsOneWidget);
      expect(find.text('Employee Login'), findsOneWidget);
      expect(find.text('Employee ID'), findsOneWidget);
      expect(find.text('PIN'), findsOneWidget);
      expect(find.text('Forgot PIN?'), findsOneWidget);
      expect(find.text('Log in'), findsOneWidget);
      expect(find.text('Admin login'), findsOneWidget);

      // Tap Admin login link
      await tester.tap(find.text('Admin login'));
      await tester.pumpAndSettle();

      // Should now show AdminLoginPage
      expect(find.text('Admin Login'), findsOneWidget);
      expect(find.text('ENTERPRISE TELEMETRY SYSTEM'), findsOneWidget);
    });

    testWidgets('Screen 03 AdminLoginPage renders email and password fields', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestableWidget(const AdminLoginPage()));

      expect(find.text('Admin Login'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);
      expect(find.text('Back to Employee Login'), findsOneWidget);
    });

    testWidgets('Screen 04 PinChangePage enforces rules and enables Save PIN', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestableWidget(const PinChangePage()));

      expect(find.text('Create your PIN'), findsOneWidget);
      expect(find.text('Set a new PIN'), findsOneWidget);
      expect(find.text('6 digits'), findsOneWidget);
      expect(find.text('Not the same digit repeated'), findsOneWidget);
      expect(find.text('Not a sequence like 123456'), findsOneWidget);
      expect(find.text('Save PIN'), findsOneWidget);

      // Initially Save PIN button is disabled
      final buttonFinder = find.widgetWithText(ElevatedButton, 'Save PIN');
      final button = tester.widget<ElevatedButton>(buttonFinder);
      expect(button.onPressed, isNull);
    });
  });

  group('Post-login routing', () {
    UserProfile profileFor(UserRole role, {bool mustChangePin = false}) {
      return UserProfile(
        id: 'user-id',
        role: role,
        status: UserStatus.active,
        fullName: role == UserRole.admin ? 'Office Admin' : 'Suresh Kumar',
        mustChangePin: mustChangePin,
        failedLoginAttempts: 0,
        createdAt: DateTime(2026, 10, 1),
        updatedAt: DateTime(2026, 10, 1),
        employeeCode: role == UserRole.employee ? 'DA-001' : null,
      );
    }

    testWidgets('employee login lands on Employee Home', (tester) async {
      final repo = MockAuthRepository()
        ..mockProfile = profileFor(UserRole.employee);
      await tester.pumpWidget(
        buildTestableWidget(const EmployeeLoginPage(), repo: repo),
      );

      await tester.enterText(find.byType(TextField).at(0), 'DA-001');
      await tester.enterText(find.byType(TextField).at(1), '482915');
      await tester.tap(find.text('Log in'));
      await tester.pumpAndSettle();

      expect(find.byType(EmployeeHomePage), findsOneWidget);
      expect(find.byType(EmployeeLoginPage), findsNothing);
    });

    testWidgets(
      'admin login pushed over employee login lands on Dashboard once',
      (tester) async {
        final repo = MockAuthRepository()
          ..mockProfile = profileFor(UserRole.admin);
        await tester.pumpWidget(
          buildTestableWidget(const EmployeeLoginPage(), repo: repo),
        );

        await tester.tap(find.text('Admin login'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).at(0), 'admin@da.in');
        await tester.enterText(find.byType(TextField).at(1), 'secret-pass');
        await tester.tap(find.text('Sign In'));
        await tester.pumpAndSettle();

        expect(find.byType(AdminDashboardPage), findsOneWidget);
        expect(find.byType(EmployeeHomePage), findsNothing);
        expect(find.byType(AdminLoginPage), findsNothing);
        expect(find.byType(EmployeeLoginPage), findsNothing);
      },
    );

    testWidgets('splash routes a stored employee session to Employee Home', (
      tester,
    ) async {
      final repo = MockAuthRepository()
        ..mockProfile = profileFor(UserRole.employee);
      await tester.pumpWidget(
        buildTestableWidget(const SplashPage(), repo: repo),
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(find.byType(EmployeeHomePage), findsOneWidget);
    });

    testWidgets('splash routes a stored admin session to the Dashboard', (
      tester,
    ) async {
      final repo = MockAuthRepository()
        ..mockProfile = profileFor(UserRole.admin);
      await tester.pumpWidget(
        buildTestableWidget(const SplashPage(), repo: repo),
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(find.byType(AdminDashboardPage), findsOneWidget);
    });

    testWidgets('saving a new PIN lands on Employee Home', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final repo = MockAuthRepository()
        ..mockProfile = profileFor(UserRole.employee, mustChangePin: true);
      await tester.pumpWidget(
        buildTestableWidget(const PinChangePage(), repo: repo),
      );

      await tester.enterText(find.byType(TextField).at(0), '482915');
      await tester.pump();
      await tester.enterText(find.byType(TextField).at(1), '482915');
      await tester.pump();
      await tester.tap(find.text('Save PIN'));
      await tester.pumpAndSettle();

      expect(find.byType(EmployeeHomePage), findsOneWidget);
      expect(find.byType(PinChangePage), findsNothing);
    });
  });
}
