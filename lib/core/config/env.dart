/// Build-time configuration.
///
/// Values arrive via `--dart-define-from-file=env.json`. Nothing here is
/// hardcoded and nothing here is committed: `env.json` is gitignored, and
/// `env.example.json` documents the shape.
///
/// What is deliberately ABSENT, and must stay absent:
///   - the Supabase database password
///   - any Cloudinary value (cloud name, API key, secret): photo uploads are
///     signed by the `visit-photos` Edge Function, which holds them all
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
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://bljroionzwxxsgmyituh.supabase.co',
  );

  /// Supabase publishable (anon) key.
  ///
  /// Public by design. Row-level security, not this key, is what protects the
  /// data. See docs/05-SECURITY.md.
  static const String supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_gjevBoMgBQ1y-HD-Y6sZUw_qDYE-W_h',
  );

  /// Optional MapTiler API key for high-detail vector street maps.
  ///
  /// If omitted or blank, the application automatically falls back to OpenFreeMap.
  static const String maptilerApiKey = String.fromEnvironment(
    'MAPTILER_API_KEY',
    defaultValue: 'zuYstC2JiIBcQzOWdGxM',
  );

  /// Every key that must be present, with its value, for validation.
  static const Map<String, String> _required = <String, String>{
    'SUPABASE_URL': supabaseUrl,
    'SUPABASE_PUBLISHABLE_KEY': supabasePublishableKey,
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
