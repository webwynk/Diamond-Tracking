import 'package:diamond_tracking/core/services/secure_session_storage.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A key store that cannot be read, like one whose key was lost in a restore.
class _BrokenStorage extends FlutterSecureStorage {
  const _BrokenStorage();

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) => throw StateError('BAD_DECRYPT');
}

void main() {
  const url = 'https://projectref.supabase.co';

  setUp(() {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test(
    'a saved session is read back, and removing it signs the person out',
    () async {
      final storage = SecureSessionStorage(supabaseUrl: url);
      await storage.initialize();

      expect(await storage.hasAccessToken(), isFalse);
      expect(await storage.accessToken(), isNull);

      await storage.persistSession('{"refresh_token":"abc"}');

      expect(await storage.hasAccessToken(), isTrue);
      expect(await storage.accessToken(), '{"refresh_token":"abc"}');

      await storage.removePersistedSession();

      expect(await storage.hasAccessToken(), isFalse);
      expect(await storage.accessToken(), isNull);
    },
  );

  test('the session is not written to plain preferences', () async {
    final storage = SecureSessionStorage(supabaseUrl: url);
    await storage.initialize();

    await storage.persistSession('{"refresh_token":"abc"}');

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getKeys(), isEmpty);
  });

  test(
    'a session left in plain preferences by an older version is removed',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'sb-projectref-auth-token': '{"refresh_token":"old"}',
        'something_else': 'kept',
      });
      final storage = SecureSessionStorage(supabaseUrl: url);

      await storage.initialize();

      final preferences = await SharedPreferences.getInstance();
      expect(preferences.containsKey('sb-projectref-auth-token'), isFalse);
      expect(preferences.getString('something_else'), 'kept');
      expect(await storage.hasAccessToken(), isFalse);
    },
  );

  test(
    'a session that cannot be read means "signed out", not a crash',
    () async {
      final storage = SecureSessionStorage(
        supabaseUrl: url,
        storage: const _BrokenStorage(),
      );
      await storage.initialize();

      expect(await storage.accessToken(), isNull);
      expect(await storage.hasAccessToken(), isFalse);
    },
  );
}
