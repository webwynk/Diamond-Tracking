import 'dart:convert';

import 'package:diamond_tracking/core/errors/app_exceptions.dart';
import 'package:diamond_tracking/core/theme/app_theme.dart';
import 'package:diamond_tracking/data/repositories/supabase_employee_repository.dart';
import 'package:diamond_tracking/features/admin/employees/presentation/admin_employee_detail_page.dart';
import 'package:diamond_tracking/features/admin/employees/presentation/controllers/admin_employee_list_state.dart';
import 'package:diamond_tracking/features/admin/employees/presentation/widgets/admin_reset_pin_sheet.dart';
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
);

Widget _host(Widget child) => MaterialApp(
  theme: AppTheme.light,
  home: Scaffold(body: child),
);

void main() {
  group('AdminResetPinSheet', () {
    Future<void> openSheet(
      WidgetTester tester,
      Future<void> Function(String pin) onConfirm,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        _host(AdminResetPinSheet(employee: _employee, onConfirm: onConfirm)),
      );
      await tester.pump();
    }

    bool submitEnabled(WidgetTester tester) => tester
        .widget<ElevatedButton>(find.byKey(const Key('btn-reset-pin-submit')))
        .enabled;

    testWidgets('names the employee and starts with the button off', (
      tester,
    ) async {
      await openSheet(tester, (_) async {});

      expect(find.text('Reset PIN for Suresh Patel?'), findsOneWidget);
      expect(find.text('DA-022'), findsOneWidget);
      expect(submitEnabled(tester), isFalse);
      expect(find.byKey(const Key('reset-pin-error')), findsNothing);
    });

    testWidgets('only digits are accepted, at most six', (tester) async {
      await openSheet(tester, (_) async {});

      await tester.enterText(
        find.byKey(const Key('input-reset-pin')),
        '48a2-9157',
      );
      await tester.pump();

      final field = tester.widget<TextField>(
        find.byKey(const Key('input-reset-pin')),
      );
      expect(field.controller!.text, '482915');
    });

    testWidgets(
      'weak PINs say why and keep the button off; a good one turns it on',
      (tester) async {
        await openSheet(tester, (_) async {});
        final input = find.byKey(const Key('input-reset-pin'));

        for (final entry in <String, String>{
          '111111': 'PIN cannot be one repeated digit.',
          '123456': 'PIN cannot be a simple sequence like 123456.',
          '890123': 'PIN cannot be a simple sequence like 123456.',
        }.entries) {
          await tester.enterText(input, entry.key);
          await tester.pump();
          expect(find.text(entry.value), findsOneWidget, reason: entry.key);
          expect(submitEnabled(tester), isFalse, reason: entry.key);
        }

        await tester.enterText(input, '4829');
        await tester.pump();
        expect(find.byKey(const Key('reset-pin-error')), findsNothing);
        expect(submitEnabled(tester), isFalse, reason: 'only 4 digits');

        await tester.enterText(input, '482915');
        await tester.pump();
        expect(find.byKey(const Key('reset-pin-error')), findsNothing);
        expect(submitEnabled(tester), isTrue);
      },
    );

    testWidgets('submitting sends the PIN and closes the sheet with true', (
      tester,
    ) async {
      String? sent;
      bool? result;
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
                onPressed: () async {
                  result = await AdminResetPinSheet.show(
                    context,
                    employee: _employee,
                    onConfirm: (pin) async => sent = pin,
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('open')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('input-reset-pin')),
        '482915',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('btn-reset-pin-submit')));
      await tester.pumpAndSettle();

      expect(sent, '482915');
      expect(result, isTrue);
      expect(find.byType(AdminResetPinSheet), findsNothing);
    });

    testWidgets('a refusal from the server is shown and the sheet stays', (
      tester,
    ) async {
      await openSheet(
        tester,
        (_) async => throw const ValidationException(
          'PIN cannot be a simple sequence like 123456',
        ),
      );

      await tester.enterText(
        find.byKey(const Key('input-reset-pin')),
        '482915',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('btn-reset-pin-submit')));
      await tester.pumpAndSettle();

      expect(
        find.text('PIN cannot be a simple sequence like 123456'),
        findsOneWidget,
      );
      expect(find.byType(AdminResetPinSheet), findsOneWidget);
      expect(submitEnabled(tester), isTrue, reason: 'it can be tried again');
    });
  });

  testWidgets('the profile has a Reset PIN button that sets the PIN through '
      'the repository and says so', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = FakeEmployeeRepository();
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
      find.byKey(const Key('btn-employee-reset-pin')),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('btn-employee-reset-pin')));
    await tester.pumpAndSettle();

    expect(find.byType(AdminResetPinSheet), findsOneWidget);

    await tester.enterText(find.byKey(const Key('input-reset-pin')), '482915');
    await tester.pump();
    await tester.tap(find.byKey(const Key('btn-reset-pin-submit')));
    await tester.pumpAndSettle();

    expect(repository.pinsReset, <String, String>{'emp-1': '482915'});
    expect(find.byType(AdminResetPinSheet), findsNothing);
    expect(
      find.textContaining('Temporary PIN set for Suresh Patel'),
      findsOneWidget,
    );
  });

  group('SupabaseEmployeeRepository.resetPin', () {
    late List<http.Request> requests;

    SupabaseEmployeeRepository answering(
      http.Response Function(http.Request) answer,
    ) {
      final supabase = MockSupabase(answer);
      requests = supabase.requests;
      return SupabaseEmployeeRepository(supabase.client);
    }

    test('sends the reset to the function and nothing else', () async {
      final repository = answering(
        (_) => jsonResponse(<String, Object?>{'ok': true}),
      );

      await repository.resetPin(id: 'emp-1', newPin: '482915');

      expect(requests, hasLength(1));
      expect(requests.single.url.path, endsWith('/functions/v1/employee-auth'));
      expect(jsonDecode(requests.single.body), <String, Object?>{
        'action': 'reset_pin',
        'employee_id': 'emp-1',
        'new_pin': '482915',
      });
    });

    test('each refusal becomes a plain message', () async {
      Future<void> expectError(
        int status,
        Map<String, Object?> body,
        Matcher matcher,
      ) async {
        final repository = answering((_) => jsonResponse(body, status));
        await expectLater(
          repository.resetPin(id: 'emp-1', newPin: '482915'),
          throwsA(matcher),
        );
      }

      await expectError(
        400,
        <String, Object?>{
          'error': 'validation_failed',
          'fields': <String, Object?>{
            'pin': 'PIN cannot be one repeated digit',
          },
        },
        isA<ValidationException>().having(
          (e) => e.message,
          'message',
          'PIN cannot be one repeated digit',
        ),
      );
      await expectError(
        403,
        <String, Object?>{'error': 'forbidden'},
        isA<UnauthorizedRoleException>().having(
          (e) => e.message,
          'message',
          'Only active administrators can do this.',
        ),
      );
      await expectError(404, <String, Object?>{
        'error': 'employee_not_found',
      }, isA<ValidationException>());
      await expectError(
        500,
        <String, Object?>{'error': 'server_error'},
        isA<ServerException>().having(
          (e) => e.message,
          'message',
          'Could not reset the PIN. Please try again.',
        ),
      );
    });

    test('no internet is a network error', () async {
      final repository = SupabaseEmployeeRepository(
        MockSupabase.offline().client,
      );

      await expectLater(
        repository.resetPin(id: 'emp-1', newPin: '482915'),
        throwsA(isA<NetworkException>()),
      );
    });
  });
}
