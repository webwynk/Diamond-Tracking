import 'package:diamond_tracking/core/theme/app_theme.dart';
import 'package:diamond_tracking/shared/widgets/error_states/error_offline_states_page.dart';
import 'package:diamond_tracking/shared/widgets/error_states/widgets/floating_undo_snackbar.dart';
import 'package:diamond_tracking/shared/widgets/error_states/widgets/gps_blocking_banner.dart';
import 'package:diamond_tracking/shared/widgets/error_states/widgets/inline_field_error.dart';
import 'package:diamond_tracking/shared/widgets/error_states/widgets/load_failure_card.dart';
import 'package:diamond_tracking/shared/widgets/error_states/widgets/offline_info_banner.dart';
import 'package:diamond_tracking/shared/widgets/error_states/widgets/realtime_disconnected_strip.dart';
import 'package:diamond_tracking/shared/widgets/error_states/widgets/sync_pending_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Individual Pattern Widget Tests', () {
    testWidgets('Pattern 1: OfflineInfoBanner renders reassurance copy and icon', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: Center(child: OfflineInfoBanner()),
          ),
        ),
      );

      expect(find.byKey(const Key('banner-offline-info')), findsOneWidget);
      expect(find.text('No internet connection'), findsOneWidget);
      expect(find.text('Your work is saved and will sync automatically.'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_off), findsOneWidget);
    });

    testWidgets('Pattern 2: SyncPendingBanner displays pending count and invokes callback', (tester) async {
      var detailsClicked = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Center(
              child: SyncPendingBanner(
                pointCount: 18,
                onDetails: () => detailsClicked = true,
              ),
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('banner-sync-pending')), findsOneWidget);
      expect(find.text('18 points waiting to sync'), findsOneWidget);

      await tester.tap(find.byKey(const Key('btn-sync-details')));
      await tester.pumpAndSettle();
      expect(detailsClicked, isTrue);
    });

    testWidgets('Pattern 3: GpsBlockingBanner renders blocking warning and invokes settings callback', (tester) async {
      var settingsClicked = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Center(
              child: GpsBlockingBanner(
                onOpenSettings: () => settingsClicked = true,
              ),
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('banner-gps-blocking')), findsOneWidget);
      expect(find.text('Location is turned off'), findsOneWidget);
      expect(find.text('Turn on location to start duty.'), findsOneWidget);

      await tester.tap(find.byKey(const Key('btn-gps-open-settings')));
      await tester.pumpAndSettle();
      expect(settingsClicked, isTrue);
    });

    testWidgets('Pattern 4: InlineFieldError displays label, value, and error warning', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: Center(
              child: InlineFieldError(
                label: 'Employee Identifier',
                value: 'DA-022',
                errorMessage: 'This employee ID is already in use.',
              ),
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('field-inline-error')), findsOneWidget);
      expect(find.text('Employee Identifier'), findsOneWidget);
      expect(find.text('DA-022'), findsOneWidget);
      expect(find.text('This employee ID is already in use.'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });

    testWidgets('Pattern 5: LoadFailureCard renders retry button with callbacks', (tester) async {
      var retryClicked = false;
      var backClicked = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Center(
              child: LoadFailureCard(
                onRetry: () => retryClicked = true,
                onGoBack: () => backClicked = true,
              ),
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('card-load-failure')), findsOneWidget);
      expect(find.text("Couldn't load this"), findsOneWidget);
      expect(find.text('Check your connection and try again.'), findsOneWidget);

      await tester.tap(find.byKey(const Key('btn-load-failure-retry')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(retryClicked, isTrue);

      await tester.tap(find.byKey(const Key('btn-load-failure-back')));
      await tester.pumpAndSettle();
      expect(backClicked, isTrue);
    });

    testWidgets('Pattern 6: RealtimeDisconnectedStrip displays animated reconnecting strip', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: Center(child: RealtimeDisconnectedStrip()),
          ),
        ),
      );

      expect(find.byKey(const Key('strip-realtime-disconnected')), findsOneWidget);
      expect(find.text('Reconnecting…'), findsOneWidget);
      expect(find.byIcon(Icons.sync), findsOneWidget);
    });

    testWidgets('Pattern 7: FloatingUndoSnackbar displays undo button and provides restored feedback', (tester) async {
      var undoClicked = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Center(
              child: FloatingUndoSnackbar(
                message: 'Employee blocked',
                onUndo: () => undoClicked = true,
              ),
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('widget-undo-snackbar')), findsOneWidget);
      expect(find.text('Employee blocked'), findsOneWidget);
      expect(find.text('UNDO'), findsOneWidget);

      await tester.tap(find.byKey(const Key('btn-snackbar-undo')));
      await tester.pump();
      expect(undoClicked, isTrue);
      expect(find.text('RESTORED'), findsOneWidget);
      expect(find.text('Action restored'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 2000));
    });
  });

  group('Screen 29: ErrorOfflineStatesPage Coordinator Tests', () {
    testWidgets('renders all 7 pattern sections, headers, and bottom navigation', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      var detailsInvoked = false;
      var gpsInvoked = false;
      var retryInvoked = false;
      var undoInvoked = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: ErrorOfflineStatesPage(
            isRealtimeSpinning: false,
            onSyncDetailsPressed: () => detailsInvoked = true,
            onGpsSettingsPressed: () => gpsInvoked = true,
            onRetryPressed: () => retryInvoked = true,
            onUndoPressed: () => undoInvoked = true,
          ),
        ),
      );

      // Verify Fixed App Bar
      expect(find.text('Error & Offline States'), findsWidgets);
      expect(find.byIcon(Icons.token_outlined), findsOneWidget);
      expect(find.byIcon(Icons.person), findsOneWidget);

      // Verify Specification Header
      expect(find.text('SPECIFICATION SHEET 29'), findsOneWidget);
      expect(find.text('DIAMOND AGRITECH'), findsOneWidget);
      expect(find.text('Telemetry and connectivity exception patterns for frontline field hardware.'), findsOneWidget);

      // Verify All 7 Patterns Present
      expect(find.byKey(const Key('banner-offline-info')), findsOneWidget);
      expect(find.byKey(const Key('banner-sync-pending')), findsOneWidget);
      expect(find.byKey(const Key('banner-gps-blocking')), findsOneWidget);
      expect(find.byKey(const Key('field-inline-error')), findsOneWidget);
      expect(find.byKey(const Key('card-load-failure')), findsOneWidget);
      expect(find.byKey(const Key('strip-realtime-disconnected')), findsOneWidget);
      expect(find.byKey(const Key('widget-undo-snackbar')), findsOneWidget);

      // Verify Bottom Navigation Bar Tabs
      expect(find.text('SPECS'), findsOneWidget);
      expect(find.text('STATES'), findsOneWidget);
      expect(find.text('TELEMETRY'), findsOneWidget);
      expect(find.text('LOGS'), findsOneWidget);

      // Verify Actions trigger callbacks
      await tester.tap(find.byKey(const Key('btn-sync-details')));
      await tester.pumpAndSettle();
      expect(detailsInvoked, isTrue);

      await tester.tap(find.byKey(const Key('btn-gps-open-settings')));
      await tester.pumpAndSettle();
      expect(gpsInvoked, isTrue);

      await tester.tap(find.byKey(const Key('btn-load-failure-retry')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(retryInvoked, isTrue);

      await tester.tap(find.byKey(const Key('btn-snackbar-undo')));
      await tester.pump();
      expect(undoInvoked, isTrue);
      await tester.pump(const Duration(milliseconds: 2000));

      // Tap on bottom navigation tab
      await tester.tap(find.text('TELEMETRY'));
      await tester.pumpAndSettle();
    });
  });
}
