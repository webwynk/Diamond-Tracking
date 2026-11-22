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

  test('first name for "Welcome, Rahul."', () {
    expect(firstNameOf('  Rahul  Sharma '), 'Rahul');
    expect(firstNameOf('Asha'), 'Asha');
    expect(firstNameOf(''), isNull);
    expect(firstNameOf(null), isNull);
    expect(firstNameOf(42), isNull);
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

  test('password rules: 8+, a letter, a digit and a symbol', () {
    expect(passwordProblem('abcd@1234'), isNull);
    expect(passwordProblem('abc12!'), 'Use 8 to 72 characters');
    expect(passwordProblem('abcdefgh!'), isNotNull);
    expect(passwordProblem('12345678!'), isNotNull);
    expect(passwordProblem('abcd1234'), r'Add a symbol, like @ # $ !');
    // A space is not a symbol.
    expect(passwordProblem('abcd 1234'), r'Add a symbol, like @ # $ !');
    expect(passwordProblem('${'x' * 71}1!'), isNotNull);
    // 72 English characters are 72 bytes: allowed.
    expect(passwordProblem('${'a1' * 35}#!'), isNull);
    expect(passwordProblem('Mango@2025'), 'Do not use the example password');
    expect(passwordProblem('mango@2025'), 'Do not use the example password');
    expect(passwordProblem('Mango@2026'), isNull);
  });

  test('the checks behind the live ticks', () {
    final PasswordChecks c = PasswordChecks('river2026', userCode: 'emp1');
    expect(
      (c.long, c.letter, c.digit, c.symbol, c.notUserId),
      (true, true, true, false, true),
    );
    expect(PasswordChecks('').notUserId, isFalse);
    expect(PasswordChecks('my emp1!', userCode: 'EMP1').notUserId, isFalse);
    // A Hindi vowel sign is part of a letter, not a symbol.
    expect(PasswordChecks('रवि1234ab').symbol, isFalse);
  });

  test('a password over 72 bytes is too long, even under 72 characters', () {
    // Each Hindi letter is 3 bytes: 30 letters + "ab1!" = 94 bytes.
    final String hindi = '${'क' * 30}ab1!';
    expect(hindi.length, 34);
    expect(passwordProblem(hindi), passwordTooLong);
    // 22 Hindi letters + "ab1!" = 70 bytes: allowed.
    expect(passwordProblem('${'क' * 22}ab1!'), isNull);
    expect(passwordProblem('Emp01pass9!', userCode: 'emp01'), isNotNull);
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
