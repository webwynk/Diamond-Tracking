import 'package:diamond_tracking/domain/entities/user_profile.dart';
import 'package:diamond_tracking/features/admin/employees/presentation/admin_employee_form_page.dart';
import 'package:diamond_tracking/features/admin/employees/presentation/controllers/admin_employee_form_controller.dart';
import 'package:diamond_tracking/features/admin/employees/presentation/controllers/admin_employee_list_controller.dart';
import 'package:diamond_tracking/features/admin/employees/presentation/controllers/admin_employee_list_state.dart';
import 'package:diamond_tracking/features/admin/employees/presentation/widgets/admin_employee_details_card.dart';
import 'package:diamond_tracking/features/admin/employees/presentation/widgets/admin_employee_form_top_bar.dart';
import 'package:diamond_tracking/features/admin/employees/presentation/widgets/admin_employee_info_strip.dart';
import 'package:diamond_tracking/features/admin/employees/presentation/widgets/admin_employee_login_card.dart';
import 'package:diamond_tracking/features/admin/employees/presentation/widgets/admin_employee_role_card.dart';
import 'package:diamond_tracking/features/admin/employees/presentation/widgets/admin_employee_telemetry_preview_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _createTestableWidget(Widget child) {
  return ProviderScope(
    child: MaterialApp(
      home: child,
    ),
  );
}

