import 'package:diamond_tracking/core/theme/app_theme.dart';
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
    testWidgets(
      'Pattern 1: OfflineInfoBanner renders reassurance copy and icon',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: const Scaffold(body: Center(child: OfflineInfoBanner())),
          ),
        );

        expect(find.byKey(const Key('banner-offline-info')), findsOneWidget);
        expect(find.text('No internet connection'), findsOneWidget);
        expect(
          find.text('Your work is saved and will sync automatically.'),
          findsOneWidget,
        );
        expect(find.byIcon(Icons.cloud_off), findsOneWidget);
      },
    );

    testWidgets(
      'Pattern 2: SyncPendingBanner displays pending count and invokes callback',
      (tester) async {
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
      },
    );

    testWidgets(
      'Pattern 3: GpsBlockingBanner renders blocking warning and invokes settings callback',
      (tester) async {
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
      },
    );

    testWidgets(
      'Pattern 4: InlineFieldError displays label, value, and error warning',
      (tester) async {
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
        expect(
          find.text('This employee ID is already in use.'),
          findsOneWidget,
        );
        expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
        expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
      },
    );

    testWidgets(
      'Pattern 5: LoadFailureCard renders retry button with callbacks',
      (tester) async {
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
        expect(
          find.text('Check your connection and try again.'),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const Key('btn-load-failure-retry')));
        await tester.pump(const Duration(milliseconds: 100));
        expect(retryClicked, isTrue);

        await tester.tap(find.byKey(const Key('btn-load-failure-back')));
        await tester.pumpAndSettle();
        expect(backClicked, isTrue);
      },
    );

    testWidgets(
      'Pattern 6: RealtimeDisconnectedStrip displays animated reconnecting strip',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: const Scaffold(
              body: Center(child: RealtimeDisconnectedStrip()),
            ),
          ),
        );

        expect(
          find.byKey(const Key('strip-realtime-disconnected')),
          findsOneWidget,
        );
        expect(find.text('Reconnecting…'), findsOneWidget);
        expect(find.byIcon(Icons.sync), findsOneWidget);
      },
    );

    testWidgets(
      'Pattern 7: FloatingUndoSnackbar displays undo button and provides restored feedback',
      (tester) async {
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
      },
    );
  });
}
