import 'package:diamond_tracking/features/duty/domain/duty_day.dart';
import 'package:diamond_tracking/features/routes/domain/geo_point.dart';
import 'package:diamond_tracking/features/routes/domain/live_position.dart';
import 'package:diamond_tracking/features/routes/presentation/live_map_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  LivePosition at(int? day) => LivePosition(
    userId: 'u$day',
    point: const GeoPoint(22.5, 88.3),
    recordedAt: DateTime.utc(2026, 11, 20, 6),
    dutyDayId: day,
  );
  DutyDay day(int id) => DutyDay(
    id: id,
    day: DateTime.utc(2026, 11, 20),
    status: DayStatus.onDuty,
  );

  test('a position from a new duty asks once for the duty list (L76)', () {
    final List<LivePosition> live = <LivePosition>[at(1), at(2), at(null)];
    expect(unknownDutyDays(live, <DutyDay>[day(1)], <int>{}), <int>{2});
    expect(unknownDutyDays(live, <DutyDay>[day(1)], <int>{2}), isEmpty);
    expect(unknownDutyDays(live, <DutyDay>[day(1), day(2)], <int>{}), isEmpty);
    expect(dutyListReloadMinutes, 5);
  });
}
