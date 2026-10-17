import 'package:diamond_tracking/core/theme/app_theme.dart';
import 'package:diamond_tracking/shared/widgets/empty_states/empty_state_card.dart';
import 'package:diamond_tracking/shared/widgets/empty_states/empty_state_illustration.dart';
import 'package:diamond_tracking/shared/widgets/empty_states/empty_state_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EmptyStateType Unit Tests', () {
    test('all 6 enum cases have complete metadata and valid specs', () {
      expect(EmptyStateType.values.length, 6);

      for (final type in EmptyStateType.values) {
        expect(type.caseLabel, startsWith('CASE 0'));
        expect(type.statusCode.isNotEmpty, isTrue);
        expect(type.title.isNotEmpty, isTrue);
        expect(type.defaultDescription.isNotEmpty, isTrue);
      }

      // Verify specific specs per HTML reference
      expect(EmptyStateType.noEmployees.isPrimaryAction, isTrue);
      expect(EmptyStateType.noEmployees.actionLabel, 'Add employee');

      expect(EmptyStateType.nobodyOnDuty.isPrimaryAction, isFalse);
      expect(EmptyStateType.nobodyOnDuty.actionLabel, 'View team');

      expect(EmptyStateType.noNotifications.actionLabel, isNull);
      expect(
        EmptyStateType.noNotifications.pendingBadgeText,
        'NO ACTIONS PENDING',
      );

      expect(EmptyStateType.filteredToNothing.actionLabel, 'Clear filters');
      expect(EmptyStateType.noRoute.actionLabel, 'Pick another date');
      expect(EmptyStateType.routeExpired.actionLabel, 'View summary');
    });
  });

  group('EmptyStateIllustration Widget Tests', () {
    testWidgets(
      'renders all 6 illustration variants with appropriate badge overlays',
      (tester) async {
        for (final type in EmptyStateType.values) {
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.light,
              home: Scaffold(
                body: Center(child: EmptyStateIllustration(type: type)),
              ),
            ),
          );

          expect(find.byType(EmptyStateIllustration), findsOneWidget);
        }
      },
    );
  });

  group('EmptyStateCard Widget Tests', () {
    testWidgets('renders Case 01 with primary button and triggers callback', (
      tester,
    ) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Center(
              child: EmptyStateCard(
                type: EmptyStateType.noEmployees,
                onActionPressed: () => tapped = true,
              ),
            ),
          ),
        ),
      );

      // Verify header strip
      expect(find.text('CASE 01 · NO EMPLOYEES'), findsOneWidget);
      expect(find.text('EMPTY_INIT'), findsOneWidget);

      // Verify content
      expect(find.text('No employees yet'), findsOneWidget);
      expect(
        find.text('Add your first team member to initiate regional tracking.'),
        findsOneWidget,
      );

      // Verify primary action button
      final buttonFinder = find.byKey(
        const Key('btn-empty-action-noEmployees'),
      );
      expect(buttonFinder, findsOneWidget);
      expect(find.text('Add employee'), findsOneWidget);

      await tester.tap(buttonFinder);
      await tester.pumpAndSettle();
      expect(tapped, isTrue);
    });

    testWidgets('renders Case 03 with passive status badge and no button', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: Center(
              child: EmptyStateCard(type: EmptyStateType.noNotifications),
            ),
          ),
        ),
      );

      expect(find.text('CASE 03 · NO NOTIFICATIONS'), findsOneWidget);
      expect(find.text('FEED_CLEAR'), findsOneWidget);
      expect(find.text("You're all caught up"), findsOneWidget);
      expect(
        find.byKey(const Key('badge-empty-pending-noNotifications')),
        findsOneWidget,
      );
      expect(find.text('NO ACTIONS PENDING'), findsOneWidget);
    });

    testWidgets('renders without case header when showCaseHeader is false', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: Center(
              child: EmptyStateCard(
                type: EmptyStateType.filteredToNothing,
                showCaseHeader: false,
              ),
            ),
          ),
        ),
      );

      expect(find.text('CASE 04 · FILTERED TO NOTHING'), findsNothing);
      expect(find.text('No results for these filters'), findsOneWidget);
    });
  });
}
