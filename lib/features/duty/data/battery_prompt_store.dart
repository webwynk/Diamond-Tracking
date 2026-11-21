import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Remembers when the "no battery limits" question was last shown, so duty
/// on asks it at most once a week (L52).
class BatteryPromptStore {
  BatteryPromptStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const String key = 'battery_prompt_at';

  /// How often the question may come back while it is still not allowed.
  static const Duration interval = Duration(days: 7);

  final FlutterSecureStorage _storage;

  /// Whether the question is due at [now]. When the date cannot be read,
  /// it is asked, as before.
  Future<bool> isDue(DateTime now) async {
    try {
      final DateTime? last = DateTime.tryParse(
        await _storage.read(key: key) ?? '',
      );
      return last == null || !now.isBefore(last.add(interval));
    } on Object {
      return true;
    }
  }

  Future<void> markAsked(DateTime now) async {
    try {
      await _storage.write(key: key, value: now.toUtc().toIso8601String());
    } on Object {
      // Not saved: the question just comes back at the next duty on.
    }
  }
}