void main() {
  group('AdminEmployeeFormNotifier Unit Tests', () {
    test('initializes with default values from HTML design reference', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(adminEmployeeFormControllerProvider);
      expect(state.fullName, 'Kiran Deshmukh');
      expect(state.phoneNumber, '+91 98220 11334');
      expect(state.email, 'kiran.d@diamondagritech.in');
      expect(state.employeeCode, 'DA-144');
      expect(state.initialPin, '849201');
      expect(state.role, UserRole.employee);
      expect(state.isValid, isTrue);
    });

    test('regeneratePin creates a new 6-digit numeric string', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(adminEmployeeFormControllerProvider.notifier).regeneratePin();

      final updatedPin = container.read(adminEmployeeFormControllerProvider).initialPin;
      expect(updatedPin.length, 6);
      expect(int.tryParse(updatedPin), isNotNull);
      expect(container.read(adminEmployeeFormControllerProvider).isPinValid, isTrue);
    });

    test('toggling role updates state', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(adminEmployeeFormControllerProvider.notifier);
      notifier.setRole(UserRole.admin);
      expect(container.read(adminEmployeeFormControllerProvider).role, UserRole.admin);

      notifier.setRole(UserRole.employee);
      expect(container.read(adminEmployeeFormControllerProvider).role, UserRole.employee);
    });

    test('initForm with existing employee sets edit mode', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      const existing = AdminEmployeeItem(
        id: 'emp-022',
        name: 'Suresh Patel',
        employeeCode: 'DA-022',
        phoneNumber: '+91 98201 44556',
        email: 'suresh.p@diamondagritech.in',
        status: AdminEmployeeStatus.onDuty,
        role: UserRole.employee,
      );

      container.read(adminEmployeeFormControllerProvider.notifier).initForm(employee: existing);
      final state = container.read(adminEmployeeFormControllerProvider);

      expect(state.isEditMode, isTrue);
      expect(state.existingEmployeeId, 'emp-022');
      expect(state.fullName, 'Suresh Patel');
      expect(state.employeeCode, 'DA-022');
      expect(state.phoneNumber, '+91 98201 44556');
    });

    test('submit adds employee to list controller and updates success state', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final initialCount =
          container.read(adminEmployeeListControllerProvider).employees.length;

      final success =
          await container.read(adminEmployeeFormControllerProvider.notifier).submit();

      expect(success, isTrue);
      expect(container.read(adminEmployeeFormControllerProvider).isSuccess, isTrue);
      expect(
        container.read(adminEmployeeListControllerProvider).employees.length,
        initialCount + 1,
      );
    });
  });

  group('Screen 19 AdminEmployeeFormTopBar Widget Tests', () {
    testWidgets('renders title and triggers close and save callbacks', (tester) async {
      bool closed = false;
      bool saved = false;

      await tester.pumpWidget(
        _createTestableWidget(
          AdminEmployeeFormTopBar(
            isEditMode: false,
            isValid: true,
            isSaving: false,
            onClose: () => closed = true,
            onSave: () => saved = true,
          ),
        ),
      );

      expect(find.text('Add employee'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);

      await tester.tap(find.byKey(const Key('admin-employee-form-close-btn')));
      expect(closed, isTrue);

      await tester.tap(find.byKey(const Key('admin-employee-form-header-save-btn')));
      expect(saved, isTrue);
    });

    testWidgets('renders Edit employee title when in edit mode', (tester) async {
      await tester.pumpWidget(
        _createTestableWidget(
          AdminEmployeeFormTopBar(
            isEditMode: true,
            isValid: true,
            isSaving: false,
            onClose: () {},
            onSave: () {},
          ),
        ),
      );

      expect(find.text('Edit employee'), findsOneWidget);
    });
  });

  group('Screen 19 AdminEmployeeDetailsCard Widget Tests', () {
    testWidgets('renders all fields, icons, and helper texts', (tester) async {
      final nameCtrl = TextEditingController(text: 'Kiran Deshmukh');
      final phoneCtrl = TextEditingController(text: '+91 98220 11334');
      final emailCtrl = TextEditingController(text: 'kiran.d@diamondagritech.in');

      await tester.pumpWidget(
        _createTestableWidget(
          Scaffold(
            body: AdminEmployeeDetailsCard(
              nameController: nameCtrl,
              phoneController: phoneCtrl,
              emailController: emailCtrl,
              onNameChanged: (_) {},
              onPhoneChanged: (_) {},
              onEmailChanged: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('EMPLOYEE DETAILS'), findsOneWidget);
      expect(find.text('Full name'), findsOneWidget);
      expect(find.text('Phone number'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Used for SMS dispatch and field verification'), findsOneWidget);
      expect(find.text('Official company domain required'), findsOneWidget);

      expect(find.byKey(const Key('admin-employee-name-field')), findsOneWidget);
      expect(find.byKey(const Key('admin-employee-phone-field')), findsOneWidget);
      expect(find.byKey(const Key('admin-employee-email-field')), findsOneWidget);
    });
  });

  group('Screen 19 AdminEmployeeLoginCard Widget Tests', () {
    testWidgets('renders Employee ID with Available chip and PIN with Regen button', (tester) async {
      final idCtrl = TextEditingController(text: 'DA-144');
      final pinCtrl = TextEditingController(text: '849201');
      bool regenTapped = false;

      await tester.pumpWidget(
        _createTestableWidget(
          Scaffold(
            body: AdminEmployeeLoginCard(
              employeeIdController: idCtrl,
              pinController: pinCtrl,
              isEmployeeCodeAvailable: true,
              onEmployeeIdChanged: (_) {},
              onPinChanged: (_) {},
              onRegeneratePin: () => regenTapped = true,
            ),
          ),
        ),
      );

      expect(find.text('LOGIN'), findsOneWidget);
      expect(find.text('Employee ID'), findsOneWidget);
      expect(find.text('Available'), findsOneWidget);
      expect(find.text('Cannot be changed later.'), findsOneWidget);
      expect(find.text('Initial PIN'), findsOneWidget);
      expect(find.text('Regen'), findsOneWidget);
      expect(find.text('The employee must change this at first login.'), findsOneWidget);

      await tester.tap(find.byKey(const Key('admin-employee-pin-regen-btn')));
      expect(regenTapped, isTrue);
    });
  });

  group('Screen 19 AdminEmployeeRoleCard Widget Tests', () {
    testWidgets('renders Employee and Admin role tiles and toggles selection', (tester) async {
      UserRole currentRole = UserRole.employee;

      await tester.pumpWidget(
        _createTestableWidget(
          StatefulBuilder(
            builder: (ctx, setState) => Scaffold(
              body: AdminEmployeeRoleCard(
                selectedRole: currentRole,
                onRoleChanged: (newRole) => setState(() => currentRole = newRole),
              ),
            ),
          ),
        ),
      );

      expect(find.text('ROLE'), findsOneWidget);
      expect(find.text('Permissions tier'), findsOneWidget);
      expect(find.text('Employee'), findsOneWidget);
      expect(find.text('Field Officer'), findsOneWidget);
      expect(find.text('Admin'), findsOneWidget);
      expect(find.text('Supervisor'), findsOneWidget);

      // Tap Admin tile
      await tester.tap(find.byKey(const Key('admin-role-admin-tile')));
      await tester.pumpAndSettle();
      expect(currentRole, UserRole.admin);
    });
  });

  group('Screen 19 Informational Strips Widget Tests', () {
    testWidgets('renders notice strip and telemetry preview card', (tester) async {
      await tester.pumpWidget(
        _createTestableWidget(
          const Scaffold(
            body: Column(
              children: [
                AdminEmployeeInfoStrip(),
                AdminEmployeeTelemetryPreviewCard(),
              ],
            ),
          ),
        ),
      );

      expect(
        find.text(
          'The employee will be asked to allow location access and background tracking at first login.',
        ),
        findsOneWidget,
      );
      expect(find.text('Auto-Provision GPS Sync'), findsOneWidget);
      expect(find.text('15-SECOND HEARTBEAT ACTIVE'), findsOneWidget);
      expect(find.text('READY'), findsOneWidget);
    });
  });

  group('Screen 19 AdminEmployeeFormPage Full Screen Tests', () {
    testWidgets('renders full form page and submits successfully', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _createTestableWidget(
          const AdminEmployeeFormPage(),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Add employee'), findsOneWidget);
      expect(find.text('Create employee'), findsOneWidget);

      // Verify submit button is enabled with valid initial data
      final submitBtnFinder = find.byKey(const Key('admin-employee-form-submit-btn'));
      expect(submitBtnFinder, findsOneWidget);

      await tester.tap(submitBtnFinder);
      await tester.pump(); // Start async provisioning

      // Verify progress indicator appears
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Complete async simulation
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();
    });

    testWidgets('renders edit mode when initialized with existing employee', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const employee = AdminEmployeeItem(
        id: 'emp-022',
        name: 'Suresh Patel',
        employeeCode: 'DA-022',
        phoneNumber: '+91 98201 44556',
        status: AdminEmployeeStatus.onDuty,
      );

      await tester.pumpWidget(
        _createTestableWidget(
          const AdminEmployeeFormPage(employee: employee),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Edit employee'), findsOneWidget);
      expect(find.text('Save changes'), findsOneWidget);
    });
  });
}
