import 'package:diamond_tracking/core/supabase/secure_session_storage.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('saves, reads and removes the session', () async {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    const SecureSessionStorage storage = SecureSessionStorage();
    expect(await storage.hasAccessToken(), isFalse);

    await storage.persistSession('{"token":"x"}');
    expect(await storage.accessToken(), '{"token":"x"}');

    await storage.removePersistedSession();
    expect(await storage.hasAccessToken(), isFalse);
  });
}
