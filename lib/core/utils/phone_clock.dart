import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The phone's clock, as a provider so tests can fix or move it.
///
/// Use it only to pick a first day or month and to bound a date picker. Any
/// decision that matters (is it today, is a position stale, how long has a duty
/// run) is judged on the server's clock (Rule 3).
final phoneClockProvider = Provider<DateTime Function()>((ref) {
  return DateTime.now;
});
