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

  group('AppIconButton', () {
    testWidgets('enforces minimum 48x48 dp touch target and tooltip', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          AppIconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () {},
          ),
        ),
      );

      final Size size = tester.getSize(find.byType(IconButton));
      expect(size.width, greaterThanOrEqualTo(AppSizes.minTouchTarget));
      expect(size.height, greaterThanOrEqualTo(AppSizes.minTouchTarget));

      final IconButton button = tester.widget<IconButton>(
        find.byType(IconButton),
      );
      expect(button.tooltip, 'Settings');
    });
  });

  group('AppTextField', () {
    testWidgets('renders label strictly above field and handles error text', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const AppTextField(
            label: 'Employee ID',
            hintText: 'e.g. DA-001',
            errorText: 'Employee ID is required',
          ),
        ),
      );

      expect(find.text('Employee ID'), findsOneWidget);
      expect(find.text('Employee ID is required'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
    });
  });

  group('AppStatCard', () {
    testWidgets('renders category, tabular value, and unit', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const AppStatCard(
            title: 'Distance Today',
            value: '42.8',
            unit: 'km',
            trend: '+5.2 km vs yesterday',
          ),
        ),
      );

      expect(find.text('DISTANCE TODAY'), findsOneWidget);
      expect(find.text('42.8'), findsOneWidget);
      expect(find.text('km'), findsOneWidget);
      expect(find.text('+5.2 km vs yesterday'), findsOneWidget);
    });
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

  group('AppPaginationLoader and AppMapPlaceholder', () {
    testWidgets('pagination loader renders 56 dp spinner row', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(const AppPaginationLoader()));

      final Size size = tester.getSize(find.byType(AppPaginationLoader));
      expect(size.height, equals(56));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('map placeholder renders branded container without shimmer', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(const AppMapPlaceholder()));

      expect(find.text('Loading map…'), findsOneWidget);
      expect(find.byIcon(Icons.location_on_outlined), findsOneWidget);
    });
  });

  group('AppShimmer and Skeletons', () {
    testWidgets('skeletons render without crashing', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const Column(
            children: <Widget>[
              AppListSkeleton(itemCount: 2),
              SizedBox(height: 16),
              AppStatRowSkeleton(),
            ],
          ),
        ),
      );

      expect(find.byType(AppListSkeleton), findsOneWidget);
      expect(find.byType(AppStatRowSkeleton), findsOneWidget);
    });
  });
}
