import 'dart:async';

import 'package:diamond_tracking/core/theme/app_theme.dart';
import 'package:diamond_tracking/features/admin/employees/presentation/admin_employee_detail_page.dart';
import 'package:diamond_tracking/features/admin/employees/presentation/controllers/admin_employee_list_controller.dart';
import 'package:diamond_tracking/features/admin/employees/presentation/controllers/admin_employee_list_state.dart';
import 'package:diamond_tracking/features/admin/employees/presentation/widgets/admin_block_employee_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const testEmployee = AdminEmployeeItem(
    id: 'emp-1',
    name: 'Suresh Patel',
    employeeCode: 'DA-022',
    phoneNumber: '+91 98201 44556',
    status: AdminEmployeeStatus.onDuty,
    dutyStartTime: '8:04 AM',
    distanceTodayKm: '38.6 km',
    locationName: 'Shivpuri Agricultural Cluster',
  );

  Widget buildTestableWidget(Widget child, {ProviderContainer? container}) {
    if (container != null) {
      return UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(body: child),
        ),
      );
    }
    return ProviderScope(
      child: MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: child),
      ),
    );
  }

  group('Screen 20 AdminBlockEmployeeSheet Widget & Visual Tests', () {
    testWidgets('renders all visual elements matching HTML design reference', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildTestableWidget(
          AdminBlockEmployeeSheet(
            employee: testEmployee,
            onConfirmBlock: (_) async {},
          ),
        ),
      );
      await tester.pump();

      // Title & Code
      expect(find.byKey(const Key('block-sheet-title')), findsOneWidget);
      expect(find.text('Block Suresh Patel?'), findsOneWidget);
      expect(find.byKey(const Key('block-sheet-code')), findsOneWidget);
      expect(find.text('DA-022'), findsOneWidget);

      // 56 dp circular red badge with block icon
      expect(find.byIcon(Icons.block_rounded), findsOneWidget);

      // Consequence Warning Panel
      expect(find.text('This will immediately:'), findsOneWidget);
      expect(find.text('End their current duty session'), findsOneWidget);
      expect(find.text('Stop location tracking'), findsOneWidget);
      expect(find.text('Prevent them from logging in'), findsOneWidget);

      // Reason Input Field
      expect(find.text('Reason (required)'), findsOneWidget);
      expect(find.byKey(const Key('input-block-reason')), findsOneWidget);
      expect(find.text('Why is this employee being blocked?'), findsOneWidget);
      expect(find.text('This reason is recorded in the audit log.'), findsOneWidget);

      // Action Buttons
      expect(find.byKey(const Key('btn-block-submit')), findsOneWidget);
      expect(find.text('Block employee'), findsOneWidget);
      expect(find.byKey(const Key('btn-block-cancel')), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('block button is disabled when reason is empty or whitespace', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      bool blockCalled = false;

      await tester.pumpWidget(
        buildTestableWidget(
          AdminBlockEmployeeSheet(
            employee: testEmployee,
            onConfirmBlock: (_) async {
              blockCalled = true;
            },
          ),
        ),
      );
      await tester.pump();

      // Check Opacity is 0.4 when empty
      final opacityFinder = find.byType(Opacity);
      expect(opacityFinder, findsOneWidget);
      final Opacity opacityWidget = tester.widget(opacityFinder);
      expect(opacityWidget.opacity, 0.4);

      // Tapping disabled button does nothing
      await tester.tap(find.byKey(const Key('btn-block-submit')));
      await tester.pump();
      expect(blockCalled, isFalse);

      // Entering only whitespace keeps it disabled
      await tester.enterText(find.byKey(const Key('input-block-reason')), '   \n  ');
      await tester.pump();

      final Opacity opacityAfterWhitespace = tester.widget(find.byType(Opacity));
      expect(opacityAfterWhitespace.opacity, 0.4);
      await tester.tap(find.byKey(const Key('btn-block-submit')));
      await tester.pump();
      expect(blockCalled, isFalse);
    });

    testWidgets('typing a valid reason enables the block button and triggers callback',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      String? capturedReason;
      final completer = Completer<void>();

      await tester.pumpWidget(
        buildTestableWidget(
          AdminBlockEmployeeSheet(
            employee: testEmployee,
            onConfirmBlock: (reason) async {
              capturedReason = reason;
              await completer.future;
            },
          ),
        ),
      );
      await tester.pump();

      // Enter valid reason
      await tester.enterText(
        find.byKey(const Key('input-block-reason')),
        'Unapproved absence and repeated mock-location flag',
      );
      await tester.pump();

      // Button is now enabled with full opacity
      final Opacity enabledOpacity = tester.widget(find.byType(Opacity));
      expect(enabledOpacity.opacity, 1.0);

      // Tap submit button
      await tester.tap(find.byKey(const Key('btn-block-submit')));
      await tester.pump();

      // Captured reason matches entered string
      expect(capturedReason, 'Unapproved absence and repeated mock-location flag');

      // Shows loading progress indicator
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Complete async operation
      completer.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('cancel button invokes pop without triggering block callback', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      bool blockCalled = false;
      bool? dialogResult;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  dialogResult = await AdminBlockEmployeeSheet.show(
                    context,
                    employee: testEmployee,
                    onConfirmBlock: (_) async {
                      blockCalled = true;
                    },
                  );
                },
                child: const Text('Open Sheet'),
              ),
            ),
          ),
        ),
      );

      // Open bottom sheet
      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('btn-block-cancel')), findsOneWidget);

      // Tap cancel
      await tester.tap(find.byKey(const Key('btn-block-cancel')));
      await tester.pumpAndSettle();

      expect(blockCalled, isFalse);
      expect(dialogResult, isFalse);
      expect(find.byType(AdminBlockEmployeeSheet), findsNothing);
    });

    testWidgets('AdminEmployeeListNotifier.blockEmployee mutates roster state to blocked',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(adminEmployeeListControllerProvider.notifier);
      final initialEmployees = container.read(adminEmployeeListControllerProvider).employees;

      // Suresh Patel initial state
      final initialSuresh = initialEmployees.firstWhere((e) => e.id == 'emp-1');
      expect(initialSuresh.status, AdminEmployeeStatus.onDuty);
      expect(initialSuresh.isActive, isTrue);

      // Block employee
      notifier.blockEmployee(
        employeeId: 'emp-1',
        reason: 'Policy breach',
      );

      final updatedEmployees = container.read(adminEmployeeListControllerProvider).employees;
      final blockedSuresh = updatedEmployees.firstWhere((e) => e.id == 'emp-1');

      expect(blockedSuresh.status, AdminEmployeeStatus.blocked);
      expect(blockedSuresh.isActive, isFalse);
      expect(blockedSuresh.dutyStartTime, isNull);
      expect(blockedSuresh.hasFlags, isFalse);
      expect(blockedSuresh.locationName, 'Blocked (Policy breach)');
    });

    testWidgets('AdminEmployeeDetailPage danger button opens AdminBlockEmployeeSheet',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        buildTestableWidget(
          const AdminEmployeeDetailPage(employee: testEmployee),
          container: container,
        ),
      );
      await tester.pumpAndSettle();

      // Scroll to danger action button
      await tester.scrollUntilVisible(
        find.byKey(const Key('btn-employee-block-action')),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('btn-employee-block-action')), findsOneWidget);

      // Tap block button to open Screen 20 bottom sheet
      await tester.tap(find.byKey(const Key('btn-employee-block-action')));
      await tester.pumpAndSettle();

      // Screen 20 modal sheet is now displayed
      expect(find.byType(AdminBlockEmployeeSheet), findsOneWidget);
      expect(find.text('Block Suresh Patel?'), findsOneWidget);

      // Enter reason and submit
      await tester.enterText(
        find.byKey(const Key('input-block-reason')),
        'Suspected fraudulent duty log',
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('btn-block-submit')));
      await tester.pumpAndSettle();

      // Sheet is closed
      expect(find.byType(AdminBlockEmployeeSheet), findsNothing);

      // SnackBar confirmation is shown
      expect(find.text('Suresh Patel has been blocked.'), findsOneWidget);

      // State was updated in list provider
      final employees = container.read(adminEmployeeListControllerProvider).employees;
      final blockedEmp = employees.firstWhere((e) => e.id == 'emp-1');
      expect(blockedEmp.status, AdminEmployeeStatus.blocked);
      expect(blockedEmp.isActive, isFalse);
    });
  });
}
