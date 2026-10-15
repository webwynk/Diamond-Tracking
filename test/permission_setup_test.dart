import 'package:diamond_tracking/core/services/permission_service.dart';
import 'package:diamond_tracking/core/theme/app_theme.dart';
import 'package:diamond_tracking/features/onboarding/presentation/controllers/permission_controller.dart';
import 'package:diamond_tracking/features/onboarding/presentation/controllers/permission_state.dart';
import 'package:diamond_tracking/features/onboarding/presentation/permission_setup_page.dart';
import 'package:diamond_tracking/shared/widgets/app_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class MockPermissionService implements PermissionService {
  bool locationGranted = false;
  bool backgroundGranted = false;
  bool batteryOptimizationIgnored = false;
  bool openSettingsCalled = false;

  @override
  Future<bool> isLocationGranted() async => locationGranted;

  @override
  Future<bool> isBackgroundLocationGranted() async => backgroundGranted;

  @override
  Future<bool> isBatteryOptimizationIgnored() async => batteryOptimizationIgnored;

  @override
  Future<bool> requestLocation() async {
    locationGranted = true;
    return true;
  }

  @override
  Future<bool> requestBackgroundLocation() async {
    backgroundGranted = true;
    return true;
  }

  @override
  Future<bool> requestIgnoreBatteryOptimizations() async {
    batteryOptimizationIgnored = true;
    return true;
  }

  @override
  Future<bool> openAppSettings() async {
    openSettingsCalled = true;
    return true;
  }
}

