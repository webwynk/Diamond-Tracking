import 'package:diamond_tracking/features/auth/domain/auth_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('no user is signed out', () {
    expect(
      authStatusFromUser(userId: null, appMetadata: null),
      isA<SignedOut>(),
    );
  });

  test('role comes from app_metadata', () {
    final AuthStatus s = authStatusFromUser(
      userId: 'a',
      appMetadata: <String, dynamic>{'role': 'admin'},
    );
    expect((s as SignedIn).role, AppRole.admin);
    expect(s.mustChangePassword, isFalse);
  });

  test('a missing or unknown role is the least-privileged one', () {
    expect(
      (authStatusFromUser(userId: 'a', appMetadata: null) as SignedIn).role,
      AppRole.employee,
    );
    expect(
      (authStatusFromUser(
        userId: 'a',
        appMetadata: <String, dynamic>{'role': 'superuser'},
      ) as SignedIn).role,
      AppRole.employee,
    );
  });

  test('must_change_password must be exactly true', () {
    final SignedIn s = authStatusFromUser(
      userId: 'a',
      appMetadata: <String, dynamic>{'must_change_password': 'yes'},
    ) as SignedIn;
    expect(s.mustChangePassword, isFalse);
  });
}
