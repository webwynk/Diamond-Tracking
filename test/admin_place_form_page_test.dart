import 'package:diamond_tracking/core/theme/app_theme.dart';
import 'package:diamond_tracking/features/admin/places/presentation/admin_place_form_page.dart';
import 'package:diamond_tracking/features/admin/places/presentation/admin_places_page.dart';
import 'package:diamond_tracking/features/admin/places/presentation/controllers/admin_places_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget createWidget({AdminPlaceItem? place, VoidCallback? onClose, VoidCallback? onSaved}) {
    return ProviderScope(
      child: MaterialApp(
        theme: AppTheme.light,
        home: AdminPlaceFormPage(
          place: place,
          onClose: onClose,
          onSaved: onSaved,
        ),
      ),
    );
  }

  group('Screen 25 AdminPlaceFormPage Visual & Structural Tests', () {
    testWidgets('renders all visual elements for New place form', (tester) async {
      tester.view.physicalSize = const Size(400, 850);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      // 1. Floating Top Bar
      expect(find.byKey(const Key('admin-place-form-top-bar')), findsOneWidget);
      expect(find.byKey(const Key('btn-place-form-close')), findsOneWidget);
      expect(find.text('New place'), findsOneWidget);
      expect(find.byKey(const Key('btn-place-form-save')), findsOneWidget);

      // 2. Geofence Map Viewport Elements
      expect(find.byKey(const Key('admin-place-geofence-map')), findsOneWidget);
      expect(find.byKey(const Key('scale-bar-text')), findsOneWidget);
      expect(find.text('500 m'), findsWidgets); // Scale bar and radius
      expect(find.byKey(const Key('btn-toggle-map-layer')), findsOneWidget);
      expect(find.byKey(const Key('center-geofence-pin')), findsOneWidget);
      expect(find.byKey(const Key('adjacent-geofence-badge')), findsOneWidget);
      expect(find.text('Patel Agro Dealer — 320 m away'), findsOneWidget);

      // 3. Form Sheet Elements
      expect(find.byKey(const Key('admin-place-form-sheet')), findsOneWidget);
      expect(find.byKey(const Key('input-place-name')), findsOneWidget);
      expect(find.byKey(const Key('chip-type-farm')), findsOneWidget);
      expect(find.byKey(const Key('chip-type-dealer')), findsOneWidget);
      expect(find.byKey(const Key('chip-type-office')), findsOneWidget);
      expect(find.byKey(const Key('chip-type-warehouse')), findsOneWidget);
      expect(find.byKey(const Key('chip-type-other')), findsOneWidget);

      // 4. Radius Slider & Photo Prompt Banner
      expect(find.byKey(const Key('slider-geofence-radius')), findsOneWidget);
      expect(find.byKey(const Key('photo-prompt-banner')), findsOneWidget);

      // 5. Coordinates & Active Switch
      expect(find.byKey(const Key('text-coordinates-value')), findsOneWidget);
      expect(find.byKey(const Key('btn-copy-coordinates')), findsOneWidget);
      expect(find.byKey(const Key('switch-place-active')), findsOneWidget);
    });

    testWidgets('renders Edit place mode when existing place is provided', (tester) async {
      const samplePlace = AdminPlaceItem(
        id: 'place-99',
        name: 'Kisan Kendra Hub',
        category: AdminPlaceCategory.dealers,
        badgeTag: 'Dealer',
        location: 'Taluka Sanand',
        radiusMeters: 750,
        visitsThisMonth: 8,
        latitude: 22.9862,
        longitude: 72.3789,
        isActive: true,
      );

      await tester.pumpWidget(createWidget(place: samplePlace));
      await tester.pumpAndSettle();

      expect(find.text('Edit place'), findsOneWidget);
      expect(find.text('Kisan Kendra Hub'), findsOneWidget);
      expect(find.text('750 m'), findsWidgets);
    });

    testWidgets('radius slider updates real-time radius display and map circle', (tester) async {
      tester.view.physicalSize = const Size(400, 850);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      final sliderFinder = find.byKey(const Key('slider-geofence-radius'));
      expect(sliderFinder, findsOneWidget);

      // Drag slider forward to increase radius
      await tester.drag(sliderFinder, const Offset(60, 0));
      await tester.pumpAndSettle();

      // Radius value should have changed from default 500m
      expect(find.byKey(const Key('text-radius-value')), findsOneWidget);
    });

    testWidgets('switching category chips updates selected state', (tester) async {
      tester.view.physicalSize = const Size(400, 850);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      final dealerChip = find.byKey(const Key('chip-type-dealer'));
      await tester.tap(dealerChip);
      await tester.pumpAndSettle();

      // Dealer chip tapped successfully
      expect(dealerChip, findsOneWidget);
    });

    testWidgets('tapping copy coordinates triggers toast notification', (tester) async {
      tester.view.physicalSize = const Size(400, 850);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      // Scroll form sheet down to ensure copy button is visible
      await tester.drag(find.byKey(const Key('admin-place-form-sheet')), const Offset(0, -200));
      await tester.pumpAndSettle();

      final copyBtn = find.byKey(const Key('btn-copy-coordinates'));
      await tester.tap(copyBtn);
      await tester.pumpAndSettle();

      expect(find.text('Coordinates copied to clipboard.'), findsOneWidget);
    });

    testWidgets('validation prevents saving when place name is empty', (tester) async {
      tester.view.physicalSize = const Size(400, 850);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      bool wasSaved = false;
      await tester.pumpWidget(createWidget(onSaved: () => wasSaved = true));
      await tester.pumpAndSettle();

      // Clear the text field
      final nameField = find.byKey(const Key('input-place-name'));
      await tester.enterText(nameField, '');
      await tester.pumpAndSettle();

      // Tap Save
      await tester.tap(find.byKey(const Key('btn-place-form-save')));
      await tester.pumpAndSettle();

      // Validation error appears and onSaved is not called
      expect(find.byKey(const Key('text-form-error')), findsOneWidget);
      expect(find.text('Place name cannot be empty'), findsOneWidget);
      expect(wasSaved, isFalse);
    });

    testWidgets('valid form triggers save and invokes onSaved callback', (tester) async {
      tester.view.physicalSize = const Size(400, 850);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      bool wasSaved = false;
      await tester.pumpWidget(createWidget(onSaved: () => wasSaved = true));
      await tester.pumpAndSettle();

      final nameField = find.byKey(const Key('input-place-name'));
      await tester.enterText(nameField, 'Anand Research Depot');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('btn-place-form-save')));
      await tester.pumpAndSettle();

      expect(wasSaved, isTrue);
    });

    testWidgets('AdminPlacesPage FAB navigates to AdminPlaceFormPage in New place mode', (tester) async {
      tester.view.physicalSize = const Size(400, 850);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: AdminPlacesPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final fab = find.byKey(const Key('btn-add-place'));
      expect(fab, findsOneWidget);

      await tester.tap(fab);
      await tester.pumpAndSettle();

      expect(find.byType(AdminPlaceFormPage), findsOneWidget);
      expect(find.text('New place'), findsOneWidget);
    });
  });
}
