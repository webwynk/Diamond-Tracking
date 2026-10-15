import 'package:diamond_tracking/core/theme/app_theme.dart';
import 'package:diamond_tracking/features/admin/dashboard/presentation/admin_dashboard_page.dart';
import 'package:diamond_tracking/features/admin/dashboard/presentation/widgets/admin_bottom_navigation.dart';
import 'package:diamond_tracking/features/admin/dashboard/presentation/widgets/admin_map_preview_card.dart';
import 'package:diamond_tracking/features/admin/dashboard/presentation/widgets/admin_recent_activity_card.dart';
import 'package:diamond_tracking/features/admin/dashboard/presentation/widgets/admin_stat_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildTestableAdminDashboard({
    VoidCallback? onNavigateToMap,
    VoidCallback? onNavigateToTeam,
    VoidCallback? onNavigateToNotifications,
  }) {
    return ProviderScope(
      child: MaterialApp(
        theme: AppTheme.light,
        home: AdminDashboardPage(
          onNavigateToMap: onNavigateToMap,
          onNavigateToTeam: onNavigateToTeam,
          onNavigateToNotifications: onNavigateToNotifications,
        ),
      ),
    );
  }

  group('Screen 14 AdminDashboardPage Widget Tests', () {
    testWidgets('renders header with branding, refresh action, and notification badge',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      bool notified = false;
      await tester.pumpWidget(
        buildTestableAdminDashboard(
          onNavigateToNotifications: () => notified = true,
        ),
      );
      await tester.pump();

      // Brand headers
      expect(find.text('Diamond Agritech'), findsOneWidget);
      expect(find.text('Admin • Home'), findsOneWidget);

      // Notification badge (7 unread notifications)
      expect(find.text('7'), findsOneWidget);

      // Tap notification bell
      await tester.tap(find.byTooltip('Notifications'));
      await tester.pump();
      expect(notified, isTrue);
    });

    testWidgets('renders 2x2 stat cards with correct metrics and styling',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestableAdminDashboard());
      await tester.pump();

      // Section header
      expect(find.text('TELEMETRY LIVE'), findsOneWidget);

      // 4 Stat Cards
      expect(find.byType(AdminStatCard), findsNWidgets(4));
      expect(find.text('112'), findsOneWidget);
      expect(find.text('ON DUTY'), findsOneWidget);

      expect(find.text('31'), findsOneWidget);
      expect(find.text('OFF DUTY'), findsOneWidget);

      expect(find.text('4'), findsOneWidget);
      expect(find.text('NO UPDATE'), findsOneWidget);

      expect(find.text('3'), findsOneWidget);
      expect(find.text('NEEDS CHECK'), findsOneWidget);
    });

    testWidgets('renders live map preview card with clusters, calibration badge, and navigates',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      bool mapNavigated = false;
      await tester.pumpWidget(
        buildTestableAdminDashboard(
          onNavigateToMap: () => mapNavigated = true,
        ),
      );
      await tester.pump();

      expect(find.byType(AdminMapPreviewCard), findsOneWidget);
      expect(find.text('Live map'), findsOneWidget);
      expect(find.text('View all'), findsOneWidget);

      // Map clusters
      expect(find.text('12'), findsOneWidget);
      expect(find.text('8'), findsOneWidget);

      // Accuracy and legal attribution badges
      expect(find.text('98.4% Acc.'), findsOneWidget);
      expect(find.text('Mapbox © OpenStreetMap'), findsOneWidget);

      // Tap View full map
      await tester.tap(find.text('View all'));
      await tester.pump();
      expect(mapNavigated, isTrue);
    });

    testWidgets('renders recent activity card with stream rows', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestableAdminDashboard());
      await tester.pump();

      expect(find.byType(AdminRecentActivityCard), findsOneWidget);
      expect(find.text('Recent activity'), findsOneWidget);
      expect(find.text('See all'), findsOneWidget);

      // Activity entries
      expect(find.text('Suresh Patel started duty'), findsOneWidget);
      expect(find.text('Anil Sharma — location flagged'), findsOneWidget);
      expect(find.text('Vijay Singh reached Shivpuri Farm'), findsOneWidget);
      expect(find.text('Prakash Rao — no update 12 min'), findsOneWidget);
    });

    testWidgets('tapping Broadcast Alert opens modal and submits', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestableAdminDashboard());
      await tester.pump();

      final broadcastBtn = find.byKey(const Key('btn-broadcast-alert'));
      expect(broadcastBtn, findsOneWidget);

      await tester.tap(broadcastBtn);
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Broadcast Alert'),
        ),
        findsOneWidget,
      );
      expect(find.text('Send Broadcast'), findsOneWidget);

      // Tap Send Broadcast
      await tester.tap(find.text('Send Broadcast'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Broadcast notification queued for delivery.'), findsOneWidget);
    });

    testWidgets('tapping Export Day Log shows feedback snackbar', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestableAdminDashboard());
      await tester.pump();

      final exportBtn = find.byKey(const Key('btn-export-day-log'));
      expect(exportBtn, findsOneWidget);

      await tester.tap(exportBtn);
      await tester.pump();

      expect(
        find.text('Exporting attendance & telemetry day log as CSV...'),
        findsOneWidget,
      );
    });

    testWidgets('refresh icon button triggers telemetry refresh and snackbar',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestableAdminDashboard());
      await tester.pump();

      await tester.tap(find.byTooltip('Refresh Data'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Dashboard telemetry refreshed.'), findsOneWidget);
    });

    testWidgets('renders 5-item admin bottom navigation bar and selects tabs',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestableAdminDashboard());
      await tester.pump();

      expect(find.byType(AdminBottomNavigationBar), findsOneWidget);
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Map'), findsOneWidget);
      expect(find.text('Team'), findsOneWidget);
      expect(find.text('Places'), findsOneWidget);
      expect(find.text('Reports'), findsOneWidget);

      // Tap Team tab
      await tester.tap(find.text('Team'));
      await tester.pump();

      // Tap Map tab
      await tester.tap(find.text('Map'));
      await tester.pump();
    });
  });
}
