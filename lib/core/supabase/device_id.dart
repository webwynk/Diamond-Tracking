import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// A random id for this app install, used for the one-phone-at-a-time rule.
///
/// It is created once and kept in encrypted storage. Uninstalling the app
/// removes it, so after a reinstall the admin resets the user's password,
/// which frees the account for the new install.
class DeviceIdStore {
  DeviceIdStore({FlutterSecureStorage? storage, Random? random})
    : _storage = storage ?? const FlutterSecureStorage(),
      _random = random ?? Random.secure();

  static const String key = 'diamond_device_id';

  final FlutterSecureStorage _storage;
  final Random _random;
  String? _cached;

  Future<String> get() async {
    final String? cached = _cached;
    if (cached != null) return cached;
    String? id = await _storage.read(key: key);
    if (id == null || id.length < 16) {
      id = List<String>.generate(
        32,
        (_) => _random.nextInt(16).toRadixString(16),
      ).join();
      await _storage.write(key: key, value: id);
    }
    return _cached = id;
  }
}
