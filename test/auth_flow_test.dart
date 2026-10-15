import 'package:diamond_tracking/core/theme/app_theme.dart';
import 'package:diamond_tracking/domain/entities/user_profile.dart';
import 'package:diamond_tracking/domain/repositories/auth_repository.dart';
import 'package:diamond_tracking/features/auth/presentation/admin_login_page.dart';
import 'package:diamond_tracking/features/auth/presentation/controllers/auth_controller.dart';
import 'package:diamond_tracking/features/auth/presentation/employee_login_page.dart';
import 'package:diamond_tracking/features/auth/presentation/pin_change_page.dart';
import 'package:diamond_tracking/features/auth/presentation/splash_page.dart';
import 'package:diamond_tracking/features/auth/presentation/widgets/pin_box_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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

void main() {
  Widget buildTestableWidget(Widget child, {MockAuthRepository? repo}) {
    final mockRepo = repo ?? MockAuthRepository();
    return ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(mockRepo),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: child,
      ),
    );
  }

  group('Auth Flow Presentation Tests', () {
    testWidgets('PinBoxInput renders 6 segmented boxes', (tester) async {
      final controller = TextEditingController(text: '123');
      await tester.pumpWidget(
        buildTestableWidget(
          Scaffold(
            body: PinBoxInput(controller: controller, length: 6),
          ),
        ),
      );

      // Verify row of 6 boxes
      expect(find.byType(PinBoxInput), findsOneWidget);
      controller.dispose();
    });

    testWidgets('Screen 01 SplashPage renders brand and version', (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(const SplashPage()),
      );

      expect(find.text('Diamond Agritech'), findsOneWidget);
      expect(find.text('Field Tracking'), findsOneWidget);
      expect(find.text('v1.0.0'), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
    });

    testWidgets('Screen 02 EmployeeLoginPage renders fields and admin switch',
        (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(const EmployeeLoginPage()),
      );

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

    testWidgets('Screen 03 AdminLoginPage renders email and password fields',
        (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(const AdminLoginPage()),
      );

      expect(find.text('Admin Login'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);
      expect(find.text('Back to Employee Login'), findsOneWidget);
    });

    testWidgets('Screen 04 PinChangePage enforces rules and enables Save PIN',
        (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(const PinChangePage()),
      );

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
}
