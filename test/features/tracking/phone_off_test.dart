import 'package:diamond_tracking/features/tracking/domain/phone_off.dart';
import 'package:diamond_tracking/features/tracking/domain/track_break.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final DateTime last = DateTime.utc(2026, 11, 20, 8, 40);
  final Heartbeat beat = Heartbeat(
    dayId: 7,
    at: last,
    uptime: const Duration(hours: 30),
    bootId: 'boot-a',
  );

  test('a restart means the phone was off until it booted', () {
    final DateTime now = last.add(const Duration(minutes: 55));
    final TrackBreak? b = breakSince(
      beat,
      dayId: 7,
      now: now,
      uptime: const Duration(minutes: 2),
      bootId: 'boot-b',
    );
    expect(
      b,
      TrackBreak(
        from: last,
        to: now.subtract(const Duration(minutes: 2)),
        kind: TrackBreakKind.phoneOff,
      ),
    );
  });

  test('without a boot id, less uptime also means a restart', () {
    final TrackBreak? b = breakSince(
      Heartbeat(dayId: 7, at: last, uptime: const Duration(hours: 30)),
      dayId: 7,
      now: last.add(const Duration(hours: 1)),
      uptime: const Duration(minutes: 1),
    );
    expect(b?.kind, TrackBreakKind.phoneOff);
  });

  test('same boot: the tracker was stopped, not the phone', () {
    final DateTime now = last.add(const Duration(minutes: 20));
    final TrackBreak? b = breakSince(
      beat,
      dayId: 7,
      now: now,
      uptime: const Duration(hours: 30, minutes: 20),
      bootId: 'boot-a',
    );
    expect(b?.kind, TrackBreakKind.trackingStopped);
    expect(b?.to, now);
  });

  test('short breaks and other days are ignored', () {
    expect(
      breakSince(
        beat,
        dayId: 7,
        now: last.add(const Duration(minutes: 2)),
        uptime: const Duration(hours: 30, minutes: 2),
        bootId: 'boot-a',
      ),
      isNull,
    );
    expect(
      breakSince(
        beat,
        dayId: 8,
        now: last.add(const Duration(hours: 2)),
        uptime: const Duration(minutes: 1),
        bootId: 'boot-b',
      ),
      isNull,
    );
    expect(
      breakSince(null, dayId: 7, now: last, uptime: Duration.zero),
      isNull,
    );
  });
}
