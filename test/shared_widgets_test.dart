import 'package:diamond_tracking/core/theme/app_colors.dart';
import 'package:diamond_tracking/core/theme/app_dimens.dart';
import 'package:diamond_tracking/core/theme/app_theme.dart';
import 'package:diamond_tracking/shared/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

void main() {
  group('AppButton', () {
    testWidgets('primary variant renders with correct label and 48 dp height', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(AppButton(label: 'Submit', onPressed: () {})),
      );

      final Finder finder = find.text('Submit');
      expect(finder, findsOneWidget);

      final Size size = tester.getSize(find.byType(ElevatedButton));
      expect(size.height, greaterThanOrEqualTo(AppSizes.controlHeight));
    });

    testWidgets('loading state renders inline spinner and disables tap', (
      WidgetTester tester,
    ) async {
      bool tapped = false;
      await tester.pumpWidget(
        _wrap(
          AppButton(
            label: 'Submit',
            isLoading: true,
            loadingLabel: 'Submitting…',
            onPressed: () {
              tapped = true;
            },
          ),
        ),
      );

      expect(find.text('Submitting…'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.tap(find.byType(ElevatedButton));
      expect(tapped, isFalse);
    });

    testWidgets(
      'disabled button wraps in Tooltip when disabledReason provided',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          _wrap(
            const AppButton(
              label: 'Submit',
              onPressed: null,
              disabledReason: 'Outside duty hours (8:00 AM – 11:00 PM)',
            ),
          ),
        );

        expect(find.byType(Tooltip), findsOneWidget);
        final Tooltip tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
        expect(tooltip.message, 'Outside duty hours (8:00 AM – 11:00 PM)');
      },
    );

    testWidgets(
      'secondary, tertiary, and destructive variants render correctly',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          _wrap(
            Column(
              children: <Widget>[
                AppButton(
                  label: 'Cancel',
                  variant: AppButtonVariant.secondary,
                  onPressed: () {},
                ),
                AppButton(
                  label: 'Skip',
                  variant: AppButtonVariant.tertiary,
                  onPressed: () {},
                ),
                AppButton(
                  label: 'Block',
                  variant: AppButtonVariant.destructive,
                  onPressed: () {},
                ),
              ],
            ),
          ),
        );

        expect(find.byType(OutlinedButton), findsOneWidget);
        expect(find.byType(TextButton), findsOneWidget);
        expect(find.text('Block'), findsOneWidget);
      },
    );
  });

  group('AppStatusPill', () {
    testWidgets('enforces colour plus text label for all statuses', (
      WidgetTester tester,
    ) async {
      const List<String> statuses = <String>[
        'active',
        'stale',
        'suspect',
        'off',
        'blocked',
      ];

      for (final String status in statuses) {
        await tester.pumpWidget(_wrap(AppStatusPill(statusKey: status)));

        final String expectedLabel = AppStatusColors.labels[status]!;
        expect(find.text(expectedLabel), findsOneWidget);
      }
    });
  });

  group('AppBadge', () {
    testWidgets('formats count correctly including 99+', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          Column(children: <Widget>[AppBadge.count(5), AppBadge.count(120)]),
        ),
      );

      expect(find.text('5'), findsOneWidget);
      expect(find.text('99+'), findsOneWidget);
    });
  });

  group('AppEmptyState', () {
    testWidgets('renders headline, description, and action button', (
      WidgetTester tester,
    ) async {
      bool actionTapped = false;
      await tester.pumpWidget(
        _wrap(
          AppEmptyState.noEmployees(
            onAddEmployee: () {
              actionTapped = true;
            },
          ),
        ),
      );

      expect(find.text('No employees yet'), findsOneWidget);
      expect(find.text('Add your first team member.'), findsOneWidget);
      expect(find.text('Add employee'), findsOneWidget);

      await tester.tap(find.text('Add employee'));
      expect(actionTapped, isTrue);
    });
  });

  group('AppBanner', () {
    testWidgets('offline banner displays reassurance without retry button', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(AppBanner.offline()));

      expect(find.text('No internet connection'), findsOneWidget);
      expect(
        find.text('Your work is saved and will sync automatically.'),
        findsOneWidget,
      );
      expect(find.byType(ElevatedButton), findsNothing);
    });

    testWidgets('gpsOff banner includes action button', (
      WidgetTester tester,
    ) async {
      bool opened = false;
      await tester.pumpWidget(
        _wrap(
          AppBanner.gpsOff(
            onOpenSettings: () {
              opened = true;
            },
          ),
        ),
      );

      expect(find.text('Location is turned off'), findsOneWidget);
      expect(find.text('Open settings'), findsOneWidget);

      await tester.tap(find.text('Open settings'));
      expect(opened, isTrue);
    });
  });

  group('AppErrorView', () {
    testWidgets('invokes onRetry callback on tap', (WidgetTester tester) async {
      bool retried = false;
      await tester.pumpWidget(
        _wrap(
          AppErrorView(
            onRetry: () {
              retried = true;
            },
          ),
        ),
      );

      expect(find.text("Couldn't load this"), findsOneWidget);
      await tester.tap(find.text('Retry'));
      expect(retried, isTrue);
    });
  });

  group('AppPaginationLoader', () {
    testWidgets('pagination loader renders 56 dp spinner row', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(const AppPaginationLoader()));

      final Size size = tester.getSize(find.byType(AppPaginationLoader));
      expect(size.height, equals(56));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('AppShimmer and Skeletons', () {
    testWidgets('skeletons render without crashing', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const Column(children: <Widget>[AppListSkeleton(itemCount: 2)])),
      );

      expect(find.byType(AppListSkeleton), findsOneWidget);
    });
  });
}
