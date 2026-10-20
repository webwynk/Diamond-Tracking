import 'package:diamond_tracking/core/theme/app_theme.dart';
import 'package:diamond_tracking/features/admin/attendance/presentation/controllers/admin_attendance_controller.dart';
import 'package:diamond_tracking/features/admin/employees/presentation/admin_employee_detail_page.dart';
import 'package:diamond_tracking/features/admin/employees/presentation/controllers/admin_employee_list_state.dart';
import 'package:diamond_tracking/features/admin/visits/presentation/controllers/admin_visits_controller.dart';
import 'package:diamond_tracking/features/admin/visits/presentation/controllers/visit_photo_source.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_admin_visits.dart';
import 'support/fake_attendance.dart';

/// docs/03 sections 3 and 5: the profile must work on a 320 dp budget phone
/// and survive the system text size at 150%, without anything overflowing.
void main() {
  const longName = AdminEmployeeItem(
    id: 'emp-1',
    name: 'Venkataraghavan Subramaniam Iyer',
    employeeCode: 'DA-1024',
    phoneNumber: '+91 98201 44556',
    email: 'venkataraghavan.subramaniam@diamondagritech.in',
    status: AdminEmployeeStatus.onDuty,
    dutyStartTime: '8:04 AM',
  );

  Future<void> pumpAt(
    WidgetTester tester, {
    required double widthDp,
    required double textScale,
  }) async {
    tester.view.physicalSize = Size(widthDp * 2, 1600 * 2);
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
          adminVisitRepositoryProvider.overrideWithValue(
            FakeAdminVisitRepository([
              adminVisit('v1', storeName: 'Shri Ganesh Krishi Seva Kendra'),
            ]),
          ),
          visitPhotoRequestProvider.overrideWithValue((_, _) => null),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: const AdminEmployeeDetailPage(employee: longName),
        ),
      ),
    );
    for (var i = 0; i < 4; i++) {
      await tester.pump();
    }
  }

  testWidgets('a 320 dp phone at 150% text: nothing overflows', (tester) async {
    await pumpAt(tester, widthDp: 320, textScale: 1.5);

    expect(tester.takeException(), isNull);
    expect(find.text('Track live'), findsOneWidget);
    expect(find.text('This month'), findsOneWidget);
  });

  testWidgets('a typical phone at normal text: nothing overflows', (
    tester,
  ) async {
    await pumpAt(tester, widthDp: 393, textScale: 1.0);

    expect(tester.takeException(), isNull);
    expect(find.text('On duty · since 8:04 AM'), findsOneWidget);
  });
}
