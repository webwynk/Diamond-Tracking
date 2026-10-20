import 'dart:convert';

import 'package:diamond_tracking/core/errors/app_exceptions.dart';
import 'package:diamond_tracking/core/theme/app_theme.dart';
import 'package:diamond_tracking/data/repositories/supabase_employee_repository.dart';
import 'package:diamond_tracking/features/admin/employees/presentation/admin_employee_detail_page.dart';
import 'package:diamond_tracking/features/admin/employees/presentation/controllers/admin_employee_list_state.dart';
import 'package:diamond_tracking/features/admin/employees/presentation/widgets/admin_clear_device_sheet.dart';
import 'package:diamond_tracking/features/admin/employees/presentation/widgets/admin_employee_clear_device_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'support/employee_fixtures.dart';
import 'support/fake_admin_visits.dart';
import 'support/fake_attendance.dart';
import 'support/fake_employee_repository.dart';
import 'support/mock_supabase.dart';

const _employee = AdminEmployeeItem(
  id: 'emp-1',
  name: 'Suresh Patel',
  employeeCode: 'DA-022',
  phoneNumber: '+91 98201 44556',
  status: AdminEmployeeStatus.offDuty,
  deviceRegistered: true,
);

Widget _host(Widget child) => MaterialApp(
  theme: AppTheme.light,
  home: Scaffold(body: child),
);

