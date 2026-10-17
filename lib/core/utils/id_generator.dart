import 'dart:math';

/// Client-side identifiers for records that must be created offline and sent
/// to the server later (docs/08 section 6: every queued write carries a
/// client-generated id so a retried upload is recognised as a duplicate).
abstract final class IdGenerator {
  const IdGenerator._();

  static final Random _random = Random.secure();

  /// A random (version 4) UUID, e.g. `3f2b8c1e-9a4d-4c7e-b1f0-6d5a2e8c9b04`.
  static String uuidV4() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // RFC 4122 variant

    String hex(int from, int to) => bytes
        .sublist(from, to)
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();

    return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
  }
}
