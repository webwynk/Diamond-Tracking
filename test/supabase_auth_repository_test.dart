import 'dart:convert';

import 'package:diamond_tracking/core/errors/app_exceptions.dart';
import 'package:diamond_tracking/data/repositories/supabase_auth_repository.dart';
import 'package:diamond_tracking/domain/entities/user_profile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'support/mock_supabase.dart';

/// These tests drive the real [SupabaseAuthRepository] and the real Supabase
/// client; only the network is replaced. They check what is sent (the PIN goes
/// to the `employee-auth` function and never to Supabase Auth) and how each
/// answer, including every refusal, is turned into the app's own errors.
const _userId = '11111111-1111-4111-8111-111111111111';

String _jwt() {
  String part(Map<String, Object?> map) =>
      base64Url.encode(utf8.encode(jsonEncode(map))).replaceAll('=', '');
  final exp =
      DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
      1000;
  return '${part(<String, Object?>{'alg': 'HS256', 'typ': 'JWT'})}'
      '.${part(<String, Object?>{'sub': _userId, 'exp': exp, 'role': 'authenticated'})}'
      '.signature';
}

Map<String, Object?> _sessionJson() => <String, Object?>{
  'access_token': _jwt(),
  'token_type': 'bearer',
  'expires_in': 3600,
  'refresh_token': 'refresh-1',
  'user': <String, Object?>{
    'id': _userId,
    'aud': 'authenticated',
    'role': 'authenticated',
    'email': 'da-014@staff.diamondagritech.internal',
    'app_metadata': <String, Object?>{},
    'user_metadata': <String, Object?>{},
    'created_at': '2026-10-17T09:00:00Z',
  },
};

Map<String, Object?> _profile({
  String role = 'employee',
  String status = 'active',
  String? deviceId,
}) => <String, Object?>{
  'id': _userId,
  'role': role,
  'status': status,
  'full_name': 'Ramesh Kumar',
  'employee_code': role == 'employee' ? 'DA-014' : null,
  'phone': '+919822011334',
  'email': 'da-014@staff.diamondagritech.internal',
  'device_id': deviceId,
  'must_change_pin': false,
  'failed_login_attempts': 0,
  'locked_until': null,
  'created_at': '2026-10-17T09:00:00Z',
  'updated_at': '2026-10-17T09:00:00Z',
};

http.Response _fn(int status, Map<String, Object?> body) =>
    jsonResponse(body, status);

