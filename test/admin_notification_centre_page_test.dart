import 'package:diamond_tracking/core/theme/app_theme.dart';
import 'package:diamond_tracking/features/admin/dashboard/presentation/admin_dashboard_page.dart';
import 'package:diamond_tracking/features/admin/notifications/presentation/admin_notification_centre_page.dart';
import 'package:diamond_tracking/features/admin/notifications/presentation/controllers/admin_notification_controller.dart';
import 'package:diamond_tracking/features/admin/notifications/presentation/widgets/admin_notification_filter_chips.dart';
import 'package:diamond_tracking/features/admin/notifications/presentation/widgets/admin_notification_ticker.dart';
import 'package:diamond_tracking/features/admin/notifications/presentation/widgets/admin_notification_top_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildTestableWidget(Widget child, {ProviderContainer? container}) {
    if (container != null) {
      return UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light,
          home: child,
        ),
      );
    }
    return ProviderScope(
      child: MaterialApp(
        theme: AppTheme.light,
        home: child,
      ),
    );
  }

  group('Screen 21 AdminNotificationCentrePage Visual & Structural Tests', () {
    testWidgets('renders top bar, telemetry ticker, filter chips, and feed items', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildTestableWidget(const AdminNotificationCentrePage()),
      );
      await tester.pumpAndSettle();

      // Top Bar
      expect(find.byType(AdminNotificationTopBar), findsOneWidget);
      expect(find.text('Notifications'), findsOneWidget);
      expect(find.byKey(const Key('btn-notif-back')), findsOneWidget);
      expect(find.byKey(const Key('badge-unread-count-pill')), findsOneWidget);
      expect(find.text('4'), findsWidgets); // 4 unread items initially
      expect(find.byKey(const Key('btn-mark-all-read')), findsOneWidget);
      expect(find.text('Mark all read'), findsOneWidget);

      // Telemetry Ticker
      expect(find.byType(AdminNotificationTicker), findsOneWidget);
      expect(find.text('SYNC ENGINE: ACTIVE'), findsOneWidget);
      expect(find.text('Pune Division · Fleet Latency 1.2s'), findsOneWidget);

      // Filter Chips
      expect(find.byType(AdminNotificationFilterChips), findsOneWidget);
      expect(find.byKey(const Key('filter-chip-unread')), findsOneWidget);
      expect(find.byKey(const Key('filter-chip-all')), findsOneWidget);
      expect(find.byKey(const Key('filter-chip-duty')), findsOneWidget);
      expect(find.byKey(const Key('filter-chip-alerts')), findsOneWidget);
      expect(find.byKey(const Key('filter-chip-visits')), findsOneWidget);

      // Initial Unread feed items (4 unread items)
      expect(find.text('Location flagged as mock'), findsOneWidget);
      expect(find.text('Anil Sharma · DA-008'), findsOneWidget);
      expect(find.text('2:46 PM'), findsOneWidget);

      expect(find.text('No update for 12 minutes'), findsOneWidget);
      expect(find.text('Prakash Rao · DA-017'), findsOneWidget);

      expect(find.text('Started duty'), findsOneWidget);
      expect(find.text('Suresh Patel · DA-022'), findsOneWidget);

      expect(find.text('Arrived at Shivpuri Farm'), findsOneWidget);
      expect(find.text('Vijay Singh · DA-031'), findsOneWidget);

      // Footer
      expect(find.text('END OF EVENT LOG'), findsOneWidget);
      expect(
        find.text('Synchronized with Central Agricultural Hub. All field logs retained for 90 days.'),
        findsOneWidget,
      );
    });

    testWidgets('filter chips filter notification stream correctly', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildTestableWidget(const AdminNotificationCentrePage()),
      );
      await tester.pumpAndSettle();

      // Tap "All" chip
      await tester.tap(find.byKey(const Key('filter-chip-all')));
      await tester.pumpAndSettle();

      // All 7 items + sticky header are present
      expect(find.text('EARLIER TODAY'), findsOneWidget);
      expect(find.text('Battery below 15%'), findsOneWidget);
      expect(find.text('Meena Kulkarni · DA-045'), findsOneWidget);
      expect(find.text('Login from a new device'), findsOneWidget);
      expect(find.text('Ended duty'), findsOneWidget);

      // Tap "Duty" chip
      await tester.tap(find.byKey(const Key('filter-chip-duty')));
      await tester.pumpAndSettle();

      expect(find.text('Started duty'), findsOneWidget);
      expect(find.text('Ended duty'), findsOneWidget);
      expect(find.text('Location flagged as mock'), findsNothing);
      expect(find.text('Arrived at Shivpuri Farm'), findsNothing);

      // Tap "Visits" chip
      await tester.tap(find.byKey(const Key('filter-chip-visits')));
      await tester.pumpAndSettle();

      expect(find.text('Arrived at Shivpuri Farm'), findsOneWidget);
      expect(find.text('Started duty'), findsNothing);
      expect(find.text('Battery below 15%'), findsNothing);

      // Tap "Alerts" chip
      await tester.tap(find.byKey(const Key('filter-chip-alerts')));
      await tester.pumpAndSettle();

      expect(find.text('Location flagged as mock'), findsOneWidget);
      expect(find.text('No update for 12 minutes'), findsOneWidget);
      expect(find.text('Battery below 15%'), findsOneWidget);
      expect(find.text('Login from a new device'), findsOneWidget);
      expect(find.text('Started duty'), findsNothing);
    });

    testWidgets('tapping an unread notification tile marks it read', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        buildTestableWidget(
          const AdminNotificationCentrePage(),
          container: container,
        ),
      );
      await tester.pumpAndSettle();

      // Switch to All view so item stays visible when read
      await tester.tap(find.byKey(const Key('filter-chip-all')));
      await tester.pumpAndSettle();

      expect(container.read(adminNotificationControllerProvider).unreadCount, 4);

      // Tap first tile (notif-1)
      await tester.tap(find.byKey(const Key('notif-tile-notif-1')));
      await tester.pumpAndSettle();

      // Unread count decremented to 3
      expect(container.read(adminNotificationControllerProvider).unreadCount, 3);
      final notif1 = container
          .read(adminNotificationControllerProvider)
          .notifications
          .firstWhere((n) => n.id == 'notif-1');
      expect(notif1.isUnread, isFalse);
    });

    testWidgets('tapping Mark all read marks entire stream read and updates UI', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        buildTestableWidget(
          const AdminNotificationCentrePage(),
          container: container,
        ),
      );
      await tester.pumpAndSettle();

      expect(container.read(adminNotificationControllerProvider).unreadCount, 4);

      // Tap "Mark all read"
      await tester.tap(find.byKey(const Key('btn-mark-all-read')));
      await tester.pumpAndSettle();

      // All unread flags cleared
      expect(container.read(adminNotificationControllerProvider).unreadCount, 0);

      // In Unread filter view, empty state is shown
      expect(find.text('No notifications in this filter'), findsOneWidget);
      expect(find.byKey(const Key('badge-unread-count-pill')), findsNothing);

      // SnackBar feedback
      expect(find.text('All notifications marked as read.'), findsOneWidget);
    });

    testWidgets('AdminDashboardPage notification bell navigates to AdminNotificationCentrePage',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildTestableWidget(const AdminDashboardPage()),
      );
      await tester.pumpAndSettle();

      // Bell button exists
      expect(find.byKey(const Key('admin-notifications-btn')), findsOneWidget);

      // Tap bell icon
      await tester.tap(find.byKey(const Key('admin-notifications-btn')));
      await tester.pumpAndSettle();

      // AdminNotificationCentrePage is pushed
      expect(find.byType(AdminNotificationCentrePage), findsOneWidget);
      expect(find.text('Notifications'), findsOneWidget);

      // Tap back button
      await tester.tap(find.byKey(const Key('btn-notif-back')));
      await tester.pumpAndSettle();

      // Back on dashboard
      expect(find.byType(AdminDashboardPage), findsOneWidget);
    });
  });
}
