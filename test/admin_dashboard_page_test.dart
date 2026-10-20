import 'package:diamond_tracking/core/errors/app_exceptions.dart';
import 'package:diamond_tracking/core/theme/app_theme.dart';
import 'package:diamond_tracking/domain/entities/admin_activity_event.dart';
import 'package:diamond_tracking/domain/entities/live_position.dart';
import 'package:diamond_tracking/domain/entities/user_profile.dart';
import 'package:diamond_tracking/domain/repositories/live_location_repository.dart';
import 'package:diamond_tracking/domain/repositories/notification_repository.dart';
import 'package:diamond_tracking/features/admin/dashboard/presentation/admin_dashboard_page.dart';
import 'package:diamond_tracking/features/admin/dashboard/presentation/controllers/admin_attention.dart';
import 'package:diamond_tracking/features/admin/dashboard/presentation/widgets/admin_map_preview_card.dart';
import 'package:diamond_tracking/features/admin/dashboard/presentation/widgets/admin_profile_sheet.dart';
import 'package:diamond_tracking/features/admin/dashboard/presentation/widgets/admin_recent_activity_card.dart';
import 'package:diamond_tracking/features/admin/dashboard/presentation/widgets/admin_stat_card.dart';
import 'package:diamond_tracking/features/admin/employees/presentation/admin_employee_form_page.dart';
import 'package:diamond_tracking/features/admin/employees/presentation/controllers/admin_employee_list_state.dart';
import 'package:diamond_tracking/features/admin/map/presentation/controllers/admin_live_map_controller.dart';
import 'package:diamond_tracking/features/admin/map/presentation/controllers/admin_live_map_state.dart';
import 'package:diamond_tracking/features/admin/shell/admin_tab.dart';
import 'package:diamond_tracking/features/auth/presentation/controllers/auth_controller.dart';
import 'package:diamond_tracking/features/auth/presentation/controllers/auth_state.dart';
import 'package:diamond_tracking/shared/widgets/app_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_admin_activity.dart';
import 'support/fake_auth.dart';
import 'support/fake_employee_repository.dart';
import 'support/fake_live_locations.dart';
import 'support/fake_notification_repository.dart';

class TestAuthNotifier extends AuthNotifier {
  TestAuthNotifier(this._initialState);
  final AuthState _initialState;

  @override
  AuthState build() => _initialState;
}

