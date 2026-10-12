import 'package:diamond_tracking/core/config/env.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Env.validate', () {
    test(
      'throws MissingConfigException when run without --dart-define-from-file',
      () {
        // Tests run without dart-defines, so every key is blank. This asserts the
        // failure is LOUD. A silently misconfigured app would appear to work and
        // then fail to record a duty session, losing someone's working day.
        expect(Env.validate, throwsA(isA<MissingConfigException>()));
      },
    );

    test('names every missing key, and never leaks a value', () {
      try {
        Env.validate();
        fail('expected MissingConfigException');
      } on MissingConfigException catch (e) {
        expect(
          e.missingKeys,
          containsAll(<String>[
            'SUPABASE_URL',
            'SUPABASE_PUBLISHABLE_KEY',
            'CLOUDINARY_CLOUD_NAME',
            'CLOUDINARY_UPLOAD_PRESET',
          ]),
        );
        // The message must guide the developer without printing any secret.
        expect(e.toString(), contains('--dart-define-from-file=env.json'));
      }
    });
  });
}
