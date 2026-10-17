import 'package:diamond_tracking/core/utils/time_ago.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('words an age in plain English', () {
    expect(TimeAgo.format(Duration.zero), 'Just now');
    expect(TimeAgo.format(const Duration(seconds: 59)), 'Just now');
    expect(TimeAgo.format(const Duration(seconds: 60)), '1 min ago');
    expect(
      TimeAgo.format(const Duration(minutes: 59, seconds: 59)),
      '59 min ago',
    );
    expect(TimeAgo.format(const Duration(hours: 1)), '1 h ago');
    expect(
      TimeAgo.format(const Duration(hours: 2, minutes: 5)),
      '2 h 5 min ago',
    );
    expect(
      TimeAgo.format(const Duration(hours: 23, minutes: 59)),
      '23 h 59 min ago',
    );
    expect(TimeAgo.format(const Duration(hours: 24)), '1 d ago');
    expect(TimeAgo.format(const Duration(days: 3, hours: 5)), '3 d ago');
  });

  test('a time slightly in the future (clock skew) reads as just now', () {
    expect(TimeAgo.format(const Duration(seconds: -30)), 'Just now');
  });
}
