import 'dart:io';

import 'package:diamond_tracking/core/time/clock_providers.dart';
import 'package:diamond_tracking/features/admin/presentation/admin_dashboard_page.dart';
import 'package:diamond_tracking/features/duty/domain/duty_day.dart';
import 'package:diamond_tracking/features/requests/application/requests_providers.dart';
import 'package:diamond_tracking/features/routes/application/route_providers.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';
import '../../support/pump.dart';

void main() {
  final DateTime now = DateTime.utc(2026, 11, 20, 6);
  late FakeRouteRepository routes;
  late FakeRequestsRepository requests;
  setUp(() {
    routes = FakeRouteRepository();
    requests = FakeRequestsRepository();
  });

  List<Override> overrides() => <Override>[
    routeRepositoryProvider.overrideWithValue(routes),
    requestsRepositoryProvider.overrideWithValue(requests),
    serverClockProvider.overrideWithValue(FixedClock(now).clock),
  ];

  testWidgets('a failed load shows Retry, and it refreshes by itself (L85)', (
    WidgetTester tester,
  ) async {
    routes.daysOnError = const SocketException('offline');
    await pumpPage(tester, const AdminDashboardPage(), overrides: overrides());
    expect(find.text('Could not load today'), findsOneWidget);

    routes.daysOnError = null;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Could not load today'), findsNothing);
    expect(find.text('0'), findsWidgets);

    // Someone goes on duty; two minutes later the dashboard shows it.
    routes.days[1] = DutyDay(
      id: 1,
      userId: 'u',
      day: DateTime.utc(2026, 11, 20),
      status: DayStatus.onDuty,
      dutyOnAt: now,
    );
    await tester.pump(dashboardRefreshEvery);
    await tester.pumpAndSettle();
    expect(find.text('1'), findsOneWidget);
  });
}