final testAdminProfile = UserProfile(
  id: 'admin-123',
  role: UserRole.admin,
  status: UserStatus.active,
  fullName: 'Operations Administrator',
  email: 'admin@diamondagritech.in',
  mustChangePin: false,
  failedLoginAttempts: 0,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

void main() {
  late FakeLiveLocationRepository live;
  late FakeEmployeeRepository roster;
  late FakeAdminActivityRepository activity;
  late FakeNotificationRepository notifications;

  setUp(() {
    live = FakeLiveLocationRepository();
    roster = FakeEmployeeRepository(
      roster: [
        rosterEmployee('e-asha', 'Asha Patil', 'DA-101'),
        rosterEmployee('e-ravi', 'Ravi Kumar', 'DA-102'),
        rosterEmployee('e-meena', 'Meena Joshi', 'DA-103'),
        rosterEmployee('e-sunil', 'Sunil More', 'DA-104'),
        rosterEmployee('e-leena', 'Leena Shah', 'DA-105'),
        // Active but not on duty:
        const AdminEmployeeItem(
          id: 'e-off',
          name: 'Off Duty Person',
          employeeCode: 'DA-106',
          phoneNumber: '+919820000106',
          status: AdminEmployeeStatus.offDuty,
        ),
        // Blocked people are not counted as off duty:
        const AdminEmployeeItem(
          id: 'e-blocked',
          name: 'Blocked Person',
          employeeCode: 'DA-107',
          phoneNumber: '+919820000107',
          status: AdminEmployeeStatus.blocked,
          isActive: false,
        ),
      ],
    );
    activity = FakeAdminActivityRepository();
    notifications = FakeNotificationRepository();
  });

  /// Asha fresh, Ravi stale, Meena flagged.
  void threePeople() {
    live.positions = [
      livePosition('e-asha'),
      livePosition('e-ravi', ago: const Duration(minutes: 9)),
      livePosition('e-meena', isMock: true),
    ];
  }

  Future<void> pumpPage(
    WidgetTester tester, {
    VoidCallback? onNavigateToNotifications,
    VoidCallback? onProfilePressed,
    bool settle = true,
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...liveMapOverrides(live, roster),
          activityOverride(activity),
          notificationOverride(notifications),
          authControllerProvider.overrideWith(
            () => TestAuthNotifier(AuthAuthenticated(testAdminProfile)),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: AdminDashboardPage(
            onNavigateToNotifications: onNavigateToNotifications,
            onProfilePressed: onProfilePressed,
          ),
        ),
      ),
    );
    if (settle) await settleFrames(tester);
  }

  /// The Home owns timers (live feed, activity), so the page is taken down
  /// before the test ends (the framework checks for timers before tear-down).
  Future<void> closePage(WidgetTester tester) =>
      tester.pumpWidget(const SizedBox());

  /// The big number inside the status tile labelled [label].
  Finder valueOf(String label, String value) => find.descendant(
    of: find.ancestor(
      of: find.text(label),
      matching: find.byType(AdminStatCard),
    ),
    matching: find.text(value),
  );

  /// The headline "On duty now" figure in the hero.
  Finder onDutyNow(String value) => find.byWidgetPredicate(
    (w) =>
        w is Text &&
        w.key == const Key('dashboard-on-duty-count') &&
        w.data == value,
  );

  group('Screen 14 AdminDashboardPage header', () {
    testWidgets(
      'renders header with branding and a notification bell without invented badge',
      (tester) async {
        bool notified = false;
        await pumpPage(
          tester,
          onNavigateToNotifications: () => notified = true,
        );

        expect(find.text('Diamond Agritech'), findsOneWidget);
        expect(find.text('Admin • Home'), findsOneWidget);
        expect(find.byType(AppBadge), findsNothing);

        await tester.tap(find.byTooltip('Notifications'));
        await tester.pump();
        expect(notified, isTrue);
        await closePage(tester);
      },
    );

    testWidgets('shows the date from the clock, not a fixed date', (
      tester,
    ) async {
      await pumpPage(tester);

      expect(find.textContaining('12 October 2026 · 2:48 PM'), findsNothing);
      expect(find.textContaining('${DateTime.now().year}'), findsOneWidget);
      await closePage(tester);
    });
  });

  group('duty counts come from the same live feed as the map', () {
    testWidgets('show a dash while loading, never a made-up zero', (
      tester,
    ) async {
      threePeople();
      await pumpPage(tester, settle: false);

      // The four 2x2 telemetry status tiles (ON DUTY, OFF DUTY, NO UPDATE, NEEDS CHECK).
      expect(find.byType(AdminStatCard), findsNWidgets(4));
      expect(find.text('–'), findsNWidgets(4));
      expect(find.byKey(const Key('dashboard-of-total')), findsNothing);
      expect(find.text('0'), findsNothing);

      await settleFrames(tester);
      expect(find.text('–'), findsNothing);
      await closePage(tester);
    });

    testWidgets('count everyone on duty, the quiet ones and the flagged ones', (
      tester,
    ) async {
      threePeople();
      await pumpPage(tester);

      // 3 on duty (fresh, stale and flagged all count as on duty), 1 quiet,
      // 1 flagged. Off duty: the 6 active staff minus the 3 on duty. The
      // blocked person is not counted.
      expect(onDutyNow('3'), findsOneWidget);
      expect(find.text('of 6 active'), findsOneWidget);
      expect(valueOf('OFF DUTY', '3'), findsOneWidget);
      expect(valueOf('NO UPDATE', '1'), findsOneWidget);
      expect(valueOf('NEEDS CHECK', '1'), findsOneWidget);
      await closePage(tester);
    });

    testWidgets('are zero when nobody is on duty and the load succeeded', (
      tester,
    ) async {
      await pumpPage(tester);

      expect(onDutyNow('0'), findsOneWidget);
      expect(find.text('of 6 active'), findsOneWidget);
      expect(valueOf('NO UPDATE', '0'), findsOneWidget);
      expect(valueOf('NEEDS CHECK', '0'), findsOneWidget);
      // Every active employee is off duty (6); the blocked one is excluded.
      expect(valueOf('OFF DUTY', '6'), findsOneWidget);
      await closePage(tester);
    });

    testWidgets('move when someone starts duty, without any reload', (
      tester,
    ) async {
      await pumpPage(tester);
      expect(onDutyNow('0'), findsOneWidget);

      live.emit(LivePositionChanged(livePosition('e-asha')));
      await tester.pump(const Duration(seconds: 1));

      expect(onDutyNow('1'), findsOneWidget);
      expect(valueOf('OFF DUTY', '5'), findsOneWidget);
      await closePage(tester);
    });

    testWidgets('show dashes, not zeros, when the load failed', (tester) async {
      live.error = const NetworkException();
      await pumpPage(tester);

      expect(find.text('–'), findsNWidgets(4));
      expect(find.text('0'), findsNothing);
      await closePage(tester);
    });

    testWidgets('every status tile opens the Team tab, the hero the Map tab', (
      tester,
    ) async {
      await pumpPage(tester);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(AdminDashboardPage)),
      );
      final tab = container.listen(adminTabProvider, (_, _) {});
      addTearDown(tab.close);

      for (final label in ['OFF DUTY', 'NO UPDATE', 'NEEDS CHECK']) {
        container.read(adminTabProvider.notifier).select(AdminTab.home);
        await tester.tap(find.text(label));
        await tester.pump();
        expect(tab.read(), AdminTab.team, reason: label);
      }

      container.read(adminTabProvider.notifier).select(AdminTab.home);
      await tester.tap(find.byKey(const Key('dashboard-on-duty')));
      await tester.pump();
      expect(tab.read(), AdminTab.map, reason: 'On duty now');
      await closePage(tester);
    });
  });

  group('live map card', () {
    testWidgets('lists who is on duty with how fresh each position is', (
      tester,
    ) async {
      threePeople();
      await pumpPage(tester);

      expect(find.byType(AdminMapPreviewCard), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AdminMapPreviewCard),
          matching: find.text('Live map'),
        ),
        findsOneWidget,
      );
      expect(find.text('No one is on duty'), findsNothing);
      expect(find.byKey(const Key('preview-officer-e-asha')), findsOneWidget);
      expect(find.text('Asha Patil'), findsOneWidget);
      expect(find.text('Just now'), findsNWidgets(2));
      expect(find.text('9 min ago'), findsOneWidget);
      // A worrying status is in words as well as colour.
      expect(find.text('No update 5 min'), findsOneWidget);
      expect(find.text('Check needed'), findsOneWidget);
      expect(find.byKey(const Key('preview-more')), findsNothing);
      await closePage(tester);
    });

    testWidgets('shows only the first three and counts the rest', (
      tester,
    ) async {
      live.positions = [
        livePosition('e-asha'),
        livePosition('e-ravi'),
        livePosition('e-meena'),
        livePosition('e-sunil'),
        livePosition('e-leena'),
      ];
      await pumpPage(tester);

      expect(find.byKey(const Key('preview-officer-e-asha')), findsOneWidget);
      expect(find.byKey(const Key('preview-officer-e-sunil')), findsNothing);
      expect(find.text('+2 more on duty'), findsOneWidget);
      await closePage(tester);
    });

    testWidgets('says plainly when nobody is on duty, and navigates', (
      tester,
    ) async {
      await pumpPage(tester);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(AdminDashboardPage)),
      );
      final tab = container.listen(adminTabProvider, (_, _) {});
      addTearDown(tab.close);
      expect(tab.read(), AdminTab.home);

      expect(find.text('No one is on duty'), findsOneWidget);
      expect(find.text('View all'), findsOneWidget);
      // No drawn map, invented clusters or wrong attribution.
      expect(find.text('Mapbox © OpenStreetMap'), findsNothing);

      await tester.tap(find.text('View all'));
      await tester.pump();
      expect(tab.read(), AdminTab.map);
      await closePage(tester);
    });

    testWidgets('a person row opens the Map tab', (tester) async {
      threePeople();
      await pumpPage(tester);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(AdminDashboardPage)),
      );
      final tab = container.listen(adminTabProvider, (_, _) {});
      addTearDown(tab.close);

      await tester.tap(find.byKey(const Key('preview-officer-e-ravi')));
      await tester.pump();

      expect(tab.read(), AdminTab.map);
      await closePage(tester);
    });

    testWidgets('loading and failure are not "No one is on duty"', (
      tester,
    ) async {
      live.error = const NetworkException();
      await pumpPage(tester, settle: false);
      expect(find.byKey(const Key('preview-loading')), findsOneWidget);
      expect(find.text('No one is on duty'), findsNothing);

      await settleFrames(tester);
      expect(find.byKey(const Key('preview-error')), findsOneWidget);
      expect(find.text('No one is on duty'), findsNothing);
      await closePage(tester);
    });
  });

  group('recent activity', () {
    testWidgets('shows real events, newest first, worded for the admin', (
      tester,
    ) async {
      activity.events = [
        activityEvent(
          AdminActivityKind.dutyStarted,
          id: 'start:1',
          ago: const Duration(minutes: 2),
        ),
        activityEvent(
          AdminActivityKind.dutyEnded,
          id: 'end:2',
          name: 'Ravi Kumar',
          code: 'DA-102',
          ago: const Duration(hours: 1, minutes: 5),
        ),
        activityEvent(
          AdminActivityKind.dutyAutoEnded,
          id: 'end:3',
          name: 'Meena Joshi',
          code: 'DA-103',
          ago: const Duration(days: 1),
        ),
        activityEvent(
          AdminActivityKind.employeeBlocked,
          id: 'audit:4',
          name: 'Sunil More',
          code: 'DA-104',
          detail: 'by Operations Administrator',
          ago: const Duration(minutes: 30),
        ),
      ];
      await pumpPage(tester);

      expect(find.byType(AdminRecentActivityCard), findsOneWidget);
      expect(find.text('Recent activity'), findsOneWidget);
      expect(find.text('Asha Patil started duty'), findsOneWidget);
      expect(find.text('2 min ago'), findsOneWidget);
      expect(find.text('Ravi Kumar ended duty'), findsOneWidget);
      expect(find.text('1 h 5 min ago'), findsOneWidget);
      expect(find.text('Duty ended automatically'), findsOneWidget);
      expect(find.text('Meena Joshi · DA-103'), findsOneWidget);
      expect(find.text('1 d ago'), findsOneWidget);
      expect(find.text('Sunil More was blocked'), findsOneWidget);
      expect(find.text('by Operations Administrator'), findsOneWidget);
      expect(find.text('No activity yet'), findsNothing);
      await closePage(tester);
    });

    testWidgets('says "No activity yet" only after a successful empty load', (
      tester,
    ) async {
      await pumpPage(tester, settle: false);
      expect(find.byKey(const Key('activity-loading')), findsOneWidget);
      expect(find.text('No activity yet'), findsNothing);

      await settleFrames(tester);
      expect(find.byKey(const Key('activity-loading')), findsNothing);
      expect(find.text('No activity yet'), findsOneWidget);
      await closePage(tester);
    });

    testWidgets('a failed load is an error with Retry, then recovers', (
      tester,
    ) async {
      activity.error = const NetworkException();
      await pumpPage(tester);

      expect(find.byKey(const Key('activity-error')), findsOneWidget);
      expect(find.text('No activity yet'), findsNothing);

      activity
        ..error = null
        ..events = [activityEvent(AdminActivityKind.dutyStarted)];
      await tester.ensureVisible(find.byKey(const Key('btn-activity-retry')));
      await tester.tap(find.byKey(const Key('btn-activity-retry')));
      await settleFrames(tester);

      expect(find.byKey(const Key('activity-error')), findsNothing);
      expect(find.text('Asha Patil started duty'), findsOneWidget);
      await closePage(tester);
    });

    testWidgets('reloads when someone starts duty, and every minute', (
      tester,
    ) async {
      await pumpPage(tester);
      final loads = activity.fetchCount;

      live.emit(LivePositionChanged(livePosition('e-asha')));
      await tester.pump(const Duration(seconds: 1));
      await settleFrames(tester);
      expect(activity.fetchCount, loads + 1);

      await tester.pump(const Duration(minutes: 1));
      await settleFrames(tester);
      expect(activity.fetchCount, greaterThan(loads + 1));
      await closePage(tester);
    });

    testWidgets('a failed refresh keeps what is already shown', (tester) async {
      activity.events = [activityEvent(AdminActivityKind.dutyStarted)];
      await pumpPage(tester);
      expect(find.text('Asha Patil started duty'), findsOneWidget);

      activity.error = const NetworkException();
      await tester.pump(const Duration(minutes: 1));
      await settleFrames(tester);

      expect(find.text('Asha Patil started duty'), findsOneWidget);
      expect(find.byKey(const Key('activity-error')), findsNothing);
      await closePage(tester);
    });

    testWidgets('See all opens notifications', (tester) async {
      bool opened = false;
      await pumpPage(tester, onNavigateToNotifications: () => opened = true);

      await tester.ensureVisible(
        find.byKey(const Key('btn-see-all-activities')),
      );
      await tester.tap(find.byKey(const Key('btn-see-all-activities')));
      await tester.pump();

      expect(opened, isTrue);
      await closePage(tester);
    });
  });

  testWidgets('pull to refresh reloads the live positions and the activity', (
    tester,
  ) async {
    await pumpPage(tester);
    final liveLoads = live.fetchCount;
    final activityLoads = activity.fetchCount;
    threePeople();

    await tester.fling(
      find.byType(SingleChildScrollView),
      const Offset(0, 400),
      1000,
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await settleFrames(tester);
    await tester.pump(const Duration(seconds: 1));

    expect(live.fetchCount, greaterThan(liveLoads));
    expect(activity.fetchCount, greaterThan(activityLoads));
    expect(onDutyNow('3'), findsOneWidget);
    await closePage(tester);
  });

  testWidgets(
    'has no Broadcast Alert or Export Day Log action (features removed)',
    (tester) async {
      await pumpPage(tester);

      expect(find.byKey(const Key('btn-broadcast-alert')), findsNothing);
      expect(find.text('Broadcast Alert'), findsNothing);
      expect(find.byKey(const Key('btn-export-day-log')), findsNothing);
      expect(find.text('Export Day Log'), findsNothing);
      await closePage(tester);
    },
  );

  group('the bell', () {
    testWidgets(
      'shows the SERVER unread count, not the rows that happen to be loaded',
      (tester) async {
        notifications.all = [
          for (var id = 120; id >= 1; id--) notification(id),
        ];
        await pumpPage(tester);

        expect(
          find.descendant(
            of: find.byKey(const Key('admin-notifications-btn')),
            matching: find.text('99+'),
          ),
          findsOneWidget,
        );
        await closePage(tester);
      },
    );

    testWidgets('shows a small exact count', (tester) async {
      notifications.all = [for (var id = 3; id >= 1; id--) notification(id)];
      await pumpPage(tester);

      expect(
        find.descendant(
          of: find.byKey(const Key('admin-notifications-btn')),
          matching: find.text('3'),
        ),
        findsOneWidget,
      );
      await closePage(tester);
    });

    testWidgets(
      'rises the moment a notification arrives, without opening the centre',
      (tester) async {
        notifications.all = [notification(1)];
        await pumpPage(tester);

        notifications.emit(NotificationArrived(notification(2)));
        await tester.pump();

        expect(
          find.descendant(
            of: find.byKey(const Key('admin-notifications-btn')),
            matching: find.text('2'),
          ),
          findsOneWidget,
        );
        await closePage(tester);
      },
    );

    testWidgets(
      'has no number when nothing is unread, and when the count cannot be read',
      (tester) async {
        notifications.countError = const NetworkException();
        await pumpPage(tester);

        expect(find.byType(AppBadge), findsNothing);
        await closePage(tester);
      },
    );

    testWidgets('pull to refresh reads the notifications again too', (
      tester,
    ) async {
      await pumpPage(tester);
      final calls = notifications.pageCalls.length;
      notifications.all = [notification(1)];

      await tester.fling(
        find.byType(SingleChildScrollView).first,
        const Offset(0, 400),
        1000,
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await settleFrames(tester);
      await tester.pump(const Duration(seconds: 1));

      expect(notifications.pageCalls.length, greaterThan(calls));
      await closePage(tester);
    });
  });

  group('admin profile', () {
    testWidgets(
      'tapping admin profile avatar opens AdminProfileSheet with metadata',
      (tester) async {
        await pumpPage(tester);

        final profileBtn = find.byKey(const Key('admin-profile-btn'));
        expect(profileBtn, findsOneWidget);

        await tester.tap(profileBtn);
        await tester.pumpAndSettle();

        expect(find.byType(AdminProfileSheet), findsOneWidget);
        expect(find.text('Admin Profile'), findsOneWidget);
        expect(find.text('ACTIVE'), findsOneWidget);
        expect(find.text('ADMINISTRATOR'), findsOneWidget);
        expect(find.text('Diamond Agritech Pvt Ltd'), findsOneWidget);
        expect(find.text('v1.0.2 (Build 3)'), findsOneWidget);
        expect(find.byKey(const Key('btn-admin-logout')), findsOneWidget);

        await tester.tap(find.byKey(const Key('btn-close-admin-profile')));
        await tester.pumpAndSettle();
        expect(find.byType(AdminProfileSheet), findsNothing);
        await closePage(tester);
      },
    );

    testWidgets('custom onProfilePressed callback executes when provided', (
      tester,
    ) async {
      bool profileTapped = false;
      await pumpPage(tester, onProfilePressed: () => profileTapped = true);

      await tester.tap(find.byKey(const Key('admin-profile-btn')));
      await tester.pump();

      expect(profileTapped, isTrue);
      await closePage(tester);
    });
  });

  group('operational header and telemetry', () {
    testWidgets('shows the operational date in header', (tester) async {
      await pumpPage(tester);

      expect(find.byKey(const Key('dashboard-date')), findsOneWidget);
      expect(find.textContaining('${DateTime.now().year}'), findsOneWidget);
      await closePage(tester);
    });

    testWidgets('shows how many of the active people are on duty', (
      tester,
    ) async {
      threePeople();
      await pumpPage(tester);

      expect(find.text('of 6 active'), findsOneWidget);
      expect(onDutyNow('3'), findsOneWidget);
      await closePage(tester);
    });

    testWidgets('says whether the live feed is connected', (tester) async {
      await pumpPage(tester);

      Finder pill(String word) => find.descendant(
        of: find.byKey(const Key('dashboard-connection')),
        matching: find.text(word),
      );

      live.emit(const LiveConnectionChanged(connected: true));
      await tester.pump();
      expect(pill('Live'), findsOneWidget);

      live.emit(const LiveConnectionChanged(connected: false));
      await tester.pump();
      expect(pill('Offline'), findsOneWidget);
      await closePage(tester);
    });
  });

  group('needs attention', () {
    testWidgets('lists fake GPS, then gone quiet, then low battery, once each', (
      tester,
    ) async {
      live.positions = [
        livePosition('e-asha', battery: 80),
        livePosition('e-ravi', ago: const Duration(minutes: 9)),
        livePosition('e-meena', isMock: true, battery: 5),
        livePosition('e-sunil', battery: 9),
      ];
      await pumpPage(tester);

      expect(find.byKey(const Key('dashboard-attention')), findsOneWidget);
      expect(find.byKey(const Key('attention-count')), findsOneWidget);
      expect(find.text('3'), findsWidgets);
      // Meena is flagged AND low on battery: one row, the more serious reason.
      expect(find.text('Fake GPS flagged'), findsOneWidget);
      expect(find.text('No update · 9 min ago'), findsOneWidget);
      expect(find.text('Battery 9%'), findsOneWidget);
      expect(find.text('Battery 5%'), findsNothing);
      // Someone fresh with a good battery is not listed.
      expect(find.byKey(const Key('attention-row-e-asha')), findsNothing);
      // Order: flagged, quiet, low battery.
      final meena = tester
          .getTopLeft(find.byKey(const Key('attention-row-e-meena')))
          .dy;
      final ravi = tester
          .getTopLeft(find.byKey(const Key('attention-row-e-ravi')))
          .dy;
      final sunil = tester
          .getTopLeft(find.byKey(const Key('attention-row-e-sunil')))
          .dy;
      expect(meena, lessThan(ravi));
      expect(ravi, lessThan(sunil));
      await closePage(tester);
    });

    testWidgets('is not shown when everyone is fine or the load failed', (
      tester,
    ) async {
      live.positions = [livePosition('e-asha'), livePosition('e-ravi')];
      await pumpPage(tester);
      expect(find.byKey(const Key('dashboard-attention')), findsNothing);
      await closePage(tester);

      live.error = const NetworkException();
      await pumpPage(tester);
      expect(find.byKey(const Key('dashboard-attention')), findsNothing);
      await closePage(tester);
    });

    testWidgets('a missing battery reading is never "low"', (tester) async {
      live.positions = [livePosition('e-asha', battery: null)];
      await pumpPage(tester);

      expect(find.byKey(const Key('dashboard-attention')), findsNothing);
      await closePage(tester);
    });

    testWidgets('tapping a person opens the Map tab on them', (tester) async {
      threePeople();
      await pumpPage(tester);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(AdminDashboardPage)),
      );
      final tab = container.listen(adminTabProvider, (_, _) {});
      addTearDown(tab.close);

      await tester.tap(find.byKey(const Key('attention-row-e-meena')));
      await tester.pump();

      expect(tab.read(), AdminTab.map);
      expect(container.read(liveMapFocusProvider), 'e-meena');
      await closePage(tester);
    });

    testWidgets('shows three people and counts the rest', (tester) async {
      live.positions = [
        livePosition('e-asha', isMock: true),
        livePosition('e-ravi', isMock: true),
        livePosition('e-meena', isMock: true),
        livePosition('e-sunil', isMock: true),
        livePosition('e-leena', isMock: true),
      ];
      await pumpPage(tester);

      expect(find.text('+2 more'), findsOneWidget);
      await closePage(tester);
    });
  });

  group('quick actions', () {
    testWidgets('open the Map, Team and Reports tabs', (tester) async {
      await pumpPage(tester);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(AdminDashboardPage)),
      );
      final tab = container.listen(adminTabProvider, (_, _) {});
      addTearDown(tab.close);

      for (final entry in {
        'quick-live-map': AdminTab.map,
        'quick-team': AdminTab.team,
        'quick-reports': AdminTab.reports,
      }.entries) {
        container.read(adminTabProvider.notifier).select(AdminTab.home);
        await tester.tap(find.byKey(Key(entry.key)));
        await tester.pump();
        expect(tab.read(), entry.value, reason: entry.key);
      }
      await closePage(tester);
    });

    testWidgets('Add employee opens the new-employee form', (tester) async {
      await pumpPage(tester);

      await tester.tap(find.byKey(const Key('quick-add-employee')));
      await tester.pumpAndSettle();

      expect(find.byType(AdminEmployeeFormPage), findsOneWidget);
      await closePage(tester);
    });
  });

  group('small screens', () {
    testWidgets('nothing overflows at 320 dp wide with 150% text', (
      tester,
    ) async {
      live.positions = [
        livePosition('e-asha'),
        livePosition('e-ravi', ago: const Duration(minutes: 9)),
        livePosition('e-meena', isMock: true),
      ];
      tester.view.physicalSize = const Size(640, 1400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...liveMapOverrides(live, roster),
            activityOverride(activity),
            notificationOverride(notifications),
            signedInAdminOverride(),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.5)),
              child: child!,
            ),
            home: const AdminDashboardPage(),
          ),
        ),
      );
      await settleFrames(tester);

      expect(tester.takeException(), isNull);
      // Scroll to the bottom: the last card must lay out too.
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -3000),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      await closePage(tester);
    });
  });

  group('attentionItems', () {
    LiveOfficer officer(
      String id,
      String name,
      LiveStatus status,
      int? battery,
    ) => LiveOfficer(
      id: id,
      name: name,
      employeeCode: 'DA-$id',
      phoneNumber: '',
      position: livePosition(id, battery: battery),
      status: status,
      lastSeen: '2 min ago',
    );

    test('orders by reason, then by name, and drops people who are fine', () {
      final items = attentionItems([
        officer('1', 'Zed', LiveStatus.stale, 80),
        officer('2', 'Amy', LiveStatus.stale, 80),
        officer('3', 'Bob', LiveStatus.suspect, 80),
        officer('4', 'Cat', LiveStatus.active, 14),
        officer('5', 'Dan', LiveStatus.active, 15),
        officer('6', 'Eve', LiveStatus.active, null),
      ]);

      expect(items.map((i) => i.officer.name), ['Bob', 'Amy', 'Zed', 'Cat']);
      expect(items.map((i) => i.reason), [
        AttentionReason.fakeGps,
        AttentionReason.noUpdate,
        AttentionReason.noUpdate,
        AttentionReason.lowBattery,
      ]);
      expect(items.last.text, 'Battery 14%');
    });
  });
}

/// Lets queued async work finish.
Future<void> settleFrames(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump();
  }
}
