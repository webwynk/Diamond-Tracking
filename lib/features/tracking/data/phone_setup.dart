import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/logging/app_log.dart';
import '../domain/phone_maker.dart';

/// The phone maker's own battery settings (Setup screen and duty on).
/// Overridden in tests.
abstract interface class PhoneSetup {
  /// The phone's maker when it has its own settings to change, else null.
  Future<PhoneMaker?> maker();

  /// Opens [page] (or the app's info page when the phone has no such page).
  Future<void> open(PhoneSettingsPage page);

  /// The employee tapped "I've done these".
  Future<bool> isDone();
  Future<void> markDone();

  /// Whether duty on should show the steps again: not done, and not shown
  /// in the last [askInterval].
  Future<bool> isDue(DateTime now);
  Future<void> markAsked(DateTime now);
}

/// How often duty on shows the steps while they are not done (like the
/// battery question, L52).
const Duration askInterval = Duration(days: 7);

class DevicePhoneSetup implements PhoneSetup {
  DevicePhoneSetup({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const MethodChannel _channel = MethodChannel(
    'com.diamondagritech.tracking/phone_setup',
  );
  static const String doneKey = 'phone_setup_done';
  static const String askedKey = 'phone_setup_asked_at';

  final FlutterSecureStorage _storage;
  PhoneMaker? _maker;
  bool _makerRead = false;

  @override
  Future<PhoneMaker?> maker() async {
    if (_makerRead) return _maker;
    try {
      final Map<Object?, Object?>? info = await _channel
          .invokeMapMethod<Object?, Object?>('maker');
      _maker = PhoneMaker.fromBuild(
        manufacturer: info?['manufacturer'] as String?,
        brand: info?['brand'] as String?,
      );
    } on Object {
      // Not on Android (tests): no maker steps.
      _maker = null;
    }
    _makerRead = true;
    return _maker;
  }

  @override
  Future<void> open(PhoneSettingsPage page) async {
    try {
      final String? opened = await _channel.invokeMethod<String>(
        'open',
        <String, Object?>{'page': page.wire},
      );
      AppLog.info('Phone setup: ${page.wire} opened ${opened ?? '-'}');
    } on Object catch (e) {
      AppLog.failure('PhoneSetup.open', e);
    }
  }

  @override
  Future<bool> isDone() async {
    try {
      return await _storage.read(key: doneKey) == 'yes';
    } on Object {
      return false;
    }
  }

  @override
  Future<void> markDone() async {
    try {
      await _storage.write(key: doneKey, value: 'yes');
    } on Object {
      // Not saved: the card just shows again next time.
    }
  }

  @override
  Future<bool> isDue(DateTime now) async {
    if (await maker() == null || await isDone()) return false;
    try {
      final DateTime? last = DateTime.tryParse(
        await _storage.read(key: askedKey) ?? '',
      );
      return last == null || !now.isBefore(last.add(askInterval));
    } on Object {
      return true;
    }
  }

  @override
  Future<void> markAsked(DateTime now) async {
    try {
      await _storage.write(key: askedKey, value: now.toUtc().toIso8601String());
    } on Object {
      // Not saved: shown again at the next duty on.
    }
  }
}