void main() {
  group('PermissionSetupState Unit Tests', () {
    test('default state has all requirements false and allRequirementsSatisfied is false', () {
      const state = PermissionSetupState();
      expect(state.isLocationGranted, isFalse);
      expect(state.isBackgroundGranted, isFalse);
      expect(state.isBatteryOptimizationIgnored, isFalse);
      expect(state.isLoading, isFalse);
      expect(state.allRequirementsSatisfied, isFalse);
    });

    test('allRequirementsSatisfied is true only when all 3 flags are true', () {
      const state1 = PermissionSetupState(isLocationGranted: true);
      expect(state1.allRequirementsSatisfied, isFalse);

      const state2 = PermissionSetupState(
        isLocationGranted: true,
        isBackgroundGranted: true,
      );
      expect(state2.allRequirementsSatisfied, isFalse);

      const state3 = PermissionSetupState(
        isLocationGranted: true,
        isBackgroundGranted: true,
        isBatteryOptimizationIgnored: true,
      );
      expect(state3.allRequirementsSatisfied, isTrue);
    });

    test('copyWith updates specific fields correctly', () {
      const original = PermissionSetupState();
      final updated = original.copyWith(
        isLocationGranted: true,
        isBackgroundGranted: true,
      );
      expect(updated.isLocationGranted, isTrue);
      expect(updated.isBackgroundGranted, isTrue);
      expect(updated.isBatteryOptimizationIgnored, isFalse);
    });

    test('value equality and hashCode behave correctly', () {
      const a = PermissionSetupState(isLocationGranted: true);
      const b = PermissionSetupState(isLocationGranted: true);
      const c = PermissionSetupState(isLocationGranted: false);

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
    });
  });

  group('PermissionNotifier Unit Tests', () {
    test('loads initial permission status from service on build', () async {
      final mock = MockPermissionService()..locationGranted = true;
      final container = ProviderContainer(
        overrides: [
          permissionServiceProvider.overrideWithValue(mock),
        ],
      );
      addTearDown(container.dispose);

      // Keep provider subscribed and await microtask
      final sub = container.listen(permissionControllerProvider, (_, _) {});
      await Future<void>.delayed(Duration.zero);

      final state = container.read(permissionControllerProvider);
      expect(state.isLocationGranted, isTrue);
      expect(state.isBackgroundGranted, isFalse);
      expect(state.isBatteryOptimizationIgnored, isFalse);
      expect(state.isLoading, isFalse);
      sub.close();
    });

    test('requestLocation updates location flag and refreshes state', () async {
      final mock = MockPermissionService();
      final container = ProviderContainer(
        overrides: [
          permissionServiceProvider.overrideWithValue(mock),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(permissionControllerProvider.notifier);
      await container.pump();

      expect(container.read(permissionControllerProvider).isLocationGranted, isFalse);

      final granted = await notifier.requestLocation();
      expect(granted, isTrue);
      expect(container.read(permissionControllerProvider).isLocationGranted, isTrue);
    });

    test('requestBackgroundLocation updates background flag', () async {
      final mock = MockPermissionService();
      final container = ProviderContainer(
        overrides: [
          permissionServiceProvider.overrideWithValue(mock),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(permissionControllerProvider.notifier);
      await container.pump();

      final granted = await notifier.requestBackgroundLocation();
      expect(granted, isTrue);
      expect(container.read(permissionControllerProvider).isBackgroundGranted, isTrue);
    });

    test('requestBatteryOptimization updates battery flag', () async {
      final mock = MockPermissionService();
      final container = ProviderContainer(
        overrides: [
          permissionServiceProvider.overrideWithValue(mock),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(permissionControllerProvider.notifier);
      await container.pump();

      final ignored = await notifier.requestBatteryOptimization();
      expect(ignored, isTrue);
      expect(container.read(permissionControllerProvider).isBatteryOptimizationIgnored, isTrue);
    });
  });

  group('PermissionSetupPage Widget Tests', () {
    Widget buildTestApp({
      required MockPermissionService mockService,
      VoidCallback? onCompleted,
      VoidCallback? onBackPressed,
    }) {
      return ProviderScope(
        overrides: [
          permissionServiceProvider.overrideWithValue(mockService),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: PermissionSetupPage(
            onCompleted: onCompleted,
            onBackPressed: onBackPressed,
          ),
        ),
      );
    }

    testWidgets('renders top bar, explanatory text, and 3 cards', (tester) async {
      final mock = MockPermissionService();
      await tester.pumpWidget(buildTestApp(mockService: mock));
      await tester.pumpAndSettle();

      expect(find.text('Before You Start'), findsOneWidget);
      expect(
        find.text('Duty tracking needs these three settings. We only record your location while you are on duty.'),
        findsOneWidget,
      );
      expect(find.text('Location access'), findsOneWidget);
      expect(find.text('Allow all the time'), findsOneWidget);
      expect(find.text('Disable battery saver'), findsOneWidget);
      expect(find.textContaining('On Xiaomi, Oppo, Vivo and Realme'), findsOneWidget);

      // Continue button should be disabled initially
      final continueBtn = tester.widget<AppButton>(find.byKey(const Key('btn-continue')));
      expect(continueBtn.onPressed, isNull);
      expect(find.text('Complete all three steps to continue.'), findsWidgets);
    });

    testWidgets('tapping Allow on Card 1 requests location and transitions focus', (tester) async {
      final mock = MockPermissionService();
      await tester.pumpWidget(buildTestApp(mockService: mock));
      await tester.pumpAndSettle();

      // Tap Allow on Card 1
      final allowButtons = find.widgetWithText(ElevatedButton, 'Allow');
      expect(allowButtons, findsNWidgets(2)); // Card 1 and Card 2 both have 'Allow'

      await tester.tap(allowButtons.first);
      await tester.pumpAndSettle();

      expect(mock.locationGranted, isTrue);
      // Location access should now display 'Granted'
      expect(find.text('Granted'), findsOneWidget);
    });

    testWidgets('when all 3 prerequisites granted, Continue button is enabled and completes', (tester) async {
      final mock = MockPermissionService()
        ..locationGranted = true
        ..backgroundGranted = true
        ..batteryOptimizationIgnored = true;

      var completedCalled = false;
      await tester.pumpWidget(buildTestApp(
        mockService: mock,
        onCompleted: () => completedCalled = true,
      ));
      await tester.pumpAndSettle();

      // All 3 should show checkmarks
      expect(find.byIcon(Icons.check_circle), findsNWidgets(3));
      expect(find.text('All requirements satisfied. You are ready to start.'), findsOneWidget);

      final continueBtn = tester.widget<AppButton>(find.byKey(const Key('btn-continue')));
      expect(continueBtn.onPressed, isNotNull);

      await tester.tap(find.byKey(const Key('btn-continue')));
      await tester.pumpAndSettle();

      expect(completedCalled, isTrue);
    });

    testWidgets('tapping Open on Card 3 shows guidance dialog', (tester) async {
      final mock = MockPermissionService()
        ..locationGranted = true
        ..backgroundGranted = true;

      await tester.pumpWidget(buildTestApp(mockService: mock));
      await tester.pumpAndSettle();

      final openBtn = find.widgetWithText(OutlinedButton, 'Open');
      expect(openBtn, findsOneWidget);

      await tester.tap(openBtn);
      await tester.pumpAndSettle();

      // Dialog should be presented
      expect(find.text('Battery Optimization'), findsOneWidget);
      expect(find.textContaining('Aggressive battery savers'), findsOneWidget);
      expect(find.text('Proceed'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      // Tap Proceed
      await tester.tap(find.text('Proceed'));
      await tester.pumpAndSettle();

      expect(mock.batteryOptimizationIgnored, isTrue);
    });
  });
}
