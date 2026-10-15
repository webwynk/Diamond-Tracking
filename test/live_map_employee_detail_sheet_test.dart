import 'package:diamond_tracking/core/theme/app_theme.dart';
import 'package:diamond_tracking/features/admin/map/presentation/admin_live_map_employee_detail_page.dart';
import 'package:diamond_tracking/features/admin/map/presentation/controllers/admin_live_map_state.dart';
import 'package:diamond_tracking/features/admin/map/presentation/widgets/live_map_employee_detail_sheet.dart';
import 'package:diamond_tracking/features/admin/map/presentation/widgets/live_map_focused_canvas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const sureshPatel = MapOfficerItem(
    id: 'officer-on-1',
    name: 'Suresh Patel',
    employeeCode: 'DA-022',
    relativeX: 0.36,
    relativeY: 0.19,
    status: AdminOfficerStatus.onDuty,
    locationName: 'Shivpuri Agricultural Cluster',
    lastUpdated: 'Updated 8 sec ago',
    batteryPercent: 82,
    phoneNumber: '+91 98201 44556',
    dutyDuration: '7h 24m',
    dutyStartTime: '8:04 AM',
    distanceTodayKm: '38.6 km',
    visitsToday: 3,
    accuracyMeters: 6,
    speedKmh: 42,
    proximityText: 'Near Shivpuri Farm · 180 m away',
    geofenceText: 'GEOFENCE ACTIVE · 4.8 KM²',
    sectorText: 'SECTOR 04',
  );

  Widget buildTestableWidget(Widget child) {
    return ProviderScope(
      child: MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: child),
      ),
    );
  }

  group('Screen 16 LiveMapEmployeeDetailSheet Unit & Widget Tests', () {
    testWidgets('renders header with SP monogram avatar, identity, and On duty status pill',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildTestableWidget(
          const LiveMapEmployeeDetailSheet(officer: sureshPatel),
        ),
      );
      await tester.pump();

      // Avatar Monogram
      expect(find.text('SP'), findsOneWidget);

      // Identity Metadata
      expect(find.text('Suresh Patel'), findsOneWidget);
      expect(find.text('DA-022 · +91 98201 44556'), findsOneWidget);

      // Status Pill
      expect(find.byKey(const Key('badge-sheet-duty-status')), findsOneWidget);
      expect(find.text('On duty'), findsOneWidget);
    });

    testWidgets('renders status pill with appropriate styling across all officer statuses',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // 1. Stale status
      final staleOfficer = sureshPatel.copyWith(status: AdminOfficerStatus.stale);
      await tester.pumpWidget(
        buildTestableWidget(LiveMapEmployeeDetailSheet(officer: staleOfficer)),
      );
      await tester.pump();
      expect(find.text('Stale'), findsOneWidget);

      // 2. Needs check / SOS status
      final sosOfficer = sureshPatel.copyWith(
        status: AdminOfficerStatus.needsCheck,
        isSos: true,
      );
      await tester.pumpWidget(
        buildTestableWidget(LiveMapEmployeeDetailSheet(officer: sosOfficer)),
      );
      await tester.pump();
      expect(find.text('SOS Alert'), findsOneWidget);

      // 3. Off duty status
      final offDutyOfficer =
          sureshPatel.copyWith(status: AdminOfficerStatus.offDuty);
      await tester.pumpWidget(
        buildTestableWidget(LiveMapEmployeeDetailSheet(officer: offDutyOfficer)),
      );
      await tester.pump();
      expect(find.text('Off duty'), findsOneWidget);

      // 4. Blocked status
      final blockedOfficer =
          sureshPatel.copyWith(status: AdminOfficerStatus.blocked);
      await tester.pumpWidget(
        buildTestableWidget(LiveMapEmployeeDetailSheet(officer: blockedOfficer)),
      );
      await tester.pump();
      expect(find.text('Blocked'), findsOneWidget);
    });

    testWidgets('renders 2x2 telemetry stat grid with exact labels and values',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildTestableWidget(
          const LiveMapEmployeeDetailSheet(officer: sureshPatel),
        ),
      );
      await tester.pump();

      // Card 1: Duty Duration
      expect(find.byKey(const Key('stat-card-duty-duration')), findsOneWidget);
      expect(find.text('7h 24m'), findsOneWidget);
      expect(find.text('On duty since 8:04 AM'), findsOneWidget);

      // Card 2: Distance Today
      expect(find.byKey(const Key('stat-card-distance-today')), findsOneWidget);
      expect(find.text('38.6 km'), findsOneWidget);
      expect(find.text('Distance today'), findsOneWidget);

      // Card 3: Visits Today
      expect(find.byKey(const Key('stat-card-visits-today')), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('Visits today'), findsOneWidget);

      // Card 4: Battery Level
      expect(find.byKey(const Key('stat-card-battery-level')), findsOneWidget);
      expect(find.text('82%'), findsOneWidget);
      expect(find.text('Battery'), findsOneWidget);
      expect(find.byIcon(Icons.battery_charging_full_rounded), findsOneWidget);
    });

    testWidgets('renders live signal meta row and proximity strip',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildTestableWidget(
          const LiveMapEmployeeDetailSheet(officer: sureshPatel),
        ),
      );
      await tester.pump();

      // Signal Meta Row
      expect(find.text('Updated 8 sec ago'), findsOneWidget);
      expect(find.text('Accuracy 6 m'), findsOneWidget);
      expect(find.text('42 km/h'), findsOneWidget);
      expect(find.byIcon(Icons.schedule_rounded), findsOneWidget);
      expect(find.byIcon(Icons.gps_fixed_rounded), findsOneWidget);
      expect(find.byIcon(Icons.speed_rounded), findsOneWidget);

      // Proximity Strip
      expect(find.byKey(const Key('strip-sheet-proximity')), findsOneWidget);
      expect(find.text('Near Shivpuri Farm · 180 m away'), findsOneWidget);
      expect(find.byIcon(Icons.near_me_rounded), findsOneWidget);
    });

    testWidgets('tapping action buttons triggers respective callbacks',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      bool profileTapped = false;
      bool routeTapped = false;
      bool callTapped = false;

      await tester.pumpWidget(
        buildTestableWidget(
          LiveMapEmployeeDetailSheet(
            officer: sureshPatel,
            onViewProfile: () => profileTapped = true,
            onRouteView: () => routeTapped = true,
            onCallEmployee: () => callTapped = true,
          ),
        ),
      );
      await tester.pump();

      // 1. View Profile Button
      await tester.tap(find.byKey(const Key('btn-sheet-view-profile')));
      await tester.pump();
      expect(profileTapped, isTrue);

      // 2. Route Replay Button
      await tester.tap(find.byKey(const Key('btn-sheet-route-view')));
      await tester.pump();
      expect(routeTapped, isTrue);

      // 3. Call Employee Button
      await tester.tap(find.byKey(const Key('btn-sheet-call-employee')));
      await tester.pump();
      expect(callTapped, isTrue);
    });

    testWidgets('LiveMapEmployeeDetailSheet.show opens as a modal bottom sheet',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.light,
            home: Builder(
              builder: (context) {
                return Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      onPressed: () {
                        LiveMapEmployeeDetailSheet.show(
                          context,
                          officer: sureshPatel,
                        );
                      },
                      child: const Text('Open Sheet'),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pump();

      // Tap Open Sheet button
      await tester.tap(find.text('Open Sheet'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Suresh Patel'), findsOneWidget);
      expect(find.text('SP'), findsOneWidget);
      expect(find.text('DA-022 · +91 98201 44556'), findsOneWidget);
      expect(find.text('7h 24m'), findsOneWidget);
    });
  });

  group('Screen 16 LiveMapFocusedCanvas Widget Tests', () {
    testWidgets('renders focused marker, beacon tag, top controls, and geofence badge',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      bool backTapped = false;
      bool recenterTapped = false;

      await tester.pumpWidget(
        buildTestableWidget(
          SizedBox(
            height: 360,
            child: LiveMapFocusedCanvas(
              officer: sureshPatel,
              onBack: () => backTapped = true,
              onRecenter: () => recenterTapped = true,
            ),
          ),
        ),
      );
      await tester.pump();

      // Officer Marker & Spatial Beacon Tag
      expect(find.byKey(const Key('focused-marker-officer-on-1')), findsOneWidget);
      expect(find.byKey(const Key('badge-focused-officer-tag')), findsOneWidget);
      expect(find.text('SURESH P.'), findsOneWidget);

      // Top Floating Controls
      expect(find.byKey(const Key('btn-focused-map-back')), findsOneWidget);
      expect(find.byKey(const Key('badge-focused-map-sector')), findsOneWidget);
      expect(find.text('SECTOR 04'), findsOneWidget);
      expect(find.byKey(const Key('btn-focused-map-recenter')), findsOneWidget);

      // Bottom Geofence Badge
      expect(find.byKey(const Key('badge-focused-map-geofence')), findsOneWidget);
      expect(find.text('GEOFENCE ACTIVE · 4.8 KM²'), findsOneWidget);

      // Test Back Action
      await tester.tap(find.byKey(const Key('btn-focused-map-back')));
      await tester.pump();
      expect(backTapped, isTrue);

      // Test Recenter Action
      await tester.tap(find.byKey(const Key('btn-focused-map-recenter')));
      await tester.pump();
      expect(recenterTapped, isTrue);
    });
  });

  group('Screen 16 AdminLiveMapEmployeeDetailPage Full Screen Tests', () {
    testWidgets('renders complete Screen 16 layout with top bar, focused map, sheet, and bottom nav',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      bool homeNavigated = false;
      bool profileNavigated = false;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.light,
            home: AdminLiveMapEmployeeDetailPage(
              officer: sureshPatel,
              onNavigateToHome: () => homeNavigated = true,
              onViewProfile: () => profileNavigated = true,
            ),
          ),
        ),
      );
      await tester.pump();

      // Top Header
      expect(find.text('DIAMOND AGRITECH'), findsOneWidget);
      expect(find.text('Live Map Telemetry'), findsOneWidget);

      // Upper Map
      expect(find.byType(LiveMapFocusedCanvas), findsOneWidget);
      expect(find.text('SECTOR 04'), findsOneWidget);
      expect(find.text('SURESH P.'), findsOneWidget);

      // Lower Sheet
      expect(find.byType(LiveMapEmployeeDetailSheet), findsOneWidget);
      expect(find.text('Suresh Patel'), findsOneWidget);
      expect(find.text('7h 24m'), findsOneWidget);
      expect(find.text('38.6 km'), findsOneWidget);

      // Tap View Profile
      await tester.tap(find.byKey(const Key('btn-sheet-view-profile')));
      await tester.pump();
      expect(profileNavigated, isTrue);

      // Bottom Navigation: Tap Home
      await tester.tap(find.byKey(const Key('admin-nav-home')));
      await tester.pump();
      expect(homeNavigated, isTrue);
    });
  });
}
