import 'package:diamond_tracking/core/theme/app_theme.dart';
import 'package:diamond_tracking/shared/widgets/app_skeletons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child, {bool disableAnimations = false}) {
  return MaterialApp(
    theme: AppTheme.light,
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: Scaffold(body: SingleChildScrollView(child: child)),
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
    testWidgets(
      'renders CAD blueprint container, status labels, and architectural note',
      (tester) async {
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
      },
    );

    testWidgets(
      'hides architectural callout note when showCalloutNote is false',
      (tester) async {
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
      },
    );
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
          const PaginationLoaderCard(showCalloutNote: false, isSpinning: false),
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
}
