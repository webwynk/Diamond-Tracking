import 'package:diamond_tracking/features/tracking/domain/phone_maker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test("the phone's maker and brand pick the steps", () {
    PhoneMaker? of(String manufacturer, [String brand = '']) =>
        PhoneMaker.fromBuild(manufacturer: manufacturer, brand: brand);
    expect(of('Xiaomi', 'Redmi'), PhoneMaker.xiaomi);
    expect(of('Xiaomi', 'POCO'), PhoneMaker.xiaomi);
    expect(of('vivo', 'vivo'), PhoneMaker.vivo);
    expect(of('vivo', 'iQOO'), PhoneMaker.vivo);
    expect(of('OPPO', 'OPPO'), PhoneMaker.oppo);
    expect(of('OnePlus', 'OnePlus'), PhoneMaker.oppo);
    expect(of('realme', 'realme'), PhoneMaker.realme);
    expect(of('samsung', 'samsung'), PhoneMaker.samsung);
    expect(of('motorola', 'motorola'), PhoneMaker.motorola);
    expect(of('TECNO MOBILE LIMITED', 'TECNO'), PhoneMaker.tecno);
    expect(of('Google', 'google'), isNull);
    expect(PhoneMaker.fromBuild(), isNull);
  });

  test('every maker has steps; "lock in Recent apps" opens nothing', () {
    for (final PhoneMaker m in PhoneMaker.values) {
      expect(m.steps, isNotEmpty, reason: m.name);
      expect(m.title, '${m.name} phone settings');
      for (final PhoneStep s in m.steps) {
        if (s.title.startsWith('Lock')) expect(s.page, isNull);
      }
    }
  });
}
