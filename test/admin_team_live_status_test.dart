import 'package:diamond_tracking/core/theme/app_theme.dart';
import 'package:diamond_tracking/domain/entities/live_position.dart';
import 'package:diamond_tracking/features/admin/employees/presentation/controllers/admin_employee_list_controller.dart';
import 'package:diamond_tracking/features/admin/employees/presentation/controllers/admin_employee_list_state.dart';
import 'package:diamond_tracking/features/admin/shell/admin_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_admin_activity.dart';
import 'support/fake_auth.dart';
import 'support/fake_employee_repository.dart';
import 'support/fake_live_locations.dart';
import 'support/fake_notification_repository.dart';

AdminEmployeeItem _person(
  String id,
  String name, {
  AdminEmployeeStatus status = AdminEmployeeStatus.offDuty,
  bool active = true,
}) => AdminEmployeeItem(
  id: id,
  name: name,
  employeeCode: 'DA-$id',
  phoneNumber: '+91982000$id',
  status: status,
  isActive: active,
);

void main() {
  group('the Team list follows the live feed', () {
    late FakeEmployeeRepository repository;

    ProviderContainer container() {
      final c = ProviderContainer(
        overrides: [employeeRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(c.dispose);
      return c;
    }

    AdminEmployeeListNotifier notifier(ProviderContainer c) =>
        c.read(adminEmployeeListControllerProvider.notifier);
    AdminEmployeeListState state(ProviderContainer c) =>
        c.read(adminEmployeeListControllerProvider);
    AdminEmployeeItem who(ProviderContainer c, String id) =>
        state(c).employees.firstWhere((e) => e.id == id);

    setUp(() {
      repository = FakeEmployeeRepository(
        roster: [
          _person('1', 'Asha'),
          // On duty when the roster was read, but the feed no longer has them.
          _person('2', 'Ravi', status: AdminEmployeeStatus.onDuty),
          _person(
            '3',
            'Meena',
            status: AdminEmployeeStatus.blocked,
            active: false,
          ),
          _person('4', 'Bala'),
        ],
      );
    });

    test(
      'someone the feed has is on duty, someone it does not have is off',
      () async {
        final c = container();
        await notifier(c).loadEmployees();
        expect(who(c, '2').status, AdminEmployeeStatus.onDuty);

        notifier(c).applyLiveStatuses({'1': LiveStatus.active});

        expect(who(c, '1').status, AdminEmployeeStatus.onDuty);
        expect(who(c, '2').status, AdminEmployeeStatus.offDuty);
        expect(who(c, '4').status, AdminEmployeeStatus.offDuty);
        expect(state(c).onDutyCount, 1);
        expect(state(c).offDutyCount, 2);
      },
    );

    test('a blocked person stays blocked, whatever the feed says', () async {
      final c = container();
      await notifier(c).loadEmployees();

      notifier(c).applyLiveStatuses({'3': LiveStatus.active});

      expect(who(c, '3').status, AdminEmployeeStatus.blocked);
      expect(who(c, '3').isActive, isFalse);
    });

    test('no update and check needed show as the map shows them', () async {
      final c = container();
      await notifier(c).loadEmployees();

      notifier(
        c,
      ).applyLiveStatuses({'1': LiveStatus.stale, '4': LiveStatus.suspect});

      expect(who(c, '1').status, AdminEmployeeStatus.stale);
      expect(who(c, '1').hasFlags, isFalse);
      expect(who(c, '4').status, AdminEmployeeStatus.needsCheck);
      expect(who(c, '4').hasFlags, isTrue);
      // They are not counted as plainly "on duty", like the map's chip.
      expect(state(c).onDutyCount, 0);

      notifier(c).applyLiveStatuses({'4': LiveStatus.active});

      expect(who(c, '4').status, AdminEmployeeStatus.onDuty);
      expect(who(c, '4').hasFlags, isFalse);
    });

    test(
      'reloading the roster keeps the live picture, not the old snapshot',
      () async {
        final c = container();
        await notifier(c).loadEmployees();
        notifier(c).applyLiveStatuses({'1': LiveStatus.active});

        // The server roster still says Ravi is on duty.
        await notifier(c).loadEmployees(force: true);

        expect(who(c, '1').status, AdminEmployeeStatus.onDuty);
        expect(who(c, '2').status, AdminEmployeeStatus.offDuty);
      },
    );

    test(
      'what the feed said before the roster loaded is applied when it loads',
      () async {
        final c = container();
        notifier(c).applyLiveStatuses({'1': LiveStatus.active});

        await notifier(c).loadEmployees();

        expect(who(c, '1').status, AdminEmployeeStatus.onDuty);
        expect(who(c, '2').status, AdminEmployeeStatus.offDuty);
      },
    );

    test('an unchanged picture does not rebuild the list', () async {
      final c = container();
      await notifier(c).loadEmployees();
      notifier(c).applyLiveStatuses({'1': LiveStatus.active});
      var rebuilds = 0;
      c.listen(adminEmployeeListControllerProvider, (_, _) => rebuilds++);

      notifier(c).applyLiveStatuses({'1': LiveStatus.active});
      notifier(c).applyLiveStatuses({'1': LiveStatus.active});

      expect(rebuilds, 0);
    });

    test(
      'before the feed has said anything, the roster snapshot stands',
      () async {
        final c = container();

        await notifier(c).loadEmployees();

        expect(who(c, '2').status, AdminEmployeeStatus.onDuty);
      },
    );
  });

  group('in the admin app, the Team list and the live map agree', () {
    testWidgets('someone the feed shows is on duty in the Team list', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final roster = FakeEmployeeRepository(
        roster: [
          // The roster read says off duty; the feed says on duty.
          _person('1', 'Asha'),
          // The roster read says on duty; the feed has nobody for them.
          _person('2', 'Ravi', status: AdminEmployeeStatus.onDuty),
        ],
      );
      final live = FakeLiveLocationRepository(positions: [livePosition('1')]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...liveMapOverrides(live, roster),
            activityOverride(FakeAdminActivityRepository()),
            notificationOverride(FakeNotificationRepository()),
            signedInAdminOverride(),
          ],
          child: MaterialApp(theme: AppTheme.light, home: const AdminShell()),
        ),
      );
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }

      final container = ProviderScope.containerOf(
        tester.element(find.byType(AdminShell)),
      );
      await container
          .read(adminEmployeeListControllerProvider.notifier)
          .loadEmployees();
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }

      final team = container
          .read(adminEmployeeListControllerProvider)
          .employees;
      expect(
        team.firstWhere((e) => e.id == '1').status,
        AdminEmployeeStatus.onDuty,
      );
      expect(
        team.firstWhere((e) => e.id == '2').status,
        AdminEmployeeStatus.offDuty,
      );
    });
  });
}
