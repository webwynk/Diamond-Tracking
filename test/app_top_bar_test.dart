import 'package:diamond_tracking/core/theme/app_colors.dart';
import 'package:diamond_tracking/core/theme/app_dimens.dart';
import 'package:diamond_tracking/core/theme/app_theme.dart';
import 'package:diamond_tracking/features/admin/attendance/presentation/admin_attendance_page.dart';
import 'package:diamond_tracking/features/admin/employees/presentation/admin_employee_form_page.dart';
import 'package:diamond_tracking/features/admin/employees/presentation/admin_employee_list_page.dart';
import 'package:diamond_tracking/features/admin/map/presentation/admin_live_map_page.dart';
import 'package:diamond_tracking/features/admin/notifications/presentation/admin_notification_centre_page.dart';
import 'package:diamond_tracking/features/admin/places/presentation/admin_place_form_page.dart';
import 'package:diamond_tracking/features/admin/places/presentation/admin_places_page.dart';
import 'package:diamond_tracking/features/admin/reports/presentation/admin_reports_page.dart';
import 'package:diamond_tracking/features/admin/route_view/presentation/admin_route_view_page.dart';
import 'package:diamond_tracking/features/auth/presentation/controllers/auth_controller.dart';
import 'package:diamond_tracking/features/auth/presentation/controllers/auth_state.dart';
import 'package:diamond_tracking/features/history/presentation/my_duty_history_page.dart';
import 'package:diamond_tracking/shared/widgets/app_top_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_employee_repository.dart';
import 'support/fake_live_locations.dart';
import 'support/fake_notification_repository.dart';
import 'support/fake_route.dart';

class _SignedOut extends AuthNotifier {
  @override
  AuthState build() => const AuthUnauthenticated();
}

Widget _host(Widget appBarOrPage, {bool asAppBar = true}) {
  return ProviderScope(
    overrides: [
      authControllerProvider.overrideWith(_SignedOut.new),
      // The live map reads the server; the test must not.
      ...liveMapOverrides(
        FakeLiveLocationRepository(),
        FakeEmployeeRepository(),
      ),
      ...routeOverrides(FakeRouteRepository()),
      notificationOverride(FakeNotificationRepository()),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      home: asAppBar
          ? Scaffold(appBar: appBarOrPage as PreferredSizeWidget)
          : appBarOrPage,
    ),
  );
}

