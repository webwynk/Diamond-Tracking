import 'package:diamond_tracking/core/app_version.dart';
import 'package:diamond_tracking/core/design/ds_icons.dart';
import 'package:diamond_tracking/core/design/ds_layout.dart';
import 'package:diamond_tracking/core/design/ds_status.dart';
import 'package:diamond_tracking/shared/ds/ds_button.dart';
import 'package:diamond_tracking/shared/ds/ds_cards.dart';
import 'package:diamond_tracking/shared/ds/ds_chips.dart';
import 'package:diamond_tracking/shared/ds/ds_feedback.dart';
import 'package:diamond_tracking/shared/ds/ds_field.dart';
import 'package:diamond_tracking/shared/ds/ds_frame.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Small, normal and large phones (logical pixels).
const List<Size> phones = <Size>[
  Size(360, 780),
  Size(390, 844),
  Size(430, 932),
];

Future<void> pumpOn(WidgetTester tester, Size size, Widget body) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: body)));
}

const List<DsNavItem> adminTabs = <DsNavItem>[
  DsNavItem(icon: DsIcons.home, label: 'Home'),
  DsNavItem(icon: DsIcons.map, label: 'Live'),
  DsNavItem(icon: DsIcons.bell, label: 'Requests', dot: true),
  DsNavItem(icon: DsIcons.profile, label: 'Team'),
  DsNavItem(icon: DsIcons.history, label: 'Reports'),
];

/// Every part on one page, as a screen would use them.
Widget gallery() {
  return Column(
    children: <Widget>[
      DsScreenHeader(
        title: 'My requests',
        subtitle: 'Ask the admin for attendance or leave',
        onBack: () {},
        actions: <Widget>[
          DsIconButton(
            icon: DsIcons.bell,
            label: 'Notifications',
            onPressed: () {},
            badge: 12,
          ),
        ],
      ),
      Expanded(
        child: ListView(
          padding: const EdgeInsets.all(DsSpace.gutter),
          children: <Widget>[
            DsButton(label: 'Send request', onPressed: () {}, arrow: true),
            const SizedBox(height: DsSpace.md),
            DsButton(
              label: 'Keep working',
              onPressed: () {},
              kind: DsButtonKind.secondary,
            ),
            const SizedBox(height: DsSpace.md),
            for (final DsButtonKind kind in DsButtonKind.values)
              DsButton(label: kind.name, onPressed: () {}, kind: kind),
            const DsButton(label: 'Add a photo to save', onPressed: null),
            const DsButton(
              label: 'Save',
              busyLabel: 'Saving',
              onPressed: null,
              busy: true,
            ),
            Row(
              children: <Widget>[
                DsSmallButton(label: 'Allow', onPressed: () {}),
                DsTextLink(label: 'Forgot password?', onPressed: () {}),
              ],
            ),
            const DsTextField(label: 'Store name', hint: 'Maa Tara Agro Store'),
            const DsTextField(
              label: 'New password',
              password: true,
              error: "That's not your current password.",
            ),
            const DsTextField(label: 'User ID', locked: true),
            DsTextField(
              label: 'Phone',
              prefixText: '+91',
              optional: true,
              controller: TextEditingController(),
              maxLength: 10,
            ),
            DsCodeBoxes(controller: TextEditingController(text: '391')),
            const Wrap(
              spacing: DsSpace.sm,
              children: <Widget>[
                DsRuleTick(label: '8+ characters', met: true),
                DsRuleTick(label: 'Letter and digit', met: false),
              ],
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: <Widget>[
                  DsFilterChip(
                    label: 'All',
                    selected: true,
                    count: 5,
                    onTap: () {},
                  ),
                  DsFilterChip(
                    label: 'Waiting',
                    selected: false,
                    count: 1,
                    dot: DsStatus.waiting.dot,
                    onTap: () {},
                  ),
                ],
              ),
            ),
            Wrap(
              spacing: DsSpace.sm,
              runSpacing: DsSpace.sm,
              children: <Widget>[
                for (final DsStatus s in DsStatus.values)
                  DsStatusPill(status: s, label: s.name),
                const DsTag(label: 'Optional'),
                const DsTag(label: 'Recording', status: DsStatus.present),
              ],
            ),
            DsListCard(
              children: <Widget>[
                DsListRow(
                  title: 'Maa Tara Agro Store',
                  subtitle: '8:12 AM · Barasat',
                  icon: DsIcons.camera,
                  onTap: () {},
                ),
                const DsListRow(
                  title: 'Casual leave · 17 Nov',
                  subtitle: '1 day · sent 12 Nov',
                  icon: DsIcons.history,
                  status: DsStatus.leave,
                  trailing: DsStatusPill(
                    status: DsStatus.present,
                    label: 'Approved',
                  ),
                ),
              ],
            ),
            const DsHeroCard(
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: DsStatTile(
                      value: '11h 45m',
                      label: 'Worked',
                      onDeep: true,
                    ),
                  ),
                  SizedBox(width: DsSpace.sm),
                  Expanded(
                    child: DsStatTile(
                      value: '52 km',
                      label: 'Distance',
                      onDeep: true,
                    ),
                  ),
                  SizedBox(width: DsSpace.sm),
                  Expanded(
                    child: DsStatTile(
                      value: '6',
                      label: 'Visits',
                      onDeep: true,
                    ),
                  ),
                ],
              ),
            ),
            const Row(
              children: <Widget>[
                Expanded(
                  child: DsStatTile(value: '15', label: 'Present'),
                ),
                SizedBox(width: DsSpace.sm),
                Expanded(
                  child: DsStatTile(
                    value: '2',
                    label: 'Absent',
                    status: DsStatus.absent,
                  ),
                ),
              ],
            ),
            for (final DsBannerKind kind in DsBannerKind.values)
              DsBanner(
                kind: kind,
                title: "You're offline",
                message: 'Route still recording, uploads later.',
                actionLabel: 'Turn on location',
                onAction: () {},
              ),
            DsEmptyState(
              title: 'No requests yet',
              message: 'Requests you send show here with the decision.',
              actionLabel: 'Leave request',
              onAction: () {},
            ),
            DsErrorState(message: 'No internet.', onRetry: () {}),
          ],
        ),
      ),
      DsNavBar(items: adminTabs, current: 0, onTap: (_) {}),
    ],
  );
}

