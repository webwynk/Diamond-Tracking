import 'package:diamond_tracking/core/links/open_link.dart';
import 'package:diamond_tracking/core/time/clock_providers.dart';
import 'package:diamond_tracking/features/auth/domain/auth_status.dart';
import 'package:diamond_tracking/features/requests/application/requests_providers.dart';
import 'package:diamond_tracking/features/visits/application/visits_providers.dart';
import 'package:diamond_tracking/features/visits/data/visit_outbox.dart';
import 'package:diamond_tracking/features/visits/presentation/add_visit_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';
import '../../support/pump.dart';

void main() {
  // Friday 20 Nov 2026, 1:30 PM IST.
  final DateTime now = DateTime.utc(2026, 11, 20, 8);
  const SignedIn employee = SignedIn(
    userId: 'u',
    role: AppRole.employee,
    mustChangePassword: false,
  );

  late FakeVisitsRepository visits;
  late FakePhotoPicker picker;
  late FakeLocation location;
  late VisitOutbox outbox;
  late int settingsOpened;
  setUp(() {
    visits = FakeVisitsRepository();
    picker = FakePhotoPicker();
    location = FakeLocation();
    outbox = tempOutbox();
    settingsOpened = 0;
  });

  Future<void> open(WidgetTester tester, {Size? size}) async {
    tester.view.physicalSize = size ?? const Size(1080, 4000);
    tester.view.devicePixelRatio = size == null ? 2 : 3;
    addTearDown(tester.view.reset);
    await pumpPushed(
      tester,
      const AddVisitPage(dayId: 5),
      status: employee,
      visits: visits,
      outbox: outbox,
      overrides: <Override>[
        photoPickerProvider.overrideWithValue(picker),
        currentLocationProvider.overrideWithValue(location),
        serverClockProvider.overrideWithValue(FixedClock(now).clock),
        openAppSettingsProvider.overrideWithValue(() async {
          settingsOpened++;
          return true;
        }),
      ],
    );
  }

  testWidgets('the title line shows the day and the place', (
    WidgetTester tester,
  ) async {
    await open(tester);
    expect(find.text('New visit'), findsOneWidget);
    expect(find.text('Friday, 20 Nov · 22.50000, 88.30000'), findsOneWidget);
    expect(find.text('Camera · 1:30 PM'), findsOneWidget);
  });

  testWidgets('a blocked camera says so, opens settings, or uses gallery', (
    WidgetTester tester,
  ) async {
    picker.cameraBlocked = true;
    await open(tester);
    expect(find.text('Camera is blocked'), findsOneWidget);
    await tester.tap(find.text('Open settings'));
    await tester.pumpAndSettle();
    expect(settingsOpened, 1);

    await tester.tap(find.text('Use gallery'));
    await tester.pumpAndSettle();
    expect(find.text('Camera is blocked'), findsNothing);
    expect(find.text('No place saved.'), findsOneWidget);
    // No "Take photo" while the camera is still blocked.
    expect(find.text('Take photo'), findsNothing);
  });

  testWidgets('quick words fill the note', (WidgetTester tester) async {
    await open(tester);
    await tester.tap(find.text('+ Order taken'));
    await tester.pump();
    await tester.tap(find.text('+ Visit again'));
    await tester.pump();
    final TextField note = tester.widget<TextField>(
      find.byType(TextField).at(1),
    );
    expect(note.controller!.text, 'Order taken. Visit again');
    expect(find.text('24 / 300'), findsOneWidget);
  });

  testWidgets('remove the photo, then retake it', (WidgetTester tester) async {
    await open(tester);
    await tester.tap(find.bySemanticsLabel('Remove photo'));
    await tester.pumpAndSettle();
    expect(find.text('Take the dealer photo'), findsOneWidget);
    await tester.tap(find.text('Take photo'));
    await tester.pumpAndSettle();
    expect(find.text('Location saved'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Retake photo'));
    await tester.pumpAndSettle();
    expect(picker.picks, hasLength(3));
    expect(location.calls, 3);
  });

  testWidgets('a gallery photo can switch to the camera', (
    WidgetTester tester,
  ) async {
    picker.cancelCamera = true;
    await open(tester);
    await tester.tap(find.text('Gallery'));
    await tester.pumpAndSettle();
    expect(find.text('Friday, 20 Nov · photo from gallery'), findsOneWidget);
    picker.cancelCamera = false;
    await tester.tap(find.text('Take photo'));
    await tester.pumpAndSettle();
    expect(find.text('No place saved.'), findsNothing);
    expect(find.text('Location saved'), findsOneWidget);
  });

  for (final double width in <double>[360, 390, 430]) {
    for (final bool blocked in <bool>[false, true]) {
      testWidgets(
        'add visit fits a $width wide phone${blocked ? ' (blocked)' : ''}',
        (WidgetTester tester) async {
          picker.cameraBlocked = blocked;
          location.accuracyM = 1500;
          await open(tester, size: Size(width * 3, 720 * 3));
          await tester.enterText(
            find.byType(TextField).first,
            'Sri Sri Maa Annapurna Krishi Seva Kendra',
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
