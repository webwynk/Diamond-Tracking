import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../errors/app_exceptions.dart';

/// The identifier that binds an employee account to one phone (PRD BR-13).
///
/// It is made once, saved on the phone, and sent at every sign-in, so signing
/// out, an expired session or a restart never changes it. Reinstalling the app
/// or clearing its data makes a new one: the server then refuses the sign-in
/// until an admin clears the binding, which is how an employee changes phone.
class DeviceIdService {
  const DeviceIdService._();

  static const String _storageKey = 'device_id';

  /// The id being made right now, so two sign-in attempts at once cannot make
  /// two different ids.
  static Future<String>? _inFlight;

  /// Returns this phone's identifier, making and saving it the first time.
  ///
  /// Throws [ServerException] when it cannot be saved: an id that is not kept
  /// would change on the next sign-in and lock the employee out.
  static Future<String> getDeviceId() {
    return _inFlight ??= _load().whenComplete(() => _inFlight = null);
  }

  static Future<String> _load() async {
    final preferences = await SharedPreferences.getInstance();
    final saved = preferences.getString(_storageKey);
    if (saved != null && saved.isNotEmpty) return saved;

    final id = _newId();
    final stored = await preferences.setString(_storageKey, id);
    if (!stored) {
      throw const ServerException(
        'This phone could not be prepared for sign-in. Please try again.',
      );
    }
    return id;
  }

  /// 128 bits from the system's secure random source.
  static String _newId() {
    final random = Random.secure();
    final parts = List.generate(
      4,
      (_) => random.nextInt(0x100000000).toRadixString(16).padLeft(8, '0'),
    );
    return 'device_${parts.join('-')}';
  }
}
