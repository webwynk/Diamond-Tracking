import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/failure_log.dart';

/// Keeps the signed-in session in the phone's encrypted key store instead of
/// plain preferences (docs/05 section 7, docs/08 section 9).
///
/// The session holds a refresh token, which is as good as a password until it
/// is revoked. Plain preferences are readable on a rooted phone and in some
/// backups; this storage is encrypted with a key that never leaves the phone.
///
/// A session that cannot be read (the key was lost, for example after a restore
/// onto another phone) is treated as "not signed in": the person signs in again
/// rather than the app failing to start.
class SecureSessionStorage extends LocalStorage {
  SecureSessionStorage({
    required String supabaseUrl,
    FlutterSecureStorage? storage,
  }) : _storage = storage ?? const FlutterSecureStorage(),
       // The key the standard storage used, so the leftover copy can be removed.
       _legacyKey =
           'sb-${Uri.parse(supabaseUrl).host.split('.').first}-auth-token';

  static const String _key = 'diamond_supabase_session';

  final FlutterSecureStorage _storage;
  final String _legacyKey;

  @override
  Future<void> initialize() async {
    // Sessions saved by earlier versions sit in plain preferences. Remove that
    // copy now: the person signs in once more, and no token stays readable.
    try {
      final preferences = await SharedPreferences.getInstance();
      if (preferences.containsKey(_legacyKey)) {
        await preferences.remove(_legacyKey);
      }
    } on Object catch (e, st) {
      logFailure(
        'SecureSessionStorage: could not clear the old session',
        e,
        st,
      );
    }
  }

  @override
  Future<bool> hasAccessToken() async => (await accessToken()) != null;

  @override
  Future<String?> accessToken() async {
    try {
      return await _storage.read(key: _key);
    } on Object catch (e, st) {
      logFailure('SecureSessionStorage: could not read the session', e, st);
      await _forget();
      return null;
    }
  }

  @override
  Future<void> persistSession(String persistSessionString) async {
    try {
      await _storage.write(key: _key, value: persistSessionString);
    } on Object catch (e, st) {
      // Not being able to save means the person signs in again next time. It
      // must not break the sign-in that is happening now.
      logFailure('SecureSessionStorage: could not save the session', e, st);
    }
  }

  @override
  Future<void> removePersistedSession() => _forget();

  Future<void> _forget() async {
    try {
      await _storage.delete(key: _key);
    } on Object catch (e, st) {
      logFailure('SecureSessionStorage: could not remove the session', e, st);
    }
  }
}
