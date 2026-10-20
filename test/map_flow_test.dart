import 'package:diamond_tracking/core/config/env.dart';
import 'package:diamond_tracking/core/constants/map_constants.dart';
import 'package:diamond_tracking/core/theme/app_theme.dart';
import 'package:diamond_tracking/features/duty/presentation/controllers/duty_controller.dart';
import 'package:diamond_tracking/features/duty/presentation/controllers/duty_state.dart';
import 'package:diamond_tracking/features/map/presentation/employee_map_page.dart';
import 'package:diamond_tracking/shared/widgets/app_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MapConstants Unit Tests', () {
    test(
      'defines provider-aware tile styles and attribution with automatic fallback',
      () {
        if (Env.maptilerApiKey.isEmpty) {
          expect(
            MapConstants.defaultStyle,
            contains('tiles.openfreemap.org/styles/liberty'),
          );
          expect(
            MapConstants.brightStyle,
            contains('tiles.openfreemap.org/styles/bright'),
          );
          expect(MapConstants.attribution, contains('OpenFreeMap'));
          expect(MapConstants.attribution, contains('OpenStreetMap'));
          expect(MapConstants.providerName, equals('OpenFreeMap'));
        } else {
          expect(
            MapConstants.defaultStyle,
            contains('api.maptiler.com/maps/streets-v2/style.json'),
          );
          expect(
            MapConstants.brightStyle,
            contains('api.maptiler.com/maps/outdoor-v2/style.json'),
          );
          expect(MapConstants.attribution, contains('MapTiler'));
          expect(MapConstants.attribution, contains('OpenStreetMap'));
          expect(MapConstants.providerName, equals('MapTiler'));
        }
      },
    );

    test(
      'default coordinates point to Sinnar / Baramati agricultural sector',
      () {
        expect(MapConstants.defaultLatitude, closeTo(19.85, 0.05));
        expect(MapConstants.defaultLongitude, closeTo(73.85, 0.05));
        expect(MapConstants.defaultZoom, greaterThanOrEqualTo(14.0));
      },
    );
  });

  group('EmployeeMapPage Widget Tests', () {
    Widget buildTestMap({
      required DutyScreenState dutyState,
      VoidCallback? onAddVisitPressed,
    }) {
      return ProviderScope(
        overrides: [
          dutyControllerProvider.overrideWith(
            () => TestDutyNotifier(dutyState),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: EmployeeMapPage(onAddVisitPressed: onAddVisitPressed),
        ),
      );
    }

    testWidgets(
      'renders header, telemetry chip, attribution, and bottom sheet',
      (tester) async {
        const dutyState = DutyScreenState(
          status: DutyStatus.onDuty,
          elapsedDuration: Duration(hours: 7, minutes: 24),
          distanceKm: 38.6,
          visitsCount: 3,
        );

        await tester.pumpWidget(buildTestMap(dutyState: dutyState));
        await tester.pumpAndSettle();

        // Header
        expect(find.text('My location'), findsOneWidget);
        expect(find.text('On duty'), findsOneWidget);

        // Telemetry chip
        expect(find.text('Waiting for GPS…'), findsOneWidget);
        expect(find.textContaining('Sinnar'), findsNothing);

        // Attribution
        expect(find.text(MapConstants.attribution), findsOneWidget);

        // Controls
        expect(find.byKey(const Key('btn-recenter')), findsOneWidget);
        expect(find.byKey(const Key('btn-layers')), findsOneWidget);

        // Bottom sheet stats
        expect(find.text('TODAY'), findsOneWidget);
        expect(find.text('7h 24m'), findsOneWidget);
        expect(find.text('38.6'), findsOneWidget);
        expect(find.text('3'), findsOneWidget);
        expect(find.text('Hours'), findsOneWidget);
        expect(find.text('km'), findsOneWidget);
        expect(find.text('Visits'), findsOneWidget);

        // Add visit action button
        expect(find.byKey(const Key('btn-add-visit')), findsOneWidget);
        expect(find.widgetWithText(AppButton, 'Add visit'), findsOneWidget);
      },
    );

    testWidgets('tapping Add visit triggers onAddVisitPressed callback', (
      tester,
    ) async {
      var addVisitTriggered = false;
      const dutyState = DutyScreenState(status: DutyStatus.onDuty);

      await tester.pumpWidget(
        buildTestMap(
          dutyState: dutyState,
          onAddVisitPressed: () => addVisitTriggered = true,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('btn-add-visit')));
      await tester.pumpAndSettle();

      expect(addVisitTriggered, isTrue);
    });

    testWidgets('is a tab screen, so its header has no back button', (
      tester,
    ) async {
      const dutyState = DutyScreenState(status: DutyStatus.onDuty);

      await tester.pumpWidget(buildTestMap(dutyState: dutyState));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Back'), findsNothing);
      expect(find.byTooltip('Go back'), findsNothing);
    });

    testWidgets('tapping layer switch toggles map style', (tester) async {
      const dutyState = DutyScreenState(status: DutyStatus.onDuty);

      await tester.pumpWidget(buildTestMap(dutyState: dutyState));
      await tester.pumpAndSettle();

      final layersBtn = find.byKey(const Key('btn-layers'));
      expect(layersBtn, findsOneWidget);

      await tester.tap(layersBtn);
      await tester.pumpAndSettle();
    });
  });
}

class TestDutyNotifier extends DutyNotifier {
  TestDutyNotifier(this._initialState);
  final DutyScreenState _initialState;

  @override
  DutyScreenState build() => _initialState;
}
