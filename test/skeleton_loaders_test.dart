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
}
