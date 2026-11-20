import 'dart:async';

import 'package:diamond_tracking/core/supabase/device_id.dart';
import 'package:diamond_tracking/core/time/server_clock.dart';
import 'package:diamond_tracking/features/auth/data/auth_repository.dart';
import 'package:diamond_tracking/features/auth/domain/auth_failure.dart';
import 'package:diamond_tracking/features/auth/domain/auth_status.dart';
import 'package:diamond_tracking/features/duty/data/duty_repository.dart';
import 'package:diamond_tracking/features/duty/domain/duty_day.dart';
import 'package:diamond_tracking/features/routes/data/route_repository.dart';
import 'package:diamond_tracking/features/routes/domain/day_route.dart';
import 'package:diamond_tracking/features/routes/domain/live_position.dart';
import 'package:diamond_tracking/features/tracking/application/tracker_control.dart';
import 'package:diamond_tracking/features/tracking/domain/tracking_session.dart';
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

/// A clock fixed at [at] (move it with [FixedClock.at]).
class FixedClock {
  FixedClock(DateTime at) : _at = at.toUtc();

  DateTime _at;
  final _NoElapsed _timer = _NoElapsed();

  /// A [ServerClock] that reads this time from the "server".
  late final ServerClock clock = ServerClock(
    source: () async => _at,
    timer: _timer,
    phoneNow: () => _at,
  );

  /// Moves the time on (or back).
  set at(DateTime value) {
    _timer.elapsed += value.toUtc().difference(_at);
    _at = value.toUtc();
  }
}

class _NoElapsed implements ElapsedTimer {
  @override
  Duration elapsed = Duration.zero;
}

/// A fixed install id.
class FakeDeviceIdStore extends DeviceIdStore {
  @override
  Future<String> get() async => 'test-device-0001';
}

/// Duty calls with a programmable today. Set [error] to make calls throw.
class FakeDutyRepository implements DutyRepository {
  FakeDutyRepository({this.today});

  DutyDay? today;
  Exception? error;
  final List<String> calls = <String>[];
  int _nextId = 100;

  void _maybeFail() {
    final Exception? e = error;
    if (e != null) throw e;
  }

  @override
  Future<DutyDay?> forDay(String userId, DateTime day) async {
    calls.add('forDay');
    _maybeFail();
    return today;
  }

  /// Thrown by duty on only.
  Exception? dutyOnError;

  @override
  Future<DutyStart> dutyOn(String deviceId) async {
    calls.add('dutyOn');
    _maybeFail();
    final Exception? onError = dutyOnError;
    if (onError != null) throw onError;
    final DutyDay day = DutyDay(
      id: _nextId++,
      day: DateTime.utc(2026, 11, 20),
      status: DayStatus.onDuty,
      dutyOnAt: dutyOnTime,
    );
    today = day;
    return DutyStart(day: day, pass: 'pass-${day.id}');
  }

  /// The time duty on records.
  DateTime dutyOnTime = DateTime.utc(2026, 11, 20, 1, 30);

  @override
  Future<DutyStart> resume(String deviceId) async {
    calls.add('resume');
    _maybeFail();
    return DutyStart(day: today!, pass: 'pass-resumed');
  }

  @override
  Future<DutyDay> dutyOff(int dayId, DateTime offAt) async {
    calls.add('dutyOff');
    _maybeFail();
    final DutyDay on = today!;
    final int minutes = offAt.difference(on.dutyOnAt!).inMinutes;
    final DutyDay off = DutyDay(
      id: on.id,
      day: on.day,
      status: minutes >= 600 ? DayStatus.present : DayStatus.pending,
      dutyOnAt: on.dutyOnAt,
      dutyOffAt: offAt,
      workedMinutes: minutes,
    );
    today = off;
    return off;
  }
}

/// The tracker without Android.
class FakeTrackerControl implements TrackerControl {
  List<TrackerRequirement> missing = <TrackerRequirement>[];
  TrackingSession? stored;
  bool running = false;
  bool unsent = false;
  bool failStart = false;
  final List<String> calls = <String>[];
  // Lives as long as the test; nothing to clean up.
  // ignore: close_sinks
  final StreamController<int> battery = StreamController<int>.broadcast();

  @override
  Future<List<TrackerRequirement>> missingRequirements() async =>
      List<TrackerRequirement>.of(missing);

  @override
  Future<void> request(TrackerRequirement requirement) async {
    calls.add('request:${requirement.name}');
    missing.remove(requirement);
  }

  @override
  Future<TrackingSession?> session() async => stored;

  @override
  Future<void> start(TrackingSession session) async {
    calls.add('start:${session.dayId}');
    stored = session;
    if (failStart) throw const TrackerStartFailed('test');
    running = true;
  }

  @override
  Future<void> dutyOff(DateTime offAt, {required bool confirmed}) async {
    calls.add('dutyOff:$confirmed');
    stored = stored?.withDutyOff(offAt, confirmed: confirmed);
  }

  @override
  Future<void> ensureRunning() async => calls.add('ensureRunning');

  @override
  Future<bool> isRunning() async => running;

  @override
  Future<bool> hasUnsentWork() async => unsent;

  @override
  Stream<int> get batteryWarnings => battery.stream;

  @override
  Future<void> clear() async {
    calls.add('clear');
    stored = null;
  }
}

/// Routes and live positions from memory.
class FakeRouteRepository implements RouteRepository {
  final Map<int, DutyDay> days = <int, DutyDay>{};
  final Map<int, DayRoute> routes = <int, DayRoute>{};
  // Lives as long as the test.
  // ignore: close_sinks
  final StreamController<List<LivePosition>> live =
      StreamController<List<LivePosition>>.broadcast();
  List<LivePosition> initialLive = <LivePosition>[];
  int addressRequests = 0;

  /// Addresses the next request "finds", by stop index.
  Map<int, String> addressesToFind = <int, String>{};

  @override
  Future<DayRoute?> dayRoute(int dayId) async => routes[dayId];

  @override
  Future<DutyDay?> day(int dayId) async => days[dayId];

  @override
  Future<List<DutyDay>> history(String userId, DateTime since) async =>
      days.values.where((DutyDay d) => d.userId == userId).toList()
        ..sort((DutyDay a, DutyDay b) => b.day.compareTo(a.day));

  @override
  Future<List<DutyDay>> daysOn(DateTime day) async =>
      days.values.where((DutyDay d) => d.day == day).toList();

  @override
  Future<int> requestAddresses(int dayId) async {
    addressRequests++;
    final DayRoute? r = routes[dayId];
    if (r == null || addressesToFind.isEmpty) return 0;
    routes[dayId] = DayRoute(
      dayId: r.dayId,
      segments: r.segments,
      stops: <RouteStop>[
        for (int i = 0; i < r.stops.length; i++)
          RouteStop(
            point: r.stops[i].point,
            start: r.stops[i].start,
            end: r.stops[i].end,
            address: addressesToFind[i] ?? r.stops[i].address,
          ),
      ],
      notes: r.notes,
      distanceM: r.distanceM,
      pointCount: r.pointCount,
    );
    return addressesToFind.length;
  }

  @override
  Stream<List<LivePosition>> livePositions() async* {
    yield initialLive;
    yield* live.stream;
  }
}
