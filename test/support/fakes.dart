import 'package:diamond_tracking/features/auth/data/auth_repository.dart';
import 'package:diamond_tracking/features/auth/domain/auth_failure.dart';
import 'package:diamond_tracking/features/auth/domain/auth_status.dart';
import 'package:diamond_tracking/features/users/data/users_repository.dart';
import 'package:diamond_tracking/features/users/domain/profile.dart';

/// Records calls; throws [failWith] when set.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.userCode = 'emp1'});

  final String userCode;
  final List<String> calls = <String>[];
  AuthFailure? failWith;

  /// Called after a successful sign-in, so a test can emit a status.
  void Function()? onSignIn;

  void _maybeFail() {
    final AuthFailure? f = failWith;
    if (f != null) throw f;
  }

  @override
  String? get currentUserCode => userCode;

  @override
  Future<void> signIn({
    required String loginId,
    required String password,
  }) async {
    calls.add('signIn:$loginId');
    _maybeFail();
    onSignIn?.call();
  }

  @override
  Future<void> setFirstPassword(String newPassword) async {
    calls.add('setFirstPassword');
    _maybeFail();
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    calls.add('changePassword');
    _maybeFail();
  }

  @override
  Future<void> requestResetCode(String userCode) async {
    calls.add('requestResetCode:$userCode');
    _maybeFail();
  }

  @override
  Future<void> resetWithCode({
    required String userCode,
    required String code,
    required String newPassword,
  }) async {
    calls.add('resetWithCode:$userCode:$code');
    _maybeFail();
  }

  @override
  Future<void> signOut() async => calls.add('signOut');
}

Profile profile(
  String id, {
  String? code,
  String? name,
  AppRole role = AppRole.employee,
  bool active = true,
  bool phone = false,
}) => Profile(
  id: id,
  userCode: code ?? id,
  fullName: name ?? 'User $id',
  role: role,
  isActive: active,
  hasPhoneSignedIn: phone,
);

/// In-memory users.
class FakeUsersRepository implements UsersRepository {
  FakeUsersRepository([List<Profile>? users]) : users = users ?? <Profile>[];

  final List<Profile> users;
  final List<String> calls = <String>[];
  Exception? failWith;

  @override
  Future<List<Profile>> list() async => List<Profile>.of(users);

  @override
  Future<Profile?> byId(String id) async {
    for (final Profile p in users) {
      if (p.id == id) return p;
    }
    return null;
  }

  @override
  Future<Profile> create(ProfileDraft draft, {required String tempPin}) async {
    calls.add('create:${draft.userCode}:$tempPin');
    final Exception? f = failWith;
    if (f != null) throw f;
    final Profile p = Profile(
      id: 'new-${users.length}',
      userCode: draft.userCode,
      fullName: draft.fullName,
      role: draft.role,
      isActive: true,
    );
    users.add(p);
    return p;
  }

  @override
  Future<Profile> update(String id, ProfileDraft draft) async {
    calls.add('update:$id:${draft.fullName}:${draft.isActive}');
    final Exception? f = failWith;
    if (f != null) throw f;
    final Profile p = (await byId(id))!;
    final Profile updated = Profile(
      id: id,
      userCode: p.userCode,
      fullName: draft.fullName,
      role: draft.role,
      isActive: draft.isActive,
    );
    users[users.indexOf(p)] = updated;
    return updated;
  }

  @override
  Future<void> resetPin(String id, {required String tempPin}) async {
    calls.add('resetPin:$id:$tempPin');
    final Exception? f = failWith;
    if (f != null) throw f;
  }
}
