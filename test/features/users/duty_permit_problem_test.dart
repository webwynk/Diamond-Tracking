import 'package:diamond_tracking/features/users/presentation/duty_on_permission_row.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('too late says 9:00 PM and why (L28)', () {
    final String text = dutyPermitProblem(
      const PostgrestException(message: 'too_late'),
    );
    expect(text, contains('9:00 PM'));
    expect(text, contains('too short'));
  });

  test('a day with a record cannot be allowed again', () {
    expect(
      dutyPermitProblem(
        const PostgrestException(message: 'day_already_recorded'),
      ),
      contains('already has a record for today'),
    );
  });
}
