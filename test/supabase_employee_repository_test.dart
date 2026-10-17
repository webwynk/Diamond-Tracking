import 'dart:convert';

import 'package:diamond_tracking/core/errors/app_exceptions.dart';
import 'package:diamond_tracking/data/repositories/supabase_employee_repository.dart';
import 'package:diamond_tracking/features/admin/employees/presentation/controllers/admin_employee_list_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'support/mock_supabase.dart';

/// These tests drive the real [SupabaseEmployeeRepository] and the real
/// Supabase client; only the network is replaced by [MockClient], so they
/// check the requests it sends and how it reads the server's answers.
Map<String, Object?> _profile({
  String id = 'e1',
  String status = 'active',
  String? contactEmail,
}) => <String, Object?>{
  'id': id,
  'role': 'employee',
  'status': status,
  'full_name': 'Kiran Deshmukh',
  'employee_code': 'DA-144',
  'phone': '+919822011334',
  'email': 'da-144@staff.diamondagritech.internal',
  'contact_email': contactEmail,
  'must_change_pin': true,
  'created_at': '2026-10-17T09:00:00Z',
  'updated_at': '2026-10-17T09:00:00Z',
};

void main() {
  late List<http.Request> requests;

  SupabaseEmployeeRepository repositoryAnswering(
    http.Response Function(http.Request request) answer,
  ) {
    final supabase = MockSupabase(answer);
    requests = supabase.requests;
    return SupabaseEmployeeRepository(supabase.client);
  }

  group('getEmployees', () {
    test(
      'marks on-duty from live_locations, blocked from status, and never shows the login email',
      () async {
        final repository = repositoryAnswering((request) {
          if (request.url.path.endsWith('/live_locations')) {
            return jsonResponse(<Object>[
              <String, Object>{'employee_id': 'e1'},
            ]);
          }
          return jsonResponse(<Object>[
            _profile(),
            _profile(
              id: 'e2',
              status: 'blocked',
              contactEmail: 'real@example.com',
            ),
            _profile(id: 'e3'),
          ]);
        });

        final items = await repository.getEmployees();

        expect(items.map((e) => e.status), <AdminEmployeeStatus>[
          AdminEmployeeStatus.onDuty,
          AdminEmployeeStatus.blocked,
          AdminEmployeeStatus.offDuty,
        ]);
        expect(items[1].isActive, isFalse);
        expect(
          items[0].email,
          isNull,
          reason: 'the synthetic login address is not a contact email',
        );
        expect(items[1].email, 'real@example.com');
        expect(requests.first.url.queryParameters['role'], 'eq.employee');
      },
    );

    test('a server failure is an error, not an empty team', () async {
      final repository = repositoryAnswering(
        (_) => jsonResponse(<String, Object>{
          'code': '500',
          'message': 'boom',
        }, 500),
      );

      await expectLater(
        repository.getEmployees(),
        throwsA(isA<ServerException>()),
      );
    });

    test('a lost connection is reported as a network error', () async {
      final repository = SupabaseEmployeeRepository(
        MockSupabase.offline().client,
      );

      await expectLater(
        repository.getEmployees(),
        throwsA(isA<NetworkException>()),
      );
    });
  });

  group('createEmployee', () {
    Future<AdminEmployeeItem> create(SupabaseEmployeeRepository repository) {
      return repository.createEmployee(
        fullName: '  Kiran Deshmukh ',
        phone: '+919822011334',
        employeeCode: ' da-144 ',
        pin: '482915',
        email: '  ',
      );
    }

    test(
      'sends trimmed, upper-cased values to the create-employee function and reads the answer',
      () async {
        final repository = repositoryAnswering(
          (_) => jsonResponse(<String, Object>{
            'employee': <String, Object?>{
              'id': 'new-id',
              'employee_code': 'DA-144',
              'full_name': 'Kiran Deshmukh',
              'phone': '+919822011334',
              'contact_email': null,
            },
          }, 201),
        );

        final employee = await create(repository);

        expect(requests.single.url.path, '/functions/v1/create-employee');
        final sent = jsonDecode(requests.single.body) as Map<String, dynamic>;
        expect(sent['full_name'], 'Kiran Deshmukh');
        expect(sent['employee_code'], 'DA-144');
        expect(sent['email'], '');
        expect(employee.id, 'new-id');
        expect(employee.status, AdminEmployeeStatus.offDuty);
      },
    );

    test('409 employee_code_taken becomes a ConflictException', () async {
      final repository = repositoryAnswering(
        (_) =>
            jsonResponse(<String, Object>{'error': 'employee_code_taken'}, 409),
      );

      await expectLater(
        create(repository),
        throwsA(
          isA<ConflictException>().having(
            (e) => e.message,
            'message',
            contains('code'),
          ),
        ),
      );
    });

    test(
      '409 phone_taken becomes a ConflictException about the phone',
      () async {
        final repository = repositoryAnswering(
          (_) => jsonResponse(<String, Object>{'error': 'phone_taken'}, 409),
        );

        await expectLater(
          create(repository),
          throwsA(
            isA<ConflictException>().having(
              (e) => e.message,
              'message',
              contains('phone'),
            ),
          ),
        );
      },
    );

    test('400 carries the server field messages to the admin', () async {
      final repository = repositoryAnswering(
        (_) => jsonResponse(<String, Object>{
          'error': 'validation_failed',
          'fields': <String, String>{
            'pin': 'PIN cannot be a simple sequence like 123456',
          },
        }, 400),
      );

      await expectLater(
        create(repository),
        throwsA(
          isA<ValidationException>().having(
            (e) => e.message,
            'message',
            contains('simple sequence'),
          ),
        ),
      );
    });

    test('403 and 401 become permission errors', () async {
      for (final status in <int>[401, 403]) {
        final repository = repositoryAnswering(
          (_) => jsonResponse(<String, Object>{'error': 'forbidden'}, status),
        );
        await expectLater(
          create(repository),
          throwsA(isA<UnauthorizedRoleException>()),
        );
      }
    });

    test('a 201 without an employee id is not trusted', () async {
      final repository = repositoryAnswering(
        (_) => jsonResponse(<String, Object>{}, 201),
      );

      await expectLater(create(repository), throwsA(isA<ServerException>()));
    });
  });

  group('updateEmployee, blockEmployee, unblockEmployee', () {
    test(
      'update sends only the editable fields and clears an emptied email',
      () async {
        final repository = repositoryAnswering((_) => jsonResponse(_profile()));

        await repository.updateEmployee(
          id: 'e1',
          fullName: ' Kiran D ',
          phone: '+919822011334',
          email: '',
        );

        final sent = jsonDecode(requests.single.body) as Map<String, dynamic>;
        expect(requests.single.method, 'PATCH');
        expect(sent.keys.toSet(), <String>{
          'full_name',
          'phone',
          'contact_email',
        });
        expect(sent['full_name'], 'Kiran D');
        expect(sent['contact_email'], isNull);
      },
    );

    test('the database refusing a code change is explained', () async {
      final repository = repositoryAnswering(
        (_) => jsonResponse(<String, Object>{
          'code': 'P0001',
          'message': 'immutable_field',
        }, 400),
      );

      await expectLater(
        repository.updateEmployee(
          id: 'e1',
          fullName: 'Kiran',
          phone: '+919822011334',
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test(
      'block sends the reason; a block that changes no row is an error',
      () async {
        var affected = true;
        final repository = repositoryAnswering(
          (_) => jsonResponse(
            affected
                ? <Object>[
                    <String, Object>{'id': 'e1'},
                  ]
                : <Object>[],
          ),
        );

        await repository.blockEmployee(id: 'e1', reason: ' Fake GPS ');
        final sent = jsonDecode(requests.single.body) as Map<String, dynamic>;
        expect(sent, <String, Object>{
          'status': 'blocked',
          'blocked_reason': 'Fake GPS',
        });

        affected = false;
        await expectLater(
          repository.blockEmployee(id: 'e1', reason: 'x'),
          throwsA(isA<UnauthorizedRoleException>()),
        );
        await expectLater(
          repository.unblockEmployee(id: 'e1'),
          throwsA(isA<UnauthorizedRoleException>()),
        );
      },
    );
  });
}
