/// Build-time configuration.
///
/// Values arrive with `--dart-define-from-file=env.json`. `env.json` is
/// gitignored and `env.example.json` shows its shape. There are deliberately no
/// default values: a build without configuration must fail at startup instead
/// of quietly talking to the wrong backend.
///
/// What must never be here: the database password, the Supabase service key,
/// and Cloudinary secrets. Those live only in Supabase Edge Function secrets.
/// The Google Maps key is not here either: Android reads it from the manifest
/// (see android/app/build.gradle.kts), and it is restricted to this app's
/// package name and signing certificate in the Google Cloud console.
library;

abstract final class Env {
  const Env._();

  /// Supabase project URL, for example `https://<ref>.supabase.co`.
  ///
  /// `const` is required: a non-const `String.fromEnvironment` silently
  /// returns the default instead of the supplied value.
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');

  /// Supabase publishable key. Public by design: row-level security, not this
  /// key, protects the data.
  static const String supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );

  /// Every required key with its value.
  static const Map<String, String> required = <String, String>{
    'SUPABASE_URL': supabaseUrl,
    'SUPABASE_PUBLISHABLE_KEY': supabasePublishableKey,
  };

  /// Throws [MissingConfigException] if a required key is absent or blank,
  /// or if the Supabase URL is not an https URL.
  static void validate([Map<String, String> values = required]) {
    final List<String> missing = <String>[
      for (final MapEntry<String, String> entry in values.entries)
        if (entry.value.trim().isEmpty) entry.key,
    ];
    if (missing.isNotEmpty) {
      throw MissingConfigException(missing);
    }
    final Uri? url = Uri.tryParse(values['SUPABASE_URL'] ?? '');
    if (url == null || url.scheme != 'https' || url.host.isEmpty) {
      throw const MissingConfigException(<String>[
        'SUPABASE_URL (must be https)',
      ]);
    }
  }
}

/// Raised when build-time configuration is absent. Names keys, never values.
class MissingConfigException implements Exception {
  const MissingConfigException(this.missingKeys);

  final List<String> missingKeys;

  @override
  String toString() =>
      'Missing build configuration: ${missingKeys.join(', ')}.\n\n'
      'Run with the env file:\n'
      '  flutter run --dart-define-from-file=env.json\n\n'
      'If env.json does not exist, copy env.example.json and fill it in. '
      'env.json is gitignored and must never be committed.';
}
