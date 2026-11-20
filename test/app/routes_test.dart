import 'package:diamond_tracking/app/routes.dart';
import 'package:diamond_tracking/features/auth/domain/auth_status.dart';
import 'package:flutter_test/flutter_test.dart';

const SignedIn employee = SignedIn(
  userId: 'u1',
  role: AppRole.employee,
  mustChangePassword: false,
);
const SignedIn admin = SignedIn(
  userId: 'a1',
  role: AppRole.admin,
  mustChangePassword: false,
);
const SignedIn newUser = SignedIn(
  userId: 'u2',
  role: AppRole.employee,
  mustChangePassword: true,
);

void main() {
  test('loading always shows the splash', () {
    expect(resolveRedirect(const AuthLoading(), Routes.splash), isNull);
    expect(
      resolveRedirect(const AuthLoading(), Routes.adminUsers),
      Routes.splash,
    );
  });

  test('signed out always goes to login', () {
    expect(resolveRedirect(const SignedOut(), Routes.userHome), Routes.login);
    expect(
      resolveRedirect(const SignedOut(), Routes.adminDashboard),
      Routes.login,
    );
    expect(resolveRedirect(const SignedOut(), Routes.login), isNull);
  });

  test('a temporary PIN forces the password change first', () {
    expect(resolveRedirect(newUser, Routes.userHome), Routes.setPassword);
    expect(resolveRedirect(newUser, Routes.setPassword), isNull);
  });

  test('an employee can never open admin screens', () {
    expect(resolveRedirect(employee, Routes.adminDashboard), Routes.userHome);
    expect(resolveRedirect(employee, Routes.adminUsers), Routes.userHome);
    expect(resolveRedirect(employee, Routes.login), Routes.userHome);
    expect(resolveRedirect(employee, Routes.userMap), isNull);
  });

  test('an admin lands on the admin side', () {
    expect(resolveRedirect(admin, Routes.userHome), Routes.adminDashboard);
    expect(resolveRedirect(admin, Routes.splash), Routes.adminDashboard);
    expect(resolveRedirect(admin, Routes.adminReports), isNull);
  });

  test('admin path check does not match look-alike paths', () {
    expect(Routes.isAdminPath('/administrator'), isFalse);
    expect(Routes.isAdminPath('/admin/live'), isTrue);
  });
}
