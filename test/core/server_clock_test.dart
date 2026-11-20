import 'package:diamond_tracking/core/logging/app_log.dart';
import 'package:diamond_tracking/core/time/server_clock.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeTimer implements ElapsedTimer {
  Duration value = Duration.zero;
  @override
  Duration get elapsed => value;
}

void main() {
  late FakeTimer timer;
  final DateTime server = DateTime.utc(2026, 11, 20, 1, 30);
  final DateTime phone = DateTime.utc(
    2030,
    1,
    1,
  ); // a phone set to the wrong time

  setUp(() => timer = FakeTimer());
  tearDown(() => AppLog.onFailure = null);

  test('before sync it falls back to the phone and says so', () {
    final ServerClock clock = ServerClock(
      source: () async => server,
      timer: timer,
      phoneNow: () => phone,
    );
    expect(clock.isSynced, isFalse);
    expect(clock.now(), phone);
  });

  test('after sync it follows the server, not the phone', () async {
    final ServerClock clock = ServerClock(
      source: () async => server,
      timer: timer,
      phoneNow: () => phone,
    );
    expect(await clock.sync(), isTrue);
    expect(clock.isSynced, isTrue);
    expect(clock.now(), server);

    timer.value = const Duration(hours: 2, minutes: 5);
    expect(clock.now(), server.add(const Duration(hours: 2, minutes: 5)));
  });

  test('adds half the round trip', () async {
    final ServerClock clock = ServerClock(
      source: () async {
        timer.value += const Duration(milliseconds: 400);
        return server;
      },
      timer: timer,
    );
    await clock.sync();
    expect(clock.now(), server.add(const Duration(milliseconds: 200)));
  });

  test('a failed sync keeps the previous one', () async {
    bool fail = false;
    final List<String> failures = <String>[];
    AppLog.onFailure = (String where, Object _) => failures.add(where);
    final ServerClock clock = ServerClock(
      source: () async => fail ? throw Exception('offline') : server,
      timer: timer,
    );
    await clock.sync();
    fail = true;
    timer.value = const Duration(minutes: 10);
    expect(await clock.sync(), isFalse);
    expect(clock.now(), server.add(const Duration(minutes: 10)));
    expect(failures, <String>['ServerClock.sync']);
  });
}
