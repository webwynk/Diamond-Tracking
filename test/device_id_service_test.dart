import 'package:diamond_tracking/core/utils/device_id_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

final RegExp _idShape = RegExp(r'^device_[0-9a-f]{8}(-[0-9a-f]{8}){3}$');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('makes an id the first time, in the same shape as before', () async {
    final id = await DeviceIdService.getDeviceId();

    expect(id, matches(_idShape));
  });

  test('gives the same id every time after that', () async {
    final first = await DeviceIdService.getDeviceId();
    final second = await DeviceIdService.getDeviceId();

    expect(second, first);
  });

  test('keeps the id across an app restart', () async {
    final first = await DeviceIdService.getDeviceId();

    // A restart forgets everything in memory; what the phone saved remains.
    final saved = (await SharedPreferences.getInstance()).getString(
      'device_id',
    );
    SharedPreferences.setMockInitialValues(<String, Object>{
      'device_id': saved!,
    });

    expect(await DeviceIdService.getDeviceId(), first);
  });

  test('uses the id the phone already holds', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'device_id': 'device_saved-earlier',
    });

    expect(await DeviceIdService.getDeviceId(), 'device_saved-earlier');
  });

  test('two sign-in attempts at once get one id, not two', () async {
    final both = await Future.wait([
      DeviceIdService.getDeviceId(),
      DeviceIdService.getDeviceId(),
    ]);

    expect(both[0], both[1]);
    expect(
      (await SharedPreferences.getInstance()).getString('device_id'),
      both[0],
    );
  });

  test('a different phone makes a different id', () async {
    final first = await DeviceIdService.getDeviceId();

    // A fresh install: nothing saved.
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final other = await DeviceIdService.getDeviceId();

    expect(other, isNot(first));
  });
}
