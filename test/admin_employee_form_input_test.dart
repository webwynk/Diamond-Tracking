import 'package:diamond_tracking/core/errors/app_exceptions.dart';
import 'package:diamond_tracking/domain/entities/user_profile.dart';
import 'package:diamond_tracking/features/admin/employees/presentation/admin_employee_form_page.dart';
import 'package:diamond_tracking/features/admin/employees/presentation/controllers/admin_employee_form_controller.dart';
import 'package:diamond_tracking/features/admin/employees/presentation/controllers/admin_employee_list_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_employee_repository.dart';

ProviderContainer _container([FakeEmployeeRepository? repository]) {
  final container = ProviderContainer(
    overrides: [fakeEmployeeRepositoryOverride(repository)],
  );
  addTearDown(container.dispose);
  return container;
}

AdminEmployeeFormNotifier _form(ProviderContainer container) =>
    container.read(adminEmployeeFormControllerProvider.notifier);

AdminEmployeeFormNotifier _filled(ProviderContainer container) {
  return _form(container)
    ..initForm()
    ..setFullName('Kiran Deshmukh')
    ..setPhoneNumber('+91 98220 11334')
    ..setEmployeeCode('da-144')
    ..setPin('482915');
}

Widget _page(FakeEmployeeRepository repository) => ProviderScope(
  overrides: [fakeEmployeeRepositoryOverride(repository)],
  child: const MaterialApp(home: AdminEmployeeFormPage()),
);

Future<void> _fillPage(WidgetTester tester, {String pin = '482915'}) async {
  await tester.enterText(
    find.byKey(const Key('admin-employee-name-field')),
    'Kiran Deshmukh',
  );
  await tester.enterText(
    find.byKey(const Key('admin-employee-phone-field')),
    '+91 98220 11334',
  );
  await tester.enterText(
    find.byKey(const Key('admin-employee-id-field')),
    'DA-144',
  );
  await tester.enterText(
    find.byKey(const Key('admin-employee-pin-field')),
    pin,
  );
  await tester.pump();
}

