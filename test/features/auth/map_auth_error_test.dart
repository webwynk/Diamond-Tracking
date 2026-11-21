import 'dart:io';

import 'package:diamond_tracking/features/auth/data/auth_repository.dart';
import 'package:diamond_tracking/features/auth/domain/auth_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('no connection', () {
    expect(mapAuthError(const SocketException('x')), AuthFailure.network);
    expect(mapAuthError(AuthRetryableFetchException()), AuthFailure.network);
  });

  test('sign-in errors', () {
    expect(
      mapAuthError(
        const AuthApiException(
          'x',
          statusCode: '400',
          code: 'invalid_credentials',
        ),
      ),
      AuthFailure.invalidCredentials,
    );
    expect(
      mapAuthError(const AuthApiException('x', statusCode: '429')),
      AuthFailure.tooManyAttempts,
    );
    expect(
      mapAuthError(
        const AuthApiException('x', statusCode: '400', code: 'user_banned'),
      ),
      AuthFailure.accountInactive,
    );
  });

  test('database errors from claiming the phone', () {
    expect(
      mapAuthError(const PostgrestException(message: 'signed_in_elsewhere')),
      AuthFailure.signedInElsewhere,
    );
    expect(
      mapAuthError(const PostgrestException(message: 'account_inactive')),
      AuthFailure.accountInactive,
    );
  });

  test('Edge Function errors', () {
    FunctionException fx(int status, String error) => FunctionException(
      status: status,
      details: <String, dynamic>{'error': error},
    );
    expect(mapAuthError(fx(400, 'invalid_code')), AuthFailure.invalidCode);
    expect(
      mapAuthError(fx(503, 'email_not_configured')),
      AuthFailure.emailNotConfigured,
    );
    expect(
      mapAuthError(fx(429, 'daily_email_limit')),
      AuthFailure.dailyEmailLimit,
    );
    expect(mapAuthError(fx(409, 'user_code_taken')), AuthFailure.userCodeTaken);
    expect(
      mapAuthError(fx(409, 'cannot_change_own_access')),
      AuthFailure.cannotChangeOwnAccess,
    );
    expect(
      mapAuthError(fx(500, 'reset_incomplete')),
      AuthFailure.resetIncomplete,
    );
    expect(mapAuthError(fx(429, 'whatever')), AuthFailure.tooManyAttempts);
    expect(mapAuthError(fx(500, 'boom')), AuthFailure.unknown);
  });

  test('anything else is unknown', () {
    expect(mapAuthError(StateError('x')), AuthFailure.unknown);
  });
}
