import 'dart:math';

import 'package:diamond_tracking/features/auth/domain/credentials.dart';
import 'package:diamond_tracking/features/users/domain/temp_pin.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('user IDs become sign-in emails; emails stay as typed', () {
    expect(loginEmailFor(' EMP01 '), 'emp01@$loginEmailDomain');
    expect(loginEmailFor('Boss@Example.com'), 'boss@example.com');
  });

  test('the user ID is read back from a sign-in email only', () {
    expect(userCodeFromLoginEmail('emp01@$loginEmailDomain'), 'emp01');
    expect(userCodeFromLoginEmail('boss@example.com'), isNull);
    expect(userCodeFromLoginEmail(null), isNull);
  });

  test('user ID rules', () {
    expect(userCodeProblem('EMP-01'), isNull);
    expect(userCodeProblem('a'), isNotNull);
    expect(userCodeProblem('-abc'), isNotNull);
    expect(userCodeProblem('has space'), isNotNull);
    expect(userCodeProblem('a' * 21), isNotNull);
    expect(loginIdProblem(''), 'Enter your user ID');
    expect(loginIdProblem('boss@example.com'), isNull);
  });

  test('password rules', () {
    expect(passwordProblem('abcd1234'), isNull);
    expect(passwordProblem('abc123'), 'Use 8 to 72 characters');
    expect(passwordProblem('abcdefgh'), isNotNull);
    expect(passwordProblem('12345678'), isNotNull);
    expect(passwordProblem('x' * 72 + '1'), isNotNull);
    expect(passwordProblem('Emp01pass9', userCode: 'emp01'), isNotNull);
  });

  test('temporary PIN rules', () {
    expect(pinProblem('482913'), isNull);
    expect(pinProblem('12345'), isNotNull);
    expect(pinProblem('12a456'), isNotNull);
    expect(pinProblem('777777'), isNotNull);
  });

  test('generated PINs always pass the rules', () {
    final Random r = Random(7);
    for (int i = 0; i < 500; i++) {
      expect(pinProblem(generateTempPin(r)), isNull);
    }
  });
}
