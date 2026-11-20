import 'package:diamond_tracking/core/config/env.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a build with no configuration fails at startup', () {
    // Tests run without --dart-define, so the real values are empty.
    expect(Env.validate, throwsA(isA<MissingConfigException>()));
  });

  test('names every missing key', () {
    try {
      Env.validate(<String, String>{
        'SUPABASE_URL': '',
        'SUPABASE_PUBLISHABLE_KEY': ' ',
      });
      fail('should throw');
    } on MissingConfigException catch (e) {
      expect(e.missingKeys, <String>[
        'SUPABASE_URL',
        'SUPABASE_PUBLISHABLE_KEY',
      ]);
    }
  });

  test('rejects a non-https Supabase URL', () {
    expect(
      () => Env.validate(<String, String>{
        'SUPABASE_URL': 'http://example.supabase.co',
        'SUPABASE_PUBLISHABLE_KEY': 'key',
      }),
      throwsA(isA<MissingConfigException>()),
    );
  });

  test('accepts complete configuration', () {
    Env.validate(<String, String>{
      'SUPABASE_URL': 'https://abc.supabase.co',
      'SUPABASE_PUBLISHABLE_KEY': 'sb_publishable_x',
    });
  });

  test('the error message never contains values', () {
    const MissingConfigException e = MissingConfigException(<String>[
      'SUPABASE_URL',
    ]);
    expect(e.toString(), contains('SUPABASE_URL'));
    expect(e.toString(), contains('env.json'));
  });
}