void main() {
  group('AppTopBar', () {
    testWidgets('is exactly AppSizes.appBarHeight tall in both styles', (
      tester,
    ) async {
      for (final style in AppTopBarStyle.values) {
        await tester.pumpWidget(_host(AppTopBar(title: 'Title', style: style)));
        expect(
          tester.getSize(find.byType(AppTopBar)).height,
          AppSizes.appBarHeight,
          reason: '$style',
        );
      }
    });

    testWidgets('sits below the status bar and keeps its 56 dp content row', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.light,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(padding: const EdgeInsets.only(top: 24)),
              child: child!,
            ),
            home: const Scaffold(
              appBar: AppTopBar(title: 'Title', leading: AppTopBarLeading.back),
            ),
          ),
        ),
      );

      expect(
        tester.getSize(find.byType(AppTopBar)).height,
        AppSizes.appBarHeight + 24,
      );
      // Back button is vertically centred in the 56 dp row below the inset.
      expect(
        tester.getCenter(find.byIcon(Icons.arrow_back_rounded)).dy,
        24 + 28,
      );
    });

    testWidgets('brand style is solid brand colour, surface style is white '
        'with a bottom border', (tester) async {
      await tester.pumpWidget(
        _host(const AppTopBar(title: 'Brand', style: AppTopBarStyle.brand)),
      );
      var box = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byType(AppTopBar),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      var decoration = box.decoration as BoxDecoration;
      expect(decoration.color, AppColors.primary600);
      expect(decoration.border, isNull);

      await tester.pumpWidget(_host(const AppTopBar(title: 'Surface')));
      box = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byType(AppTopBar),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      decoration = box.decoration as BoxDecoration;
      expect(decoration.color, AppColors.surface);
      expect(decoration.border, isNotNull);
    });

    testWidgets('title uses the h3 style in both styles', (tester) async {
      for (final style in AppTopBarStyle.values) {
        await tester.pumpWidget(_host(AppTopBar(title: 'Title', style: style)));
        final text = tester.widget<Text>(find.text('Title'));
        expect(text.style?.fontSize, 20);
      }
    });

    testWidgets('back button pops the route by default', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.light,
            home: Builder(
              builder: (context) => TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const Scaffold(
                      appBar: AppTopBar(
                        title: 'Detail',
                        leading: AppTopBarLeading.back,
                      ),
                    ),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Detail'), findsOneWidget);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Detail'), findsNothing);
    });

    testWidgets('custom leading callback replaces the default pop', (
      tester,
    ) async {
      var pressed = 0;
      await tester.pumpWidget(
        _host(
          AppTopBar(
            title: 'Form',
            leading: AppTopBarLeading.close,
            leadingKey: const Key('lead'),
            onLeadingPressed: () => pressed++,
          ),
        ),
      );

      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
      await tester.tap(find.byKey(const Key('lead')));
      expect(pressed, 1);
    });

    testWidgets('leading and action buttons meet the 48 dp touch target', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          AppTopBar(
            title: 'Title',
            leading: AppTopBarLeading.back,
            leadingKey: const Key('lead'),
            actions: <Widget>[
              AppTopBarIconButton(
                key: const Key('bell'),
                icon: Icons.notifications_none,
                tooltip: 'Bell',
                onPressed: () {},
              ),
              AppTopBarProfileButton(
                key: const Key('profile'),
                onPressed: () {},
              ),
            ],
          ),
        ),
      );

      for (final key in const ['lead', 'bell', 'profile']) {
        final size = tester.getSize(find.byKey(Key(key)));
        expect(size.width, greaterThanOrEqualTo(AppSizes.minTouchTarget));
        expect(size.height, greaterThanOrEqualTo(AppSizes.minTouchTarget));
      }
    });

    testWidgets('long title ellipsises without overflow', (tester) async {
      await tester.pumpWidget(
        _host(
          AppTopBar(
            title: 'A very long screen title that cannot possibly fit ' * 3,
            subtitle: 'And a very long subtitle line ' * 3,
            leading: AppTopBarLeading.back,
            titleTrailing: const Text('12 ACTIVE'),
            actions: <Widget>[
              IconButton(
                icon: const Icon(Icons.tune_rounded),
                onPressed: () {},
              ),
              IconButton(
                icon: const Icon(Icons.download_rounded),
                onPressed: () {},
              ),
            ],
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('icon button shows a count badge, capped at 99+', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          AppTopBar(
            title: 'Title',
            actions: <Widget>[
              AppTopBarIconButton(
                icon: Icons.notifications_none,
                tooltip: 'Bell',
                badgeCount: 7,
                onPressed: () {},
              ),
            ],
          ),
        ),
      );
      expect(find.text('7'), findsOneWidget);

      await tester.pumpWidget(
        _host(
          AppTopBar(
            title: 'Title',
            actions: <Widget>[
              AppTopBarIconButton(
                icon: Icons.notifications_none,
                tooltip: 'Bell',
                badgeCount: 150,
                onPressed: () {},
              ),
            ],
          ),
        ),
      );
      expect(find.text('99+'), findsOneWidget);
    });

    testWidgets('icon button shows no badge for a zero count', (tester) async {
      await tester.pumpWidget(
        _host(
          AppTopBar(
            title: 'Title',
            actions: <Widget>[
              AppTopBarIconButton(
                icon: Icons.notifications_none,
                tooltip: 'Bell',
                onPressed: () {},
              ),
            ],
          ),
        ),
      );
      expect(find.text('0'), findsNothing);
    });
  });

  // Guards against header drift: every real screen must use the shared bar at
  // the same height.
  group('Every screen uses the shared AppTopBar at one height', () {
    final screens = <String, Widget>{
      'Notifications': const AdminNotificationCentrePage(),
      'Attendance': const AdminAttendancePage(
        employeeId: 'emp-1',
        employeeName: 'Suresh Patel',
        employeeCode: 'DA-022',
      ),
      'Team': const AdminEmployeeListPage(),
      'Places': const AdminPlacesPage(),
      'Reports': const AdminReportsPage(),
      'Live map': const AdminLiveMapPage(),
      'Route view': const AdminRouteViewPage(
        employeeId: 'emp-1',
        employeeName: 'Suresh Patel',
      ),
      'Employee form': const AdminEmployeeFormPage(),
      'Place form': const AdminPlaceFormPage(),
      'My history': const MyDutyHistoryPage(),
    };

    for (final entry in screens.entries) {
      testWidgets(entry.key, (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(_host(entry.value, asAppBar: false));
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.byType(AppTopBar), findsOneWidget);
        expect(
          tester.getSize(find.byType(AppTopBar)).height,
          AppSizes.appBarHeight,
        );
      });
    }
  });
}