void main() {
  group('AdminEmployeeClearDeviceButton', () {
    Future<void> pump(WidgetTester tester, bool? registered) async {
      await tester.pumpWidget(
        _host(
          AdminEmployeeClearDeviceButton(
            deviceRegistered: registered,
            onPressed: () {},
          ),
        ),
      );
    }

    bool enabled(WidgetTester tester) => tester
        .widget<OutlinedButton>(
          find.byKey(const Key('btn-employee-clear-device')),
        )
        .enabled;

    testWidgets('a registered phone: says so and the button is on', (
      tester,
    ) async {
      await pump(tester, true);

      expect(find.text('Clear device binding'), findsOneWidget);
      expect(
        find.text('A phone is registered to this employee.'),
        findsOneWidget,
      );
      expect(enabled(tester), isTrue);
    });

    testWidgets('no phone registered: says so and the button is off', (
      tester,
    ) async {
      await pump(tester, false);

      expect(find.textContaining('No phone is registered yet'), findsOneWidget);
      expect(enabled(tester), isFalse);
    });

    testWidgets('not known: nothing is claimed and the button is on', (
      tester,
    ) async {
      await pump(tester, null);

      expect(find.byKey(const Key('clear-device-caption')), findsNothing);
      expect(enabled(tester), isTrue);
    });
  });

  group('AdminClearDeviceSheet', () {
    Future<void> open(
      WidgetTester tester,
      Future<bool> Function() onConfirm,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                key: const Key('open'),
                onPressed: () => AdminClearDeviceSheet.show(
                  context,
                  employee: _employee,
                  onConfirm: onConfirm,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('open')));
      await tester.pumpAndSettle();
    }

    testWidgets('names the employee and says what will happen', (tester) async {
      await open(tester, () async => true);

      expect(
        find.text('Clear device binding for Suresh Patel?'),
        findsOneWidget,
      );
      expect(find.text('DA-022'), findsOneWidget);
      expect(
        find.text('They are signed out of their current phone.'),
        findsOneWidget,
      );
      expect(
        find.textContaining('next phone they sign in on becomes'),
        findsOneWidget,
      );
      expect(find.text('This is recorded in the audit log.'), findsOneWidget);
    });

    testWidgets('confirming asks the server once and closes with its answer', (
      tester,
    ) async {
      var calls = 0;
      bool? popped;
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                key: const Key('open'),
                onPressed: () async =>
                    popped = await AdminClearDeviceSheet.show(
                      context,
                      employee: _employee,
                      onConfirm: () async {
                        calls++;
                        return false;
                      },
                    ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('open')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('btn-clear-device-submit')));
      await tester.pumpAndSettle();

      expect(calls, 1);
      expect(
        popped,
        isFalse,
        reason: 'the server said no phone was registered',
      );
      expect(find.byType(AdminClearDeviceSheet), findsNothing);
    });

    testWidgets('cancel closes with null and asks nothing', (tester) async {
      var calls = 0;
      bool? popped = true;
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                key: const Key('open'),
                onPressed: () async =>
                    popped = await AdminClearDeviceSheet.show(
                      context,
                      employee: _employee,
                      onConfirm: () async {
                        calls++;
                        return true;
                      },
                    ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('open')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('btn-clear-device-cancel')));
      await tester.pumpAndSettle();

      expect(calls, 0);
      expect(popped, isNull);
    });

    testWidgets('a refusal is shown, the sheet stays and can be retried', (
      tester,
    ) async {
      await open(
        tester,
        () async => throw const UnauthorizedRoleException(
          'Only active administrators can do this.',
        ),
      );

      await tester.tap(find.byKey(const Key('btn-clear-device-submit')));
      await tester.pumpAndSettle();

      expect(
        find.text('Only active administrators can do this.'),
        findsOneWidget,
      );
      expect(find.byType(AdminClearDeviceSheet), findsOneWidget);
      expect(
        tester
            .widget<ElevatedButton>(
              find.byKey(const Key('btn-clear-device-submit')),
            )
            .enabled,
        isTrue,
      );
    });
  });

  group('the profile page', () {
    Future<FakeEmployeeRepository> pumpPage(
      WidgetTester tester, {
      bool result = true,
    }) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repository = FakeEmployeeRepository()..clearDeviceResult = result;
      final container = ProviderContainer(
        overrides: [
          fixtureEmployeeListOverride,
          fakeEmployeeRepositoryOverride(repository),
          adminVisitsOverride(),
          ...attendanceOverrides(FakeAttendanceRepository()),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: _host(const AdminEmployeeDetailPage(employee: _employee)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('btn-employee-clear-device')),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      return repository;
    }

    testWidgets('clearing asks the server, then the page says no phone is '
        'registered and the button turns off', (tester) async {
      final repository = await pumpPage(tester);
      expect(
        find.text('A phone is registered to this employee.'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('btn-employee-clear-device')));
      await tester.pumpAndSettle();
      expect(find.byType(AdminClearDeviceSheet), findsOneWidget);

      await tester.tap(find.byKey(const Key('btn-clear-device-submit')));
      await tester.pumpAndSettle();

      expect(repository.devicesCleared, <String>['emp-1']);
      expect(find.byType(AdminClearDeviceSheet), findsNothing);
      expect(
        find.textContaining('Device binding cleared for Suresh Patel'),
        findsOneWidget,
      );
      expect(find.textContaining('No phone is registered yet'), findsOneWidget);
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const Key('btn-employee-clear-device')),
            )
            .enabled,
        isFalse,
      );
    });

    testWidgets('when the server says no phone was registered, the page says '
        'so instead of claiming a clear', (tester) async {
      await pumpPage(tester, result: false);

      await tester.tap(find.byKey(const Key('btn-employee-clear-device')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('btn-clear-device-submit')));
      await tester.pumpAndSettle();

      expect(
        find.text('No phone was registered for Suresh Patel.'),
        findsOneWidget,
      );
      expect(find.textContaining('Device binding cleared'), findsNothing);
    });
  });

  group('SupabaseEmployeeRepository.clearDevice', () {
    late List<http.Request> requests;

    SupabaseEmployeeRepository answering(
      http.Response Function(http.Request) answer,
    ) {
      final supabase = MockSupabase(answer);
      requests = supabase.requests;
      return SupabaseEmployeeRepository(supabase.client);
    }

    http.Response error(int status, String code, String message) =>
        jsonResponse(<String, Object?>{
          'code': code,
          'message': message,
          'details': null,
          'hint': null,
        }, status);

    test(
      'calls the database function with the employee id and nothing else',
      () async {
        final repository = answering((_) => jsonResponse(true));

        final cleared = await repository.clearDevice(id: 'emp-1');

        expect(cleared, isTrue);
        expect(requests, hasLength(1));
        expect(requests.single.url.path, endsWith('/rpc/admin_clear_device'));
        expect(jsonDecode(requests.single.body), <String, Object?>{
          'p_employee': 'emp-1',
        });
      },
    );

    test('false means no phone was registered', () async {
      final repository = answering((_) => jsonResponse(false));

      expect(await repository.clearDevice(id: 'emp-1'), isFalse);
    });

    test('each refusal becomes a plain message', () async {
      Future<void> expectError(http.Response answer, Matcher matcher) async {
        final repository = answering((_) => answer);
        await expectLater(
          repository.clearDevice(id: 'emp-1'),
          throwsA(matcher),
        );
      }

      await expectError(
        error(403, '42501', 'forbidden'),
        isA<UnauthorizedRoleException>(),
      );
      await expectError(
        error(400, 'P0001', 'employee_not_found'),
        isA<ValidationException>().having(
          (e) => e.message,
          'message',
          'That employee no longer exists.',
        ),
      );
      await expectError(
        error(500, 'XX000', 'secret database text'),
        isA<ServerException>().having(
          (e) => e.message,
          'message',
          'Could not clear the device binding. Please try again.',
        ),
      );
      await expectError(
        jsonResponse(<String, Object?>{'unexpected': true}),
        isA<ServerException>(),
      );
    });

    test('no internet is a network error', () async {
      final repository = SupabaseEmployeeRepository(
        MockSupabase.offline().client,
      );

      await expectLater(
        repository.clearDevice(id: 'emp-1'),
        throwsA(isA<NetworkException>()),
      );
    });
  });
}
