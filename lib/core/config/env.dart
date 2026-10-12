/// Build-time configuration.
///
/// Values arrive via `--dart-define-from-file=env.json`. Nothing here is
/// hardcoded and nothing here is committed: `env.json` is gitignored, and
/// `env.example.json` documents the shape.
///
/// What is deliberately ABSENT, and must stay absent:
///   - the Supabase database password
///   - the Cloudinary API key and secret (Edge Function secrets only)
///   - any map credential (MapLibre + OpenFreeMap need none)
///
/// See docs/05-SECURITY.md.
library;

/// Configuration read at compile time.
///
/// These must be `const` so the compiler can inline them; a non-const read of
/// [String.fromEnvironment] silently returns the default instead of the
/// supplied value.
abstract final class Env {
  const Env._();

  /// Supabase project URL, e.g. `https://<ref>.supabase.co`.
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');

  /// Supabase publishable (anon) key.
  ///
  /// Public by design. Row-level security, not this key, is what protects the
  /// data. See docs/05-SECURITY.md.
  static const String supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );

  /// Cloudinary cloud name. Not a secret.
  static const String cloudinaryCloudName = String.fromEnvironment(
    'CLOUDINARY_CLOUD_NAME',
  );

  /// Cloudinary upload preset name. Not a secret once uploads are signed.
  static const String cloudinaryUploadPreset = String.fromEnvironment(
    'CLOUDINARY_UPLOAD_PRESET',
  );

  /// Every key that must be present, with its value, for validation.
  static const Map<String, String> _required = <String, String>{
    'SUPABASE_URL': supabaseUrl,
    'SUPABASE_PUBLISHABLE_KEY': supabasePublishableKey,
    'CLOUDINARY_CLOUD_NAME': cloudinaryCloudName,
    'CLOUDINARY_UPLOAD_PRESET': cloudinaryUploadPreset,
  };

  /// Throws [MissingConfigException] if any key is absent or blank.
  ///
  /// Called before anything else in `main`. Failing loudly at startup is
  /// deliberate: an app that launches with no configuration would appear to
  /// work and then silently fail to record a duty session, which on this
  /// product means losing someone's working day.
  static void validate() {
    final missing = <String>[
      for (final MapEntry<String, String> entry in _required.entries)
        if (entry.value.trim().isEmpty) entry.key,
    ];

    if (missing.isNotEmpty) {
      throw MissingConfigException(missing);
    }
  }
}

/// Raised when build-time configuration is absent.
class MissingConfigException implements Exception {
  const MissingConfigException(this.missingKeys);

  /// Names of the keys that were absent or blank. Never their values.
  final List<String> missingKeys;

  @override
  String toString() =>
      'Missing build configuration: ${missingKeys.join(', ')}.\n'
      '\n'
      'Run the app with the env file:\n'
      '  flutter run --dart-define-from-file=env.json\n'
      '\n'
      'If env.json does not exist, copy env.example.json and fill it in.\n'
      'env.json is gitignored and must never be committed.';
}
