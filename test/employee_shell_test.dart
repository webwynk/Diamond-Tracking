import 'package:diamond_tracking/core/theme/app_theme.dart';
import 'package:diamond_tracking/domain/entities/user_profile.dart';
import 'package:diamond_tracking/features/auth/presentation/controllers/auth_controller.dart';
import 'package:diamond_tracking/features/auth/presentation/controllers/auth_state.dart';
import 'package:diamond_tracking/features/duty/presentation/controllers/duty_controller.dart';
import 'package:diamond_tracking/features/duty/presentation/controllers/duty_state.dart';
import 'package:diamond_tracking/features/history/presentation/my_duty_history_page.dart';
import 'package:diamond_tracking/features/home/presentation/employee_home_page.dart';
import 'package:diamond_tracking/features/map/presentation/employee_map_page.dart';
import 'package:diamond_tracking/features/profile/presentation/employee_profile_page.dart';
import 'package:diamond_tracking/features/shell/employee_shell.dart';
import 'package:diamond_tracking/features/visits/presentation/controllers/visit_capture_controller.dart';
import 'package:diamond_tracking/shared/widgets/app_bottom_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_duty.dart';
import 'support/quiet_visit_sync.dart';

class _OffDutyNotifier extends DutyNotifier {
  @override
  DutyScreenState build() => const DutyScreenState();
}

class _SignedInEmployee extends AuthNotifier {
  @override
  AuthState build() => AuthAuthenticated(
    UserProfile(
      id: 'emp-1',
      role: UserRole.employee,
      status: UserStatus.active,
      fullName: 'Suresh Kumar',
      mustChangePin: false,
      failedLoginAttempts: 0,
      createdAt: DateTime(2026, 10, 1),
      updatedAt: DateTime(2026, 10, 1),
      employeeCode: 'DA-001',
    ),
  );
}

void main() {
  Future<void> pumpShell(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dutyControllerProvider.overrideWith(_OffDutyNotifier.new),
          authControllerProvider.overrideWith(_SignedInEmployee.new),
          visitSyncServiceProvider.overrideWithValue(QuietVisitSync()),
          dutyRepositoryProvider.overrideWithValue(FakeDutyRepository()),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const EmployeeShell()),
      ),
    );
    await tester.pump();
  }

  group('EmployeeShell', () {
    testWidgets('opens on Duty with a three-item bottom bar', (tester) async {
      await pumpShell(tester);

      expect(find.byType(EmployeeHomePage), findsOneWidget);
      expect(find.byType(AppBottomNavigationBar), findsOneWidget);
      for (final label in const ['duty', 'map', 'history']) {
        expect(find.byKey(Key('nav-$label')), findsOneWidget);
      }
    });

    testWidgets('builds Map and History only when first opened', (
      tester,
    ) async {
      await pumpShell(tester);

      expect(find.byType(EmployeeMapPage, skipOffstage: false), findsNothing);
      expect(find.byType(MyDutyHistoryPage, skipOffstage: false), findsNothing);

      await tester.tap(find.byKey(const Key('nav-map')));
      await tester.pump();
      expect(find.byType(EmployeeMapPage), findsOneWidget);
      expect(find.byType(MyDutyHistoryPage, skipOffstage: false), findsNothing);
    });

    testWidgets('every tab is reachable from every other tab', (tester) async {
      await pumpShell(tester);

      final pages = <String, Type>{
        'map': EmployeeMapPage,
        'history': MyDutyHistoryPage,
        'duty': EmployeeHomePage,
      };

      for (final label in [...pages.keys, ...pages.keys.toList().reversed]) {
        await tester.tap(find.byKey(Key('nav-$label')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(
          find.byWidgetPredicate((w) => w.runtimeType == pages[label]),
          findsOneWidget,
          reason: 'tab $label',
        );
      }
    });

    testWidgets('Profile opens above the shell and returns to the same tab', (
      tester,
    ) async {
      await pumpShell(tester);

      await tester.tap(find.byKey(const Key('profile-action-btn')));
      await tester.pumpAndSettle();

      expect(find.byType(EmployeeProfilePage), findsOneWidget);
      expect(find.byType(AppBottomNavigationBar), findsNothing);

      await tester.tap(find.byKey(const Key('profile-back-btn')));
      await tester.pumpAndSettle();

      expect(find.byType(EmployeeHomePage), findsOneWidget);
      expect(find.byType(AppBottomNavigationBar), findsOneWidget);
    });

    testWidgets('back on another tab returns to Duty first', (tester) async {
      await pumpShell(tester);

      await tester.tap(find.byKey(const Key('nav-history')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(MyDutyHistoryPage), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(EmployeeHomePage), findsOneWidget);
      expect(find.byType(MyDutyHistoryPage), findsNothing);
    });
  });
}
