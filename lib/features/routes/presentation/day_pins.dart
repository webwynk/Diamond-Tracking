import '../../../core/time/ist_format.dart';
import '../../duty/domain/duty_day.dart';
import '../../visits/domain/visit.dart';
import '../domain/day_route.dart';
import 'app_map.dart';

/// The pins of one day (design v2): the start, numbered stops, the day's
/// visits with a location, and where the person is now (on duty) or where
/// the duty ended. [nowTitle] names the "now" pin: "You" on the employee's
/// own map, "Last position" when an admin looks.
List<MapPin> dayPins(
  DutyDay? day,
  DayRoute? route,
  List<Visit> visits, {
  String nowTitle = 'Last position',
}) {
  final bool onDuty = day?.status == DayStatus.onDuty;
  return <MapPin>[
    if (route?.start case final start?)
      MapPin(
        id: 'start',
        point: start,
        kind: PinKind.start,
        title: day?.dutyOnAt == null
            ? 'Start'
            : 'Start ${IstFormat.time(day!.dutyOnAt!)}',
      ),
    for (final (int i, RouteStop s)
        in (route?.stops ?? const <RouteStop>[]).indexed)
      MapPin(
        id: 'stop$i',
        point: s.point,
        kind: PinKind.stop,
        label: '${i + 1}',
        title: s.address ?? 'Stop ${i + 1}',
        snippet: stopTimes(s),
      ),
    for (final Visit v in visits)
      if (v.location case final at?)
        MapPin(
          id: 'visit-${v.id}',
          point: at,
          kind: PinKind.visit,
          title: v.storeName,
          snippet: 'Visit ${IstFormat.time(v.capturedAt)}',
        ),
    if (route?.end case final end?)
      onDuty
          ? MapPin(id: 'now', point: end, kind: PinKind.person, title: nowTitle)
          : MapPin(
              id: 'end',
              point: end,
              kind: PinKind.end,
              title: day?.dutyOffAt == null
                  ? 'End'
                  : 'Duty off ${IstFormat.time(day!.dutyOffAt!)}',
            ),
  ];
}

/// "8:12 AM to 9:05 AM (53 min)".
String stopTimes(RouteStop s) =>
    '${IstFormat.time(s.start)} to ${IstFormat.time(s.end)} '
    '(${IstFormat.duration(s.length)})';
