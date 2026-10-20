import 'package:diamond_tracking/core/theme/app_theme.dart';
import 'package:diamond_tracking/features/admin/attendance/presentation/controllers/admin_attendance_controller.dart';
import 'package:diamond_tracking/features/admin/employees/presentation/admin_employee_detail_page.dart';
import 'package:diamond_tracking/features/admin/employees/presentation/controllers/admin_employee_list_state.dart';
import 'package:diamond_tracking/features/admin/visits/presentation/controllers/admin_visits_controller.dart';
import 'package:diamond_tracking/features/admin/visits/presentation/controllers/visit_photo_source.dart';
import 'package:diamond_tracking/features/admin/visits/presentation/widgets/admin_visits_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_admin_visits.dart';
import 'support/fake_attendance.dart';

/// The Team profile (Screen 18) has a Visits card that leads to the full list
/// and to one visit.
void main() {
  const asha = AdminEmployeeItem(
    id: 'emp-1',
    name: 'Asha Patil',
    employeeCode: 'DA-101',
    phoneNumber: '+919820000101',
    status: AdminEmployeeStatus.onDuty,
  );

  Future<FakeAdminVisitRepository> pumpProfile(
    WidgetTester tester,
    FakeAdminVisitRepository visits,
  ) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          attendanceRepositoryProvider.overrideWithValue(
            FakeAttendanceRepository(
              employeeCreatedAt: DateTime.utc(2026, 9, 1, 3),
            ),
          ),
          adminVisitRepositoryProvider.overrideWithValue(visits),
          visitPhotoRequestProvider.overrideWithValue((_, _) => null),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const AdminEmployeeDetailPage(employee: asha),
        ),
      ),
    );
    for (var i = 0; i < 4; i++) {
      await tester.pump();
    }
    return visits;
  }

  testWidgets('shows the latest three visits on the profile', (tester) async {
    await pumpProfile(
      tester,
      FakeAdminVisitRepository([
        for (var i = 4; i >= 0; i--) adminVisit('v$i', minute: i),
      ]),
    );

    expect(
      find.descendant(
        of: find.byType(AdminVisitsCard),
        matching: find.text('Visits'),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('visit-tile-v4')), findsOneWidget);
    expect(find.byKey(const Key('visit-tile-v2')), findsOneWidget);
    expect(find.byKey(const Key('visit-tile-v1')), findsNothing);
  });

  testWidgets('an employee with no visits says so on the profile', (
    tester,
  ) async {
    await pumpProfile(tester, FakeAdminVisitRepository([]));

    expect(find.byKey(const Key('text-visits-empty')), findsOneWidget);
    expect(find.text('No visits yet.'), findsOneWidget);
  });

  testWidgets('View all opens the full list for this employee', (tester) async {
    final visits = await pumpProfile(
      tester,
      FakeAdminVisitRepository([
        for (var i = 4; i >= 0; i--) adminVisit('v$i', minute: i),
      ]),
    );

    await tester.ensureVisible(find.byKey(const Key('btn-visits-view-all')));
    await tester.tap(find.byKey(const Key('btn-visits-view-all')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('visits-list')), findsOneWidget);
    expect(find.text('Asha Patil · DA-101'), findsOneWidget);
    expect(find.byKey(const Key('visit-tile-v0')), findsOneWidget);
    // The card and the list share one load of the first page.
    expect(visits.calls, hasLength(1));
    expect(visits.calls.single.employeeId, 'emp-1');
  });

  testWidgets('a tap on a visit in the card opens its details', (tester) async {
    await pumpProfile(
      tester,
      FakeAdminVisitRepository([adminVisit('a', note: 'Left samples')]),
    );

    await tester.ensureVisible(find.byKey(const Key('visit-tile-a')));
    await tester.tap(find.byKey(const Key('visit-tile-a')));
    await tester.pumpAndSettle();

    expect(find.text('Visit details'), findsOneWidget);
    expect(find.text('Asha Patil'), findsOneWidget);
    expect(find.text('Left samples'), findsOneWidget);
  });
}
