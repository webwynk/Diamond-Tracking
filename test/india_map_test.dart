import 'package:diamond_tracking/core/constants/map_constants.dart';
import 'package:diamond_tracking/core/theme/app_theme.dart';
import 'package:diamond_tracking/shared/widgets/india_map.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('IndiaMap bounds', () {
    test('cover every part of India, including the island groups', () {
      const places = <String, (double, double)>{
        'Delhi': (28.61, 77.21),
        'Mumbai': (19.07, 72.87),
        'Chennai': (13.08, 80.27),
        'Kolkata': (22.57, 88.36),
        'Guwahati': (26.14, 91.74),
        'Leh': (34.15, 77.58),
        'Kanyakumari': (8.08, 77.54),
        'Bhuj (far west)': (23.25, 69.67),
        'Tawang (far east)': (27.59, 91.86),
        'Port Blair (Andaman)': (11.62, 92.73),
        'Great Nicobar (far south)': (6.85, 93.92),
        'Kavaratti (Lakshadweep)': (10.57, 72.64),
      };
      for (final entry in places.entries) {
        expect(
          IndiaMap.contains(entry.value.$1, entry.value.$2),
          isTrue,
          reason: entry.key,
        );
      }
    });

    test('exclude places outside India', () {
      const outside = <String, (double, double)>{
        'London': (51.5, -0.12),
        'Dubai': (25.2, 55.27),
        'Bangkok': (13.75, 100.5),
        'Sydney': (-33.87, 151.2),
      };
      for (final entry in outside.entries) {
        expect(
          IndiaMap.contains(entry.value.$1, entry.value.$2),
          isFalse,
          reason: entry.key,
        );
      }
    });

    test(
      'the starting centre is inside the bounds and the zoom range is sane',
      () {
        expect(
          IndiaMap.contains(
            IndiaMap.center.latitude,
            IndiaMap.center.longitude,
          ),
          isTrue,
        );
        expect(IndiaMap.minZoom, lessThan(IndiaMap.initialZoom));
        expect(IndiaMap.initialZoom, lessThan(IndiaMap.maxZoom));
      },
    );
  });

  testWidgets(
    'shows the placeholder and the mandatory attribution when no native map exists',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: SizedBox(width: 400, height: 600, child: IndiaMap()),
          ),
        ),
      );

      expect(find.byKey(const Key('india-map-placeholder')), findsOneWidget);
      expect(find.byKey(const Key('india-map-attribution')), findsOneWidget);
      expect(find.text(MapConstants.attribution), findsOneWidget);
    },
  );

  test(
    'recentering with no map controller does nothing and does not throw',
    () async {
      await IndiaMap.recenter(null);
    },
  );
}