void main() {
  for (final Size phone in phones) {
    testWidgets('every part fits a ${phone.width.toInt()} wide phone', (
      WidgetTester tester,
    ) async {
      await pumpOn(tester, phone, gallery());
      // Scroll through all of it, so every part is laid out and drawn.
      await tester.drag(find.byType(ListView), const Offset(0, -4000));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('a button runs once per tap, never when disabled or busy', (
    WidgetTester tester,
  ) async {
    int taps = 0;
    await pumpOn(
      tester,
      phones[1],
      Column(
        children: <Widget>[
          DsButton(label: 'Send', onPressed: () => taps++),
          const DsButton(
            label: 'Off',
            onPressed: null,
            kind: DsButtonKind.danger,
          ),
          DsButton(
            label: 'Save',
            busyLabel: 'Saving',
            busy: true,
            onPressed: () => taps++,
          ),
        ],
      ),
    );
    await tester.tap(find.text('Send'));
    await tester.tap(find.text('Off'));
    await tester.tap(find.text('Saving'));
    expect(taps, 1);
    expect(find.text('Save'), findsNothing);
  });

  testWidgets('small buttons and links are at least 48 tall to tap', (
    WidgetTester tester,
  ) async {
    await pumpOn(
      tester,
      phones[0],
      Column(
        children: <Widget>[
          DsSmallButton(label: 'Maps', onPressed: () {}),
          DsTextLink(label: 'See all', onPressed: () {}),
          DsFilterChip(label: 'All', selected: false, onTap: () {}),
        ],
      ),
    );
    expect(
      tester.getSize(find.byType(DsSmallButton)).height,
      greaterThanOrEqualTo(48),
    );
    expect(
      tester.getSize(find.byType(DsTextLink)).height,
      greaterThanOrEqualTo(48),
    );
    expect(
      tester.getSize(find.byType(DsFilterChip)).height,
      greaterThanOrEqualTo(48),
    );
  });

  testWidgets('a password field hides the text until the eye is tapped', (
    WidgetTester tester,
  ) async {
    final TextEditingController c = TextEditingController(text: 'abcd1234');
    addTearDown(c.dispose);
    await pumpOn(
      tester,
      phones[1],
      DsTextField(label: 'Password', controller: c, password: true),
    );
    bool obscured() =>
        tester.widget<TextField>(find.byType(TextField)).obscureText;
    expect(obscured(), isTrue);
    await tester.tap(find.byTooltip('Show password'));
    await tester.pump();
    expect(obscured(), isFalse);
    expect(find.byTooltip('Hide password'), findsOneWidget);
  });

  testWidgets('a field shows its error and counts its characters', (
    WidgetTester tester,
  ) async {
    final TextEditingController c = TextEditingController();
    addTearDown(c.dispose);
    await pumpOn(
      tester,
      phones[1],
      DsTextField(
        label: 'Note',
        controller: c,
        maxLength: 300,
        error: 'Write the store name.',
      ),
    );
    expect(find.text('Write the store name.'), findsOneWidget);
    expect(find.text('0 / 300'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Order taken');
    await tester.pump();
    expect(find.text('11 / 300'), findsOneWidget);
  });

  testWidgets('the code boxes take digits only, and report all 6', (
    WidgetTester tester,
  ) async {
    final TextEditingController c = TextEditingController();
    addTearDown(c.dispose);
    String? done;
    await pumpOn(
      tester,
      phones[0],
      DsCodeBoxes(controller: c, onCompleted: (String v) => done = v),
    );
    await tester.enterText(find.byType(TextField), '12a3456789');
    await tester.pump();
    expect(c.text, '123456');
    expect(done, '123456');
    for (final String d in <String>['1', '2', '3', '4', '5', '6']) {
      expect(find.text(d), findsOneWidget);
    }
  });

  testWidgets('the bottom bar shows the active label when it fits', (
    WidgetTester tester,
  ) async {
    int? tapped;
    await pumpOn(
      tester,
      phones[1],
      Align(
        alignment: Alignment.bottomCenter,
        child: DsNavBar(
          items: adminTabs,
          current: 0,
          onTap: (int i) => tapped = i,
        ),
      ),
    );
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Live'), findsNothing);
    await tester.tap(find.bySemanticsLabel('Requests, new'));
    expect(tapped, 2);
  });

  testWidgets('on a narrow phone a long active label is left out', (
    WidgetTester tester,
  ) async {
    await pumpOn(
      tester,
      phones[0],
      Align(
        alignment: Alignment.bottomCenter,
        child: DsNavBar(items: adminTabs, current: 4, onTap: (_) {}),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.bySemanticsLabel('Reports'), findsOneWidget);
    for (final Element item in find.byType(InkWell).evaluate()) {
      expect(item.size!.width, greaterThanOrEqualTo(48));
    }
  });

  testWidgets('a count badge stops at 9+', (WidgetTester tester) async {
    await pumpOn(tester, phones[1], const DsCountBadge(count: 12));
    expect(find.text('9+'), findsOneWidget);
  });

  testWidgets('a bottom sheet opens with its handle and content', (
    WidgetTester tester,
  ) async {
    await pumpOn(
      tester,
      phones[0],
      Builder(
        builder: (BuildContext context) => DsButton(
          label: 'Duty off',
          onPressed: () => showDsSheet<void>(
            context: context,
            builder: (_) => const Text('End your duty?'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Duty off'));
    await tester.pumpAndSettle();
    expect(find.text('End your duty?'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('the app version reads like the design', () {
    expect(formatAppVersion('2.0.0', '46'), '2.0.0 (46)');
    expect(formatAppVersion('2.0.0', ''), '2.0.0');
  });
}