void main() {
  late List<http.Request> requests;

  SupabaseAuthRepository repositoryAnswering(
    http.Response Function(http.Request request) answer,
  ) {
    final supabase = MockSupabase(answer);
    requests = supabase.requests;
    return SupabaseAuthRepository(client: supabase.client);
  }

  bool sentToAuthPasswordGrant() => requests.any(
    (r) =>
        r.url.path.endsWith('/auth/v1/token') &&
        r.url.queryParameters['grant_type'] == 'password',
  );

  /// The happy server: the function returns a session, the refresh works, the
  /// profile is read and the device binds.
  http.Response happy(http.Request request, {bool bound = true}) {
    final path = request.url.path;
    if (path.endsWith('/functions/v1/employee-auth')) {
      return _fn(200, <String, Object?>{
        'session': <String, Object?>{'refresh_token': 'refresh-1'},
        'must_change_pin': false,
      });
    }
    if (path.endsWith('/auth/v1/token')) return jsonResponse(_sessionJson());
    if (path.endsWith('/rest/v1/profiles')) return jsonResponse(_profile());
    if (path.endsWith('/rpc/bind_my_device')) return jsonResponse(bound);
    return jsonResponse(<String, Object?>{}, 404);
  }

  group('employee sign-in', () {
    test('sends the code and PIN to the function, never to Supabase Auth, '
        'and returns the profile', () async {
      final repository = repositoryAnswering(happy);

      final profile = await repository.signInEmployee(
        employeeCode: ' DA-014 ',
        pin: '482915',
        deviceId: 'device-1',
      );

      expect(profile.employeeCode, 'DA-014');
      expect(profile.role, UserRole.employee);
      expect(profile.deviceId, 'device-1');

      final call = requests.firstWhere(
        (r) => r.url.path.endsWith('/functions/v1/employee-auth'),
      );
      expect(jsonDecode(call.body), <String, Object?>{
        'action': 'login',
        'employee_code': 'DA-014',
        'pin': '482915',
      });
      expect(sentToAuthPasswordGrant(), isFalse);
      expect(
        requests.any((r) => r.url.path.endsWith('/rpc/bind_my_device')),
        isTrue,
      );
    });

    test('empty fields are refused without asking the server', () async {
      final repository = repositoryAnswering(happy);

      await expectLater(
        repository.signInEmployee(
          employeeCode: '  ',
          pin: '482915',
          deviceId: 'device-1',
        ),
        throwsA(isA<InvalidCredentialsException>()),
      );
      expect(requests, isEmpty);
    });

    test('a wrong code or PIN is one plain message', () async {
      final repository = repositoryAnswering(
        (_) => _fn(401, <String, Object?>{'error': 'invalid_credentials'}),
      );

      await expectLater(
        repository.signInEmployee(
          employeeCode: 'DA-014',
          pin: '000001',
          deviceId: 'device-1',
        ),
        throwsA(
          isA<InvalidCredentialsException>().having(
            (e) => e.message,
            'message',
            'Incorrect employee code or PIN.',
          ),
        ),
      );
    });

    test('a locked account says how long to wait', () async {
      for (final entry in <int, String>{
        900: 'Too many wrong tries. Try again in 15 minutes.',
        600: 'Too many wrong tries. Try again in 10 minutes.',
        61: 'Too many wrong tries. Try again in 2 minutes.',
        30: 'Too many wrong tries. Try again in 1 minute.',
      }.entries) {
        final repository = repositoryAnswering(
          (_) => _fn(429, <String, Object?>{
            'error': 'account_locked',
            'retry_after_seconds': entry.key,
          }),
        );

        await expectLater(
          repository.signInEmployee(
            employeeCode: 'DA-014',
            pin: '482915',
            deviceId: 'device-1',
          ),
          throwsA(
            isA<AccountLockedException>()
                .having((e) => e.message, 'message', entry.value)
                .having((e) => e.lockedUntil, 'lockedUntil', isNotNull),
          ),
        );
      }
    });

    test('a blocked account is told to contact the office', () async {
      final repository = repositoryAnswering(
        (_) => _fn(403, <String, Object?>{'error': 'account_blocked'}),
      );

      await expectLater(
        repository.signInEmployee(
          employeeCode: 'DA-014',
          pin: '482915',
          deviceId: 'device-1',
        ),
        throwsA(isA<AccountBlockedException>()),
      );
    });

    test('no internet is a network error, not a wrong PIN', () async {
      final repository = SupabaseAuthRepository(
        client: MockSupabase.offline().client,
      );

      await expectLater(
        repository.signInEmployee(
          employeeCode: 'DA-014',
          pin: '482915',
          deviceId: 'device-1',
        ),
        throwsA(isA<NetworkException>()),
      );
    });

    test('a server fault never shows raw text', () async {
      final repository = repositoryAnswering(
        (_) => _fn(500, <String, Object?>{
          'error': 'login_failed',
          'detail': 'secret database text',
        }),
      );

      await expectLater(
        repository.signInEmployee(
          employeeCode: 'DA-014',
          pin: '482915',
          deviceId: 'device-1',
        ),
        throwsA(
          isA<ServerException>().having(
            (e) => e.message,
            'message',
            'Sign-in failed. Please try again.',
          ),
        ),
      );
    });

    test('a second device is refused and signed out again', () async {
      final repository = repositoryAnswering((r) => happy(r, bound: false));

      await expectLater(
        repository.signInEmployee(
          employeeCode: 'DA-014',
          pin: '482915',
          deviceId: 'device-2',
        ),
        throwsA(isA<DeviceBindingException>()),
      );
    });

    test('a profile that turns out to be blocked is refused', () async {
      final repository = repositoryAnswering((request) {
        if (request.url.path.endsWith('/rest/v1/profiles')) {
          return jsonResponse(_profile(status: 'blocked'));
        }
        return happy(request);
      });

      await expectLater(
        repository.signInEmployee(
          employeeCode: 'DA-014',
          pin: '482915',
          deviceId: 'device-1',
        ),
        throwsA(isA<AccountBlockedException>()),
      );
    });
  });

  group('PIN change', () {
    test(
      'goes to the function; the app no longer sets the password itself',
      () async {
        final repository = repositoryAnswering(
          (_) => _fn(200, <String, Object?>{'ok': true}),
        );

        await repository.changePin(newPin: '135792');

        expect(requests, hasLength(1));
        expect(
          requests.single.url.path,
          endsWith('/functions/v1/employee-auth'),
        );
        expect(jsonDecode(requests.single.body), <String, Object?>{
          'action': 'change_pin',
          'new_pin': '135792',
        });
      },
    );

    test(
      'a PIN the server refuses shows the server rule in plain words',
      () async {
        final repository = repositoryAnswering(
          (_) => _fn(400, <String, Object?>{
            'error': 'validation_failed',
            'fields': <String, Object?>{
              'pin': 'PIN cannot be a simple sequence like 123456',
            },
          }),
        );

        await expectLater(
          repository.changePin(newPin: '123456'),
          throwsA(
            isA<ValidationException>().having(
              (e) => e.message,
              'message',
              'PIN cannot be a simple sequence like 123456',
            ),
          ),
        );
      },
    );

    test('a change that is not allowed, and no internet', () async {
      final notAllowed = repositoryAnswering(
        (_) => _fn(403, <String, Object?>{'error': 'pin_change_not_allowed'}),
      );
      await expectLater(
        notAllowed.changePin(newPin: '135792'),
        throwsA(isA<ValidationException>()),
      );

      final offline = SupabaseAuthRepository(
        client: MockSupabase.offline().client,
      );
      await expectLater(
        offline.changePin(newPin: '135792'),
        throwsA(isA<NetworkException>()),
      );
    });
  });

  group('admin sign-in', () {
    test('a blocked administrator is told so', () async {
      final repository = repositoryAnswering(
        (_) => jsonResponse(<String, Object?>{
          'code': 403,
          'error_code': 'user_banned',
          'msg': 'User is banned',
        }, 403),
      );

      await expectLater(
        repository.signInAdmin(
          email: 'office@example.com',
          password: 'pass-word',
        ),
        throwsA(isA<AccountBlockedException>()),
      );
    });

    test('a wrong password is one plain message', () async {
      final repository = repositoryAnswering(
        (_) => jsonResponse(<String, Object?>{
          'code': 400,
          'error_code': 'invalid_credentials',
          'msg': 'Invalid login credentials',
        }, 400),
      );

      await expectLater(
        repository.signInAdmin(email: 'office@example.com', password: 'wrong'),
        throwsA(
          isA<InvalidCredentialsException>().having(
            (e) => e.message,
            'message',
            'Incorrect email or password.',
          ),
        ),
      );
    });

    test('an administrator signs in and gets the admin profile', () async {
      final repository = repositoryAnswering((request) {
        if (request.url.path.endsWith('/auth/v1/token')) {
          return jsonResponse(_sessionJson());
        }
        if (request.url.path.endsWith('/rest/v1/profiles')) {
          return jsonResponse(_profile(role: 'admin'));
        }
        return jsonResponse(<String, Object?>{}, 404);
      });

      final profile = await repository.signInAdmin(
        email: 'office@example.com',
        password: 'pass-word',
      );

      expect(profile.role, UserRole.admin);
    });

    test('an employee cannot use the admin door', () async {
      final repository = repositoryAnswering((request) {
        if (request.url.path.endsWith('/auth/v1/token')) {
          return jsonResponse(_sessionJson());
        }
        return jsonResponse(_profile());
      });

      await expectLater(
        repository.signInAdmin(email: 'x@example.com', password: 'pass-word'),
        throwsA(isA<UnauthorizedRoleException>()),
      );
    });
  });
}
