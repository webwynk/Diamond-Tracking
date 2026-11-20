import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../logging/app_log.dart';

/// Keeps the signed-in session in the phone's encrypted key store instead of
/// plain preferences. The session holds a refresh token, which works like a
/// password until it is revoked.
///
/// Phase 4 runs GPS tracking in a background service with its own Supabase
/// client. That client must use this same storage and key, or it uploads
/// while signed out (the bug the audit found in the old app).
///
/// A session that cannot be read (for example after a restore onto another
/// phone) counts as signed out: the user signs in again instead of the app
/// failing to start.
class SecureSessionStorage extends LocalStorage {
  const SecureSessionStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const String key = 'diamond_supabase_session';

  final FlutterSecureStorage _storage;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> hasAccessToken() async => (await accessToken()) != null;

  @override
  Future<String?> accessToken() async {
    try {
      return await _storage.read(key: key);
    } on Object catch (e, st) {
      AppLog.failure('SecureSessionStorage.read', e, st);
      await _forget();
      return null;
    }
  }

  @override
  Future<void> persistSession(String persistSessionString) async {
    try {
      await _storage.write(key: key, value: persistSessionString);
    } on Object catch (e, st) {
      // Not saving means signing in again next time; it must not break the
      // sign-in happening now.
      AppLog.failure('SecureSessionStorage.write', e, st);
    }
  }

  @override
  Future<void> removePersistedSession() => _forget();

  Future<void> _forget() async {
    try {
      await _storage.delete(key: key);
    } on Object catch (e, st) {
      AppLog.failure('SecureSessionStorage.delete', e, st);
    }
  }
}
