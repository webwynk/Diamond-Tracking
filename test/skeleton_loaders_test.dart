import 'package:diamond_tracking/core/theme/app_theme.dart';
import 'package:diamond_tracking/shared/widgets/app_skeletons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child, {bool disableAnimations = false}) {
  return MaterialApp(
    theme: AppTheme.light,
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: Scaffold(
        body: SingleChildScrollView(child: child),
      ),
    ),
  );
}

void main() {
  group('NotificationListSkeleton Widget Tests', () {
    testWidgets('renders grouped container with 4 default items and dividers', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const NotificationListSkeleton()));
      await tester.pump();

      expect(
        find.byKey(const Key('skeleton-notification-list')),
        findsOneWidget,
      );
      // Finds 4 avatar circles
      expect(find.byType(NotificationListSkeleton), findsOneWidget);
    });

    testWidgets('renders custom itemCount when provided', (tester) async {
      await tester.pumpWidget(
        _wrap(const NotificationListSkeleton(itemCount: 2)),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('skeleton-notification-list')),
        findsOneWidget,
      );
    });
  });

  group('DutyHistorySkeleton Widget Tests', () {
    testWidgets('renders 3 default event log card placeholders', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const DutyHistorySkeleton()));
      await tester.pump();

      expect(find.byKey(const Key('skeleton-duty-history')), findsOneWidget);
      expect(find.byType(DutyHistorySkeleton), findsOneWidget);
    });

    testWidgets('renders custom itemCount when provided', (tester) async {
      await tester.pumpWidget(_wrap(const DutyHistorySkeleton(itemCount: 5)));
      await tester.pump();

      expect(find.byKey(const Key('skeleton-duty-history')), findsOneWidget);
    });
  });

  group('EnhancedMapPlaceholder Widget Tests', () {
    testWidgets('renders CAD blueprint container, status labels, and architectural note', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const EnhancedMapPlaceholder()));
      await tester.pump();

      expect(
        find.byKey(const Key('skeleton-map-placeholder')),
        findsOneWidget,
      );
      expect(find.text('LOADING MAP…'), findsOneWidget);
      expect(find.text('TRIANGULATING SATELLITE FIX'), findsOneWidget);
      expect(find.byIcon(Icons.location_on), findsOneWidget);

      // Verify architectural note
      expect(
        find.textContaining(
          'A map never gets a shimmer skeleton — it displays this branded vector placeholder',
        ),
        findsOneWidget,
      );
    });

    testWidgets('hides architectural callout note when showCalloutNote is false', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const EnhancedMapPlaceholder(showCalloutNote: false)),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('skeleton-map-placeholder')),
        findsOneWidget,
      );
      expect(
        find.textContaining('A map never gets a shimmer skeleton'),
        findsNothing,
      );
    });
  });

  group('PaginationLoaderCard Widget Tests', () {
    testWidgets('renders 56 dp spinner card and scroll anchor note', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const PaginationLoaderCard(isSpinning: false)),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('skeleton-pagination-loader-card')),
        findsOneWidget,
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byIcon(Icons.anchor), findsOneWidget);

      // Verify architectural note
      expect(
        find.textContaining(
          'Pagination uses a 24px spinner, never a skeleton, preserving scroll anchor',
        ),
        findsOneWidget,
      );
    });

    testWidgets('hides callout note when showCalloutNote is false', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const PaginationLoaderCard(
            showCalloutNote: false,
            isSpinning: false,
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('skeleton-pagination-loader-card')),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.anchor), findsNothing);
    });
  });

  group('Screen 30: SkeletonLoadersReferencePage Coordinator Tests', () {
    testWidgets('renders all 6 geometry-matched sections, header specs, and bottom navigation', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: SkeletonLoadersReferencePage(isPaginationSpinning: false),
          ),
        ),
      );
      await tester.pump();

      // 1. App Bar Header
      expect(find.text('SYSTEM REFERENCE'), findsOneWidget);
      expect(find.byIcon(Icons.person), findsOneWidget);

      // 2. Specification Sheet Header
      expect(
        find.text('SPECIFICATION SHEET 30 • DIAMOND AGRITECH'),
        findsOneWidget,
      );
      expect(find.text('INTERACTIVE SHIMMER'), findsOneWidget);
      expect(find.text('Skeleton Loaders'), findsOneWidget);
      expect(
        find.text(
          'Progressive shimmer patterns and geometry-matched loading placeholders across field workflows.',
        ),
        findsOneWidget,
      );

      // 3. Section Titles and Subtitles
      expect(find.text('EMPLOYEE LIST'), findsOneWidget);
      expect(find.text('5 Instances • 80px Row'), findsOneWidget);

      expect(find.text('STAT CARD ROW'), findsOneWidget);
      expect(find.text('3 Metric Columns'), findsOneWidget);

      expect(find.text('NOTIFICATION LIST'), findsOneWidget);
      expect(find.text('Grouped Container'), findsOneWidget);

      expect(find.text('DUTY HISTORY'), findsOneWidget);
      expect(find.text('3 Event Log Cards'), findsOneWidget);

      expect(find.text('MAP PLACEHOLDER'), findsOneWidget);
      expect(find.text('Telemetry Exception'), findsOneWidget);

      expect(find.text('NEXT-PAGE LOADER'), findsOneWidget);
      expect(find.text('Scroll Anchor'), findsOneWidget);

      // 4. Section Placeholders
      expect(find.byType(AppListSkeleton), findsOneWidget);
      expect(find.byType(AppStatRowSkeleton), findsOneWidget);
      expect(
        find.byKey(const Key('skeleton-notification-list')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('skeleton-duty-history')), findsOneWidget);
      expect(
        find.byKey(const Key('skeleton-map-placeholder')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('skeleton-pagination-loader-card')),
        findsOneWidget,
      );

      // 5. Bottom Navigation Bar Tabs
      expect(find.text('OVERVIEW'), findsOneWidget);
      expect(find.text('TELEMETRY'), findsOneWidget);
      expect(find.text('ROUTES'), findsOneWidget);
      expect(find.text('SPECS'), findsOneWidget);

      // 6. Interactive Tab Switching
      await tester.tap(find.text('OVERVIEW'));
      await tester.pump();

      await tester.tap(find.text('TELEMETRY'));
      await tester.pump();
    });
  });
}
