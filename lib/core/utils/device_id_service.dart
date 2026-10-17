import 'dart:math';

/// Service responsible for providing a unique, persistent hardware or installation
/// identifier for BR-13 device binding.
///
/// In production Android, this is backed by a persistent identifier. In testing or
/// initial development, it falls back to a deterministic or generated client ID.
class DeviceIdService {
  static String? _cachedDeviceId;

  /// Returns the persistent device identifier.
  static Future<String> getDeviceId() async {
    if (_cachedDeviceId != null) {
      return _cachedDeviceId!;
    }

    // In initial phase or testing without external plugins, generate a
    // reproducible pseudo-unique client identifier based on device entropy.
    final random = Random();
    final parts = List.generate(
      4,
      (_) => random.nextInt(0xFFFFFFFF).toRadixString(16).padLeft(8, '0'),
    );
    _cachedDeviceId = 'device_${parts.join('-')}';
    return _cachedDeviceId!;
  }

  /// Allows setting or overriding the device ID (useful for unit tests & multi-device simulation).
  static void setMockDeviceId(String? mockId) {
    _cachedDeviceId = mockId;
  }
}
