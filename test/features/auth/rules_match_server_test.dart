import 'dart:convert';
import 'dart:io';

import 'package:diamond_tracking/features/auth/domain/credentials.dart';
import 'package:flutter_test/flutter_test.dart';

// L37: the app's rules give the same verdict as the server's on every case in
// rule_cases.json (the server's rules_test.ts reads the same file).
void main() {
  final Map<String, Object?> cases = jsonDecode(
    File('supabase/functions/_shared/rule_cases.json').readAsStringSync(),
  ) as Map<String, Object?>;
  final String passwordUser =
      (cases['password']! as Map<String, Object?>)['user_code']! as String;

  final Map<String, String? Function(String)> checks =
      <String, String? Function(String)>{
        'user_code': userCodeProblem,
        'name': nameProblem,
        'phone': phoneProblem,
        'email': emailProblem,
        'designation': designationProblem,
        'designation_required': (String v) =>
            designationProblem(v, required: true),
        'pin': pinProblem,
        'password': (String v) => passwordProblem(v, userCode: passwordUser),
      };

  for (final MapEntry<String, String? Function(String)> check
      in checks.entries) {
    test('${check.key} rules match the shared cases', () {
      final Map<String, Object?> set =
          cases[check.key]! as Map<String, Object?>;
      for (final Object? v in set['ok']! as List<Object?>) {
        expect(check.value(v! as String), isNull, reason: 'accept "$v"');
      }
      for (final Object? v in set['bad']! as List<Object?>) {
        expect(check.value(v! as String), isNotNull, reason: 'refuse "$v"');
      }
    });
  }
}