void main() {
  group('the PIN the admin types', () {
    test('is kept, digits only, at most six', () {
      final container = _container();
      _form(container).initForm();

      _form(container).setPin('482915');
      expect(
        container.read(adminEmployeeFormControllerProvider).initialPin,
        '482915',
      );

      _form(container).setPin('48a2-9 1');
      expect(
        container.read(adminEmployeeFormControllerProvider).initialPin,
        '48291',
      );

      _form(container).setPin('4829150000');
      expect(
        container.read(adminEmployeeFormControllerProvider).initialPin,
        '482915',
      );
    });

    test('a repeated digit or a simple run is refused, with the reason', () {
      final container = _container();
      _form(container).initForm();

      _form(container).setPin('111111');
      var state = container.read(adminEmployeeFormControllerProvider);
      expect(state.isPinValid, isFalse);
      expect(state.pinError, contains('repeated digit'));

      _form(container).setPin('123456');
      state = container.read(adminEmployeeFormControllerProvider);
      expect(state.isPinValid, isFalse);
      expect(state.pinError, contains('simple run'));

      _form(container).setPin('4829');
      expect(
        container.read(adminEmployeeFormControllerProvider).pinError,
        contains('6 digits'),
      );

      _form(container).setPin('482915');
      state = container.read(adminEmployeeFormControllerProvider);
      expect(state.isPinValid, isTrue);
      expect(state.pinError, isNull);
    });

    test('regenerating makes a valid PIN again', () {
      final container = _container();
      _form(container)
        ..initForm()
        ..setPin('111111')
        ..regeneratePin();

      expect(
        container.read(adminEmployeeFormControllerProvider).isPinValid,
        isTrue,
      );
    });
  });

  group('the form accepts exactly what the server accepts', () {
    test('a filled form with no email is valid: the email is optional', () {
      final container = _container();
      _filled(container);

      expect(
        container.read(adminEmployeeFormControllerProvider).isValid,
        isTrue,
      );
    });

    test('an email, when given, must look like one', () {
      final container = _container();
      _filled(container).setEmail('not-an-email');
      expect(
        container.read(adminEmployeeFormControllerProvider).isValid,
        isFalse,
      );

      _form(container).setEmail('kiran@example.com');
      expect(
        container.read(adminEmployeeFormControllerProvider).isValid,
        isTrue,
      );
    });

    test('the employee ID must look like DA-144, and says so', () {
      final container = _container();
      _filled(container);

      for (final bad in [
        'DA144',
        'DA-1',
        'D-144',
        'DAXYZ-144',
        'DA-1234567',
        '144',
      ]) {
        _form(container).setEmployeeCode(bad);
        final state = container.read(adminEmployeeFormControllerProvider);
        expect(state.isEmployeeCodeValid, isFalse, reason: bad);
        expect(state.isValid, isFalse, reason: bad);
        expect(state.employeeCodeError, contains('DA-144'), reason: bad);
      }

      _form(container).setEmployeeCode('da-144');
      expect(
        container.read(adminEmployeeFormControllerProvider).isValid,
        isTrue,
      );
    });

    test('a phone number needs 10 to 15 digits, spaces and dashes allowed', () {
      final container = _container();
      _filled(container);

      _form(container).setPhoneNumber('98220 1133');
      expect(
        container.read(adminEmployeeFormControllerProvider).isValid,
        isFalse,
      );

      _form(container).setPhoneNumber('98220-11334');
      expect(
        container.read(adminEmployeeFormControllerProvider).isValid,
        isTrue,
      );

      _form(container).setPhoneNumber('+91 98220 11334 0000 000');
      expect(
        container.read(adminEmployeeFormControllerProvider).isValid,
        isFalse,
      );
    });

    test('editing never asks for the ID or PIN again', () {
      final container = _container();
      _form(container).initForm(
        employee: const AdminEmployeeItem(
          id: 'e1',
          name: 'Kiran Deshmukh',
          employeeCode: 'DA-144',
          phoneNumber: '+919822011334',
          status: AdminEmployeeStatus.offDuty,
          role: UserRole.employee,
        ),
      );

      final state = container.read(adminEmployeeFormControllerProvider);
      expect(state.isValid, isTrue);
      expect(state.pinError, isNull);
      expect(state.employeeCodeError, isNull);
    });
  });

  group('when the server says no', () {
    test(
      'the reason is kept for the screen, never raw exception text',
      () async {
        final container = _container(
          FakeEmployeeRepository(
            error: const ValidationException(
              'PIN cannot be a simple sequence like 123456',
            ),
          ),
        );
        final form = _filled(container);

        final saved = await form.submit();

        expect(saved, isFalse);
        final state = container.read(adminEmployeeFormControllerProvider);
        expect(
          state.errorMessage,
          'PIN cannot be a simple sequence like 123456',
        );
        expect(state.isSaving, isFalse);
      },
    );
  });

  group('the Add employee screen', () {
    testWidgets('keeps the digits typed into the PIN box', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_page(FakeEmployeeRepository()));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('admin-employee-pin-field')),
        '482915',
      );
      await tester.pump();

      final field = tester.widget<TextField>(
        find.byKey(const Key('admin-employee-pin-field')),
      );
      expect(field.controller?.text, '482915');
      expect(
        field.obscureText,
        isFalse,
        reason: 'the admin must be able to read it out',
      );
    });

    testWidgets('names a bad ID and a bad PIN under the field', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_page(FakeEmployeeRepository()));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('admin-employee-id-field')),
        'DA144',
      );
      await tester.enterText(
        find.byKey(const Key('admin-employee-pin-field')),
        '123456',
      );
      await tester.pump();

      expect(
        find.text(
          'Use a code like DA-144: 2-4 letters, a dash, then 2-6 digits.',
        ),
        findsOneWidget,
      );
      expect(
        find.text('The PIN cannot be a simple run, like 123456.'),
        findsOneWidget,
      );
      final save = tester.widget<ElevatedButton>(
        find.byKey(const Key('admin-employee-form-submit-btn')),
      );
      expect(save.onPressed, isNull);
    });

    testWidgets('shows why the server refused, instead of doing nothing', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        _page(
          FakeEmployeeRepository(
            error: const ConflictException(
              'That employee code is already in use.',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _fillPage(tester);

      await tester.tap(find.byKey(const Key('admin-employee-form-submit-btn')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('banner-employee-form-error')),
        findsOneWidget,
      );
      expect(
        find.text('That employee code is already in use.'),
        findsOneWidget,
      );
      expect(
        find.byType(AdminEmployeeFormPage),
        findsOneWidget,
        reason: 'stays open to fix it',
      );
    });

    testWidgets('after creating, shows the ID and the PIN to hand over', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_page(FakeEmployeeRepository()));
      await tester.pumpAndSettle();
      await _fillPage(tester);

      await tester.tap(find.byKey(const Key('admin-employee-form-submit-btn')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('dialog-employee-login-details')),
        findsOneWidget,
      );
      expect(find.text('DA-144'), findsWidgets);
      expect(
        tester.widget<Text>(find.byKey(const Key('login-details-code'))).data,
        'DA-144',
      );
      expect(
        tester.widget<Text>(find.byKey(const Key('login-details-pin'))).data,
        '482915',
      );

      await tester.tap(find.byKey(const Key('btn-login-details-done')));
      await tester.pumpAndSettle();
      expect(find.byType(AdminEmployeeFormPage), findsNothing);
    });
  });
}
