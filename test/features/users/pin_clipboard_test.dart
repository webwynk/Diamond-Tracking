import 'package:diamond_tracking/features/users/presentation/pin_dialog.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('a copied PIN is cleared after a minute (L78)', (
    WidgetTester tester,
  ) async {
    String? clip;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall call) async {
        if (call.method == 'Clipboard.setData') {
          clip = (call.arguments as Map<Object?, Object?>)['text'] as String?;
        } else if (call.method == 'Clipboard.getData') {
          return <String, Object?>{'text': clip};
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await copyForAMinute('PIN 123456');
    expect(clip, 'PIN 123456');
    await tester.pump(const Duration(seconds: 59));
    expect(clip, 'PIN 123456');
    await tester.pump(const Duration(seconds: 2));
    expect(clip, '');

    // Something else copied since is left alone.
    await copyForAMinute('PIN 654321');
    clip = 'a shop address';
    await tester.pump(pinClipboardTime);
    expect(clip, 'a shop address');
  });
}
